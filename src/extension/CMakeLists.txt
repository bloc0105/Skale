set(SOURCES
    register_types.h
    register_types.cpp
    skale_hello.h
    skale_hello.cpp
    physics/skale_simulation.h
    physics/skale_simulation.cpp
    physics/skale_body.h
    physics/skale_body.cpp
    physics/skale_hinge.h
    physics/skale_hinge.cpp
    physics/skale_slider.h
    physics/skale_slider.cpp
    physics/skale_spring.h
    physics/skale_spring.cpp
)

add_library(skale SHARED ${SOURCES})

set_property(TARGET skale PROPERTY CXX_STANDARD 17)

target_include_directories(skale PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/src
)

target_link_libraries(skale PRIVATE
    godot::cpp
    skale_core
)

add_custom_command(TARGET skale POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy
        $<TARGET_FILE:skale>
        ${CMAKE_SOURCE_DIR}/project/bin/$<TARGET_FILE_NAME:skale>
    COMMENT "Copying extension to project/bin/"
)
