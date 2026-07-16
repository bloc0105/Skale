#include "skale_actuator.h"
#include "skale_simulation.h"
#include "skale_body.h"
#include <godot_cpp/core/class_db.hpp>

namespace godot {

SkaleActuator::SkaleActuator() : m_core(std::make_unique<skale::JointCore>()) {}

void SkaleActuator::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_body_a_path", "path"), &SkaleActuator::set_body_a_path);
    ClassDB::bind_method(D_METHOD("get_body_a_path"),         &SkaleActuator::get_body_a_path);
    ClassDB::bind_method(D_METHOD("set_body_b_path", "path"), &SkaleActuator::set_body_b_path);
    ClassDB::bind_method(D_METHOD("get_body_b_path"),         &SkaleActuator::get_body_b_path);
    ClassDB::bind_method(D_METHOD("set_anchor", "anchor"),    &SkaleActuator::set_anchor);
    ClassDB::bind_method(D_METHOD("get_anchor"),              &SkaleActuator::get_anchor);
    ClassDB::bind_method(D_METHOD("set_axis", "axis"),        &SkaleActuator::set_axis);
    ClassDB::bind_method(D_METHOD("get_axis"),                &SkaleActuator::get_axis);
    ClassDB::bind_method(D_METHOD("set_speed", "speed"),      &SkaleActuator::set_speed);
    ClassDB::bind_method(D_METHOD("get_speed"),               &SkaleActuator::get_speed);

    ClassDB::bind_method(D_METHOD("initialize_for_run", "sim"), &SkaleActuator::initialize_for_run);
    ClassDB::bind_method(D_METHOD("reset_to_design"),           &SkaleActuator::reset_to_design);

    ADD_PROPERTY(PropertyInfo(Variant::NODE_PATH, "body_a_path"), "set_body_a_path", "get_body_a_path");
    ADD_PROPERTY(PropertyInfo(Variant::NODE_PATH, "body_b_path"), "set_body_b_path", "get_body_b_path");
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3,   "anchor"),      "set_anchor",      "get_anchor");
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3,   "axis"),        "set_axis",        "get_axis");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT,     "speed"),       "set_speed",       "get_speed");
}

void SkaleActuator::set_body_a_path(NodePath p) { m_body_a_path = p; }
NodePath SkaleActuator::get_body_a_path() const  { return m_body_a_path; }
void SkaleActuator::set_body_b_path(NodePath p) { m_body_b_path = p; }
NodePath SkaleActuator::get_body_b_path() const  { return m_body_b_path; }
void SkaleActuator::set_anchor(Vector3 a)       { m_anchor = a; }
Vector3  SkaleActuator::get_anchor() const       { return m_anchor; }
void SkaleActuator::set_axis(Vector3 a)         { m_axis = a; }
Vector3  SkaleActuator::get_axis() const         { return m_axis; }
void SkaleActuator::set_speed(float s)          { m_speed = s; }
float    SkaleActuator::get_speed() const        { return m_speed; }

void SkaleActuator::initialize_for_run(SkaleSimulation *sim) {
    Node *node_a = get_node_or_null(m_body_a_path);
    Node *node_b = get_node_or_null(m_body_b_path);
    SkaleBody *body_a = Object::cast_to<SkaleBody>(node_a);
    SkaleBody *body_b = Object::cast_to<SkaleBody>(node_b);
    if (!body_a || !body_b) return;

    m_core->initialize_linear_actuator(
        sim->get_core(),
        body_a->get_body_handle(),
        body_b->get_body_handle(),
        {(double)m_anchor.x, (double)m_anchor.y, (double)m_anchor.z},
        {(double)m_axis.x,   (double)m_axis.y,   (double)m_axis.z},
        (double)m_speed);
}

void SkaleActuator::reset_to_design() {
    m_core = std::make_unique<skale::JointCore>();
}

} // namespace godot
