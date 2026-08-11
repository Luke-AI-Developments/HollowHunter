Small workflow addition: I want to keep the screenshots (and some video) you already capture during live device verification, so I can use them for build-in-public social content instead of losing them.

**Set this up:**

1. **Create a `devmedia/` folder** at the project root for captured media, organised by date: `devmedia/YYYY-MM-DD/`.

2. **Add `devmedia/` to `.gitignore`.** These are binary screenshots/video — I don't want them bloating the repo history. They live locally only.

3. **From now on, during live verification:** instead of dumping screenshots to a temp scratchpad, save them into today's `devmedia/` folder with descriptive names that say what's being shown — e.g. `2026-08-11_nadir-floor-clear.png`, `2026-08-11_battle-screen-manual.png`. Feature/step name, not `screenshot_01.png`.

4. **Add a screen-recording helper.** A small script (`scripts/record.sh` or `.bat`, whichever fits) that wraps:
   - `adb shell screenrecord --time-limit <n> /sdcard/rec.mp4`
   - then `adb pull` it into today's `devmedia/` folder and delete it off the device.
   Phone screen recording is already vertical/9:16, which is exactly what TikTok/Reels want, so this is the highest-value capture format. Default to ~30s.

5. **When you finish a patch**, capture a short recording of the new feature actually being used, not just a static screenshot — the loop in motion is what makes good content.

**Also:** at the end of each patch, add a one-line note to `devmedia/CAPTURE_LOG.md` saying what was captured and what feature it shows, so I can find usable footage later without opening every file.

Nothing here should slow down or change your actual build/test process — you're already taking these screenshots, this just puts them somewhere useful with a sensible name.
