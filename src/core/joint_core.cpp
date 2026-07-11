#include "joint_core.h"
#include "simulation_core.h"

#include <chrono/physics/ChLinkLock.h>
#include <chrono/physics/ChLinkTSDA.h>
#include <chrono/physics/ChBody.h>
#include <chrono/core/ChTypes.h>

#include <cmath>

namespace skale {

struct JointCore::Impl {
    std::shared_ptr<chrono::ChLink> link;
};

JointCore::JointCore() : m_impl(std::make_unique<Impl>()) {}
JointCore::~JointCore() = default;

// Builds a ChFrame whose Z axis aligns with `axis` at position `anchor`.
// Both ChLinkLockRevolute and ChLinkLockPrismatic use the joint frame's Z.
static chrono::ChFrame<> make_joint_frame(Vec3 anchor, Vec3 axis) {
    chrono::ChVector3d z(0, 0, 1);
    chrono::ChVector3d dir(axis.x, axis.y, axis.z);
    dir.Normalize();

    chrono::ChQuaterniond rot;
    double dot = z.Dot(dir);
    if (dot > 1.0 - 1e-6) {
        rot = chrono::ChQuaterniond(1, 0, 0, 0);
    } else if (dot < -1.0 + 1e-6) {
        rot.SetFromAngleAxis(M_PI, chrono::ChVector3d(1, 0, 0));
    } else {
        chrono::ChVector3d cross = z.Cross(dir);
        cross.Normalize();
        rot.SetFromAngleAxis(std::acos(dot), cross);
    }

    return chrono::ChFrame<>(chrono::ChVector3d(anchor.x, anchor.y, anchor.z), rot);
}

void JointCore::initialize_hinge(SimulationCore *sim,
                                  std::shared_ptr<void> body_a_handle,
                                  std::shared_ptr<void> body_b_handle,
                                  Vec3 anchor, Vec3 axis) {
    auto body_a = std::static_pointer_cast<chrono::ChBody>(body_a_handle);
    auto body_b = std::static_pointer_cast<chrono::ChBody>(body_b_handle);

    auto link = chrono_types::make_shared<chrono::ChLinkLockRevolute>();
    link->Initialize(body_a, body_b, make_joint_frame(anchor, axis));
    m_impl->link = link;
    sim->add_link(std::static_pointer_cast<void>(m_impl->link));
}

void JointCore::initialize_slider(SimulationCore *sim,
                                   std::shared_ptr<void> body_a_handle,
                                   std::shared_ptr<void> body_b_handle,
                                   Vec3 anchor, Vec3 axis) {
    auto body_a = std::static_pointer_cast<chrono::ChBody>(body_a_handle);
    auto body_b = std::static_pointer_cast<chrono::ChBody>(body_b_handle);

    auto link = chrono_types::make_shared<chrono::ChLinkLockPrismatic>();
    link->Initialize(body_a, body_b, make_joint_frame(anchor, axis));
    m_impl->link = link;
    sim->add_link(std::static_pointer_cast<void>(m_impl->link));
}

void JointCore::initialize_fixed(SimulationCore *sim,
                                  std::shared_ptr<void> body_a_handle,
                                  std::shared_ptr<void> body_b_handle,
                                  Vec3 anchor) {
    auto body_a = std::static_pointer_cast<chrono::ChBody>(body_a_handle);
    auto body_b = std::static_pointer_cast<chrono::ChBody>(body_b_handle);

    // Identity orientation — ChLinkLockLock locks everything regardless.
    chrono::ChFrame<> frame(chrono::ChVector3d(anchor.x, anchor.y, anchor.z),
                            chrono::ChQuaterniond(1, 0, 0, 0));
    auto link = chrono_types::make_shared<chrono::ChLinkLockLock>();
    link->Initialize(body_a, body_b, frame);
    m_impl->link = link;
    sim->add_link(std::static_pointer_cast<void>(m_impl->link));
}

void JointCore::initialize_spring_damper(SimulationCore *sim,
                                          std::shared_ptr<void> body_a_handle,
                                          std::shared_ptr<void> body_b_handle,
                                          Vec3 point_a,
                                          Vec3 point_b,
                                          double stiffness,
                                          double damping,
                                          double rest_length) {
    auto body_a = std::static_pointer_cast<chrono::ChBody>(body_a_handle);
    auto body_b = std::static_pointer_cast<chrono::ChBody>(body_b_handle);

    auto tsda = chrono_types::make_shared<chrono::ChLinkTSDA>();
    tsda->Initialize(body_a, body_b,
                     true,  // positions are in absolute (world) frame
                     chrono::ChVector3d(point_a.x, point_a.y, point_a.z),
                     chrono::ChVector3d(point_b.x, point_b.y, point_b.z));
    // Rest length defaults to initial distance; override only if explicit.
    if (rest_length >= 0.0)
        tsda->SetRestLength(rest_length);
    tsda->SetSpringCoefficient(stiffness);
    tsda->SetDampingCoefficient(damping);

    m_impl->link = tsda;
    sim->add_link(std::static_pointer_cast<void>(m_impl->link));
}

} // namespace skale
