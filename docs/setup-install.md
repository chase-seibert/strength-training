# Setup and installation

## Requirements

- macOS with Xcode 26 or a compatible version supporting iOS 17, SwiftData, and Swift Charts.
- `jq` for catalog validation.
- No package installation or API key is required.

## Simulator

```sh
make setup
make sim-launch
```

The default is `iPhone 17 Pro`. Override it with `make sim-launch SIM_DEVICE_NAME='iPhone 15 Pro'`.

## Physical device

Connect and unlock Chase's iPhone 17 Pro, trust the Mac if prompted, then run:

```sh
make phone-deploy
```

Defaults are device `00008150-000E41422E40401C` and Apple Personal Team `96NAC4VTEN`. The physical build uses automatic signing and provisioning updates.

## Validation

```sh
make lint
make test
```

`make lint` also validates that all 1,746 bundled WebP images exactly match the catalog and compiles and runs a Hevy CSV parser fixture covering quoted commas, routine/workout grouping, set ordering, duration, and RPE. `make bundle-exercise-images` reproducibly fetches the pinned Free Exercise DB revision and rebuilds the 640-pixel, quality-65 WebP set. `make test` validates all 873 normalized catalog records, all image references, and performs a full simulator compile. The Debug Hevy smoke test uses an isolated in-memory store to verify selected-routine filtering, complete routine exercise unions, unmapped-exercise skipping, collision-safe routine naming, per-set history, and duplicate-history protection. The clean iOS 17 runtime smoke test verified that onboarding appears and that first launch persists 873 exercises, zero people, and zero routines before the user completes setup.
