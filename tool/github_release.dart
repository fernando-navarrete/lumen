// Publishes a vX.Y.Z tag's release files as a GitHub release (the `github-release` job, after `release`).
//
//   GITHUB_RELEASE_TOKEN=… dart tool/github_release.dart [--dry-run] \
//     --tag vX.Y.Z --commit <sha> --notes release_notes.md <asset>...
//
// The repository has immutable releases on, so a published release's assets can never change. The tool
// therefore waits until the push mirror has delivered the tag to GitHub at <sha>, then:
//   no release for the tag   creates a draft with the notes, uploads the assets, checks the draft's
//                            assets (names, sizes, sha256 digests) against the local files, publishes;
//   a draft (a failed run)   updates its notes, deletes its assets, then uploads, checks and publishes;
//   a published release      only compares its assets with the local files: a match is success, any
//                            difference fails (nothing is ever replaced).
// The release is marked "Latest" only when the tag is the highest published vX.Y.Z, so a hotfix on an
// older minor never becomes what the AppImages' `gh-releases-zsync|…|latest|…` update information
// points at. The token comes only from the environment and never appears in output.
//
// --dry-run sends no token and only GETs: it runs the mirror check, the release lookup and the
// published-release comparison, and prints every write it would make instead. Drafts are invisible
// without a token, so a dry run can't see one.
//
// Exit codes: 0 done (or nothing to do), 1 the release failed, 2 bad arguments. Imports only dart:*
// libraries, so the CI image runs it without `pub get`.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const githubOwner = 'fernando-navarrete';
const githubRepo = 'lumen';
const githubRemote = 'https://github.com/$githubOwner/$githubRepo.git';
const tokenVariable = 'GITHUB_RELEASE_TOKEN';
const _apiHost = 'api.github.com';
const _pageSize = 100;

const _usage =
    'usage: dart tool/github_release.dart [--dry-run] --tag vX.Y.Z --commit <sha> '
    '--notes <file> <asset>...';
const _permissionHint =
    '$tokenVariable is missing, expired, or lacks "Contents: read and write" '
    'on $githubOwner/$githubRepo';

class GitHubResponse {
  const GitHubResponse(this.status, this.body);

  final int status;
  final String body;
}

/// The HTTP seam: one request, the whole response body back.
abstract interface class GitHubHttp {
  /// Sends [json] (encoded) or [upload] (streamed, as octet-stream) as the body, if given.
  Future<GitHubResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers,
    Object? json,
    File? upload,
  });
}

/// Returns `git ls-remote <remote> <refs>`'s output.
typedef LsRemote = Future<String> Function(String remote, List<String> refs);

/// Returns [file]'s sha256 as lowercase hex.
typedef Sha256Of = Future<String> Function(File file);

class IoGitHubHttp implements GitHubHttp {
  final HttpClient _client = HttpClient()..userAgent = 'lumen-github-release';

  @override
  Future<GitHubResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    Object? json,
    File? upload,
  }) async {
    final request = await _client.openUrl(method, url);
    headers.forEach(request.headers.set);
    if (json != null) {
      final bytes = utf8.encode(jsonEncode(json));
      request.headers.contentType = ContentType.json;
      request.contentLength = bytes.length;
      request.add(bytes);
    } else if (upload != null) {
      request.headers.contentType = ContentType('application', 'octet-stream');
      request.contentLength = await upload.length();
      await request.addStream(upload.openRead());
    }
    final response = await request.close();
    final body = await const Utf8Decoder(
      allowMalformed: true,
    ).bind(response).join();
    return GitHubResponse(response.statusCode, body);
  }

  void close() => _client.close(force: true);
}

Future<String> gitLsRemote(String remote, List<String> refs) async {
  final result = await Process.run('git', ['ls-remote', remote, ...refs]);
  if (result.exitCode != 0) {
    throw ReleaseError(
      'git ls-remote $remote failed (exit ${result.exitCode}): '
      '${(result.stderr as String).trim()}',
    );
  }
  return result.stdout as String;
}

Future<String> sha256sum(File file) async {
  final result = await Process.run('sha256sum', [file.path]);
  if (result.exitCode != 0) {
    throw ReleaseError('sha256sum ${file.path} failed: ${result.stderr}');
  }
  return (result.stdout as String).split(' ').first.trim();
}

class ReleaseError implements Exception {
  const ReleaseError(this.message);

  final String message;

  @override
  String toString() => message;
}

class _UsageError implements Exception {
  const _UsageError(this.message);

  final String message;
}

class _LocalAsset {
  const _LocalAsset(this.file, this.name, this.size, this.sha256);

  final File file;
  final String name;
  final int size;
  final String sha256;
}

class _RemoteAsset {
  _RemoteAsset(Map<String, Object?> json)
    : id = json['id'] as int,
      name = json['name'] as String,
      size = json['size'] as int,
      state = json['state'] as String?,
      digest = json['digest'] as String?;

  final int id;
  final String name;
  final int size;
  final String? state;
  final String? digest;
}

class _Release {
  _Release(Map<String, Object?> json)
    : id = json['id'] as int,
      tagName = json['tag_name'] as String,
      draft = json['draft'] == true,
      prerelease = json['prerelease'] == true,
      uploadUrl = json['upload_url'] as String,
      htmlUrl = json['html_url'] as String? ?? '',
      immutable = json['immutable'] as bool?;

  final int id;
  final String tagName;
  final bool draft;
  final bool prerelease;
  final String uploadUrl;
  final String htmlUrl;
  final bool? immutable;
}

/// `[major, minor, patch]` of a `vX.Y.Z` tag, or null.
List<int>? parseReleaseTag(String tag) {
  final m = RegExp(r'^v(\d+)\.(\d+)\.(\d+)$').firstMatch(tag);
  if (m == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)];
}

int _compareVersions(List<int> a, List<int> b) {
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i].compareTo(b[i]);
  }
  return 0;
}

/// Whether [tag] should be GitHub's "Latest": no published, non-prerelease `vX.Y.Z` release is higher.
bool shouldMakeLatest(String tag, Iterable<String> publishedTags) {
  final version = parseReleaseTag(tag)!;
  return publishedTags
      .map(parseReleaseTag)
      .nonNulls
      .every((other) => _compareVersions(other, version) <= 0);
}

/// The commit `ls-remote` output gives for [tag]: the peeled `^{}` line for an annotated tag, else the tag
/// line itself. Null when the tag isn't there.
String? tagCommitFromLsRemote(String output, String tag) {
  String? direct;
  for (final line in const LineSplitter().convert(output)) {
    final parts = line.split('\t');
    if (parts.length != 2) continue;
    if (parts[1] == 'refs/tags/$tag^{}') return parts[0];
    if (parts[1] == 'refs/tags/$tag') direct = parts[0];
  }
  return direct;
}

class _GitHub {
  _GitHub(this._http, this._token);

  final GitHubHttp _http;
  final String? _token;

  Uri api(String path, [Map<String, String>? query]) =>
      Uri.https(_apiHost, '/repos/$githubOwner/$githubRepo$path', query);

  Future<Object?> call(
    String method,
    Uri url, {
    Object? json,
    File? upload,
    Set<int> ok = const {200},
  }) async {
    final write = method != 'GET';
    if (write && _token == null) {
      throw StateError(
        '$method $url without a token',
      ); // a dry run must never get here
    }
    final GitHubResponse response;
    try {
      response = await _http.send(
        method,
        url,
        headers: {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        json: json,
        upload: upload,
      );
    } on Object catch (e) {
      throw ReleaseError('$method $url failed: $e');
    }
    if (!ok.contains(response.status)) {
      final status = response.status;
      final hint = status == 401 || status == 403 || (status == 404 && write)
          ? ' ($_permissionHint)'
          : '';
      throw ReleaseError(
        '$method $url: HTTP $status ${_message(response.body)}$hint',
      );
    }
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }

  static String _message(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } on FormatException {
      // not JSON: fall through to the raw text
    }
    return body.length > 200 ? '${body.substring(0, 200)}…' : body;
  }

  Future<List<Map<String, Object?>>> _listAll(String path) async {
    final items = <Map<String, Object?>>[];
    for (var page = 1; ; page++) {
      final batch =
          await call(
                'GET',
                api(path, {'per_page': '$_pageSize', 'page': '$page'}),
              )
              as List<Object?>;
      items.addAll(batch.cast<Map<String, Object?>>());
      if (batch.length < _pageSize) return items;
    }
  }

  /// Every release, drafts included (when the token may see them): `releases/tags/<tag>` skips drafts.
  Future<List<_Release>> releases() async => [
    for (final json in await _listAll('/releases')) _Release(json),
  ];

  Future<List<_RemoteAsset>> assets(int releaseId) async => [
    for (final json in await _listAll('/releases/$releaseId/assets'))
      _RemoteAsset(json),
  ];

  Future<_Release> createDraft(String tag, String notes) async => _Release(
    await call(
          'POST',
          api('/releases'),
          json: {'tag_name': tag, 'name': tag, 'body': notes, 'draft': true},
          ok: const {201},
        )
        as Map<String, Object?>,
  );

  Future<void> updateNotes(int releaseId, String tag, String notes) => call(
    'PATCH',
    api('/releases/$releaseId'),
    json: {'name': tag, 'body': notes},
  );

  Future<void> deleteAsset(int assetId) =>
      call('DELETE', api('/releases/assets/$assetId'), ok: const {204});

  Future<void> upload(_Release release, _LocalAsset asset) => call(
    'POST',
    Uri.parse(
      release.uploadUrl.replaceFirst(RegExp(r'\{.*\}$'), ''),
    ).replace(queryParameters: {'name': asset.name}),
    upload: asset.file,
    ok: const {201},
  );

  Future<_Release> publish(int releaseId, {required bool makeLatest}) async =>
      _Release(
        await call(
              'PATCH',
              api('/releases/$releaseId'),
              json: {'draft': false, 'make_latest': '$makeLatest'},
            )
            as Map<String, Object?>,
      );
}

/// What differs between a release's [remote] assets and the [local] files; empty when they match.
List<String> _compareAssets(
  List<_RemoteAsset> remote,
  List<_LocalAsset> local,
) {
  final problems = <String>[];
  final byName = {for (final a in remote) a.name: a};
  for (final l in local) {
    final r = byName.remove(l.name);
    if (r == null) {
      problems.add('${l.name}: missing');
      continue;
    }
    if (r.state != null && r.state != 'uploaded') {
      problems.add('${l.name}: state ${r.state}, not uploaded');
    }
    if (r.size != l.size) {
      problems.add('${l.name}: ${r.size} bytes on GitHub, ${l.size} locally');
    }
    if (r.digest != null && r.digest != 'sha256:${l.sha256}') {
      problems.add(
        '${l.name}: ${r.digest} on GitHub, sha256:${l.sha256} locally',
      );
    }
  }
  for (final name in byName.keys) {
    problems.add('$name: on GitHub but not a local file');
  }
  return problems;
}

Future<int> runRelease(
  List<String> args, {
  Map<String, String>? environment,
  required GitHubHttp http,
  LsRemote lsRemote = gitLsRemote,
  Sha256Of sha256Of = sha256sum,
  StringSink? out,
  StringSink? err,
  Duration pollInterval = const Duration(seconds: 10),
  Duration mirrorTimeout = const Duration(minutes: 5),
}) async {
  out ??= stdout;
  err ??= stderr;
  final env = environment ?? Platform.environment;
  final token = env[tokenVariable];
  String redact(String s) =>
      token == null || token.isEmpty ? s : s.replaceAll(token, '***');

  try {
    final options = _parseArgs(args);
    final dryRun = options.dryRun;
    if (!dryRun && (token == null || token.isEmpty)) {
      throw _UsageError(
        '$tokenVariable is not set (a masked, protected variable scoped to the '
        'github-release environment)',
      );
    }
    final gh = _GitHub(http, dryRun ? null : token);
    final tag = options.tag;
    if (dryRun) out.writeln('github_release: dry run, no token, no writes');

    await _waitForMirror(
      tag,
      options.commit,
      lsRemote,
      out,
      err,
      pollInterval,
      mirrorTimeout,
    );

    final local = [
      for (final file in options.assets)
        _LocalAsset(
          file,
          file.uri.pathSegments.last,
          await file.length(),
          await sha256Of(file),
        ),
    ];
    final releases = await gh.releases();
    final matching = releases.where((r) => r.tagName == tag).toList();
    if (matching.length > 1) {
      throw ReleaseError(
        '${matching.length} releases on GitHub have tag $tag '
        '(ids ${matching.map((r) => r.id).join(', ')}): delete the extra drafts by hand',
      );
    }
    final makeLatest = shouldMakeLatest(tag, [
      for (final r in releases)
        if (!r.draft && !r.prerelease && r.tagName != tag) r.tagName,
    ]);

    if (matching.isNotEmpty && !matching.single.draft) {
      final release = matching.single;
      final problems = _compareAssets(await gh.assets(release.id), local);
      if (problems.isNotEmpty) {
        throw ReleaseError(
          'release $tag is already published and differs from the local files '
          '(published releases are immutable; cut a new tag):\n  ${problems.join('\n  ')}',
        );
      }
      out.writeln(
        'github_release: $tag is already published with the same '
        '${local.length} files: nothing to do (${release.htmlUrl})',
      );
      return 0;
    }

    if (dryRun) {
      if (matching.isEmpty) {
        out.writeln(
          'would create draft release $tag '
          '(notes: ${utf8.encode(options.notes).length} bytes)',
        );
      } else {
        out.writeln(
          'would update draft ${matching.single.id}\'s notes and delete its assets',
        );
      }
      for (final a in local) {
        out.writeln(
          'would upload ${a.name} (${a.size} bytes, sha256:${a.sha256})',
        );
      }
      out.writeln(
        'would check the draft\'s assets, then publish with make_latest=$makeLatest',
      );
      return 0;
    }

    final _Release draft;
    if (matching.isEmpty) {
      out.writeln('github_release: creating draft release $tag');
      draft = await gh.createDraft(tag, options.notes);
    } else {
      draft = matching.single;
      out.writeln(
        'github_release: reusing draft ${draft.id} from an earlier run',
      );
      await gh.updateNotes(draft.id, tag, options.notes);
      for (final asset in await gh.assets(draft.id)) {
        out.writeln('github_release: deleting ${asset.name} from the draft');
        await gh.deleteAsset(asset.id);
      }
    }
    for (final asset in local) {
      out.writeln(
        'github_release: uploading ${asset.name} (${asset.size} bytes)',
      );
      await gh.upload(draft, asset);
    }
    final problems = _compareAssets(await gh.assets(draft.id), local);
    if (problems.isNotEmpty) {
      throw ReleaseError(
        'draft $tag does not match the local files, not publishing '
        '(re-run the job):\n  ${problems.join('\n  ')}',
      );
    }
    final published = await gh.publish(draft.id, makeLatest: makeLatest);
    out.writeln(
      'github_release: published ${published.htmlUrl} (latest: $makeLatest)',
    );
    if (published.immutable == false) {
      err.writeln(
        'github_release: warning: GitHub reports the release as not immutable; '
        'check the repository\'s release immutability setting',
      );
    }
    return 0;
  } on _UsageError catch (e) {
    err.writeln('github_release: ${redact(e.message)}');
    err.writeln(_usage);
    return 2;
  } on Object catch (e) {
    err.writeln('github_release: ${redact('$e')}');
    return 1;
  }
}

Future<void> _waitForMirror(
  String tag,
  String commit,
  LsRemote lsRemote,
  StringSink out,
  StringSink err,
  Duration pollInterval,
  Duration timeout,
) async {
  final elapsed = Stopwatch()..start();
  while (true) {
    String? remoteCommit;
    try {
      remoteCommit = tagCommitFromLsRemote(
        await lsRemote(githubRemote, ['refs/tags/$tag', 'refs/tags/$tag^{}']),
        tag,
      );
    } on Object catch (e) {
      err.writeln('github_release: mirror check failed, retrying: $e');
    }
    if (remoteCommit != null) {
      if (remoteCommit != commit) {
        throw ReleaseError(
          '$tag is $remoteCommit on $githubRemote, but this pipeline built $commit',
        );
      }
      out.writeln('github_release: $tag is $commit on $githubRemote');
      return;
    }
    if (elapsed.elapsed >= timeout) {
      throw ReleaseError(
        '$tag did not reach $githubRemote within ${timeout.inSeconds}s: check '
        'GitLab\'s Settings → Repository → Mirroring repositories',
      );
    }
    out.writeln('github_release: waiting for the mirror to push $tag');
    await Future<void>.delayed(pollInterval);
  }
}

class _Options {
  const _Options(this.dryRun, this.tag, this.commit, this.notes, this.assets);

  final bool dryRun;
  final String tag;
  final String commit;
  final String notes;
  final List<File> assets;
}

_Options _parseArgs(List<String> args) {
  var dryRun = false;
  String? tag;
  String? commit;
  String? notesPath;
  final assets = <String>[];
  for (var i = 0; i < args.length; i++) {
    String value() {
      if (i + 1 >= args.length) throw _UsageError('${args[i]} needs a value');
      return args[++i];
    }

    switch (args[i]) {
      case '--dry-run':
        dryRun = true;
      case '--tag':
        tag = value();
      case '--commit':
        commit = value();
      case '--notes':
        notesPath = value();
      case final a when a.startsWith('--'):
        throw _UsageError('unknown option $a');
      case final a:
        assets.add(a);
    }
  }
  if (tag == null || parseReleaseTag(tag) == null) {
    throw _UsageError('--tag must be a vX.Y.Z tag, got ${tag ?? 'nothing'}');
  }
  if (commit == null || !RegExp(r'^[0-9a-f]{40}$').hasMatch(commit)) {
    throw _UsageError(
      '--commit must be a full commit SHA, got ${commit ?? 'nothing'}',
    );
  }
  if (notesPath == null) throw const _UsageError('--notes is required');
  final notesFile = File(notesPath);
  if (!notesFile.existsSync()) {
    throw _UsageError('notes file $notesPath does not exist');
  }
  final notes = notesFile.readAsStringSync();
  if (notes.trim().isEmpty) throw _UsageError('notes file $notesPath is empty');
  if (assets.isEmpty) throw const _UsageError('no assets given');
  final files = [for (final a in assets) File(a)];
  final names = <String>{};
  for (final f in files) {
    if (!f.existsSync()) throw _UsageError('asset ${f.path} does not exist');
    if (!names.add(f.uri.pathSegments.last)) {
      throw _UsageError('two assets are named ${f.uri.pathSegments.last}');
    }
  }
  return _Options(dryRun, tag, commit, notes, files);
}

Future<void> main(List<String> args) async {
  final http = IoGitHubHttp();
  final int code;
  try {
    code = await runRelease(args, http: http);
  } finally {
    http.close();
  }
  exit(code);
}
