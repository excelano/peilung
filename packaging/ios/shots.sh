#!/bin/sh
# The App Store screenshots, as recipes. shots-appstore builds the app for the
# simulator, boots each simulator ship.toml names, installs the app (the
# embedded watch app on a watch), and calls this with the simulator, the
# language and where the frames go; this file is the half that is Peilung's:
# which screens, from the positions a Debug build sets up when launched with
# --demo. Both apps take the same scenes.
#
#     ./packaging/ios/shots.sh --app <Peilung.app> --device <udid> --lang en-us --outdir <dir>
#
# Author: David M. Anderson
# Built with AI assistance (Claude, Anthropic)
set -eu
app= device= lang= outdir=
while [ $# -gt 0 ]; do
    case "$1" in
        --app) app=$2; shift 2 ;;
        --device) device=$2; shift 2 ;;
        --lang) lang=$2; shift 2 ;;
        --outdir) outdir=$2; shift 2 ;;
        *) echo "shots.sh: unknown argument $1" >&2; exit 2 ;;
    esac
done
[ -n "$app" ] && [ -n "$device" ] && [ -n "$lang" ] && [ -n "$outdir" ] || { echo "shots.sh: --app, --device, --lang and --outdir are all required" >&2; exit 2; }
case "$lang" in
    en|en-us|en-US) languages='(en)'; locale=en_US ;;
    *) echo "shots.sh: no set is written for $lang" >&2; exit 2 ;;
esac
# A watch simulator runs the embedded watch app, with its own bundle id.
case "$(xcrun simctl list devices | grep -F "($device)" | head -1)" in
    *Watch*) bundle=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app"/Watch/*.app/Info.plist) ;;
    *) bundle=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist") ;;
esac
mkdir -p "$outdir"
settle=8
shot() {
    name=$1
    shift
    xcrun simctl launch --terminate-running-process "$device" "$bundle" \
        -AppleLanguages "$languages" -AppleLocale "$locale" "$@" >/dev/null
    sleep "$settle"
    xcrun simctl io "$device" screenshot --type=png "$outdir/$name.png" >/dev/null
    echo "$name"
}
shot 01-bearing --demo bearing
shot 02-compass --demo compass
shot 03-point --demo navigate
shot 04-odometer --demo odometer
shot 05-here --demo here
shot 06-take-bearing --demo bearing --entry bearing
xcrun simctl terminate "$device" "$bundle" >/dev/null 2>&1 || true
