#include "simulation_core.h"

#include <chrono/physics/ChSystemNSC.h>
#include <chrono/physics/ChBody.h>
#include <chrono/collision/ChCollisionSystem.h>

namespace skale {

struct SimulationCore::Impl {
    chrono::ChSystemNSC system;
};

SimulationCore::SimulationCore() : m_impl(std::make_unique<Impl>()) {
    m_impl->system.SetCollisionSystemType(chrono::ChCollisionSystem::Type::BULLET);
    m_impl->system.SetGravitationalAcceleration(chrono::ChVector3d(0, -9.81, 0));
}

SimulationCore::~SimulationCore() = default;

void SimulationCore::set_gravity(Vec3 g) {
    m_impl->system.SetGravitationalAcceleration(chrono::ChVector3d(g.x, g.y, g.z));
}

Vec3 SimulationCore::get_gravity() const {
    auto g = m_impl->system.GetGravitationalAcceleration();
    return {g.x(), g.y(), g.z()};
}

void SimulationCore::step(double dt) {
    m_impl->system.DoStepDynamics(dt);
}

void SimulationCore::add_body(std::shared_ptr<void> handle) {
    auto body = std::static_pointer_cast<chrono::ChBody>(handle);
    m_impl->system.AddBody(body);
}

} // namespace skale
