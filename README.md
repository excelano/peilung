# Peilung

Peilung is a field navigation kit for Apple Watch, for finding your way on foot when hiking, geocaching or orienteering. It answers the questions you ask on a trail: which way to go, how far you have come, where you are, and where you have been. A compass that can take and hold a bearing, navigation to a point, a distance odometer, your coordinates and saved marks all live in one app on the wrist.

It runs on the watch alone, with no iPhone app, no account, no network, no ads and no analytics, and it does not start a workout, so it never interrupts one you are recording in another app.

## Using it

The app's pages scroll vertically with the Digital Crown, and it reopens on the page you last used.

**Navigate** is a compass until you give it somewhere to go: the ring turns so its N points north, and the amber mark at the top is the direction the watch points. Once it has a goal, an amber arrow inside the ring points the way. It takes you to a point or along a bearing. For a point, the arrow aims at it and the page gives the distance and bearing, and how far to turn when it lies well off to one side. The arrow follows the watch's compass where it has one; without one, the ring is drawn north-up with the bearing marked. Within about ten meters the page shows "Near target" instead of an arrow, since GPS noise outweighs direction at that range, and the watch taps once to say you have arrived; it taps again only after you have moved well away and come back. The pencil button enters coordinates by hand: the arrows pick a field, the Digital Crown changes it, and every digit wraps on its own, so changing the last few digits of your current position never disturbs the rest. A line under the coordinates shows how far and which way the entered point is from you as it changes.

The button at the top left takes a bearing. Point 12 o'clock at a landmark and press Lock, or turn the Digital Crown to dial one read off a map, then Follow it. The arrow shows the bearing relative to where the watch points; it turns green and the watch taps once when you are within a few degrees, and when you drift off it taps a rising pattern to turn right or a falling one to turn left. On bearing taps at once; drifting off has to hold for a second with the screen up before it taps, so lowering the wrist after checking the bearing does not set off a turn cue. When a GPS fix was available as you took the bearing, the page also shows how far you are to the left or right of the line and how far along it, which catches the sideways drift a compass alone cannot see after you step around an obstacle. A watch compass is far rougher than a baseplate compass, so the page warns when the watch reports a poor heading and asks for the figure-8 calibration motion. Tapping the goal's name at the top of the page turns it into a Stop button for a few seconds; tapping that stops navigating, for a point or a bearing, and returns to the compass.

Bearings are shown against magnetic north by default, because orienteering maps are drawn to it, so a bearing measured off one can be dialed in as is. The watch's compass reads magnetic north with or without GPS, so taking and following a bearing needs no fix. The North setting switches to true north, which needs the local declination: the watch learns it from its first GPS fix and remembers it, and until then readings stay magnetic and are labelled `M`. GPS bearings to a point are true, and show as `T` while the declination is unknown.

GPS-based navigation is not allowed during most orienteering competitions; check an event's rules before using Peilung in one.

**Odometer** is a stopwatch for distance. Press Start where you are, walk, and come back to it whenever you like to see how far you have gone and for how long. The distance comes from the watch's own step count, which it records whether or not Peilung is open, so the odometer costs no battery between glances and survives the app being closed. watchOS turns steps into distance with a stride length it learns from outdoor walks and runs recorded with GPS, as long as Motion Calibration & Distance is on in the iPhone's Location Services, System Services; an outdoor walk in the Workout app calibrates a new watch. When a GPS fix was available at Start, the page also shows the straight-line distance back to where you started, and tapping that line navigates there.

**Here** shows your position in the degrees-and-decimal-minutes form geocaching uses (`N 29° 45.123  W 095° 22.456`), with its accuracy, and a Mark button that saves it. A position the watch remembered from earlier is shown dimmed with its age until a fresh fix arrives, and only a fresh one can be marked.

**Marks** lists saved points with their age and distance from here. Tap one to navigate to it, swipe to rename or delete it. The units and North settings live at the bottom of this list.

A complication opens Peilung from the watch face, in the circular, corner, rectangular and inline slots.

GPS runs only while Peilung is on screen. Raising the wrist within the watch's Return to Clock time brings it back where you left it, and a fresh fix follows within seconds. That time is two minutes unless changed; setting it to an hour for Peilung alone, under Settings, General, Return to Clock on the watch, keeps the app on the wrist through a walk.

## Building

Open `Peilung.xcodeproj` in Xcode. The `Peilung Watch App` scheme builds the watch app for a watch or the simulator and runs the tests. The App Store accepts a watch-only app inside an iOS stub with no code, so the `Peilung` scheme archives that stub with the watch app embedded.

The identity a fork changes, meaning the team id, the bundle ids and the display name, lives in `Config/Peilung.xcconfig`, and the version in `Config/Version.xcconfig`. The project has no dependencies beyond Apple's frameworks.

The complication is its own extension target, `PeilungWidgets`, embedded in the watch app.

The simulator has no pedometer, so a simulator build walks at a steady pace instead. A Debug build launched with `--demo` and a scene name replaces Core Location with a fixed position and compass and fills in a running odometer, marks and a goal, for screenshots; adding `--entry coordinates` or `--entry bearing` opens that entry sheet. The scenes are listed in `Support/Demo.swift`. A Debug build launched with `--haptics` plays each navigation cue in turn with its name on screen, which is the way to feel them on a watch.

## Privacy

Peilung makes no network connection. It reads your location while it is on screen and your step distance while the odometer runs. On the watch it keeps the odometer reading, your marks, the current target, its settings, the page last shown and the last magnetic declination the compass reported, and nothing leaves the watch. The privacy policy is at https://excelano.com/legal/#peilung.

## License

MIT. See [LICENSE](LICENSE).
