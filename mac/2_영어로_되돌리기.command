#!/bin/zsh
cd "$(dirname "$0")" || exit 1
/usr/bin/osascript -l JavaScript files/patch.js uninstall 2>&1
echo
read -k1 "?아무 키나 누르면 창이 닫혀요."
echo
