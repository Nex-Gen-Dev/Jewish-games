# Shtick Games: Godot 4.3 project

A mobile 3D game launcher plus the first game ("Rise & Shine", a third-person 3D fighter).

## Run it
1. Install Godot 4.3 (standard build): https://godotengine.org
2. Open this folder as a project, press F5.
   Desktop keys: WASD/arrows move, J punch, K kick, Space jump, Shift dodge, Esc pause.
   Mouse: drag on the right half to look around.

## Put it on a phone (Android)
1. Godot -> Editor -> Manage Export Templates -> install 4.3 templates.
2. Install Android Studio (SDK + JDK 17) and point Godot at them in Editor Settings -> Export -> Android.
3. Project -> Export -> Add... Android -> tick "Use Gradle Build" off for a first test, set a package name
   (e.g. com.yourname.launcher), and in Resources -> Filters to exclude, add `tests/*`.
4. Plug in a phone with USB debugging and use the one-click deploy button (top right of the editor).
iOS needs a Mac with Xcode (Project -> Export -> iOS).

Screen rotation is automatic (`display/window/handheld/orientation = sensor`).
The camera and HUD re-layout live when the phone rotates; portrait and landscape both work.

## Controls (change in the pause menu)
- Joystick: floating, appears where you touch on the left side.
- D-pad: fixed on the left.
- Tilt: tilt the phone to walk. Needs a quick on-device check; it auto-calibrates to the pose you hold
  when you select it, but the axis directions were not tested on a real phone.
- Right side: Punch / Kick / Jump / Dodge buttons. Drag anywhere else on the right to look around.
  The camera also auto-aims at the nearest enemy and drifts down the street in level 2.

## Per-user private content
`scripts/profile.gd` is the hook. A user's profile is a JSON object (see `data/profile_default.json`):
theme colors, the character's look (skin/shirt/kippah...), a private message, which games they own
(`entitlements`), and progress. Set `SERVER_URL` and `auth_token` in profile.gd, and the app does
`GET {SERVER_URL}/v1/me/profile` with `Authorization: Bearer <token>` at launch. Whatever JSON comes back is
merged over the local profile and saved. You can send a different one to every user.
New games/levels are listed in `data/manifest.json`; `entitlements` decides which games a user sees.
Not built yet: login screen, the server itself, downloading new level packs (Godot can load .pck files
at runtime for that).

## What is in the game
- Level 1: you start asleep in bed. Tap to wake up, then fight the Yetzer Hara (and his Snooze Imps at half health).
- Level 2: run down a 3D street, beat the Alarm Clock boss (jump its shockwaves), reach shul before the timer ends.
- Level 3 (Seder) and the Street Runner game are placeholders in the launcher.
- Attacks are telegraphed with an orange pulse; kicks and the third punch of a combo stagger bosses.

## Testing without a phone
`godot --headless --fixed-fps 60 --path . -- --selftest=bedroom` (or `street`) runs a bot through the level
and prints WIN/LOSE. Add `--shot=/tmp/x` when running with a renderer to save screenshots.

## Next steps toward your vision
- Real maps/cities: import glTF scenes (Blender, or OpenStreetMap-based tools) and replace the procedural
  builders in `scripts/levels.gd`; the gameplay code does not depend on them.
- Nicer characters: swap the blocky rig in `fighter.gd` for a rigged glTF model with animations.
- Sound and music: none yet.
