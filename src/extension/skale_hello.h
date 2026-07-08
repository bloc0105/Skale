#pragma once
#include <godot_cpp/classes/node.hpp>

namespace godot {

class SkaleHello : public Node {
    GDCLASS(SkaleHello, Node)

protected:
    static void _bind_methods();

public:
    String greet(const String &name) const;
};

} // namespace godot
