#pragma once

#include <godot_cpp/classes/node3d.hpp>
#include <core/body_core.h>
#include <memory>

namespace godot {

class SkaleSimulation;

class SkaleBody : public Node3D {
    GDCLASS(SkaleBody, Node3D)

protected:
    static void _bind_methods();

public:
    SkaleBody();

    // Initialize as a box and register with the simulation. Call before the first step.
    void initialize_box(SkaleSimulation *sim, Vector3 size, double density, bool fixed);

    // Sync Node3D transform from Chrono — called by SkaleSimulation after each step.
    void sync_transform();

private:
    std::unique_ptr<skale::BodyCore> m_core;
};

} // namespace godot
