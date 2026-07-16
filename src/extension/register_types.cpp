#include "register_types.h"
#include "skale_hello.h"
#include "physics/skale_simulation.h"
#include "physics/skale_body.h"
#include "physics/skale_hinge.h"
#include "physics/skale_slider.h"
#include "physics/skale_spring.h"
#include "physics/skale_fixed.h"
#include "physics/skale_motor.h"
#include "physics/skale_actuator.h"
#include "physics/skale_ball.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_skale(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE)
        return;

    ClassDB::register_class<SkaleHello>();
    ClassDB::register_class<SkaleSimulation>();
    ClassDB::register_class<SkaleBody>();
    ClassDB::register_class<SkaleHinge>();
    ClassDB::register_class<SkaleSlider>();
    ClassDB::register_class<SkaleSpring>();
    ClassDB::register_class<SkaleFixed>();
    ClassDB::register_class<SkaleMotor>();
    ClassDB::register_class<SkaleActuator>();
    ClassDB::register_class<SkaleBall>();
}

void uninitialize_skale(ModuleInitializationLevel p_level) {}

extern "C" {

GDExtensionBool GDE_EXPORT skale_init(
    GDExtensionInterfaceGetProcAddress p_get_proc_address,
    const GDExtensionClassLibraryPtr p_library,
    GDExtensionInitialization *r_initialization)
{
    GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
    init_obj.register_initializer(initialize_skale);
    init_obj.register_terminator(uninitialize_skale);
    init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init_obj.init();
}

} // extern "C"
