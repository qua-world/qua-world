#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

#
# Package the client as an AppImage that carries its own freeglut and GLU.
#
# glibc, libGL, and X11 stay with the host, so the AppImage runs only on a
# glibc at least as new as the build machine's.
#
# Usage: build-appimage.sh <linuxdeploy> <output-dir>

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: ${0##*/} <linuxdeploy> <output-dir>" >&2
  exit 2
fi

linuxdeploy="$(realpath "$1")"
output="$(realpath "$2")"

package="partir-qua-world"
exe="partir-glut"

# Cabal names the Paths module's data directory override after the package.
datadir_variable="${package//-/_}_datadir"

cabal build "exe:$exe"
binary="$(cabal list-bin "exe:$exe")"

# The GLUT package loads freeglut with dlopen, so linuxdeploy never sees it
# among the executable's shared libraries.
freeglut="$(ldconfig -p | awk '$1 == "libglut.so.3" { print $NF; exit }')"
if [ -z "$freeglut" ]; then
  echo "${0##*/}: libglut.so.3 not found; install freeglut" >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

appdir="$work/AppDir"
share="usr/share/$package"

# The Paths module looks for data files at the build machine's absolute path
# unless AppRun points it at the copy inside the AppImage.
mkdir -p "$appdir/$share"
cp -R examples "$appdir/$share/"

cat >"$work/AppRun" <<EOF
#!/bin/sh
here="\$(dirname "\$(readlink -f "\$0")")"
export $datadir_variable="\$here/$share"
exec "\$here/usr/bin/$exe" "\$@"
EOF
chmod +x "$work/AppRun"

cat >"$work/$exe.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Qua World
Exec=$exe
Icon=$exe
Categories=Game;
EOF

cp examples/sprites.png "$work/$exe.png"

mkdir -p "$output"
cd "$output"

LDAI_OUTPUT="$exe-x86_64.AppImage" "$linuxdeploy" \
  --appdir "$appdir" \
  --executable "$binary" \
  --library "$freeglut" \
  --desktop-file "$work/$exe.desktop" \
  --icon-file "$work/$exe.png" \
  --custom-apprun "$work/AppRun" \
  --output appimage
