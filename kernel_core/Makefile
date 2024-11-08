BUILD_DIR ?= build

################################################################################
# Mandatory modules

SRC_DIR = src
FRAMEBUFFER_SRC_DIR = framebuffer
LOADER_SRC_DIR = loader
ASSEMBLY_WRAPPER_SRC_DIR = assembly_wrappers
GLOBAL_INCLUDES := $(ASSEMBLY_WRAPPER_SRC_DIR)/include

################################################################################

CC = gcc
CXX = g++
SUB_BUILD_DIR = ${BUILD_DIR}/kernel_core
OBJECTS = ${SUB_BUILD_DIR}/kernel_core.o   \
		  ${SUB_BUILD_DIR}/kmain.o         \
		  ${SUB_BUILD_DIR}/io.o            \
		  $(SUB_BUILD_DIR)/framebuffer.o
CFLAGS = -m32 -nostdlib -nostdinc -fno-builtin -fno-stack-protector \
	     -nostartfiles -nodefaultlibs -Wall -Wextra -Werror -c -std=c11 \
		 -I $(GLOBAL_INCLUDES)
CXXFLAGS = -m32 -nostdlib -nostdinc -fno-builtin -fno-stack-protector \
	       -nostartfiles -nodefaultlibs -Wall -Wextra -Werror -c -std=c++20 \
		   -I $(GLOBAL_INCLUDES)
LDFLAGS = -T link.ld -melf_i386
ASSEMBLER = nasm
ASSEMBLER_FLAGS = -f elf

.PHONY: BUILD_DIR SUB_BUILD_DIR

all: $(BUILD_DIR) $(SUB_BUILD_DIR) kernel.elf

$(BUILD_DIR):
	@echo Top level build directory is $(BUILD_DIR)
	mkdir -p $@

$(SUB_BUILD_DIR): $(BUILD_DIR)
	@echo Module specific build directory is $(SUB_BUILD_DIR)
	mkdir -p $@

kernel.elf: $(OBJECTS)
	ld $(LDFLAGS) $(OBJECTS) -o $(SUB_BUILD_DIR)/kernel.elf

$(SUB_BUILD_DIR)/%.o: $(FRAMEBUFFER_SRC_DIR)/%.cpp
	$(CXX) $(CXXFLAGS) $< -o $@

$(SUB_BUILD_DIR)/%.o: $(LOADER_SRC_DIR)/%.c
	$(CC) $(CFLAGS) $< -o $@

$(SUB_BUILD_DIR)/%.o: $(LOADER_SRC_DIR)/%.asm
	$(ASSEMBLER) $(ASSEMBLER_FLAGS) $< -o $@

$(SUB_BUILD_DIR)/%.o: $(ASSEMBLY_WRAPPER_SRC_DIR)/%.asm
	$(ASSEMBLER) $(ASSEMBLER_FLAGS) $< -o $@

clean:
	@echo Cleaning build directory: $(BUILD_DIR)
	@rm -rf $(BUILD_DIR)
