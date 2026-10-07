// Decides whether `scan`'s OSV-Scanner report fails the pipeline.
//
//   dart tool/osv_gate.dart osv-scanner.json
//
// Every advisory group left after osv-scanner.toml's ignores is either
//   VULN  a real vulnerability: fails the job, or
//   INFO  a RUSTSEC informational advisory (`unmaintained`, `unsound`, `notice`):
//         printed and kept in the report, never fails.
// A group is INFO when one of its advisories carries a non-null
// `affected[].database_specific.informational` (only RUSTSEC records have the
// field; its GHSA aliases don't). Exit codes: 0 pass, 1 a VULN remains, 2 the
// report is missing or unreadable.
//
// Imports only dart:convert and dart:io, so the CI image runs it without
// `pub get` (the image has dart but no jq).
import 'dart:convert';
import 'dart:io';

enum OsvKind { vuln, info }

class OsvFinding {
  const OsvFinding(this.kind, this.package, this.version, this.ids);

  final OsvKind kind;
  final String package;
  final String version;
  final List<String> ids;

  @override
  String toString() =>
      '${kind == OsvKind.vuln ? 'VULN' : 'INFO'}  $package $version  ${ids.join(', ')}';
}

/// Classifies every advisory group in a decoded OSV-Scanner JSON [report].
List<OsvFinding> classifyOsv(Map<String, Object?> report) {
  final findings = <OsvFinding>[];
  for (final result in _list(report['results'])) {
    for (final pkg in _list(_map(result)['packages'])) {
      final pkgMap = _map(pkg);
      final info = _map(pkgMap['package']);
      final informationalIds = <String>{
        for (final vuln in _list(pkgMap['vulnerabilities']))
          if (_isInformational(_map(vuln))) _map(vuln)['id'] as String,
      };
      for (final group in _list(pkgMap['groups'])) {
        final ids = [for (final id in _list(_map(group)['ids'])) id as String];
        findings.add(
          OsvFinding(
            ids.any(informationalIds.contains) ? OsvKind.info : OsvKind.vuln,
            info['name'] as String? ?? '?',
            info['version'] as String? ?? '?',
            ids,
          ),
        );
      }
    }
  }
  return findings;
}

bool _isInformational(Map<String, Object?> vuln) => _list(
  vuln['affected'],
).any((a) => _map(_map(a)['database_specific'])['informational'] != null);

List<Object?> _list(Object? v) => v is List ? v : const [];

Map<String, Object?> _map(Object? v) =>
    v is Map<String, Object?> ? v : const {};

int runGate(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart tool/osv_gate.dart <osv-scanner.json>');
    return 2;
  }
  final List<OsvFinding> findings;
  try {
    final decoded = jsonDecode(File(args.single).readAsStringSync());
    findings = classifyOsv(_map(decoded));
  } on Object catch (e) {
    stderr.writeln('osv_gate: cannot read ${args.single}: $e');
    return 2;
  }
  findings.forEach(stdout.writeln);
  final vulns = findings.where((f) => f.kind == OsvKind.vuln).length;
  final infos = findings.length - vulns;
  stdout.writeln(
    'osv_gate: $vulns vulnerabilities, $infos informational (not gating)',
  );
  return vulns > 0 ? 1 : 0;
}

void main(List<String> args) => exit(runGate(args));
