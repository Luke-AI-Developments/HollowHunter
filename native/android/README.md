# native/android/

Source for our custom Android native plugin (Kotlin) — FusedLocationProvider
GPS bridge and Health Connect bridge into GDScript. Deliberately NOT named
`android/` at the project root: Godot's own gitignore convention reserves
`/android/` for the auto-generated Gradle build folder created by "Install
Android Build Template", which is git-ignored. Keeping our source in
`native/android/` avoids that collision — this folder IS tracked in git.

This is the throwaway spike task: read GPS + step/workout data into GDScript
on a physical device. Nothing here is unit tested (native/platform code is
exercised on-device, see `tests/unit/README.md`).

## Layout

```
native/android/
├── settings.gradle, build.gradle, gradle.properties   # Gradle project root
└── gps_health_bridge/                                  # the plugin module
    ├── build.gradle
    └── src/main/
        ├── AndroidManifest.xml
        └── java/com/shadowhunter/gpshealthbridge/GpsHealthBridgePlugin.kt
```

Written against Godot's documented v2 Android plugin API
(`@UsedByGodot`, `getPluginSignals()`/`emitSignal()`), but not yet compiled —
no Android toolchain was installed on this machine when it was written. See
the two `// VERIFY` comments at the top of `GpsHealthBridgePlugin.kt` before
you build.

## Build (once JDK 17 + Android Studio/SDK are installed)

```powershell
cd native/android
./gradlew :gps_health_bridge:assembleDebug
./gradlew :gps_health_bridge:assembleRelease
```

(No Gradle wrapper is checked in yet — run `gradle wrapper` once you have a
system Gradle install, or open this folder in Android Studio and let it
generate one.)

If `implementation "org.godotengine:godot:4.3.0.stable"` in
`gps_health_bridge/build.gradle` fails to resolve (version mismatch with
whatever Godot you installed), switch to the local-AAR fallback: copy
`godot-lib.*.aar` out of your Godot install (Editor > Manage Export
Templates, or the engine's `android_source` template) into a new
`gps_health_bridge/libs/` folder, and replace that line with:

```gradle
compileOnly fileTree(dir: 'libs', include: ['*.aar'])
```

## Install into the Godot project

Copy the two build outputs into `addons/gps_health_bridge/` — see that
folder's README for exact filenames and the GDScript calling convention.

## Test on device

GPS and Health Connect both no-op in the Android emulator. Build an APK
(Project > Export, Gradle Build enabled), install via
`adb install -r shadowhunter.apk` on a physical device with USB debugging on,
and watch `adb logcat` while exercising the singleton from a test scene.
