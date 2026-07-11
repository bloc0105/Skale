#pragma once
#include "skale_types.h"
#include <memory>

namespace skale {

class SimulationCore;

class JointCore {
public:
    JointCore();
    ~JointCore();

    // Creates a revolute (hinge) joint between two bodies.
    // anchor: world-space pivot point.
    // axis:   world-space rotation axis (normalized).
    void initialize_hinge(SimulationCore *sim,
                          std::shared_ptr<void> body_a_handle,
                          std::shared_ptr<void> body_b_handle,
                          Vec3 anchor,
                          Vec3 axis);

private:
    struct Impl;
    std::unique_ptr<Impl> m_impl;
};

} // namespace skale
