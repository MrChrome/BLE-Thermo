# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

```bash
./build.sh
```

Produces `build/BLE Thermo.app`. The script resolves Swift packages first, then builds with `-disableAutomaticPackageResolution` to avoid the silent SPM network-wait on subsequent builds. Requires Xcode with command-line tools. Run from the repo root.

To build directly:
```bash
xcodebuild -project BLESensors.xcodeproj -scheme BLESensors -configuration Release \
  -destination 'platform=macOS,arch=arm64' -disableAutomaticPackageResolution \
  BUILD_DIR=build CONFIGURATION_BUILD_DIR=build
```

There are no tests.

## Architecture

This is a macOS menu-bar app (no dock icon) that reads Bluetooth LE temperature/humidity sensors and optionally bridges them to HomeKit.

**Data flow:**
1. `BluetoothScanner` — scans for BLE advertisements, decodes Govee sensor packets (manufacturer data), pushes readings to `SensorStore`. Also connects to LED strip peripherals via `ObjCBLEDelegate` (ObjC shim required because `CBCentralManagerDelegate` can't be implemented directly in Swift in this project).
2. `SensorStore` — central `@Observable` state. Holds all current `SensorReading` values, runs timers to log to `SensorDatabase` (every 60 s), time out missing sensors (15 min remove / 5 min unreachable), and drive LED color changes.
3. `SensorDatabase` — SQLite3 via raw `sqlite3_*` C API. Single table `readings(timestamp, name, temp_f, humidity)`. The web server reads from this; the main app only writes. **The server is single-threaded/serialized — never issue concurrent requests to `/api/data`.**

**Sensor sources** (all merge into `SensorStore.sensors`):
- **Govee** BLE sensors — decoded in `BluetoothScanner.decodeGovee()`
- **Mysa** thermostats — polled every 60 s via `MysaClient` using AWS Cognito SRP auth (`CognitoSRP.swift`)
- **HomePod** — read via private HomeKit API through `HomePodReader` / `HomePodInterface` (ObjC)

**Device aliases / config** — `~/Library/Application Support/BLESensors/devices.json` maps BLE device names (e.g. `GVH5075_1669`) to display aliases (e.g. `Attic`) and HomeKit enrollment. The bundled `BLESensors/devices.json` is the fallback. `DeviceAliases.load()` / `DeviceAliases.save()` manage this file. Renaming a sensor in the UI renames historical records in the database too.

**HomeKit bridge** — `HomeKitBridge` uses the `HAP` package (swift-nio based). Exposes each opted-in sensor as a `Thermometer` accessory with humidity and battery services. Also exposes the BLE LED strip as a `Lightbulb` and Roku TVs as `Television` accessories. Pairing state is stored in `~/Library/Application Support/BLESensors/hap.json`; delete this file to reset HomeKit pairing.

**Web server** — `WebServer` uses `NWListener` on port 80. Serves a single-page dashboard defined entirely in `WebDashboardHTML.swift` as a Swift string constant. The frontend uses Chart.js for historical charts and fetches from these endpoints:
- `GET /api/data?range=<hour|6h|today|yesterday|day|month|year>` — always returns all sensors; client filters for the selected sensor/favorites. Dew point is calculated client-side from temp + humidity using the Magnus formula.
- `GET /api/sensors` — list of sensor names
- `GET|POST /api/title` — dashboard title
- `GET|POST /api/floorplan` — floor plan image (stored in Documents dir)
- `GET|POST /api/floorplan/positions` — sensor pin positions (stored in UserDefaults)

**UI:**
- `ContentView` — the floating panel showing live sensor readings, sorted hottest-first
- `GraphView` / `AllSensorsGraphWindow` — native SwiftUI chart window ("Graph All…" menu item)
- `SettingsView` — Mysa credentials, HomePod toggle, HomeKit setup code
- The web dashboard is the primary charting interface

**LED strip** — `ELK-BLEDOM` BLE devices are detected as LED strips. `LEDStripController` sends BLE write commands. `SolarCalculator` computes a time-of-day color for auto mode.

**Roku** — `RokuScanner` discovers TVs via SSDP, `RokuController` sends ECP commands. TVs are exposed to HomeKit as `Television` accessories.
