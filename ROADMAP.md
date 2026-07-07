# Skale Roadmap

Development is organized into sequential phases, each with a clear deliverable. A phase is complete when its deliverable works end-to-end, not just when the code is written.

---

## Phase 0 — Development Environment
**Deliverable:** CMake builds cleanly, Godot launches, all dependencies are confirmed present.

- [ ] Install CMake, Ninja, build-essential
- [ ] Install OpenCASCADE dev packages (apt)
- [ ] Build Project Chrono from source (no apt package exists)
- [ ] Download Godot 4 binary
- [ ] Initialize git repository
- [ ] Add `godot-cpp` as a git submodule
- [ ] Write top-level CMakeLists.txt skeleton
- [ ] Confirm clean build on Linux

---

## Phase 1 — GDExtension Hello World
**Deliverable:** GDScript calls a C++ function and gets a result back.

- [ ] Minimal GDExtension: one C++ class with one method
- [ ] CMake compiles extension to `.so` (Linux) and `.dll` (Windows)
- [ ] Godot loads the extension at startup
- [ ] GDScript instantiates the class and calls the method
- [ ] Establish the exact Godot version ↔ godot-cpp version lock

---

## Phase 2 — Chrono Physics in Godot
**Deliverable:** A box falls under gravity and bounces off a floor, rendered in Godot's viewport.

- [ ] Chrono linked into the GDExtension
- [ ] `ChSystem` stepping inside Godot's `_physics_process` (fixed timestep)
- [ ] Rigid body transforms synced to `MeshInstance3D` nodes each frame
- [ ] Box + static floor scene demonstrating live simulation
- [ ] Confirm simulation stability (no drift or explosion at default timestep)

---

## Phase 3 — Design Mode / Run Mode
**Deliverable:** A user can add objects, configure them, and run a live physics simulation without touching code.

- [ ] 3D viewport with free-fly observer camera (orbit, pan, zoom)
- [ ] Toolbar and properties panel (Godot UI)
- [ ] Add primitive bodies in Design mode: box, sphere, cylinder
- [ ] Set physics properties per body: mass, friction, restitution
- [ ] **Play** button: transitions to Run mode — Chrono goes live
- [ ] **Stop** button: returns to Design mode (scene resets)
- [ ] Pause and single-step controls in Run mode

---

## Phase 4 — Constraints & Joints
**Deliverable:** A working pendulum and a crank-slider mechanism can be built and simulated in the app.

- [ ] Hinge joint (wheel, door, pendulum)
- [ ] Slider joint (piston, drawer)
- [ ] Fixed joint (weld two bodies)
- [ ] Spring-damper
- [ ] UI to create constraints between selected bodies
- [ ] Constraint properties panel (limits, stiffness, etc.)

---

## Phase 5 — OpenCASCADE Geometry
**Deliverable:** Users can build compound shapes with boolean operations and simulate them.

- [ ] OCCT integrated into the GDExtension
- [ ] Primitive CSG shapes: box, cylinder, sphere, cone
- [ ] Boolean operations: union, subtract, intersect
- [ ] Triangulation pipeline: OCCT BRep → Godot `ArrayMesh`
- [ ] OCCT shapes generate Chrono collision geometry automatically
- [ ] Design mode geometry tools updated to use OCCT backend

---

## Phase 6 — Import / Export
**Deliverable:** A STEP file from Fusion 360 or FreeCAD can be imported and simulated.

- [ ] STEP import via OCCT
- [ ] STL import and export
- [ ] Save / load Skale scene (custom format)

---

## Phase 7 — Polish & Packaging
**Deliverable:** A distributable build that a stranger can download and use.

- [ ] Run mode interaction tools (grab, push, apply point force)
- [ ] Time controls (pause, slow motion, fast forward)
- [ ] Measurement tools (distance, angle, volume, mass)
- [ ] AppImage for Linux
- [ ] Installer for Windows
- [ ] User-facing documentation

---

## Future / Unscheduled
These are real goals but not yet sequenced:

- Soft body / deformable physics
- Fluid simulation
- Material library with real-world physical properties
- Animation recording and playback
- VR / first-person mode
