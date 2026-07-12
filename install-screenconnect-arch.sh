#!/bin/sh
# install-screenconnect-arch.sh — CWCR candidate fix
#
# ScreenConnect's ClientSetup.sh only detects rpm/dpkg/pkgutil, so on Arch it
# silently fails. But for Host clients the Linux payload is a per-user Java
# app that needs no package manager: a tar.gz embedded between the
# "tar.gz__commencement" and "tar.gz__completion" marker lines, containing the
# vendor's own ClientInstaller.sh. This script extracts that payload exactly
# the way the vendor's installer does and runs the vendor installer unchanged.
#
# Usage: sh install-screenconnect-arch.sh [path/to/ScreenConnect.ClientSetup.sh]
# Requires: java (jre-openjdk), tar, perl, desktop-file-utils, xdg-utils

set -eu

installerPath="${1:-$(dirname "$0")/ScreenConnect.ClientSetup.sh}"

if [ ! -f "$installerPath" ]; then
	echo "error: installer not found: $installerPath" >&2
	exit 1
fi

if ! command -v java >/dev/null 2>&1; then
	echo "error: java not found — install it first: sudo pacman -S --needed jre-openjdk" >&2
	exit 1
fi

startLine=$(($(grep -anF -m1 'tar.gz__commencement' "$installerPath" | cut -d: -f1) + 1))
endLine=$(grep -anF -m1 'tar.gz__completion' "$installerPath" | cut -d: -f1)

if [ "$startLine" -le 1 ] || [ -z "$endLine" ]; then
	echo "error: tar.gz payload markers not found in $installerPath" >&2
	exit 1
fi

payloadPath=$(mktemp -t screenconnect-payload-XXXXXX)
trap 'rm -f "$payloadPath"' EXIT

tail "-n+$startLine" "$installerPath" | head "-n$((endLine - startLine))" > "$payloadPath"
# The build process appends a newline to the binary payload; the vendor strips
# it the same way before untarring (see SCP:33423 comment in their script).
perl -i -0pe 's/\n\Z//' "$payloadPath"

packageName=$(tar -tzf "$payloadPath" | head -n1 | tr -d /)
echo "extracting payload for package: $packageName"

tar -xzf "$payloadPath" --directory /tmp

# Vendor installer: moves files to ~/.local/share/applications/<packageName>,
# writes the .desktop file, registers the sc-<id>: URL scheme, launches client.
sh "/tmp/$packageName/ClientInstaller.sh"

rm -rf "/tmp/$packageName"

echo "installed to: $HOME/.local/share/applications/$packageName"
echo "launch log:   $HOME/.local/share/applications/$packageName-logs"
