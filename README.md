# Tello EDU Controller

Android-first Flutter app for controlling a DJI Tello EDU over its local Wi-Fi.
This first phase deliberately excludes the H.264 video stream.

## Features

- SDK connection to `192.168.10.1:8889` and automatic `command` handshake
- Takeoff, landing, hover/stop, and confirmed emergency motor stop
- Two multitouch-friendly virtual joysticks
- `rc a b c d` commands every 50 ms, including neutral commands on release
- Telemetry listener on UDP port `8890`
- Battery, height, flight time, temperature, attitude, velocity,
  acceleration, barometer, and time-of-flight display
- Lifecycle safety: neutral controls when the app leaves the foreground
- Command timeout, connection state, telemetry watchdog, and visible errors
- Riverpod-based separation between UI and the central controller

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

## Next phase

The video feature should bind UDP port `11111`, start it with `streamon`, decode
H.264 with Android MediaCodec, and expose rendered frames to Flutter. Photo and
MP4 gallery export should be added only after stream stability is established.
