# native/android/

Source for our custom Android native plugins (Kotlin/Java) — FusedLocationProvider
GPS bridge and Health Connect bridge into GDScript. Deliberately NOT named
`android/` at the project root: Godot's own gitignore convention reserves
`/android/` for the auto-generated Gradle build folder created by "Install
Android Build Template", which is git-ignored. Keeping our source in
`native/android/` avoids that collision — this folder IS tracked in git.

First task here (before any game code): a throwaway spike plugin reading
GPS + step/workout data into GDScript on a physical device.
