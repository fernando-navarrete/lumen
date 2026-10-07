import 'package:flutter_test/flutter_test.dart';

import '../../tool/osv_gate.dart';

Map<String, Object?> _vuln(String id, {Object? informational}) => {
  'id': id,
  'affected': [
    {
      'database_specific': {'informational': informational},
    },
  ],
};

Map<String, Object?> _report(List<Map<String, Object?>> packages) => {
  'results': [
    {
      'source': {'path': 'Cargo.lock', 'type': 'lockfile'},
      'packages': packages,
    },
  ],
};

Map<String, Object?> _package(
  String name,
  List<List<String>> groups,
  List<Map<String, Object?>> vulns,
) => {
  'package': {'name': name, 'version': '1.0.0', 'ecosystem': 'crates.io'},
  'groups': [
    for (final ids in groups) {'ids': ids},
  ],
  'vulnerabilities': vulns,
};

void main() {
  test('an empty report has no findings', () {
    expect(classifyOsv({'results': <Object?>[]}), isEmpty);
    expect(classifyOsv(const {}), isEmpty);
  });

  test(
    'a RUSTSEC advisory with a null informational flag is a vulnerability',
    () {
      final findings = classifyOsv(
        _report([
          _package(
            'rustls',
            [
              ['RUSTSEC-1', 'GHSA-1'],
            ],
            [
              _vuln('RUSTSEC-1'),
              {'id': 'GHSA-1'},
            ],
          ),
        ]),
      );
      expect(findings, hasLength(1));
      expect(findings.single.kind, OsvKind.vuln);
      expect(findings.single.ids, ['RUSTSEC-1', 'GHSA-1']);
    },
  );

  test('unmaintained and unsound advisories are informational', () {
    final findings = classifyOsv(
      _report([
        _package(
          'adler',
          [
            ['RUSTSEC-2'],
          ],
          [_vuln('RUSTSEC-2', informational: 'unmaintained')],
        ),
        _package(
          'anyhow',
          [
            ['RUSTSEC-3'],
          ],
          [_vuln('RUSTSEC-3', informational: 'unsound')],
        ),
      ]),
    );
    expect(findings.map((f) => f.kind), [OsvKind.info, OsvKind.info]);
  });

  test('a mixed report keeps each group on its own side', () {
    final findings = classifyOsv(
      _report([
        _package(
          'adler',
          [
            ['RUSTSEC-2'],
          ],
          [_vuln('RUSTSEC-2', informational: 'unmaintained')],
        ),
        _package(
          'rustls',
          [
            ['RUSTSEC-1', 'GHSA-1'],
          ],
          [
            _vuln('RUSTSEC-1'),
            {'id': 'GHSA-1'},
          ],
        ),
      ]),
    );
    expect(findings.map((f) => f.kind), [OsvKind.info, OsvKind.vuln]);
    expect(findings.last.package, 'rustls');
  });

  test('an informational advisory in a group makes the whole group INFO', () {
    final findings = classifyOsv(
      _report([
        _package(
          'foo',
          [
            ['GHSA-9', 'RUSTSEC-9'],
          ],
          [
            {'id': 'GHSA-9'},
            _vuln('RUSTSEC-9', informational: 'unmaintained'),
          ],
        ),
      ]),
    );
    expect(findings.single.kind, OsvKind.info);
  });
}
