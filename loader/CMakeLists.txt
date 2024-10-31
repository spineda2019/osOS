project(osOS)

add_custom_target(loader_build ALL
    COMMAND python build_loader.py -b ${CMAKE_BINARY_DIR}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT Run custom nasm compilation and linking)
