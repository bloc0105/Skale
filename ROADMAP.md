# Skale Roadmap

Development is organized into sequential phases, each with a clear deliverable. A phase is complete when its deliverable works end-to-end, not just when the code is written.

---

## Phase 0 — Development Environment
**Deliverable:** CMake builds cleanly, Godot launches, all dependencies are confirmed present.

- [x] Install CMake, Ninja, build-essential
- [x] Install OpenCASCADE dev packages (apt)
- [x] Build Project Chrono from source (no apt package exists)
- [x] Download Godot 4 binary
- [x] Initialize git repository
- [x] Add `godot-cpp` as a git submodule
- [x] Write top-level CMakeLists.txt skeleton
- [x] Confirm clean build on Linux

---

## Phase 1 — GDExtension Hello World
**Deliverable:** GDScript calls a C++ function and gets a result back.

- [x] Minimal GDExtension: one C++ class with one method
- [x] CMake compiles extension to `.so` (Linux) and `.dll` (Windows)
- [x] Godot loads the extension at startup
- [x] GDScript instantiates the class and calls the method
- [x] Establish the exact Godot version ↔ godot-cpp version lock (Godot 4.6.2 / godot-cpp 4.5-stable)

---

## Phase 2 — Chrono Physics in Godot
**Deliverable:** A box falls under gravity and bounces off a floor, rendered in Godot's viewport.

- [x] Chrono linked into the GDExtension (two-layer: skale_core + skale)
- [x] `ChSystem` stepping via `step(dt)` / `_process` override
- [x] Rigid body transforms synced to Node3D each frame via `sync_transform()`
- [x] Box + static floor: falls from y=5, rests correctly at y=0.35
- [x] Confirm simulation stability — no drift or explosion at 60Hz timestep

---

## Phase 3 — Interactive Design & Simulation
**Deliverable:** A user can add objects, configure them, and run a live physics simulation without touching code.

- [x] 3D viewport with orbit/pan/zoom camera
- [x] Toolbar and properties panel (code-generated Godot UI)
- [x] Primitive bodies: box, cylinder, sphere
- [x] Per-body physics properties: density, fixed/dynamic, friction, restitution, dimensions
- [x] Body selection with orange highlight; properties panel shows selected body
- [x] Delete key removes selected body and all connected joints
- [x] XYZ axis indicator at world origin
- [x] **Play** button — Chrono goes live; **Pause** / **Resume**; **Stop** resets scene
- [x] Properties panel locked read-only during run

---

## Phase 4 — Constraints & Joints
**Deliverable:** A working mechanism (pendulum, crank-slider, driven linkage) can be built and simulated.

- [x] Hinge joint — revolute, one rotational DOF; axis picker; gold sphere glyph
- [x] Slider joint — prismatic, one translational DOF; axis picker; teal cylinder glyph
- [x] Fixed joint (weld) — locks all 6 DOFs at design-time pose; white diamond glyph
- [x] Spring-damper — stiffness/damping properties; rest length auto-set from initial positions; live visual update during run
- [x] Motor — driven hinge at constant angular speed (rad/s); orange disk glyph
- [x] Linear actuator — driven slider at constant linear speed (m/s); green cylinder glyph
- [x] Ball joint — spherical, 3 rotational DOFs, no translation; magenta sphere glyph
- [x] Click-to-connect workflow for all joint types (axis picker → body A → body B)
- [x] Joint visibility toggle — hide/show all gizmos without affecting physics
- [ ] Constraint properties panel (edit speed, stiffness, axis after placement)
- [ ] Joint selection (click a glyph to select it and edit its properties)

---

## Phase 5 — Save / Load & Scene Format
**Deliverable:** A scene can be saved to disk and reloaded exactly.

- [x] Save / load `.skale` scenes (JSON format — all bodies and joints)
- [ ] Gravity direction and magnitude configurable per scene
- [ ] Scene metadata (name, description, units)
- [ ] USD export for interoperability (long-term)

---

## Phase 6 — UI Redesign
**Deliverable:** A polished, intentional interface that matches the Design Philosophy.

- [ ] Toolbar redesigned in Godot editor (.tscn) — File / Create / Connect / Simulate / Display groups
- [ ] Palette system — contextual step-by-step panels drop from toolbar buttons
- [ ] Joint and body properties unified in a single context-sensitive panel
- [ ] Object tree panel (list all bodies and joints; select from tree)

---

## Phase 7 — OpenCASCADE Geometry
**Deliverable:** Users can build compound shapes with boolean operations and simulate them.

- [ ] OCCT integrated into the GDExtension
- [ ] Primitive CSG shapes: box, cylinder, sphere, cone
- [ ] Boolean operations: union, subtract, intersect
- [ ] Triangulation pipeline: OCCT BRep → Godot `ArrayMesh`
- [ ] OCCT shapes generate Chrono collision geometry automatically
- [ ] STEP import (Fusion 360, FreeCAD, Onshape)
- [ ] STL import and export

---

## Phase 8 — Polish & Packaging
**Deliverable:** A distributable build that a stranger can download and use.

- [ ] Run mode interaction tools (grab, push, apply point force)
- [ ] Measurement tools (distance, angle, mass, velocity readout)
- [ ] Time controls (slow motion, fast forward)
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
