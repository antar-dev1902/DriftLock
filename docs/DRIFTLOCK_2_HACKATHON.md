# DriftLock 2.0 for HackBriven

DriftLock estimates movement through a GPS blackout and shows when its position is uncertain. The offline demonstration replays real iPhone X motion recorded in Austin, with GPS fixes deliberately withheld. The Swift estimator and capture format are shared with the standalone native DriftLock app.

## Run on iOS

The verified simulator was **iPad Pro 13-inch (M5), iPadOS 26.5**, with Xcode 27.2 and Flutter 3.50.1. Open the Flutter iOS workspace in Xcode and run the **Runner** scheme on an iOS simulator.

```sh
cd hackbriven/driftlock/driftlock_flutter
flutter pub get
open ios/Runner.xcworkspace
```

The prebuilt simulator archive contains `Runner.app`. With an iOS simulator already booted, install and launch it from the extracted archive directory.

```sh
xcrun simctl install booted Runner.app
xcrun simctl launch booted space.serverpod.driftlock
```

An iPhone running iOS 17 or later is needed for physical motion capture. Select your development signing team in Xcode. In the app, open **Start Recording**, grant location access, and record at least 60 seconds with a recent moving fix before the planned cut. **Stop and save** keeps the CSV on the phone. **Replay recorded drive** runs the Swift estimator and opens the result in Flutter. The Mission Library opens or exports saved captures individually. Physical capture and device signing have yet to be verified for this Flutter build.

## Run the offline browser build

Extract the web archive and double-click `Start DriftLock.command` on macOS. It serves the bundled renderer and data on `127.0.0.1:8765`. You can also run it directly with Python 3 from the extracted directory.

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory web
```

Open [http://127.0.0.1:8765](http://127.0.0.1:8765). The browser build supports playback, scoring, exports and typed questions. Motion capture is available on iPhone.

## Three-minute judge demo

| Time | Action | What to say |
|---|---|---|
| 0:00–0:25 | Open **Mission Control → Start Judge Mode**. | “Inside a tunnel, a GPS dot can freeze. DriftLock keeps estimating motion and tells you when that estimate is unverified. We’re replaying a real iPhone recording from Austin and imposing a GPS outage.” |
| 0:25–0:55 | Tap **Start outage**. Point to the cyan estimate, amber constant-speed baseline and purple last-known position. | “The Swift estimator gets phone motion during the blackout. It receives a new GPS position only after a fresh post-outage fix arrives. The display shows how long the estimate has been running without GPS.” |
| 0:55–1:20 | Enable **Evaluation mode**. Scrub back through the blackout, then seek past 52 seconds. Show the error chart. | “The withheld phone GPS appears here for evaluation. There is no calibrated confidence radius yet, so the app shows the actual availability and age of the estimate.” |
| 1:20–2:10 | Open **View benchmark**. Compare **30 s**, **60 s** and **90 s**. Open an incomplete 90-second trial. | “In the five 30-second windows, DriftLock averaged 57.9 metres against 76.9 for constant speed. It improved in two of five. In the one scored 90-second window, holding the last GPS location was better. All windows come from one original drive.” |
| 2:10–2:35 | Go back and open **Voice Copilot**. Tap **Position reliability** and **Maximum error**. | “The typed assistant answers from this replay frame and completed comparison. The microphone path uses Serverpod and Gnani when those services are available.” |
| 2:35–3:00 | Open the **Mission Library**. Show the locally available Austin mission and the consent-gated Serverpod sync action. | “The demo runs offline. A user can choose to sync the mission summary. Adaption’s prepared dataset covers explanations about lost GPS and uncertainty.” |

## Reproduce the benchmark

From the repository root, build the Swift package and generate the app assets and canonical Serverpod metrics.

```sh
swift test --package-path ios
swift build --package-path ios
python3 tools/export_hackathon_evidence.py ios/.build/debug/driftlock-export-playback
python3 validate_contract.py contracts/fixtures
python3 validate_contract.py hackbriven/driftlock/driftlock_server/web/evidence
python3 validate_contract.py hackbriven/driftlock/driftlock_flutter/assets/nav_frame_austin_swift.jsonl
```

The generator checks all five legacy playback windows field by field and preserves the frozen `DRIFTLOCK-IFACE-1.0` contract. The new replay and benchmark presentation files use separate versioned schemas. The score compares eligible withheld phone fixes at measurement time. Each aggregate includes only complete windows. All three methods are scored on the same fixes. P90 uses nearest rank. The 30-second schedule preserves the original five trials. The new durations use 20 seconds of lead-in, the full outage, and 10 seconds of recovery. Trial starts are fixed at recording time zero and spaced by the full window plus 10 seconds.

| Imposed outage | Complete windows | Fixes | DriftLock mean | Constant speed and heading mean | Last known position mean |
|---|---:|---:|---:|---:|---:|
| 30 s | 5 / 5 | 150 | 57.9 m | 76.9 m | 181.1 m |
| 60 s | 2 / 3 | 120 | 229.9 m | 297.9 m | 267.6 m |
| 90 s | 1 / 2 | 90 | 384.0 m | 580.1 m | 240.2 m |

The recorded phone GPS is the comparison reference. The original phone and vehicle source hashes and clock checks are in `logs/hackathon_20261121_01/replay_source.json`. The vehicle-speed file was used only by the source audit. [Public source and pinned revision](https://github.com/cloudpose/smartphone_driving_dataset/tree/12ae2e804dcfbbf76b389f8af8ce726f0cb6a2e5)

## Connected services and open checks

| Capability | State |
|---|---|
| Serverpod mission storage | The generated client and authenticated, owner-scoped save/list/get endpoints exist. Server-side validation tests pass. Embedded PostgreSQL failed to allocate shared memory from the managed shell, so a fresh database round trip was blocked. The local runner did not answer. No authenticated Serverpod Cloud target was configured in this workspace. |
| Analytics | The Serverpod web server serves the three validated, public summaries at `/analytics/benchmark/austin-30s.json`, `/analytics/benchmark/austin-60s.json`, and `/analytics/benchmark/austin-90s.json` when the backend is running. |
| Gnani | The backend loads the development key and the mocked REST tests cover transcription, WAV and fallback. The managed shell could not resolve the provider host and the local backend was unavailable. The app verified the offline question path. |
| Adaption | `hackbriven/adaption/gps_status_guidance.jsonl` contains 12 guidance examples. `evaluation_cases.jsonl` contains six separate rubric cases. The account key and model were absent. No provider adaptation or evaluation ran. The live debrief API has tested fallback wording and uses no sensor training data. |
| Error prediction | `tools/drift_risk_experiment.py` implements a train-only NumPy ridge fit, validation comparison and separate calibration-group diagnostic. The data eligibility check recorded a blocker. The available benchmark has one original drive and zero training-approved groups. No model was fitted. |
| Road matching and ML correction | Both remain unavailable in this replay. The offline benchmark supports the existing physics estimator and the two baseline comparisons. |

To use Serverpod Cloud, configure the project's authenticated deployment and database, then build the Flutter client with `--dart-define=SERVER_URL=https://<project-id>.api.serverpod.space/`. The existing Serverpod login and owner-scoped mission endpoints handle user separation. Set sponsor keys through Serverpod secrets. The iPhone recording CSV stays local until explicitly exported. [Serverpod Cloud deployment](https://docs.serverpod.dev/deployments/deploy-to-serverpod-cloud) · [Gnani REST transcription](https://docs.gnani.ai/api/STT/speech-to-text) · [Adaption Adaptive Data quickstart](https://docs.adaptionlabs.ai/adaptive-data-quickstart)
