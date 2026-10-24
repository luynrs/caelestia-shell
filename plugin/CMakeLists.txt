find_package(Qt6 REQUIRED COMPONENTS ShaderTools Core Qml Gui Quick QuickControls2 Concurrent Sql Network DBus)
find_package(PkgConfig REQUIRED)
pkg_check_modules(Qalculate IMPORTED_TARGET libqalculate REQUIRED)
pkg_check_modules(Pipewire IMPORTED_TARGET libpipewire-0.3 REQUIRED)
pkg_check_modules(Aubio IMPORTED_TARGET aubio REQUIRED)
pkg_check_modules(Cava IMPORTED_TARGET libcava QUIET)
if(NOT Cava_FOUND)
    pkg_check_modules(Cava IMPORTED_TARGET cava REQUIRED)
endif()
include(cmake/sensorslib.cmake)

set(QT_QML_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml")
qt_standard_project_setup(REQUIRES 6.9)

include(cmake/pch.cmake)
include(cmake/qml-module.cmake)

# Header only helpers
add_library(caelestia-util INTERFACE)
target_include_directories(caelestia-util INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")

add_subdirectory(src/Caelestia)

if(BUILD_TESTING)
    enable_testing()
    find_package(Threads REQUIRED)
    add_executable(caelestia-audiocollector-test
        tests/audiocollector.cpp
        src/Caelestia/Services/audiocollector.cpp
        src/Caelestia/Services/service.cpp
    )
    target_include_directories(caelestia-audiocollector-test PRIVATE src/Caelestia/Services)
    target_link_libraries(caelestia-audiocollector-test PRIVATE caelestia-pch Qt::Core Qt::Qml PkgConfig::Pipewire Threads::Threads)
    add_test(NAME audiocollector-chunks COMMAND caelestia-audiocollector-test)
    add_test(NAME audiocollector-concurrency COMMAND caelestia-audiocollector-test concurrency)
    add_executable(caelestia-blobgeometry-test tests/blobgeometry.cpp)
    target_include_directories(caelestia-blobgeometry-test PRIVATE src/Caelestia/Blobs)
    target_link_libraries(caelestia-blobgeometry-test PRIVATE caelestia-blobs Qt::Quick)
    add_test(NAME blobgeometry COMMAND caelestia-blobgeometry-test)
    set_tests_properties(blobgeometry PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
    add_executable(caelestia-servicelifetime-test tests/servicelifetime.cpp)
    target_compile_options(caelestia-servicelifetime-test PRIVATE -fno-access-control)
    target_include_directories(caelestia-servicelifetime-test PRIVATE src/Caelestia/Services)
    target_link_libraries(caelestia-servicelifetime-test PRIVATE caelestia-services caelestia-core caelestia-config Qt::Network Qt::Qml)
    add_test(NAME lyrics-cancellation COMMAND caelestia-servicelifetime-test)
    add_test(NAME lyrics-track-replacement COMMAND caelestia-servicelifetime-test replace)
    add_test(NAME toast-default-timeout COMMAND caelestia-servicelifetime-test toast)
    add_test(NAME audio-queued-destruction COMMAND caelestia-servicelifetime-test audio)
    add_test(NAME service-reference-connections COMMAND caelestia-servicelifetime-test connections)
endif()
