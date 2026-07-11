#include "joint_core.h"
#include "simulation_core.h"

#include <chrono/physics/ChLinkLock.h>
#include <chrono/physics/ChBody.h>
#include <chrono/core/ChTypes.h>

#include <cmath>

namespace skale {

struct JointCore::Impl {
    std::shared_ptr<chrono::ChLinkLockRevolute> link;
};

JointCore::JointCore() : m_impl(std::make_unique<Impl>()) {}
JointCore::~JointCore() = default;

void JointCore::initialize_hinge(SimulationCore *sim,
                                  std::shared_ptr<void> body_a_handle,
                                  std::shared_ptr<void> body_b_handle,
                                  Vec3 anchor,
                                  Vec3 axis) {
    auto body_a = std::static_pointer_cast<chrono::ChBody>(body_a_handle);
    auto body_b = std::static_pointer_cast<chrono::ChBody>(body_b_handle);

    // Build a rotation that maps the joint frame's Z axis onto `axis`.
    // ChLinkLockRevolute rotates around the joint frame's Z by convention.
    chrono::ChVector3d z(0, 0, 1);
    chrono::ChVector3d rot_axis(axis.x, axis.y, axis.z);
    rot_axis.Normalize();

    chrono::ChQuaterniond rot;
    double dot = z.Dot(rot_axis);
    if (dot > 1.0 - 1e-6) {
        rot = chrono::ChQuaterniond(1, 0, 0, 0);
    } else if (dot < -1.0 + 1e-6) {
        rot.SetFromAngleAxis(M_PI, chrono::ChVector3d(1, 0, 0));
    } else {
        chrono::ChVector3d cross = z.Cross(rot_axis);
        cross.Normalize();
        rot.SetFromAngleAxis(std::acos(dot), cross);
    }

    chrono::ChFrame<> joint_frame(
        chrono::ChVector3d(anchor.x, anchor.y, anchor.z),
        rot);

    m_impl->link = chrono_types::make_shared<chrono::ChLinkLockRevolute>();
    m_impl->link->Initialize(body_a, body_b, joint_frame);

    sim->add_link(std::static_pointer_cast<void>(m_impl->link));
}

} // namespace skale
