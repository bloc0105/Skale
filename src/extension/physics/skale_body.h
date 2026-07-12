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
    enum ShapeType { BOX = 0, CYLINDER = 1, SPHERE = 2 };

    SkaleBody();

    // --- Exported properties ---
    void set_shape_type(int t);
    int  get_shape_type() const;
    void set_box_size(Vector3 size);
    Vector3 get_box_size() const;
    void set_radius(float r);
    float get_radius() const;
    void set_height(float h);
    float get_height() const;
    void set_density(double density);
    double get_density() const;
    void set_fixed(bool fixed);
    bool get_fixed() const;
    void set_friction(float friction);
    float get_friction() const;
    void set_restitution(float restitution);
    float get_restitution() const;

    // --- Physics lifecycle ---
    void initialize_for_run(SkaleSimulation *sim);
    void reset_to_design();
    void sync_transform();

    std::shared_ptr<void> get_body_handle() const;

    // Backward-compat
    void initialize_box(SkaleSimulation *sim, Vector3 size, double density, bool fixed);

private:
    std::unique_ptr<skale::BodyCore> m_core;

    int        m_shape_type  = BOX;
    Vector3    m_box_size    = Vector3(1, 1, 1);
    float      m_radius      = 0.5f;
    float      m_height      = 1.0f;
    double     m_density     = 1000.0;
    bool       m_fixed       = false;
    float      m_friction    = 0.5f;
    float      m_restitution = 0.2f;

    Vector3    m_design_position;
    Quaternion m_design_rotation;
};

} // namespace godot
