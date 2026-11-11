# Security Policy

## Reporting a vulnerability

Please report suspected vulnerabilities privately, using the **Report a vulnerability** button on the Security tab of this repository. If that button is not there, or you would rather not go through GitHub, email david.anderson@excelano.com instead. I aim to respond within seven days.

Please do not open public issues for security problems.

## Supported versions

The latest release receives security fixes. Older versions are not supported. A fix ships in a new App Store release.

## What Peilung can access

Peilung makes no network request, opens no socket and links no networking or analytics code.

It reads location and motion only with permission, and only on the device running it. Location is read while the app is on screen and the display is not dimmed, the compass while the navigation page is showing, and distance from the step count while the odometer runs. Each needs the permission the system asks for, and none of it leaves the device. The watch app and the iPhone app exchange the current goal, the saved marks, the odometer's start and stop times and start position, the units, north and coordinate format settings, and the learned magnetic declination with the position it was learned at, passed between the paired devices through Watch Connectivity. Step counts are not exchanged.

## What Peilung stores

The odometer reading, saved marks, the current target, the settings, the page last shown and the last magnetic declination with where it was learned are kept in the app's own storage on the watch and the iPhone, and removing the app from one removes them from it. A deleted mark leaves its identifier and the time of deletion for 90 days, so the deletion reaches the other device. On the watch, the app also leaves the current target's name and the odometer's start and stop times in a container shared only with its own widget, which reads the distance from the step count itself.
