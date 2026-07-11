#include "skale_spring.h"
#include "skale_simulation.h"
#include "skale_body.h"
#include <godot_cpp/core/class_db.hpp>

namespace godot {

SkaleSpring::SkaleSpring() : m_core(std::make_unique<skale::JointCore>()) {}

void SkaleSpring::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_body_a_path", "path"), &SkaleSpring::set_body_a_path);
    ClassDB::bind_method(D_METHOD("get_body_a_path"),         &SkaleSpring::get_body_a_path);
    ClassDB::bind_method(D_METHOD("set_body_b_path", "path"), &SkaleSpring::set_body_b_path);
    ClassDB::bind_method(D_METHOD("get_body_b_path"),         &SkaleSpring::get_body_b_path);
    ClassDB::bind_method(D_METHOD("set_stiffness", "v"),      &SkaleSpring::set_stiffness);
    ClassDB::bind_method(D_METHOD("get_stiffness"),           &SkaleSpring::get_stiffness);
    ClassDB::bind_method(D_METHOD("set_damping", "v"),        &SkaleSpring::set_damping);
    ClassDB::bind_method(D_METHOD("get_damping"),             &SkaleSpring::get_damping);

    ClassDB::bind_method(D_METHOD("initialize_for_run", "sim"), &SkaleSpring::initialize_for_run);
    ClassDB::bind_method(D_METHOD("reset_to_design"),           &SkaleSpring::reset_to_design);

    ADD_PROPERTY(PropertyInfo(Variant::NODE_PATH, "body_a_path"), "set_body_a_path", "get_body_a_path");
    ADD_PROPERTY(PropertyInfo(Variant::NODE_PATH, "body_b_path"), "set_body_b_path", "get_body_b_path");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "stiffness"),       "set_stiffness",   "get_stiffness");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "damping"),         "set_damping",     "get_damping");
}

void SkaleSpring::set_body_a_path(NodePath p) { m_body_a_path = p; }
NodePath SkaleSpring::get_body_a_path() const  { return m_body_a_path; }
void SkaleSpring::set_body_b_path(NodePath p) { m_body_b_path = p; }
NodePath SkaleSpring::get_body_b_path() const  { return m_body_b_path; }
void SkaleSpring::set_stiffness(double v)      { m_stiffness = v; }
double SkaleSpring::get_stiffness() const      { return m_stiffness; }
void SkaleSpring::set_damping(double v)        { m_damping = v; }
double SkaleSpring::get_damping() const        { return m_damping; }

void SkaleSpring::initialize_for_run(SkaleSimulation *sim) {
    Node *node_a = get_node_or_null(m_body_a_path);
    Node *node_b = get_node_or_null(m_body_b_path);
    SkaleBody *body_a = Object::cast_to<SkaleBody>(node_a);
    SkaleBody *body_b = Object::cast_to<SkaleBody>(node_b);

    if (!body_a || !body_b) return;

    // Attach at each body's center in world space.
    skale::Vec3 pa = {body_a->get_position().x,
                      body_a->get_position().y,
                      body_a->get_position().z};
    skale::Vec3 pb = {body_b->get_position().x,
                      body_b->get_position().y,
                      body_b->get_position().z};

    m_core->initialize_spring_damper(
        sim->get_core(),
        body_a->get_body_handle(),
        body_b->get_body_handle(),
        pa, pb,
        m_stiffness, m_damping);
}

void SkaleSpring::reset_to_design() {
    m_core = std::make_unique<skale::JointCore>();
}

} // namespace godot
