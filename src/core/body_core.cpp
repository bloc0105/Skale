#include "body_core.h"
#include "simulation_core.h"

#include <chrono/physics/ChBodyEasy.h>
#include <chrono/physics/ChContactMaterialNSC.h>
#include <chrono/core/ChTypes.h>

namespace skale {

struct BodyCore::Impl {
    std::shared_ptr<chrono::ChBody> body;
};

BodyCore::BodyCore() : m_impl(std::make_unique<Impl>()) {}
BodyCore::~BodyCore() = default;

void BodyCore::initialize_box(SimulationCore *sim, Vec3 size, double density, bool fixed, Vec3 initial_pos,
                              float friction, float restitution) {
    auto mat = chrono_types::make_shared<chrono::ChContactMaterialNSC>();
    mat->SetFriction(friction);
    mat->SetRestitution(restitution);

    m_impl->body = chrono_types::make_shared<chrono::ChBodyEasyBox>(
        size.x, size.y, size.z,
        density,
        false, // no Chrono visualization — Godot handles rendering
        true,  // enable collision
        mat);

    m_impl->body->SetPos(chrono::ChVector3d(initial_pos.x, initial_pos.y, initial_pos.z));
    m_impl->body->SetFixed(fixed);

    // Type-erase the ChBody pointer so SimulationCore's header stays Chrono-free.
    sim->add_body(std::static_pointer_cast<void>(m_impl->body));
}

void BodyCore::get_transform(Vec3 &pos, Quat &rot) const {
    const auto &p = m_impl->body->GetPos();
    const auto &q = m_impl->body->GetRot();
    pos = {p.x(), p.y(), p.z()};
    // Chrono: e0=w, e1=x, e2=y, e3=z  →  skale::Quat: x,y,z,w
    rot = {q.e1(), q.e2(), q.e3(), q.e0()};
}

} // namespace skale
