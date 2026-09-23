/// Splits [input] into words using a small POSIX-shell-like subset, so a
/// launch-args or wrapper field can hold words that contain spaces:
///
/// - whitespace (space, tab, CR, LF) separates words; runs of it collapse,
///   and leading/trailing whitespace is ignored (blank input gives `[]`),
/// - `'…'` is fully literal,
/// - `"…"` is literal except that `\"` and `\\` escape (any other `\x` is
///   kept as-is, backslash included),
/// - outside quotes, `\` escapes the next character,
/// - quotes join with adjacent text (`--dir="a b"` is the one word
///   `--dir=a b`),
/// - `""` or `''` gives an empty word; it is not dropped.
///
/// There is deliberately **no** variable expansion (`$VAR`), `~`, globbing
/// or command substitution, and `;`, `|`, `&`, `#` etc. are ordinary
/// characters: the words are passed straight to `Process.start`, never
/// through a shell.
///
/// Throws a [FormatException] on an unterminated quote or a trailing lone
/// `\`.
List<String> splitShellWords(String input) {
  final words = <String>[];
  final current = StringBuffer();
  // Tracked separately from `current.isEmpty` so `""` still yields a word.
  var inWord = false;
  var i = 0;

  while (i < input.length) {
    final char = input[i];
    if (_isWhitespace(char)) {
      if (inWord) {
        words.add(current.toString());
        current.clear();
        inWord = false;
      }
      i++;
    } else if (char == "'") {
      final close = input.indexOf("'", i + 1);
      if (close == -1) {
        throw FormatException('Unterminated single quote', input, i);
      }
      current.write(input.substring(i + 1, close));
      inWord = true;
      i = close + 1;
    } else if (char == '"') {
      final open = i;
      i++;
      var closed = false;
      while (i < input.length) {
        final c = input[i];
        if (c == '"') {
          closed = true;
          i++;
          break;
        }
        if (c == r'\' &&
            i + 1 < input.length &&
            (input[i + 1] == '"' || input[i + 1] == r'\')) {
          current.write(input[i + 1]);
          i += 2;
        } else {
          current.write(c);
          i++;
        }
      }
      if (!closed) {
        throw FormatException('Unterminated double quote', input, open);
      }
      inWord = true;
    } else if (char == r'\') {
      if (i + 1 >= input.length) {
        throw FormatException('Trailing backslash', input, i);
      }
      current.write(input[i + 1]);
      inWord = true;
      i += 2;
    } else {
      current.write(char);
      inWord = true;
      i++;
    }
  }
  if (inWord) {
    words.add(current.toString());
  }
  return words;
}

/// The inverse of [splitShellWords]: joins [words] with single spaces,
/// quoting only the words that need it (empty, or containing whitespace,
/// a quote or `\`). Single quotes are preferred; a word that itself
/// contains `'` is double-quoted with `\` and `"` escaped instead.
///
/// `splitShellWords(joinShellWords(words))` always equals `words`.
String joinShellWords(List<String> words) => words.map(_quoteWord).join(' ');

String _quoteWord(String word) {
  if (word.isNotEmpty && !word.split('').any(_needsQuoting)) {
    return word;
  }
  if (!word.contains("'")) {
    return "'$word'";
  }
  final escaped = word.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"$escaped"';
}

bool _needsQuoting(String char) =>
    _isWhitespace(char) || char == "'" || char == '"' || char == r'\';

bool _isWhitespace(String char) =>
    char == ' ' || char == '\t' || char == '\n' || char == '\r';
