import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/github_release.dart';

const _token = 'github_pat_SECRET123';
const _commit = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _other = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _repoPath = '/repos/$githubOwner/$githubRepo';

/// Stands in for sha256sum: a stable digest of the file's contents.
String _digestOf(File f) =>
    base64Url.encode(f.readAsBytesSync()).replaceAll('=', '');

Future<String> _fakeSha(File f) async => _digestOf(f);

class _Request {
  _Request(this.method, this.url, this.headers, this.json, this.upload);

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final Object? json;
  final File? upload;

  @override
  String toString() => '$method ${url.path}';
}

/// An in-memory GitHub releases API.
class _FakeGitHub implements GitHubHttp {
  final releases = <Map<String, Object?>>[];
  final assets = <int, List<Map<String, Object?>>>{};
  final requests = <_Request>[];

  /// `'METHOD path'` → status to fail that request with.
  final failures = <String, int>{};

  /// Asset name → bytes added to its uploaded size, to fake a corrupt upload.
  final uploadSizeDelta = <String, int>{};
  int _nextId = 100;

  List<_Request> get writes => [
    for (final r in requests)
      if (r.method != 'GET') r,
  ];

  Map<String, Object?> addRelease(
    String tag, {
    bool draft = false,
    bool prerelease = false,
    List<File> files = const [],
  }) {
    final id = _nextId++;
    final release = <String, Object?>{
      'id': id,
      'tag_name': tag,
      'name': tag,
      'body': '',
      'draft': draft,
      'prerelease': prerelease,
      'immutable': !draft,
      'upload_url':
          'https://uploads.github.com$_repoPath/releases/$id/assets{?name,label}',
      'html_url': 'https://github.com/$githubOwner/$githubRepo/releases/$tag',
    };
    releases.add(release);
    assets[id] = [];
    for (final f in files) {
      _addAsset(id, f.uri.pathSegments.last, f);
    }
    return release;
  }

  void _addAsset(int releaseId, String name, File file) {
    assets[releaseId]!.add({
      'id': _nextId++,
      'name': name,
      'size': file.lengthSync() + (uploadSizeDelta[name] ?? 0),
      'state': 'uploaded',
      'digest': 'sha256:${_digestOf(file)}',
    });
  }

  GitHubResponse _json(Object? body, [int status = 200]) =>
      GitHubResponse(status, jsonEncode(body));

  @override
  Future<GitHubResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    Object? json,
    File? upload,
  }) async {
    requests.add(_Request(method, url, headers, json, upload));
    final failure = failures['$method ${url.path}'];
    if (failure != null) {
      return _json({'message': 'Bad credentials'}, failure);
    }
    final path = url.path;
    final page = int.tryParse(url.queryParameters['page'] ?? '1') ?? 1;
    final perPage = int.tryParse(url.queryParameters['per_page'] ?? '30') ?? 30;
    List<Object?> paged(List<Object?> all) =>
        all.skip((page - 1) * perPage).take(perPage).toList();

    if (url.host == 'uploads.github.com' && method == 'POST') {
      final id = int.parse(
        RegExp(r'/releases/(\d+)/assets$').firstMatch(path)!.group(1)!,
      );
      _addAsset(id, url.queryParameters['name']!, upload!);
      return _json(assets[id]!.last, 201);
    }
    if (path == '$_repoPath/releases' && method == 'GET') {
      return _json(paged(releases));
    }
    if (path == '$_repoPath/releases' && method == 'POST') {
      final body = json! as Map<String, Object?>;
      final release = addRelease(body['tag_name']! as String, draft: true)
        ..['body'] = body['body'];
      return _json(release, 201);
    }
    final assetList = RegExp(r'/releases/(\d+)/assets$').firstMatch(path);
    if (assetList != null && method == 'GET') {
      return _json(paged(assets[int.parse(assetList.group(1)!)]!));
    }
    final assetDelete = RegExp(r'/releases/assets/(\d+)$').firstMatch(path);
    if (assetDelete != null && method == 'DELETE') {
      final id = int.parse(assetDelete.group(1)!);
      for (final list in assets.values) {
        list.removeWhere((a) => a['id'] == id);
      }
      return const GitHubResponse(204, '');
    }
    final releaseEdit = RegExp(r'/releases/(\d+)$').firstMatch(path);
    if (releaseEdit != null && method == 'PATCH') {
      final id = int.parse(releaseEdit.group(1)!);
      final release = releases.singleWhere((r) => r['id'] == id);
      release.addAll(json! as Map<String, Object?>);
      if (release['draft'] == false) release['immutable'] = true;
      return _json(release);
    }
    return _json({'message': 'Not Found'}, 404);
  }
}

void main() {
  late Directory dir;
  late File notes;
  late List<File> files;
  late _FakeGitHub github;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('github_release_test');
    notes = File('${dir.path}/release_notes.md')
      ..writeAsStringSync('- Notes\n');
    files = [
      for (final (name, body) in [
        ('Lumen-1.6.0-x86_64.AppImage', 'appimage bytes'),
        ('Lumen-1.6.0-x86_64.AppImage.sha256', 'checksum'),
        ('Lumen-1.6.0-x86_64.AppImage.zsync', 'zsync control'),
      ])
        File('${dir.path}/$name')..writeAsStringSync(body),
    ];
    github = _FakeGitHub();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  String tagLine(String tag, String sha) => '$sha\trefs/tags/$tag\n';

  Future<(int, String, String)> run({
    String tag = 'v1.6.0',
    bool dryRun = false,
    Map<String, String> env = const {tokenVariable: _token},
    LsRemote? lsRemote,
    List<String>? assets,
    Duration mirrorTimeout = const Duration(minutes: 1),
  }) async {
    final out = StringBuffer();
    final err = StringBuffer();
    final code = await runRelease(
      [
        if (dryRun) '--dry-run',
        '--tag',
        tag,
        '--commit',
        _commit,
        '--notes',
        notes.path,
        ...(assets ?? [for (final f in files) f.path]),
      ],
      environment: env,
      http: github,
      lsRemote: lsRemote ?? (_, _) async => tagLine(tag, _commit),
      sha256Of: _fakeSha,
      out: out,
      err: err,
      pollInterval: Duration.zero,
      mirrorTimeout: mirrorTimeout,
    );
    return (code, '$out', '$err');
  }

  Map<String, Object?> releaseFor(String tag) =>
      github.releases.singleWhere((r) => r['tag_name'] == tag);

  group('create', () {
    test('drafts, uploads three files, checks them, then publishes', () async {
      final (code, _, err) = await run();
      expect(code, 0, reason: err);
      expect(github.writes.map((r) => '$r'), [
        'POST $_repoPath/releases',
        'POST $_repoPath/releases/100/assets',
        'POST $_repoPath/releases/100/assets',
        'POST $_repoPath/releases/100/assets',
        'PATCH $_repoPath/releases/100',
      ]);
      expect(github.writes.first.json, {
        'tag_name': 'v1.6.0',
        'name': 'v1.6.0',
        'body': '- Notes\n',
        'draft': true,
      });
      final uploads = github.writes.where((r) => r.upload != null);
      expect(uploads.map((r) => r.url.queryParameters['name']), [
        for (final f in files) f.uri.pathSegments.last,
      ]);
      expect(uploads.first.url.host, 'uploads.github.com');
      // The draft's assets are listed (checked) between the last upload and the publish.
      final publishAt = github.requests.indexWhere((r) => r.method == 'PATCH');
      expect(github.requests[publishAt - 1].method, 'GET');
      expect(github.requests[publishAt - 1].url.path, endsWith('/assets'));
      expect(github.requests[publishAt].json, {
        'draft': false,
        'make_latest': 'true',
      });
      expect(releaseFor('v1.6.0')['draft'], false);
    });

    test('a newer tag than every published release is latest', () async {
      github.addRelease('v1.5.2');
      github.addRelease('v2.0.0-rc1'); // not vX.Y.Z: ignored
      await run();
      expect((github.writes.last.json! as Map)['make_latest'], 'true');
    });

    test('a hotfix below a published release is not latest', () async {
      github.addRelease('v1.6.0');
      github.addRelease('v1.5.2');
      final (code, _, err) = await run(tag: 'v1.5.3');
      expect(code, 0, reason: err);
      expect((github.writes.last.json! as Map)['make_latest'], 'false');
    });

    test('drafts and prereleases do not count against latest', () async {
      github.addRelease('v1.7.0', draft: true);
      github.addRelease('v1.8.0', prerelease: true);
      await run();
      expect((github.writes.last.json! as Map)['make_latest'], 'true');
    });

    test('a corrupt upload fails before publishing', () async {
      github.uploadSizeDelta['Lumen-1.6.0-x86_64.AppImage'] = -1;
      final (code, _, err) = await run();
      expect(code, 1);
      expect(err, contains('not publishing'));
      expect(
        err,
        contains('Lumen-1.6.0-x86_64.AppImage: 13 bytes on GitHub, 14 locally'),
      );
      expect(github.writes.where((r) => r.method == 'PATCH'), isEmpty);
      expect(releaseFor('v1.6.0')['draft'], true);
    });

    test('lists releases across pages', () async {
      for (var i = 0; i < 100; i++) {
        github.addRelease('v0.0.$i');
      }
      github.addRelease('v1.7.0');
      await run();
      final pages = github.requests
          .where(
            (r) => r.method == 'GET' && r.url.path == '$_repoPath/releases',
          )
          .map((r) => r.url.queryParameters['page']);
      expect(pages, ['1', '2']);
      expect((github.writes.last.json! as Map)['make_latest'], 'false');
    });
  });

  group('re-runs', () {
    test('a draft from a failed run gets new notes and assets', () async {
      final draft = github.addRelease(
        'v1.6.0',
        draft: true,
        files: [files.first],
      );
      final id = draft['id'];
      final (code, _, err) = await run();
      expect(code, 0, reason: err);
      expect(github.writes.map((r) => '$r'), [
        'PATCH $_repoPath/releases/$id',
        'DELETE $_repoPath/releases/assets/${(id! as int) + 1}',
        'POST $_repoPath/releases/$id/assets',
        'POST $_repoPath/releases/$id/assets',
        'POST $_repoPath/releases/$id/assets',
        'PATCH $_repoPath/releases/$id',
      ]);
      expect(github.writes.first.json, {'name': 'v1.6.0', 'body': '- Notes\n'});
      expect(github.assets[id], hasLength(3));
      expect(releaseFor('v1.6.0')['draft'], false);
    });

    test('a matching published release is left alone', () async {
      github.addRelease('v1.6.0', files: files);
      final (code, out, err) = await run();
      expect(code, 0, reason: err);
      expect(out, contains('nothing to do'));
      expect(github.writes, isEmpty);
    });

    test('a published release with another size fails', () async {
      github.uploadSizeDelta['Lumen-1.6.0-x86_64.AppImage.zsync'] = 5;
      github.addRelease('v1.6.0', files: files);
      final (code, _, err) = await run();
      expect(code, 1);
      expect(err, contains('immutable'));
      expect(err, contains('.zsync: 18 bytes on GitHub, 13 locally'));
      expect(github.writes, isEmpty);
    });

    test('a published release with another digest fails', () async {
      github.addRelease('v1.6.0', files: files);
      files.first.writeAsStringSync(
        'APPIMAGE BYTES',
      ); // same size, other content
      final (code, _, err) = await run();
      expect(code, 1);
      expect(err, contains('Lumen-1.6.0-x86_64.AppImage: sha256:'));
      expect(github.writes, isEmpty);
    });

    test('a published release missing a file fails', () async {
      github.addRelease('v1.6.0', files: files.take(2).toList());
      final (code, _, err) = await run();
      expect(code, 1);
      expect(err, contains('.zsync: missing'));
    });

    test('two releases for the tag fail', () async {
      github.addRelease('v1.6.0', draft: true);
      github.addRelease('v1.6.0', draft: true);
      final (code, _, err) = await run();
      expect(code, 1);
      expect(err, contains('2 releases on GitHub have tag v1.6.0'));
      expect(github.writes, isEmpty);
    });
  });

  group('token', () {
    for (final status in [401, 403]) {
      test('HTTP $status names the permission', () async {
        github.failures['POST $_repoPath/releases'] = status;
        final (code, out, err) = await run();
        expect(code, 1);
        expect(err, contains('HTTP $status Bad credentials'));
        expect(err, contains('Contents: read and write'));
        expect('$out$err', isNot(contains(_token)));
      });
    }

    test('is sent as a bearer token on every request', () async {
      await run();
      expect(github.requests.map((r) => r.headers['Authorization']).toSet(), {
        'Bearer $_token',
      });
    });

    test('is redacted from an error that contains it', () async {
      final buffer = StringBuffer();
      final code = await runRelease(
        [
          '--tag',
          'v1.6.0',
          '--commit',
          _commit,
          '--notes',
          notes.path,
          files.first.path,
        ],
        environment: const {tokenVariable: _token},
        http: _ThrowingHttp(),
        lsRemote: (_, _) async => tagLine('v1.6.0', _commit),
        sha256Of: _fakeSha,
        out: buffer,
        err: buffer,
      );
      expect(code, 1);
      expect('$buffer', contains('Bearer ***'));
      expect('$buffer', isNot(contains(_token)));
    });

    test('a real run without it is a usage error', () async {
      final (code, _, err) = await run(env: const {});
      expect(code, 2);
      expect(err, contains('$tokenVariable is not set'));
      expect(github.requests, isEmpty);
    });
  });

  group('dry run', () {
    test('sends no token and no writes, and prints the plan', () async {
      github.addRelease('v1.5.2');
      final (code, out, err) = await run(dryRun: true);
      expect(code, 0, reason: err);
      expect(github.writes, isEmpty);
      expect(github.requests, isNotEmpty);
      expect(
        github.requests.where((r) => r.headers.containsKey('Authorization')),
        isEmpty,
      );
      expect(out, contains('would create draft release v1.6.0'));
      expect(
        out,
        contains('would upload Lumen-1.6.0-x86_64.AppImage (14 bytes'),
      );
      expect(out, contains('make_latest=true'));
    });

    test('works without a token', () async {
      final (code, _, err) = await run(dryRun: true, env: const {});
      expect(code, 0, reason: err);
    });

    test('still checks a published release', () async {
      github.uploadSizeDelta['Lumen-1.6.0-x86_64.AppImage'] = 1;
      github.addRelease('v1.6.0', files: files);
      final (code, _, err) = await run(dryRun: true);
      expect(code, 1);
      expect(err, contains('already published and differs'));
      expect(github.writes, isEmpty);
    });
  });

  group('mirror', () {
    test('uses the peeled commit of an annotated tag', () async {
      final (code, _, err) = await run(
        lsRemote: (_, _) async =>
            '$_other\trefs/tags/v1.6.0\n$_commit\trefs/tags/v1.6.0^{}\n',
      );
      expect(code, 0, reason: err);
    });

    test('waits until the tag arrives', () async {
      var calls = 0;
      final (code, out, err) = await run(
        lsRemote: (remote, refs) async {
          expect(remote, githubRemote);
          expect(refs, ['refs/tags/v1.6.0', 'refs/tags/v1.6.0^{}']);
          return ++calls < 3 ? '' : tagLine('v1.6.0', _commit);
        },
      );
      expect(code, 0, reason: err);
      expect(calls, 3);
      expect(out, contains('waiting for the mirror'));
    });

    test('keeps polling through a failed ls-remote', () async {
      var calls = 0;
      final (code, _, err) = await run(
        lsRemote: (_, _) async {
          if (++calls == 1) throw const ReleaseError('network down');
          return tagLine('v1.6.0', _commit);
        },
      );
      expect(code, 0);
      expect(err, contains('network down'));
    });

    test('fails at once when the tag is on another commit', () async {
      var calls = 0;
      final (code, _, err) = await run(
        lsRemote: (_, _) async {
          calls++;
          return tagLine('v1.6.0', _other);
        },
      );
      expect(code, 1);
      expect(calls, 1);
      expect(err, contains('v1.6.0 is $_other'));
      expect(github.requests, isEmpty);
    });

    test('times out with a pointer to the mirroring settings', () async {
      final (code, _, err) = await run(
        lsRemote: (_, _) async => '',
        mirrorTimeout: Duration.zero,
      );
      expect(code, 1);
      expect(err, contains('Mirroring repositories'));
      expect(github.requests, isEmpty);
    });
  });

  group('arguments', () {
    test('a tag that is not vX.Y.Z is a usage error', () async {
      final (code, _, err) = await run(tag: 'v1.6');
      expect(code, 2);
      expect(err, contains('vX.Y.Z'));
    });

    test('two assets with the same name are a usage error', () async {
      final copy = Directory('${dir.path}/copy')..createSync();
      final dup = File('${copy.path}/${files.first.uri.pathSegments.last}')
        ..writeAsStringSync('x');
      final (code, _, err) = await run(assets: [files.first.path, dup.path]);
      expect(code, 2);
      expect(err, contains('two assets are named'));
    });

    test('a missing asset is a usage error', () async {
      final (code, _, err) = await run(assets: ['${dir.path}/nope']);
      expect(code, 2);
      expect(err, contains('does not exist'));
    });

    test('no assets is a usage error', () async {
      final (code, _, _) = await run(assets: []);
      expect(code, 2);
    });
  });

  test('shouldMakeLatest compares versions numerically', () {
    expect(shouldMakeLatest('v1.10.0', ['v1.9.9', 'v1.2.0']), isTrue);
    expect(shouldMakeLatest('v1.9.0', ['v1.10.0']), isFalse);
    expect(shouldMakeLatest('v1.6.0', []), isTrue);
  });

  test('tagCommitFromLsRemote prefers the peeled line', () {
    expect(tagCommitFromLsRemote('', 'v1.0.0'), isNull);
    expect(
      tagCommitFromLsRemote('$_commit\trefs/tags/v1.0.0\n', 'v1.0.0'),
      _commit,
    );
    expect(
      tagCommitFromLsRemote(
        '$_other\trefs/tags/v1.0.0\n$_commit\trefs/tags/v1.0.0^{}\n',
        'v1.0.0',
      ),
      _commit,
    );
    expect(
      tagCommitFromLsRemote('$_commit\trefs/tags/v1.0.00\n', 'v1.0.0'),
      isNull,
    );
  });
}

/// Fails every request with an exception that quotes the token, as a careless HTTP layer might.
class _ThrowingHttp implements GitHubHttp {
  @override
  Future<GitHubResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    Object? json,
    File? upload,
  }) async => throw SocketException('refused (${headers['Authorization']})');
}
