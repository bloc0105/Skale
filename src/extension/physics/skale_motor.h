#pragma once

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/variant/node_path.hpp>
#include <core/joint_core.h>
#include <memory>

namespace godot {

class SkaleSimulation;

class SkaleMotor : public Node3D {
    GDCLASS(SkaleMotor, Node3D)

protected:
    static void _bind_methods();

public:
    SkaleMotor();

    void set_body_a_path(NodePath path); NodePath get_body_a_path() const;
    void set_body_b_path(NodePath path); NodePath get_body_b_path() const;
    void set_anchor(Vector3 anchor);     Vector3   get_anchor() const;
    void set_axis(Vector3 axis);         Vector3   get_axis() const;
    void set_speed(float speed);         float     get_speed() const;

    void initialize_for_run(SkaleSimulation *sim);
    void reset_to_design();

private:
    NodePath m_body_a_path;
    NodePath m_body_b_path;
    Vector3  m_anchor = Vector3(0, 0, 0);
    Vector3  m_axis   = Vector3(0, 1, 0);
    float    m_speed  = 1.0f;

    std::unique_ptr<skale::JointCore> m_core;
};

} // namespace godot
