cmake_minimum_required(VERSION 3.18)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

project(osOS LANGUAGES ASM C CXX)

add_subdirectory(loader)

add_custom_target(build_iso ALL
    COMMAND
    genisoimage
    -R
    -b boot/grub/stage2_eltorito
    -no-emul-boot
    -boot-load-size 4
    -A osOS
    -input-charset utf8
    -quiet
    -boot-info-table
    -o osOS.iso
    iso
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT build iso)

add_dependencies(build_iso loader_build)
