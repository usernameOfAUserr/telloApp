# Tello EDU Controller

Android-first Flutter app for controlling a DJI Tello EDU over its local Wi-Fi.
The default command interface runs in portrait mode. Starting the live feed
switches the app to a landscape video HUD and decodes the Tello H.264 stream
natively on Android.

## Features

- SDK connection to `192.168.10.1:8889` and automatic `command` handshake
- Takeoff, landing, hover/stop, and emergency motor stop
- Two multitouch-friendly virtual joysticks
- `rc a b c d` commands every 50 ms, including neutral commands on release
- Telemetry listener on UDP port `8890`
- Battery, height, flight time, temperature, attitude, velocity,
  acceleration, barometer, and time-of-flight display
- Lifecycle safety: neutral controls when the app leaves the foreground
- Command timeout, connection state, telemetry watchdog, and visible errors
- Riverpod-based separation between UI and the central controller
- Native Android H.264 live view from UDP port `11111` using `MediaCodec`
- Automatic portrait/landscape switching based on live-video state
- One-tap flip and 360-degree rotation routines
- Repeatable multi-command routines for circles, spirals, squares, and zigzags
- Dark-green cyber/HUD interface with dedicated control, tricks, and data tabs
- In-video dual-stick flight controls plus takeoff, hover, and landing
- Photo capture and MP4 recording directly into the Android media gallery

## Prerequisites

- Flutter with Dart 3.7 or newer
- Android SDK and an Android device
- DJI Tello EDU

## Run and test

The repository intentionally does not contain
`android/gradle/wrapper/gradle-wrapper.jar`, because the review system does not
accept binary files. Generate it once with an installed Gradle distribution:

```bash
cd android
gradle wrapper --gradle-version 8.11.1
cd ..
```

The generated JAR is ignored by Git and remains available in the local working
copy. After that, fetch the Flutter dependencies and run the checks:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

1. Connect the phone to the Wi-Fi network broadcast by the Tello.
2. Disable mobile-data switching for that network if Android tries to leave it
   because it has no internet access.
3. Start the app and tap **Mit Tello verbinden**.
4. Verify all control directions at low altitude in a clear indoor area.
5. Tap **LIVE FEED INITIALISIEREN** to send `streamon`, rotate to landscape,
   and open the native Android video surface.
6. Use the camera and record controls in the upper-right HUD. Photos are saved
   under Pictures/Tello and MP4 recordings under Movies/Tello.

The unit tests do not require a drone. Hardware validation must verify command
responses, axis directions, packet loss, latency, app background behavior, and
the device-specific Wi-Fi behavior.

## Safety

- Keep the standard Tello app available during early testing.
- Test with propeller guards and ample clearance.
- **NOT-AUS** sends `emergency`, immediately stopping the motors.
- The app sends neutral RC values when joysticks are released or the app moves
  to the background, but mobile operating systems cannot guarantee execution
  after a process is killed.

## Architecture

```text
lib/src/
├── controllers/  Central flight state and safety behavior
├── models/       RC command and telemetry data
├── providers/    Riverpod dependency exposure
├── screens/      Main control dashboard
├── services/     UDP sockets and command-response handling
└── widgets/      Joysticks and telemetry cards
```

The native Android video path is implemented in
`android/app/src/main/kotlin/de/example/telloapp/TelloVideoView.kt`. It
assembles the Tello UDP packets into H.264 access units and renders decoded
frames directly to an Android `SurfaceView`.

## Next phase

Device testing should validate MediaCodec compatibility, gallery export,
recording playback, and the available clearance for multi-command routines.
