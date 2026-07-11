#pragma once

#include <godot_cpp/classes/node.hpp>
#include <core/simulation_core.h>
#include <vector>

namespace godot {

class SkaleBody;

class SkaleSimulation : public Node {
    GDCLASS(SkaleSimulation, Node)

protected:
    static void _bind_methods();

public:
    SkaleSimulation();

    void _process(double delta) override;

    // Gravity property
    void set_gravity(Vector3 gravity);
    Vector3 get_gravity() const;

    // Manual step — used by the headless test script.
    void step(double dt);

    // Mode controls
    void play();
    void stop();
    void pause();
    void resume();
    bool is_running() const;
    bool is_paused() const;

    // C++ only — used by SkaleBody to register itself for transform sync.
    skale::SimulationCore *get_core() { return m_core.get(); }
    void register_body(SkaleBody *body);

private:
    std::unique_ptr<skale::SimulationCore> m_core;
    std::vector<SkaleBody *> m_bodies;
    bool m_running = false;
    bool m_paused  = false;
};

} // namespace godot
