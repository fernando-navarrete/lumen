#!/usr/bin/env bash
# Builds Lumen-<version>-x86_64.AppImage (and its .sha256 and .zsync) into build/appimage/.
# Wraps the `flutter build linux --release` bundle; GTK 3 and libsecret come from the host.
# The AppImage embeds update information pointing at the latest GitHub release's .zsync.
# Downloads two pinned tools into build/appimage-tools/ and refuses any whose sha256 differs.
# FLUTTER overrides the Flutter command (CI runs the bare `flutter`).
set -euo pipefail
cd "$(dirname "$0")/.."

FLUTTER="${FLUTTER:-fvm flutter}"
id=io.github.fernando_navarrete.Lumen
version=$(sed -n 's/^version: *\([^+ ]*\).*/\1/p' pubspec.yaml)
[ -n "$version" ] || { echo "no version in pubspec.yaml" >&2; exit 1; }

tools="$PWD/build/appimage-tools"
appimagetool_url=https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage
appimagetool_sha=ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0
runtime_url=https://github.com/AppImage/type2-runtime/releases/download/20251108/runtime-x86_64
runtime_sha=2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d
update_info='gh-releases-zsync|fernando-navarrete|lumen|latest|Lumen-*-x86_64.AppImage.zsync'

fetch() { # url sha256 file
  mkdir -p "$tools"
  if [ ! -f "$3" ] || ! echo "$2  $3" | sha256sum -c --status; then
    curl -fsSL "$1" -o "$3"
  fi
  echo "$2  $3" | sha256sum -c --status || { echo "sha256 mismatch for $3" >&2; rm -f "$3"; exit 1; }
}
fetch "$appimagetool_url" "$appimagetool_sha" "$tools/appimagetool"
fetch "$runtime_url" "$runtime_sha" "$tools/runtime-x86_64"
chmod +x "$tools/appimagetool"

# A failed configure leaves CMAKE_INSTALL_PREFIX=/usr/local in the cache, so always start clean.
rm -rf build/linux
$FLUTTER build linux --release
bundle=build/linux/x64/release/bundle

appdir=build/appimage/Lumen.AppDir
rm -rf build/appimage
mkdir -p "$appdir/usr/lib" "$appdir/usr/share/applications" "$appdir/usr/share/icons" "$appdir/usr/share/metainfo"
cp -r "$bundle" "$appdir/usr/lib/lumen"
cp -r linux/packaging/icons/hicolor "$appdir/usr/share/icons/"
cp "linux/packaging/$id.desktop" "$appdir/$id.desktop"
cp "linux/packaging/$id.desktop" "$appdir/usr/share/applications/"
cp "linux/packaging/$id.metainfo.xml" "$appdir/usr/share/metainfo/"
cp "linux/packaging/icons/hicolor/256x256/apps/$id.png" "$appdir/$id.png"
cp "linux/packaging/icons/hicolor/256x256/apps/$id.png" "$appdir/.DirIcon"
cat > "$appdir/AppRun" <<'RUN'
#!/bin/sh
here=$(dirname "$(readlink -f "$0")")
exec "$here/usr/lib/lumen/lumen" "$@"
RUN
chmod +x "$appdir/AppRun"

out="Lumen-$version-x86_64.AppImage"
# No FUSE in CI containers, and AppImageLauncher's binfmt handler hangs the tool.
# appimagetool writes the .zsync into the current directory, so run it from build/appimage.
(cd build/appimage && APPIMAGE_EXTRACT_AND_RUN=1 APPIMAGELAUNCHER_DISABLE=1 ARCH=x86_64 \
  "$tools/appimagetool" --runtime-file "$tools/runtime-x86_64" -u "$update_info" \
  Lumen.AppDir "$out")
[ -f "build/appimage/$out.zsync" ] || { echo "appimagetool wrote no build/appimage/$out.zsync" >&2; exit 1; }
(cd build/appimage && sha256sum "$out" > "$out.sha256")
echo "build/appimage/$out"
