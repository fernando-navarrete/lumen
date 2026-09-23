import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/common/shell_words.dart';

void main() {
  group('splitShellWords', () {
    test('splits on whitespace and collapses runs of it', () {
      expect(splitShellWords('  -skipintro   -windowed\t-fps 60 '), [
        '-skipintro',
        '-windowed',
        '-fps',
        '60',
      ]);
    });

    test('empty or blank input gives no words', () {
      expect(splitShellWords(''), isEmpty);
      expect(splitShellWords('  \t '), isEmpty);
    });

    test('single quotes are fully literal', () {
      expect(splitShellWords(r"""'a b' 'c\d' 'e\"f'"""), [
        'a b',
        r'c\d',
        r'e\"f',
      ]);
    });

    test('double quotes only escape \\" and \\\\', () {
      expect(splitShellWords(r'"say \"hi\"" "a\\b" "a\nb"'), [
        'say "hi"',
        r'a\b',
        r'a\nb',
      ]);
    });

    test('a backslash outside quotes escapes the next character', () {
      expect(splitShellWords(r'a\ b c\"d \\'), ['a b', 'c"d', r'\']);
    });

    test('quotes join with adjacent text', () {
      expect(splitShellWords('--dir="a b"'), ['--dir=a b']);
      expect(splitShellWords(''''a'"b"c'''), ['abc']);
      // A GOG playTask argument seen in Phase 0.
      expect(splitShellWords('--launcher-fallback="DirectX 11"'), [
        '--launcher-fallback=DirectX 11',
      ]);
    });

    test('empty quotes give an empty word', () {
      expect(splitShellWords('""'), ['']);
      expect(splitShellWords("''"), ['']);
      expect(splitShellWords('a "" b'), ['a', '', 'b']);
    });

    test('does no expansion of any kind', () {
      expect(splitShellWords(r'$HOME ~ *.exe $(ls) a;b # c'), [
        r'$HOME',
        '~',
        '*.exe',
        r'$(ls)',
        'a;b',
        '#',
        'c',
      ]);
    });
  });

  group('splitShellWords errors', () {
    test('an unterminated single quote throws', () {
      expect(() => splitShellWords("a 'b c"), throwsFormatException);
    });

    test('an unterminated double quote throws', () {
      expect(() => splitShellWords('a "b c'), throwsFormatException);
    });

    test('an escaped closing quote leaves the quote unterminated', () {
      expect(() => splitShellWords(r'"abc\"'), throwsFormatException);
    });

    test('a trailing lone backslash throws', () {
      expect(() => splitShellWords(r'a b\'), throwsFormatException);
    });
  });

  group('joinShellWords', () {
    test('leaves plain words bare', () {
      expect(
        joinShellWords(['-fps', '60', r'$HOME', '<game>']),
        r'-fps 60 $HOME <game>',
      );
    });

    test('single-quotes words with whitespace, quotes or backslashes', () {
      expect(
        joinShellWords(['a b', 'say "hi"', r'C:\x']),
        r"""'a b' 'say "hi"' 'C:\x'""",
      );
    });

    test("double-quotes a word containing ', escaping \\ and \"", () {
      expect(joinShellWords(["it's"]), '"it\'s"');
      expect(joinShellWords([r'''a\"b'c''']), r'''"a\\\"b'c"''');
    });

    test('quotes an empty word', () {
      expect(joinShellWords(['a', '', 'b']), "a '' b");
      expect(joinShellWords([]), '');
    });
  });

  test('split(join(x)) == x for awkward word lists', () {
    const cases = [
      <String>[],
      [''],
      ['', ''],
      ['plain', 'words'],
      ['a b', '  leading and trailing  '],
      ["it's", 'say "hi"', "both ' and \""],
      [r'C:\Games\x', r'\', r'\\', r'trailing\'],
      [r'''a\"b'c''', r"""'"'"'"""],
      ['héllo wörld', '日本語', '🎮 game'],
      ['tab\tinside', 'new\nline'],
      ['--dir=a b', r'$HOME', '~/x', '*.exe'],
    ];
    for (final words in cases) {
      expect(splitShellWords(joinShellWords(words)), words, reason: '$words');
    }
  });
}
