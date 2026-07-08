#pragma once

// Plain C++ types shared between core and extension — no Chrono, no Godot.
namespace skale {

struct Vec3 { double x, y, z; };
struct Quat { double x, y, z, w; }; // w-last (matches Godot convention)

} // namespace skale
