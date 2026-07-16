#include "skale_ball.h"
#include "skale_simulation.h"
#include "skale_body.h"
#include <godot_cpp/core/class_db.hpp>

namespace godot {

SkaleBall::SkaleBall() : m_core(std::make_unique<skale::JointCore>()) {}

void SkaleBall::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_body_a_path", "path"), &SkaleBall::set_body_a_path);
    ClassDB::bind_method(D_METHOD("get_body_a_path"),         &SkaleBall::get_body_a_path);
    ClassDB::bind_method(D_METHOD("set_body_b_path", "path"), &SkaleBall::set_body_b_path);
    ClassDB::bind_method(D_METHOD("get_body_b_path"),         &SkaleBall::get_body_b_path);
    ClassDB::bind_method(D_METHOD("set_anchor", "anchor"),    &SkaleBall::set_anchor);
    ClassDB::bind_method(D_METHOD("get_anchor"),              &SkaleBall::get_anchor);

    ClassDB::bind_method(D_METHOD("initialize_for_run", "sim"), &SkaleBall::initialize_for_run);
    ClassDB::bind_method(D_METHOD("reset_to_design"),           &SkaleBall::reset_to_design);

    ADD_PROPERTY(PropertyInfo(Variant::NODE_PATH, "body_a_path"), "set_body_a_path", "get_body_a_path");
    ADD_PROPERTY(PropertyInfo(Variant::NODE_PATH, "body_b_path"), "set_body_b_path", "get_body_b_path");
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3,   "anchor"),      "set_anchor",      "get_anchor");
}

void SkaleBall::set_body_a_path(NodePath p) { m_body_a_path = p; }
NodePath SkaleBall::get_body_a_path() const  { return m_body_a_path; }
void SkaleBall::set_body_b_path(NodePath p) { m_body_b_path = p; }
NodePath SkaleBall::get_body_b_path() const  { return m_body_b_path; }
void SkaleBall::set_anchor(Vector3 a)       { m_anchor = a; }
Vector3  SkaleBall::get_anchor() const       { return m_anchor; }

void SkaleBall::initialize_for_run(SkaleSimulation *sim) {
    Node *node_a = get_node_or_null(m_body_a_path);
    Node *node_b = get_node_or_null(m_body_b_path);
    SkaleBody *body_a = Object::cast_to<SkaleBody>(node_a);
    SkaleBody *body_b = Object::cast_to<SkaleBody>(node_b);
    if (!body_a || !body_b) return;

    m_core->initialize_ball(
        sim->get_core(),
        body_a->get_body_handle(),
        body_b->get_body_handle(),
        {(double)m_anchor.x, (double)m_anchor.y, (double)m_anchor.z});
}

void SkaleBall::reset_to_design() {
    m_core = std::make_unique<skale::JointCore>();
}

} // namespace godot
