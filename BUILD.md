# How to build and publish (for any Claude session working in this repo)

Source of truth for the app is `godot/` (Godot 4.3 project). Backend is `backend/`. Published files are in `docs/`.

## Setup in a fresh sandbox
1. `git clone https://github.com/Nex-Gen-Dev/jewish-games` (or `git pull` if already cloned). ALWAYS pull before you build.
2. Get Godot 4.3 stable (linux x86_64 zip) and the 4.3 export templates from github.com/godotengine/godot/releases (the sandbox can reach GitHub).
   Templates go in `~/.local/share/godot/export_templates/4.3.stable/`.
3. Headless checks: `godot --headless --fixed-fps 60 --path godot -- --selftest=<level>`
   levels: bedroom street shul market seder purim finale runner1 runner2. Prints `RESULT WIN/LOSE`.
   Screenshots need a renderer: `xvfb-run -a godot --path godot --resolution 540x960 -- --selftest=<level> --shot=/tmp/x`.

## Publish a content update (no new APK needed)
1. `git pull`. Edit only your own area (see PROJECT_STATE in the Claude project).
2. Export the pack: `godot --headless --path godot --export-pack "Android" /tmp/content.pck`
3. Copy it to `docs/content.pck`, compute `sha256sum`, and edit `docs/version.json`:
   `content` = previous number + 1, `sha256` = new hash, `notes` = one line. Keep `api_url`, `apk_url`, `min_binary`.
4. `git add -A && git commit && git push`. Phones pick it up within about 30 seconds of opening the app.
Because the pack contains ALL games, always build from a freshly pulled tree so you include other sessions' work.

## New APK (only when native code/binary changes: BINARY_VERSION in scripts/updater.gd)
Export with the "Android" preset, then sign with `python3 tools/signv2.py in.apk out.apk <keystore>` (keystore password `android`).
The signing keystore is NOT in this repo. It is stored in the Claude project doc `claude/keystore_b64.txt` (base64).
It must be the same key every time or phones will refuse to update the app. Only the Launcher session builds APKs.

## Never
- Never run tests that create accounts against production (see tests/cloud_test.gd; Updater overwrites user://update/meta.json).
- Never commit the keystore or the admin token.
