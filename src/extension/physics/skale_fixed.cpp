#include "skale_fixed.h"
#include "skale_simulation.h"
#include "skale_body.h"
#include <godot_cpp/core/class_db.hpp>

namespace godot {

SkaleFixed::SkaleFixed() : m_core(std::make_unique<skale::JointCore>()) {}

void SkaleFixed::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_body_a_path", "path"), &SkaleFixed::set_body_a_path);
    ClassDB::bind_method(D_METHOD("get_body_a_path"),         &SkaleFixed::get_body_a_path);
    ClassDB::bind_method(D_METHOD("set_body_b_path", "path"), &SkaleFixed::set_body_b_path);
    ClassDB::bind_method(D_METHOD("get_body_b_path"),         &SkaleFixed::get_body_b_path);

    ClassDB::bind_method(D_METHOD("initialize_for_run", "sim"), &SkaleFixed::initialize_for_run);
    ClassDB::bind_method(D_METHOD("reset_to_design"),           &SkaleFixed::reset_to_design);

    ADD_PROPERTY(PropertyInfo(Variant::NODE_PATH, "body_a_path"), "set_body_a_path", "get_body_a_path");
    ADD_PROPERTY(PropertyInfo(Variant::NODE_PATH, "body_b_path"), "set_body_b_path", "get_body_b_path");
}

void SkaleFixed::set_body_a_path(NodePath p) { m_body_a_path = p; }
NodePath SkaleFixed::get_body_a_path() const  { return m_body_a_path; }
void SkaleFixed::set_body_b_path(NodePath p) { m_body_b_path = p; }
NodePath SkaleFixed::get_body_b_path() const  { return m_body_b_path; }

void SkaleFixed::initialize_for_run(SkaleSimulation *sim) {
    Node *node_a = get_node_or_null(m_body_a_path);
    Node *node_b = get_node_or_null(m_body_b_path);
    SkaleBody *body_a = Object::cast_to<SkaleBody>(node_a);
    SkaleBody *body_b = Object::cast_to<SkaleBody>(node_b);

    if (!body_a || !body_b) return;

    // Anchor at the midpoint between the two bodies.
    Vector3 mid = (body_a->get_position() + body_b->get_position()) * 0.5f;
    m_core->initialize_fixed(
        sim->get_core(),
        body_a->get_body_handle(),
        body_b->get_body_handle(),
        {(double)mid.x, (double)mid.y, (double)mid.z});
}

void SkaleFixed::reset_to_design() {
    m_core = std::make_unique<skale::JointCore>();
}

} // namespace godot
