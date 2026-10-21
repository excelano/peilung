# Peilung

Peilung is a field tool for Apple Watch that tells you how far you have walked, where you are, and how far and which way it is to the place you want to reach. It runs on the watch alone, with no iPhone app, no account, no network, no ads and no analytics, and it does not start a workout, so it never interrupts one you are recording in another app.

## Using it

The app's pages scroll vertically with the Digital Crown.

**Odometer** is a stopwatch for distance. Press Start where you are, walk, and come back to it whenever you like to see how far you have gone and for how long. The distance comes from the watch's own step count, which it records whether or not Peilung is open, so the odometer costs no battery between glances and survives the app being closed. When a GPS fix was available at Start, the page also shows the straight-line distance back to where you started, and tapping that line navigates there.

**Here** shows your position in the degrees-and-decimal-minutes form geocaching uses (`N 29° 45.123  W 095° 22.456`), with its accuracy, and a Mark button that saves it.

**Navigate** points an arrow at the target and gives the distance and bearing. The arrow follows the watch's compass where it has one; without one, the ring is drawn north-up with the bearing marked. Within about ten meters the page shows "Near target" instead of an arrow, since GPS noise outweighs direction at that range. The pencil button enters a target by hand: the arrows pick a field, the Digital Crown changes it, and every digit wraps on its own, so changing the last few digits of your current position never disturbs the rest.

**Marks** lists saved points with their age and distance from here. Tap one to navigate to it, swipe to rename or delete it. The units setting lives at the bottom of this list.

GPS runs only while Peilung is on screen. Raising the wrist within the watch's Return to Clock time brings it back where you left it, and a fresh fix follows within seconds.

## Building

Open `Peilung.xcodeproj` in Xcode. The `Peilung Watch App` scheme builds the watch app for a watch or the simulator and runs the tests. The App Store accepts a watch-only app inside an iOS stub with no code, so the `Peilung` scheme archives that stub with the watch app embedded.

The identity a fork changes, meaning the team id, the bundle ids and the display name, lives in `Config/Peilung.xcconfig`, and the version in `Config/Version.xcconfig`. The project has no dependencies beyond Apple's frameworks.

The simulator has no pedometer, so a simulator build walks at a steady pace instead. A Debug build launched with `--demo odometer`, `--demo here`, `--demo navigate` or `--demo marks` replaces Core Location with a fixed position and fills in a running odometer, marks and a target, for screenshots; adding `--entry` opens the target entry sheet.

## Privacy

Peilung makes no network connection. It reads your location while it is on screen and your step distance while the odometer runs, and it keeps only the odometer reading, your marks, the current target and the units setting, on the watch.

## License

MIT. See [LICENSE](LICENSE).
