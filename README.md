# CWCF — ConnectWise (ScreenConnect) Client Fix for Arch

Working fix for running the ScreenConnect Client (Host/support session client)
on Arch-based Linux distributions — verified on CachyOS, 2026-07-11, client
version 25.9.5.9483.

Research behind this fix lives in the CWCR repository. If you want an AI agent
to walk you through this instead, copy `agent.md` into your agent.

## The problem

ScreenConnect's `ScreenConnect.ClientSetup.sh` installer (downloaded from the
Control Center when you remote into a machine) silently fails on Arch. Its
package detection only checks for `rpm`, `dpkg`, and macOS's `pkgutil` —
`pacman` is never considered, so the script can't tell it's on Linux and exits
without installing anything.

The twist: for Host clients the installer never uses the .deb/.rpm payloads
anyway. The real payload is a tar.gz embedded in the .sh file containing a
per-user Java app — no root, no package manager. The dpkg/rpm check is only a
broken "am I on Linux?" proxy.

## The fix

1. Get `ScreenConnect.ClientSetup.sh` from your ScreenConnect server (it
   downloads automatically when you try to join a session from the web page).
2. Put it next to `install-screenconnect-arch.sh` (or pass its path as an
   argument) and run:

```sh
sudo pacman -S --needed jre-openjdk desktop-file-utils xdg-utils
sh install-screenconnect-arch.sh
```

The script extracts the embedded tar.gz exactly the way the vendor's installer
does and runs the vendor's own `ClientInstaller.sh` unchanged. The client
installs to `~/.local/share/applications/<packageName>/`, registers the
`sc-<instanceId>:` URL scheme so the browser "Join" button works, and launches
immediately.

## Verifying

- The ScreenConnect Client window opens at the end of the install.
- Joining a session from the ScreenConnect web page launches the client
  (allow the browser's protocol prompt once).
- If nothing opens, check `~/.local/share/applications/<packageName>-logs`.

## Notes

- Works per ScreenConnect instance: the installer .sh is instance-specific,
  but the fix script reads the package name from the payload, so it works for
  any instance's Host-client installer.
- Unattended agents (Access/Guest installs) are a different code path
  (.deb/.rpm with an init service) and are **not** covered by this fix.
- Do not commit `ScreenConnect.ClientSetup.sh` — it's proprietary
  (gitignored here).
