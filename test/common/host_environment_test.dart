import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/common/host_environment.dart';

void main() {
  group('hostEnvironment', () {
    test(
      'inside an AppImage drops the runtime variables and keeps the rest',
      () {
        final input = {
          'APPIMAGE': '/x/Lumen.AppImage',
          'APPDIR': '/tmp/.mount_x',
          'ARGV0': 'Lumen',
          'OWD': '/home/u',
          'PATH': '/usr/bin',
          'LD_LIBRARY_PATH': '/opt/lib',
          'XDG_DATA_DIRS': '/usr/share',
        };
        expect(hostEnvironment(input), {
          'PATH': '/usr/bin',
          'LD_LIBRARY_PATH': '/opt/lib',
          'XDG_DATA_DIRS': '/usr/share',
        });
      },
    );

    test('outside an AppImage returns the environment unchanged', () {
      final input = {'APPDIR': '/stray', 'PATH': '/usr/bin'};
      expect(hostEnvironment(input), input);
    });

    test('never mutates its input', () {
      final input = {'APPIMAGE': 'a', 'APPDIR': 'b'};
      hostEnvironment(input);
      expect(input, {'APPIMAGE': 'a', 'APPDIR': 'b'});
    });
  });
}
