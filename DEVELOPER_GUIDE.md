# Skale Developer Guide

This guide takes you from a fresh machine to a running Skale build. Follow it top to bottom. At the end you will run a physics test that prints a box falling under gravity and coming to rest on a floor — if that works, the entire stack is functional.

---

## What You're Building

Skale uses three C++ libraries wired together:

```
OpenCASCADE (geometry) → Project Chrono (physics) → Godot (rendering + interaction)
```

The Chrono integration is a C++ shared library (GDExtension) that Godot loads at startup. You build that library with CMake, then run the Godot binary against the project folder.

**Current build milestone:** Phase 2 — Chrono physics running inside Godot. Geometry (OCCT) comes in Phase 5.

---

## System Requirements

| Item | Minimum |
|---|---|
| OS | Linux (Debian/Ubuntu) or Windows 10+ |
| CPU | x86_64, any modern multi-core |
| RAM | 8 GB (16 GB recommended for building Chrono) |
| Disk | ~5 GB free (Chrono source + build artifacts) |
| GPU | Any GPU with OpenGL 3.3+ support |

---

## Dependencies

### Linux (Debian/Ubuntu)

Install build tools and OpenCASCADE dev packages in one command:

```bash
sudo apt install \
  git cmake ninja-build build-essential pkg-config \
  libocct-foundation-dev libocct-modeling-algorithms-dev \
  libocct-modeling-data-dev libocct-visualization-dev \
  libocct-data-exchange-dev \
  libeigen3-dev libglm-dev
```

### Windows

> Windows build instructions are coming in a future update. For now, develop on Linux.

---

## Step 1 — Get Godot

Download the **Godot 4.6.x** Linux binary from [godotengine.org](https://godotengine.org/download).

Put it somewhere permanent — we'll call that path `GODOT_BIN` below. Example:

```bash
mkdir -p ~/bin
mv ~/Downloads/Godot_v4.6.x-stable_linux.x86_64 ~/bin/godot
chmod +x ~/bin/godot
```

**Version matters.** The godot-cpp submodule is pinned to `godot-4.5-stable`, which is compatible with Godot 4.5.x and 4.6.x. Do not use Godot 4.7+ until the submodule is updated.

---

## Step 2 — Build Project Chrono

Chrono is not available as a system package. You must build it from source.

```bash
git clone https://github.com/projectchrono/chrono.git
cd chrono
git checkout tags/9.0.1
mkdir build && cd build

cmake .. -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DENABLE_MODULE_IRRLICHT=OFF \
  -DENABLE_MODULE_VSG=OFF \
  -DENABLE_MODULE_GPU=OFF \
  -DENABLE_MODULE_FSI=OFF \
  -DENABLE_MODULE_VEHICLE=OFF \
  -DENABLE_MODULE_SENSOR=OFF \
  -DENABLE_MODULE_PARSERS=OFF \
  -DENABLE_MODULE_CSHARP=OFF \
  -DENABLE_MODULE_PYTHON=OFF \
  -DBUILD_TESTING=OFF \
  -DBUILD_BENCHMARKING=OFF

ninja -j$(nproc)
sudo ninja install
```

This takes 10–20 minutes depending on your hardware. When it finishes, verify:

```bash
ls /usr/local/lib/libChronoEngine.so   # should exist
ls /usr/local/lib/cmake/Chrono/        # should contain chrono-config.cmake
```

---

## Step 3 — Get the Skale Source

**Fresh clone:**
```bash
git clone --recurse-submodules https://github.com/your-org/Skale.git
cd Skale
```

**Already have the repo (pull + sync submodules):**
```bash
cd Skale
git pull
git submodule update --init --recursive
```

> **Important:** `git submodule update` without `--init --recursive` will silently do nothing if the submodule was never initialized. Always use `--init --recursive`.

Verify the submodule is populated before continuing:
```bash
ls thirdparty/godot-cpp/include/   # should show godot_cpp/ directory
```

If that directory is empty, the build will fail. Re-run `git submodule update --init --recursive`.

---

## Step 4 — Build Skale

```bash
mkdir build && cd build

cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Debug

ninja -j$(nproc)
```

The first build compiles godot-cpp (~2000 generated files) and takes several minutes. Subsequent builds only recompile changed files and are fast.

**Expected output:**
```
[...] Building CXX object ...
[...] Linking CXX shared library src/extension/libskale.so
Copying extension to project/bin/
```

If the build succeeds, confirm the output landed in the right place:

```bash
ls ../project/bin/libskale.so   # should exist and be ~13MB
```

---

## Step 5 — Run the Physics Test

**Before running, verify the build output is in place:**
```bash
ls project/bin/libskale.so          # must exist
ldd project/bin/libskale.so         # all deps must show a path, none "not found"
```

If `libskale.so` is missing, the build failed — check ninja output for errors.  
If any `ldd` entry shows `not found`, a runtime library is missing (most likely `libChronoEngine.so` — check that Chrono was installed with `sudo ninja install`).

**Run from the repo root (not the `build/` directory):**
```bash
/path/to/godot --headless --path project --script res://scripts/test.gd -v
```

Replace `/path/to/godot` with your actual Godot binary path (e.g. `~/bin/godot`).

**Expected output:**

```
--- Skale Physics Test ---
  t(s)     box_y
  0.000    5.0000
  0.333    4.4278
  0.667    2.7655
  1.000    0.3980
  1.333    0.4035
  1.667    0.3500
  2.000    0.3500
  ...
  4.000    0.3500
--- Done ---
```

The box starts at y=5, falls under gravity, hits the floor (~t=1s), bounces once, and comes to rest at y=0.35. That rest position is deterministic: floor top (y=0.1) + box half-height (0.25) = 0.35.

> **Note on the `-v` flag:** This verbose flag is required on first run because Godot needs to scan the project and discover the GDExtension. After the first successful run, the `.godot/` cache is populated and `-v` is optional.

---

## Troubleshooting

### `libskale.so` not found / extension not loading

Godot looks for the library at `project/bin/libskale.so`. The CMake post-build step copies it there automatically. If it's missing, run `ninja` again and check for errors.

### `SkaleHello` / `SkaleSimulation` not declared in GDScript

The extension isn't loading. Check:
1. Does `project/bin/libskale.so` exist?
2. Does `project/skale.gdextension` point to the right path (`res://bin/libskale.so`)?
3. Run with `-v` for verbose output — Godot will print extension load errors.

### `relocation R_X86_64_PC32 ... recompile with -fPIC`

The `skale_core` static library wasn't compiled with position-independent code. Ensure `src/core/CMakeLists.txt` contains:
```cmake
set_property(TARGET skale_core PROPERTY POSITION_INDEPENDENT_CODE ON)
```
Then delete `build/` and rebuild from scratch.

### Chrono not found by CMake

CMake looks for Chrono at `/usr/local/lib/cmake/Chrono/`. If you installed Chrono to a different prefix, edit `src/core/CMakeLists.txt` and update the `PATHS` argument in `find_package(Chrono ...)`.

### Box falls through the floor (no collision)

This was a known issue during development. Ensure `SimulationCore::SimulationCore()` calls:
```cpp
m_impl->system.SetCollisionSystemType(chrono::ChCollisionSystem::Type::BULLET);
```
before any bodies are added.

### Build is very slow

First build of godot-cpp always takes several minutes — that's normal. Use `ninja -j$(nproc)` to parallelize. If RAM is tight (under 8 GB), reduce to `-j4`.

---

## Project Structure

```
Skale/
├── CMakeLists.txt          # top-level build
├── thirdparty/
│   └── godot-cpp/          # git submodule — GDExtension C++ bindings
├── src/
│   ├── core/               # pure C++ — Chrono wrappers, no Godot headers
│   │   ├── skale_types.h   # shared plain-C++ types (Vec3, Quat)
│   │   ├── simulation_core.h/cpp
│   │   └── body_core.h/cpp
│   └── extension/          # GDExtension — Godot nodes, no Chrono headers
│       ├── register_types.h/cpp
│       └── physics/
│           ├── skale_simulation.h/cpp
│           └── skale_body.h/cpp
├── project/                # Godot project
│   ├── project.godot
│   ├── skale.gdextension
│   ├── bin/                # compiled .so/.dll (populated by CMake post-build)
│   └── scripts/
│       └── test.gd         # physics verification test
└── build/                  # CMake build directory (gitignored)
```

### Why two source layers?

godot-cpp compiles with `-fno-exceptions`. Chrono's headers use C++ exceptions internally. Mixing them in the same translation unit causes a compile error.

The fix: `src/core/` is a static library (`skale_core`) compiled with normal C++ settings — it can include Chrono freely. `src/extension/` only includes `src/core/*.h` headers, which expose a clean plain-C++ interface with no Chrono types. The GDExtension links both libraries.

---

## Next Steps

If the physics test passes, you're set up correctly. The next milestone is **Phase 3: Design Mode / Run Mode** — a Godot scene with a 3D viewport, camera, and toolbar where you can add bodies and run the simulation interactively.

See [ROADMAP.md](ROADMAP.md) for the full plan.
