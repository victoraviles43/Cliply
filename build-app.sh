#!/bin/zsh
set -euo pipefail

cd "${0:A:h}"
swift build -c release --scratch-path .build
app_path="${PWD}/dist/Portapapeles.app"
mkdir -p "${app_path}/Contents/MacOS"
cp .build/release/Portapapeles "${app_path}/Contents/MacOS/Portapapeles"
cp Info.plist "${app_path}/Contents/Info.plist"
codesign --force --sign - "${app_path}"
echo "App creada: ${app_path}"

