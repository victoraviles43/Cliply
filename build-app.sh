#!/bin/zsh
set -euo pipefail

cd "${0:A:h}"
swift build -c release --scratch-path .build
app_path="${PWD}/dist/Portapapeles.app"
rm -rf "${app_path}"
mkdir -p "${app_path}/Contents/MacOS"
cp .build/release/Portapapeles "${app_path}/Contents/MacOS/Portapapeles"
cp Info.plist "${app_path}/Contents/Info.plist"
signing_identity=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ { print $2; exit }')
if [[ -n "${signing_identity}" ]]; then
    codesign --force --deep --options runtime --sign "${signing_identity}" "${app_path}"
    echo "Firma: ${signing_identity}"
else
    codesign --force --deep --sign - "${app_path}"
    echo "Firma temporal: los permisos de macOS pueden requerir activarse otra vez después de recompilar."
fi
echo "App creada: ${app_path}"
