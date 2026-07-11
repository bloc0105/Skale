#pragma once
#include "skale_types.h"
#include <memory>

namespace skale {

class SimulationCore;

class BodyCore {
public:
    BodyCore();
    ~BodyCore();

    // Creates a ChBodyEasyBox, seeds position, and registers it with the simulation.
    void initialize_box(SimulationCore *sim, Vec3 size, double density, bool fixed, Vec3 initial_pos,
                        float friction = 0.5f, float restitution = 0.2f);

    // Read the current simulated transform.
    void get_transform(Vec3 &pos, Quat &rot) const;

private:
    struct Impl;
    std::unique_ptr<Impl> m_impl;
};

} // namespace skale
