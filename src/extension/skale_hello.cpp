#include "skale_hello.h"
#include <godot_cpp/core/class_db.hpp>

namespace godot {

void SkaleHello::_bind_methods() {
    ClassDB::bind_method(D_METHOD("greet", "name"), &SkaleHello::greet);
}

String SkaleHello::greet(const String &name) const {
    return "Hello from Skale C++, " + name + "!";
}

} // namespace godot
