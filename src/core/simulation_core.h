#pragma once
#include "skale_types.h"
#include <memory>

namespace skale {

class SimulationCore {
public:
    SimulationCore();
    ~SimulationCore();

    void set_gravity(Vec3 g);
    Vec3 get_gravity() const;
    void step(double dt);

    void add_body(std::shared_ptr<void> chrono_body_handle);
    void add_link(std::shared_ptr<void> chrono_link_handle);

private:
    struct Impl;
    std::unique_ptr<Impl> m_impl;
};

} // namespace skale
