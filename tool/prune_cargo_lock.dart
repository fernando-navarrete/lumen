// Prunes a Cargo.lock to the crates Cargo actually resolves for a build.
//
//   dart tool/prune_cargo_lock.dart <Cargo.lock> <cargo-tree.txt> <out Cargo.lock>
//
// <cargo-tree.txt> is `cargo tree --locked --target all --all-features -e normal,build,dev
// --prefix none --format '{p}'` run next to the lockfile. A lockfile also lists optional
// dependencies that no enabled feature turns on (reqwest's `quinn?/…` weak reference keeps
// `quinn-proto` there), and OSV-Scanner flags those although nothing compiles them. Scanning
// the pruned file keeps the gate honest without an ignore list: a crate that joins the build
// graph later is in `cargo tree`, so it stays in the file and is scanned.
//
// Exit codes: 0 written, 2 bad arguments, an unreadable file, an empty tree, or a crate in the
// tree that the lockfile doesn't list (one of the two parsers is wrong, and scanning less must
// never pass silently).
//
// Imports only dart:io, so the CI image runs it without `pub get`.
import 'dart:io';

/// Each crate in `cargo tree --prefix none --format '{p}'` output as `name version`.
Set<String> parseCargoTree(String text) {
  final crates = <String>{};
  final line = RegExp(r'^(\S+) v(\S+)(?: |$)');
  for (final raw in text.split('\n')) {
    final match = line.firstMatch(raw.trim());
    if (match != null) crates.add('${match[1]} ${match[2]}');
  }
  return crates;
}

/// [lock] without the `[[package]]` blocks whose `name version` is not in [keep]; the header
/// and the kept blocks are copied unchanged. [dropped] lists what was removed, and [missing]
/// the [keep] entries that [lock] doesn't have.
({String lock, List<String> dropped, List<String> missing}) pruneCargoLock(
  String lock,
  Set<String> keep,
) {
  final parts = lock.split(RegExp(r'^\[\[package\]\]\n', multiLine: true));
  final out = StringBuffer(parts.first);
  final dropped = <String>[];
  final found = <String>{};
  final name = RegExp(r'^name = "([^"]+)"', multiLine: true);
  final version = RegExp(r'^version = "([^"]+)"', multiLine: true);
  for (final block in parts.skip(1)) {
    final id = '${name.firstMatch(block)?[1]} ${version.firstMatch(block)?[1]}';
    if (keep.contains(id)) {
      found.add(id);
      out.write('[[package]]\n$block');
    } else {
      dropped.add(id);
    }
  }
  final text = out.toString().trimRight();
  return (
    lock: '$text\n',
    dropped: dropped,
    missing: (keep.difference(found).toList()..sort()),
  );
}

int runPrune(List<String> args) {
  if (args.length != 3) {
    stderr.writeln(
      'usage: dart tool/prune_cargo_lock.dart <Cargo.lock> <cargo-tree.txt> '
      '<out Cargo.lock>',
    );
    return 2;
  }
  final String lock;
  final String tree;
  try {
    lock = File(args[0]).readAsStringSync();
    tree = File(args[1]).readAsStringSync();
  } on Object catch (e) {
    stderr.writeln('prune_cargo_lock: cannot read input: $e');
    return 2;
  }
  final keep = parseCargoTree(tree);
  if (keep.isEmpty) {
    stderr.writeln('prune_cargo_lock: ${args[1]} lists no crates');
    return 2;
  }
  final pruned = pruneCargoLock(lock, keep);
  if (pruned.missing.isNotEmpty) {
    stderr.writeln(
      'prune_cargo_lock: in cargo tree but not in ${args[0]}: '
      '${pruned.missing.join(', ')}',
    );
    return 2;
  }
  File(args[2]).writeAsStringSync(pruned.lock);
  stdout.writeln(
    'prune_cargo_lock: kept ${keep.length} of '
    '${keep.length + pruned.dropped.length} crates; dropped (not in the build '
    'graph): ${pruned.dropped.join(', ')}',
  );
  return 0;
}

void main(List<String> args) => exit(runPrune(args));
