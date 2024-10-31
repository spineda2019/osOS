import sys
import subprocess
from typing import Callable
import shutil
import os
import argparse


cwd: str = os.path.dirname(os.path.abspath(__file__))


def print_err(error: str) -> None:
    print(f"Error: {error}", file=sys.stderr)


def compile_loader() -> int:
    print("Compiling loader.s into object file...")
    compile_process: subprocess.CompletedProcess[bytes] \
        = subprocess.run(["nasm", "-f", "elf32", "loader.s"], cwd=cwd)

    if compile_process.returncode != 0:
        print_err("Error compiling loader")
        return compile_process.returncode

    print("Finished compiling loader.s!")
    return 0


def link_kernel() -> int:
    print("linking loader.o into kernel.elf...")
    link_process: subprocess.CompletedProcess[bytes] \
        = subprocess.run(["ld",
                          "-T",
                          "link.ld",
                          "-melf_i386",
                          "loader.o",
                          "-o",
                          "kernel.elf"],
                         cwd=cwd)

    if link_process.returncode != 0:
        print_err("Error compiling loader")
        return link_process.returncode

    print("Finished linking kernel.elf!")
    return 0


def check_tools() -> int:
    return_code: int = 0
    required_tools: list[str] = ["nasm", "bochs", "ld"]
    for tool in required_tools:
        if shutil.which(tool) is None:
            print_err(f"Tool not found: {tool}")
            return_code = -1

    return return_code


def generate_image_tree(build_dir_name: str) -> int:
    cmake_build_dir: str = os.path.join(cwd, "..", build_dir_name)
    if not os.path.exists(cmake_build_dir):
        print("CMake build output directory not found...")
        print("Assuming you are running this standalone, making directory...")
        os.makedirs(cmake_build_dir)

    iso_dir: str = os.path.join(cmake_build_dir, "iso")
    boot_dir: str = os.path.join(iso_dir, "boot")
    grub_dir: str = os.path.join(boot_dir, "grub")

    needed_dirs: list[str] = [iso_dir, boot_dir, grub_dir]

    for dir in needed_dirs:
        if not os.path.exists(dir):
            os.makedirs(dir)

    shutil.move(os.path.join(cwd, "kernel.elf"), boot_dir)
    shutil.copy(os.path.join(cwd, "stage2_eltorito"), grub_dir)
    shutil.copy(os.path.join(cwd, "menu.lst"), grub_dir)

    return 0


def build_loader(build_dir_name: str) -> int:
    steps: list[Callable[[], int]] = [check_tools, compile_loader, link_kernel]
    for func in steps:
        result: int = func()
        if result != 0:
            print_err("Loader build failed...")
            return result

    result: int = generate_image_tree(build_dir_name)
    if result != 0:
        print_err("Loader build failed...")
        return result

    print("Loader build completed")
    return 0


if __name__ == "__main__":
    arg_parser: argparse.ArgumentParser = argparse.ArgumentParser()
    arg_parser.add_argument("-b", "--build", default="build",
                            type=str,
                            help="name of output directory of build system")

    args: argparse.Namespace = arg_parser.parse_args()

    return_code: int = build_loader(args.build)
    sys.exit(return_code)
