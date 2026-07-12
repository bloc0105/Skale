#include "skale_body.h"
#include "skale_simulation.h"
#include <godot_cpp/core/class_db.hpp>

namespace godot {

SkaleBody::SkaleBody() : m_core(std::make_unique<skale::BodyCore>()) {}

void SkaleBody::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_shape_type", "t"),         &SkaleBody::set_shape_type);
    ClassDB::bind_method(D_METHOD("get_shape_type"),              &SkaleBody::get_shape_type);
    ClassDB::bind_method(D_METHOD("set_box_size", "size"),        &SkaleBody::set_box_size);
    ClassDB::bind_method(D_METHOD("get_box_size"),                &SkaleBody::get_box_size);
    ClassDB::bind_method(D_METHOD("set_radius", "r"),             &SkaleBody::set_radius);
    ClassDB::bind_method(D_METHOD("get_radius"),                  &SkaleBody::get_radius);
    ClassDB::bind_method(D_METHOD("set_height", "h"),             &SkaleBody::set_height);
    ClassDB::bind_method(D_METHOD("get_height"),                  &SkaleBody::get_height);
    ClassDB::bind_method(D_METHOD("set_density", "density"),      &SkaleBody::set_density);
    ClassDB::bind_method(D_METHOD("get_density"),                 &SkaleBody::get_density);
    ClassDB::bind_method(D_METHOD("set_fixed", "fixed"),          &SkaleBody::set_fixed);
    ClassDB::bind_method(D_METHOD("get_fixed"),                   &SkaleBody::get_fixed);
    ClassDB::bind_method(D_METHOD("set_friction", "friction"),    &SkaleBody::set_friction);
    ClassDB::bind_method(D_METHOD("get_friction"),                &SkaleBody::get_friction);
    ClassDB::bind_method(D_METHOD("set_restitution", "restitution"), &SkaleBody::set_restitution);
    ClassDB::bind_method(D_METHOD("get_restitution"),             &SkaleBody::get_restitution);

    ADD_PROPERTY(PropertyInfo(Variant::INT,     "shape_type"),   "set_shape_type",   "get_shape_type");
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3, "box_size"),     "set_box_size",     "get_box_size");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT,   "radius"),       "set_radius",       "get_radius");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT,   "height"),       "set_height",       "get_height");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT,   "density"),      "set_density",      "get_density");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL,    "is_fixed"),     "set_fixed",        "get_fixed");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT,   "friction"),     "set_friction",     "get_friction");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT,   "restitution"),  "set_restitution",  "get_restitution");

    ClassDB::bind_method(D_METHOD("initialize_for_run", "sim"), &SkaleBody::initialize_for_run);
    ClassDB::bind_method(D_METHOD("reset_to_design"),           &SkaleBody::reset_to_design);
    ClassDB::bind_method(D_METHOD("sync_transform"),            &SkaleBody::sync_transform);

    ClassDB::bind_method(
        D_METHOD("initialize_box", "sim", "size", "density", "fixed"),
        &SkaleBody::initialize_box);
}

// --- Accessors ---

void SkaleBody::set_shape_type(int t)       { m_shape_type = t; }
int  SkaleBody::get_shape_type() const      { return m_shape_type; }
void SkaleBody::set_box_size(Vector3 size)  { m_box_size = size; }
Vector3 SkaleBody::get_box_size() const     { return m_box_size; }
void SkaleBody::set_radius(float r)         { m_radius = r; }
float SkaleBody::get_radius() const         { return m_radius; }
void SkaleBody::set_height(float h)         { m_height = h; }
float SkaleBody::get_height() const         { return m_height; }
void SkaleBody::set_density(double d)       { m_density = d; }
double SkaleBody::get_density() const       { return m_density; }
void SkaleBody::set_fixed(bool f)           { m_fixed = f; }
bool SkaleBody::get_fixed() const           { return m_fixed; }
void SkaleBody::set_friction(float f)       { m_friction = f; }
float SkaleBody::get_friction() const       { return m_friction; }
void SkaleBody::set_restitution(float r)    { m_restitution = r; }
float SkaleBody::get_restitution() const    { return m_restitution; }

// --- Lifecycle ---

void SkaleBody::initialize_for_run(SkaleSimulation *sim) {
    m_design_position = get_position();
    m_design_rotation = get_quaternion();

    Vector3 pos = get_position();
    skale::Vec3 p = {(double)pos.x, (double)pos.y, (double)pos.z};

    switch (m_shape_type) {
        case CYLINDER:
            m_core->initialize_cylinder(sim->get_core(), m_radius, m_height,
                                        m_density, m_fixed, p, m_friction, m_restitution);
            break;
        case SPHERE:
            m_core->initialize_sphere(sim->get_core(), m_radius,
                                      m_density, m_fixed, p, m_friction, m_restitution);
            break;
        default: // BOX
            m_core->initialize_box(sim->get_core(),
                                   {m_box_size.x, m_box_size.y, m_box_size.z},
                                   m_density, m_fixed, p, m_friction, m_restitution);
            break;
    }
    sim->register_body(this);
}

void SkaleBody::reset_to_design() {
    m_core = std::make_unique<skale::BodyCore>();
    set_position(m_design_position);
    set_quaternion(m_design_rotation);
}

void SkaleBody::sync_transform() {
    skale::Vec3 pos;
    skale::Quat rot;
    m_core->get_transform(pos, rot);
    set_position(Vector3(pos.x, pos.y, pos.z));
    set_quaternion(Quaternion(rot.x, rot.y, rot.z, rot.w));
}

std::shared_ptr<void> SkaleBody::get_body_handle() const {
    return m_core->get_chrono_body();
}

// --- Backward compat ---

void SkaleBody::initialize_box(SkaleSimulation *sim, Vector3 size, double density, bool fixed) {
    m_shape_type = BOX;
    m_box_size   = size;
    m_density    = density;
    m_fixed      = fixed;
    initialize_for_run(sim);
}

} // namespace godot
