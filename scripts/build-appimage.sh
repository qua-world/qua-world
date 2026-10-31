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

# The GLUT package loads freeglut with dlopen, which linuxdeploy's dependency
# walk cannot see.
freeglut="$(ldconfig -p | awk '$1 == "libglut.so.3" { print $NF; exit }')"
if [ -z "$freeglut" ]; then
  echo "${0##*/}: libglut.so.3 not found; install freeglut" >&2
  exit 1
fi

# A relocatable build looks for its data files at ../share/<datasubdir> from
# the executable, which is where the AppDir puts them.
build=(--enable-relocatable "--datasubdir=$package" "exe:$exe")

cabal build "${build[@]}"
binary="$(cabal list-bin "${build[@]}")"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

appdir="$work/AppDir"
share="$appdir/usr/share/$package"

mkdir -p "$share"
cp -R examples "$share/"

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
  --output appimage
