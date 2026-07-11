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

    // --- Exported properties (set in Design mode) ---
    void set_box_size(Vector3 size);
    Vector3 get_box_size() const;
    void set_density(double density);
    double get_density() const;
    void set_fixed(bool fixed);
    bool get_fixed() const;
    void set_friction(float friction);
    float get_friction() const;
    void set_restitution(float restitution);
    float get_restitution() const;

    // --- Physics lifecycle ---
    // Called by SkaleSimulation::play() — saves design transform, enters Chrono.
    void initialize_for_run(SkaleSimulation *sim);
    // Called by SkaleSimulation::stop() — restores saved design transform.
    void reset_to_design();
    // Called by SkaleSimulation every step to sync Chrono → Node3D transform.
    void sync_transform();

    // Backward-compat: explicit init used by the headless test script.
    void initialize_box(SkaleSimulation *sim, Vector3 size, double density, bool fixed);

private:
    std::unique_ptr<skale::BodyCore> m_core;

    Vector3    m_box_size    = Vector3(1, 1, 1);
    double     m_density     = 1000.0;
    bool       m_fixed       = false;
    float      m_friction    = 0.5f;
    float      m_restitution = 0.2f;

    // Saved when Play is pressed; restored on Stop.
    Vector3    m_design_position;
    Quaternion m_design_rotation;
};

} // namespace godot
