#pragma once

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/variant/node_path.hpp>
#include <core/joint_core.h>
#include <memory>

namespace godot {

class SkaleSimulation;

class SkaleSpring : public Node3D {
    GDCLASS(SkaleSpring, Node3D)

protected:
    static void _bind_methods();

public:
    SkaleSpring();

    void set_body_a_path(NodePath path);
    NodePath get_body_a_path() const;
    void set_body_b_path(NodePath path);
    NodePath get_body_b_path() const;
    void set_stiffness(double v);
    double get_stiffness() const;
    void set_damping(double v);
    double get_damping() const;

    void initialize_for_run(SkaleSimulation *sim);
    void reset_to_design();

private:
    NodePath m_body_a_path;
    NodePath m_body_b_path;
    double   m_stiffness = 2000.0;
    double   m_damping   = 10.0;

    std::unique_ptr<skale::JointCore> m_core;
};

} // namespace godot
