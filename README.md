# Skale

> The thing you want to invent, digitally built and fully interactive.

Skale is an open-source desktop tool for inventors, makers, and garage engineers. Build your mechanical idea as a real digital object — then live inside the simulation and see if it works.

## What Makes Skale Different

Every CAD tool with physics has a hard wall between "design mode" and "simulate mode." You build, press a button, watch it run, stop it, go back to design. That wall is what makes engineering software feel clinical instead of something you actually want to use.

**Skale removes that wall.**

- **Design mode** — Model geometry with CAD-quality tools. Place objects, set physical properties, define constraints. The world is yours to build.
- **Run mode** — Press play. The world goes live. Physics runs in real time. You reach in and interact with it like a game.

Think *Half-Life 2* physics sandbox, but the things you're throwing around are things you engineered yourself.

## Tech Stack

| Role | Technology |
|---|---|
| Frontend / Interaction | [Godot 4](https://godotengine.org/) |
| Physics Simulation | [Project Chrono](https://projectchrono.org/) |
| 3D Geometry / CAD | [OpenCASCADE (OCCT)](https://dev.opencascade.org/) |
| Build System | CMake (cross-platform) |
| Primary Language | C++ (engine layer) + GDScript (UI / application logic) |

Project Chrono replaces Godot's built-in physics backend via GDExtension, becoming the simulation engine underneath Godot's scene system. OpenCASCADE handles parametric geometry and CAD operations in Design mode. Godot handles everything visible and interactive.

## Status

Early development. See [ROADMAP.md](ROADMAP.md) for planned milestones and current progress.

## Dependencies

- CMake 3.20+
- GCC 12+ or MSVC 2022+
- Ninja (recommended build backend)
- Godot 4.3+
- Project Chrono 9.x (built from source)
- OpenCASCADE 7.7+ (`libocct-*-dev` on Debian/Ubuntu)
- `godot-cpp` (included as a git submodule)

## Building

Build instructions will be finalized in Phase 0. See the [wiki](https://github.com/your-repo/Skale/wiki) for dependency setup guides.

## Contributing

Skale is early-stage and the architecture is actively being defined. Check the [roadmap](ROADMAP.md) and [wiki](https://github.com/your-repo/Skale/wiki) before diving in.

## License

[MIT](LICENSE)
