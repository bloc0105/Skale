set(SOURCES
    register_types.h
    register_types.cpp
    skale_hello.h
    skale_hello.cpp
)

add_library(skale SHARED ${SOURCES})

set_property(TARGET skale PROPERTY CXX_STANDARD 17)

target_include_directories(skale PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

target_link_libraries(skale PRIVATE godot::cpp)

# Copy compiled library into the Godot project bin/ after each build
add_custom_command(TARGET skale POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy
        $<TARGET_FILE:skale>
        ${CMAKE_SOURCE_DIR}/project/bin/$<TARGET_FILE_NAME:skale>
    COMMENT "Copying extension to project/bin/"
)
