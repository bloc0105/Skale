#include "skale_simulation.h"
#include "skale_body.h"
#include <godot_cpp/core/class_db.hpp>

namespace godot {

SkaleSimulation::SkaleSimulation()
    : m_core(std::make_unique<skale::SimulationCore>()) {}

void SkaleSimulation::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_gravity", "gravity"), &SkaleSimulation::set_gravity);
    ClassDB::bind_method(D_METHOD("get_gravity"), &SkaleSimulation::get_gravity);
    ClassDB::bind_method(D_METHOD("step", "dt"), &SkaleSimulation::step);

    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3, "gravity"), "set_gravity", "get_gravity");
}

void SkaleSimulation::_process(double delta) {
    step(delta);
}

void SkaleSimulation::set_gravity(Vector3 g) {
    m_core->set_gravity({g.x, g.y, g.z});
}

Vector3 SkaleSimulation::get_gravity() const {
    auto g = m_core->get_gravity();
    return Vector3(g.x, g.y, g.z);
}

void SkaleSimulation::step(double dt) {
    m_core->step(dt);
    for (SkaleBody *body : m_bodies)
        body->sync_transform();
}

void SkaleSimulation::register_body(SkaleBody *body) {
    m_bodies.push_back(body);
}

} // namespace godot
