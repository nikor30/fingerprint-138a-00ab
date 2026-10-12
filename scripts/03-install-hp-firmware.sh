#!/bin/bash
# Download HP SoftPaq sp135736, extract the sensor firmware extension and put
# it where the driver looks for it. The firmware is NOT redistributed here.
#
# After this, the next time the sensor is opened the driver writes this file
# to the sensor's flash. That write cannot be undone. Run as root.
set -euo pipefail

URL=https://ftp.hp.com/pub/softpaq/sp135501-136000/sp135736.exe
EXE_SHA=be83e4cab0db523e66818b9eee9b8bd2c0e9144821bf96cdc162bb73d62ad311
FW=6_07f_hp_cmit_mis_qm.xpfwext
FW_SHA=2b68b33668215cfc2a08c80a1f2c0e66c4c02927895d70a7d5f237e5201d5d2f
DEST=/usr/share/libfprint/validity

[[ $EUID -eq 0 ]] || { echo "run as root (sudo)"; exit 1; }
pacman -S --needed --noconfirm 7zip curl

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
curl -fL --max-time 300 -o "$TMP/sp135736.exe" "$URL"
echo "$EXE_SHA  $TMP/sp135736.exe" | sha256sum -c -
7z x -y -o"$TMP/x" "$TMP/sp135736.exe" >/dev/null
SRC=$(find "$TMP/x" -name "$FW" | head -1)
echo "$FW_SHA  $SRC" | sha256sum -c -
install -Dm644 "$SRC" "$DEST/$FW"
echo "installed $DEST/$FW"
