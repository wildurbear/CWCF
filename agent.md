# Agent instructions: fix ScreenConnect Client on Arch-based Linux

You are helping a user get the ScreenConnect (ConnectWise Control) Client
working on an Arch-based distro (CachyOS, EndeavourOS, Manjaro, vanilla Arch).
This procedure is proven — it was verified working on CachyOS with client
version 25.9.5.9483. Follow it as written; only debug if a step fails.

## Background you need (do not re-research this)

- `ScreenConnect.ClientSetup.sh` is a ~45 MB self-extracting POSIX-sh
  installer with binary payloads appended after the script, delimited by
  marker lines `pkg__commencement`, `deb__commencement`, `rpm__commencement`,
  `app__commencement`, `tar.gz__commencement` and matching `*__completion`.
- Its `determinePackageType()` only checks `which rpm` / `which pkgutil` /
  `which dpkg`. On Arch all are absent → it returns an empty string → the
  script calls a nonexistent function and fails silently. That is the entire
  bug.
- For Host clients (support sessions — this installer), the .deb/.rpm payloads
  are dead weight even on Debian: the Linux payload actually used is the
  `tar.gz` section, a per-user Java Swing app (bytecode major version 49, runs
  on any modern JRE; native .so libs need only glibc). Its own
  `ClientInstaller.sh` installs to `~/.local/share/applications/<packageName>/`,
  registers an `sc-<instanceId>:` URL-scheme handler, and launches the client.
  No root, no package manager.
- The installer .sh is proprietary. Never commit it to a repo or upload it.

## Procedure

1. Confirm the user has `ScreenConnect.ClientSetup.sh` (their ScreenConnect
   server offers it when joining a session from the web page). Note its path.

2. Install dependencies (the only one normally missing is Java; Swing GUI, so
   NOT the headless variant):

   ```sh
   sudo pacman -S --needed jre-openjdk desktop-file-utils xdg-utils
   ```

3. Run the fix script from this repo (or recreate it — logic below):

   ```sh
   sh install-screenconnect-arch.sh /path/to/ScreenConnect.ClientSetup.sh
   ```

   What it does (if you must recreate it): find the line numbers of
   `tar.gz__commencement` and `tar.gz__completion` with `grep -anF -m1`;
   extract the lines strictly between them with `tail -n+START | head -nCOUNT`;
   strip the single trailing newline (`perl -i -0pe 's/\n\Z//'` — required or
   gunzip fails); `tar -xzf` to /tmp; run
   `sh /tmp/<packageName>/ClientInstaller.sh` (packageName = the tarball's
   top-level directory). Locate markers by grep, never by hardcoded line
   numbers — they differ per instance.

4. Success criteria: the ScreenConnect Client window opens at the end of the
   install (the vendor installer auto-launches it), and clicking Join on the
   ScreenConnect web page launches the client (the browser asks once to allow
   the `sc-<instanceId>:` protocol).

## If it fails

- Read `~/.local/share/applications/<packageName>-logs` first — the launcher
  redirects all output there.
- `java: command not found` → step 2 skipped or wrong variant installed.
- `UnsatisfiedLinkError` in the log → java.library.path/.so problem; confirm
  the .so files are in the install dir.
- Installs but no window on Wayland → ensure `xorg-xwayland`; on tiling WMs
  try `_JAVA_AWT_WM_NONREPARENTING=1`.
- `gzip: invalid magic` during extraction → the trailing-newline strip was
  skipped or the marker line math is off by one.

## Scope limits

- This covers **Host/support-session clients only.** Unattended access agents
  (Access/Guest) use the .deb/.rpm payloads with an init.d service and are not
  fixed by this procedure.
