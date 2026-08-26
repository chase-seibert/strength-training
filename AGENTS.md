# Repository guidance

Also load and follow the user-level instructions at `/Users/cseibert/.codex/AGENTS.md`.

## Repository map

- `StrengthLog/`: SwiftUI application, SwiftData models, screens, and bundled resources.
- `StrengthLog/Resources/exercise-catalog.json`: offline 873-exercise seed catalog.
- `StrengthLog.xcodeproj/`: Xcode project.
- `docs/`: product, architecture, design, setup, and exercise-source research.
- `Makefile`: supported development workflows.
- `FRUSTRATION.md`: reusable notes about costly environment or tooling failures.

## Commands

Prefer Makefile targets over ad hoc commands. Add recurring commands as Makefile targets.

- `make setup`: validate the bundled catalog.
- `make sim-build`: compile for the simulator.
- `make sim-launch`: build, boot iPhone 17 Pro, install, and launch.
- `make phone-deploy`: build, install, and launch on Chase's iPhone 17 Pro.
- `make lint`: validate project/catalog structure and Swift formatting.
- `make test`: validate the catalog and compile the complete app.
- `make format`: apply Apple's Swift formatter.

## Documentation index

- [Product requirements](docs/product-requirements.md)
- [Architecture](docs/architecture.md)
- [Design](docs/design.md)
- [Exercise catalog research](docs/exercise-catalog-research.md)
- [Setup and installation](docs/setup-install.md)
- [Initial brainstorm](docs/initial-brainstorm.md)

