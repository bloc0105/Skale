find_package(Chrono CONFIG REQUIRED
    PATHS /usr/local/lib/cmake/Chrono
)

set(SOURCES
    skale_types.h
    simulation_core.h
    simulation_core.cpp
    body_core.h
    body_core.cpp
)

add_library(skale_core STATIC ${SOURCES})

set_property(TARGET skale_core PROPERTY CXX_STANDARD 17)
set_property(TARGET skale_core PROPERTY POSITION_INDEPENDENT_CODE ON)

target_include_directories(skale_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CHRONO_INCLUDE_DIRS}
)

target_compile_options(skale_core PRIVATE ${CHRONO_CXX_FLAGS})

target_link_libraries(skale_core PUBLIC ${CHRONO_LIBRARIES})
