# Security Policy

## Reporting a vulnerability

Please report suspected vulnerabilities privately through GitHub Security Advisories at https://github.com/excelano/peilung/security/advisories/new. If you would rather not use GitHub, email david.anderson@excelano.com instead. I aim to respond within seven days.

Please do not open public issues for security problems.

## Supported versions

Only the latest version on the App Store receives fixes. Security fixes ship through `main` and reach the App Store in the next release; there are no maintained release branches.

## Security model

**Peilung has no network surface.** It makes no network request, opens no socket and links no networking or analytics code.

**It reads location and motion only with permission, and only on the watch.** Location is read while the app is on screen, the compass while the navigation page is showing, and walking distance from the step count while the odometer runs. Each needs the permission watchOS asks for, and none of it leaves the watch.

**What it keeps stays on the watch.** The odometer reading, saved marks, the current target and the settings are kept in the app's own storage on the watch, and removing the app removes them. The complication shares nothing with the app; it only opens it.
