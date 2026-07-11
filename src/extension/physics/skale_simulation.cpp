#include "skale_simulation.h"
#include "skale_body.h"
#include "skale_hinge.h"
#include <godot_cpp/core/class_db.hpp>

namespace godot {

SkaleSimulation::SkaleSimulation()
    : m_core(std::make_unique<skale::SimulationCore>()) {}

void SkaleSimulation::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_gravity", "gravity"), &SkaleSimulation::set_gravity);
    ClassDB::bind_method(D_METHOD("get_gravity"),            &SkaleSimulation::get_gravity);
    ClassDB::bind_method(D_METHOD("step", "dt"),             &SkaleSimulation::step);
    ClassDB::bind_method(D_METHOD("play"),                   &SkaleSimulation::play);
    ClassDB::bind_method(D_METHOD("stop"),                   &SkaleSimulation::stop);
    ClassDB::bind_method(D_METHOD("pause"),                  &SkaleSimulation::pause);
    ClassDB::bind_method(D_METHOD("resume"),                 &SkaleSimulation::resume);
    ClassDB::bind_method(D_METHOD("is_running"),             &SkaleSimulation::is_running);
    ClassDB::bind_method(D_METHOD("is_paused"),              &SkaleSimulation::is_paused);

    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3, "gravity"), "set_gravity", "get_gravity");
}

void SkaleSimulation::_process(double delta) {
    if (m_running && !m_paused)
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

void SkaleSimulation::play() {
    if (m_running) return;
    m_bodies.clear();
    int count = get_child_count();
    // Bodies must be initialized before joints.
    for (int i = 0; i < count; i++) {
        SkaleBody *body = Object::cast_to<SkaleBody>(get_child(i));
        if (body)
            body->initialize_for_run(this);
    }
    for (int i = 0; i < count; i++) {
        SkaleHinge *hinge = Object::cast_to<SkaleHinge>(get_child(i));
        if (hinge)
            hinge->initialize_for_run(this);
    }
    m_running = true;
    m_paused  = false;
}

void SkaleSimulation::stop() {
    m_running = false;
    m_paused  = false;
    for (SkaleBody *body : m_bodies)
        body->reset_to_design();
    m_bodies.clear();
    int count = get_child_count();
    for (int i = 0; i < count; i++) {
        SkaleHinge *hinge = Object::cast_to<SkaleHinge>(get_child(i));
        if (hinge)
            hinge->reset_to_design();
    }
    m_core = std::make_unique<skale::SimulationCore>();
}

void SkaleSimulation::pause() {
    if (m_running) m_paused = true;
}

void SkaleSimulation::resume() {
    if (m_running) m_paused = false;
}

bool SkaleSimulation::is_running() const { return m_running; }
bool SkaleSimulation::is_paused()  const { return m_paused;  }

void SkaleSimulation::register_body(SkaleBody *body) {
    m_bodies.push_back(body);
}

} // namespace godot
