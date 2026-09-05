# Coordinate probe

Open **Coordinate Probe** below **DeepHierarchy** on the IntegrationApp home screen.
Use the standard Back button to return to the existing fixtures. Opening the probe
creates a fresh measurement session.

The **Touch** canvas records actual `UITouch.locationInView:` coordinates rather
than assuming that a gesture succeeded because it hit a large button. **Scroll**
shows 80 numbered rows, each 44 points high.

## Automation identifiers

| Identifier | Purpose |
| --- | --- |
| `coordinate-probe` | Home screen button that opens the probe |
| `probe-status` | Label containing the measurement JSON |
| `coordinate-canvas` | Touch target |
| `probe-mode` | Touch/Scroll segmented control |
| `probe-table` | Scrollable table |
| `probe-row-0` through `probe-row-79` | Individual table rows |

The `probe-status` label exposes `start`, `last`, `phase`, and `count` after a
touch. `start` and `last` are **canvas-local app points**. It also exposes
`canvasBounds`, `canvasWindowRect`, `windowSize`, `screenSize`, and `scrollY`.
Geometry is refreshed when the view lays out, including after rotation or window
resizing. Touch-related fields are absent before the first touch.

For example, locate `coordinate-probe` by accessibility ID and click it. Then
locate `coordinate-canvas`, send an element-relative action, and read the JSON
from `probe-status`. Check that `count` increased and compare `start`/`last` with
the expected canvas-local point within a suitable tolerance. Derive test offsets
from the current element rectangle rather than hard-coding a device size.

## Native and compatibility builds

The screen uses the same source for both configurations. Keep the IntegrationApp
scheme and set the build's `TARGETED_DEVICE_FAMILY`:

- `1,2`: native support for iPhone and iPad (the existing default).
- `1`: iPhone-only; install on iPad to exercise iPhone compatibility mode.

These are build settings, not a switch within the running app. Verify the actual
window and element frames before interpreting results. An iPad-native app can
also run in a resized window; maximize it when testing a full-screen native case.
For the compatibility case, compare app and SpringBoard window sizes and the
reported element rectangles with the recorded probe geometry.

If keeping both builds installed at once, give them distinct bundle IDs. This
change does not add another app target or alter the existing bundle ID or signing
configuration.
