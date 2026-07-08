#include "skale_body.h"
#include "skale_simulation.h"
#include <godot_cpp/core/class_db.hpp>

namespace godot {

SkaleBody::SkaleBody() : m_core(std::make_unique<skale::BodyCore>()) {}

void SkaleBody::_bind_methods() {
    ClassDB::bind_method(
        D_METHOD("initialize_box", "sim", "size", "density", "fixed"),
        &SkaleBody::initialize_box);
}

void SkaleBody::initialize_box(SkaleSimulation *sim, Vector3 size, double density, bool fixed) {
    Vector3 pos = get_position();
    m_core->initialize_box(
        sim->get_core(),
        {size.x, size.y, size.z},
        density,
        fixed,
        {pos.x, pos.y, pos.z});
    sim->register_body(this);
}

void SkaleBody::sync_transform() {
    skale::Vec3 pos;
    skale::Quat rot;
    m_core->get_transform(pos, rot);
    set_position(Vector3(pos.x, pos.y, pos.z));
    set_quaternion(Quaternion(rot.x, rot.y, rot.z, rot.w));
}

} // namespace godot
