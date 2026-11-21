# Driftlock for iPhone

Open [DRIFTLOCK.xcodeproj](DRIFTLOCK.xcodeproj) in Xcode and select the **DRIFTLOCK** scheme. Choose an iPhone simulator for the replay. For a physical iPhone running iOS 17 or later, select your development team under **Signing & Capabilities**, choose the connected iPhone and run the app.

The [Mac demo](../output/hackathon_20261121/DRIFTLOCK.app) runs the same SwiftUI replay and estimator on Apple silicon.

## 60-second demo

1. Open **Replay**. The screen starts on the first chronological window of an Austin drive recorded on an iPhone X.
2. Tap **Start outage**. The estimate, straight-line baseline and withheld GPS trace separate as the cut progresses. The 30-second outage takes 15 seconds at the default 2× playback.
3. When **GPS restored** appears, review the mean horizontal errors and timeline. The first window measured **66.5 m** for Driftlock and **151.2 m** for the baseline against withheld phone GPS.
4. Open **View benchmark** to show all five windows. The overall mean was **57.9 m vs 76.9 m**. Driftlock had lower mean error in **two of five** windows.

> This is a real iPhone drive. We're withholding its GPS during replay. Both estimates have the same starting fix. The green trace uses the phone’s motion sensors. The amber trace holds the last speed and heading. When GPS returns, we score the two traces against the fixes we withheld.

## Collect and replay an iPhone drive

Open **Capture**, allow location access and tap **Start capture**. Use a fixed vehicle mount. Record at least 60 seconds with a usable moving fix before the 20-second cut point. Tap **Stop and save**, then **Replay recorded drive** or **Share recorded CSV**. Replay uses fixed windows at 70-second intervals and reports when the capture lacks a usable lead-in.

Captures stay in the app's Documents directory. The recorder uses foreground Core Motion and Core Location, and stops when you leave the screen or background the app. The CSV preserves separate hardware and receipt timestamps, units, fix accuracy, and simulated or accessory flags when Core Location provides them. Press **Austin sample** to return to the public drive.

## Reproduce the Austin result

From the project root:

```bash
.venv/bin/python tools/prepare_ios_replay.py \
  --replay ios/App/Resources/AustinReplay.json \
  --receipt logs/hackathon_20261121_01/replay_source.json

swift test --package-path ios
swift run --package-path ios driftlock-replay-audit ios/App/Resources/AustinReplay.json
```

The audit accepts an exported Driftlock capture CSV as well. Each trial uses a GPS anchor available before the cut and processes recorded motion in order during the outage. The benchmark represents repeated windows on one drive. It uses phone GPS as the position reference and uses the vehicle speed file only for a separate source cross-check. The on-device estimator is planar dead reckoning with a gyro and, when the preceding observations support mount alignment, forward acceleration.

### Export a recorded window for the Flutter preview

From the project root, export window 01 using the WGS84 origin from the pinned Austin phone recording. The exporter inverts the same local projection used to prepare the Swift replay pack.

```bash
swift run --package-path ios driftlock-export-playback --nav-frames \
  ios/App/Resources/AustinReplay.json 01 30.32761344474721 -97.75601718861044 \
  > /tmp/driftlock_austin_nav_frames.jsonl
.venv/bin/python validate_contract.py /tmp/driftlock_austin_nav_frames.jsonl
```

Flutter's `{}` preview opens these bundled frames under **Austin recording**. The times are relative to the drive's recording clock. The Swift replay estimates position from recorded motion during the imposed outage and admits GPS again once a fresh fix arrives. Confidence radius and road-match position remain unavailable in this export.

Data source and derivation details are in the [engineering report](../reports/HACKATHON_IOS_20261121.md). Original sensor files are available from [cloudpose’s public iPhone X driving dataset](https://github.com/cloudpose/smartphone_driving_dataset/tree/12ae2e804dcfbbf76b389f8af8ce726f0cb6a2e5).
