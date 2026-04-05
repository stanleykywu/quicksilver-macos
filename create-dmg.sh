#!/usr/bin/env bash

app_dir=$1
version=$2
dmg_name="Quicksilver-macos-v$version.dmg"

# Remove old DMG if exists
[ -f "$dmg_name" ] && rm "$dmg_name"

create-dmg \
  --volname "Quicksilver Installer" \
  --window-size 600 400 \
  --background "dmg-background.png" \
  --icon-size 100 \
  --icon "Quicksilver.app" 150 200 \
  --app-drop-link 450 200 \
  "$dmg_name" \
  "$app_dir"