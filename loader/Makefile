ifndef BUILD_DIR
	BUILD_DIR = build
endif
SUB_BUILD_DIR = ${BUILD_DIR}/loader
SRC_DIR = src
OBJECTS = ${SUB_BUILD_DIR}/loader.o ${SUB_BUILD_DIR}/kmain.o
CFLAGS = -m32 -nostdlib -nostdinc -fno-builtin -fno-stack-protector \
	     -nostartfiles -nodefaultlibs -Wall -Wextra -Werror -c
LDFLAGS = -T link.ld -melf_i386
ASSEMBLER = nasm
ASSEMBLER_FLAGS = -f elf

.PHONY: all copystep

all: $(BUILD_DIR) $(SUB_BUILD_DIR) kernel.elf

$(BUILD_DIR):
	@echo Top level build directory is $(BUILD_DIR)
	mkdir -p $@

$(SUB_BUILD_DIR): $(BUILD_DIR)
	@echo Module specific build directory is $(SUB_BUILD_DIR)
	mkdir -p $@

kernel.elf: $(OBJECTS)
	ld $(LDFLAGS) $(OBJECTS) -o $(SUB_BUILD_DIR)/kernel.elf

$(SUB_BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	$(CC) $(CFLAGS) $< -o $@

$(SUB_BUILD_DIR)/%.o: $(SRC_DIR)/%.s
	$(ASSEMBLER) $(ASSEMBLER_FLAGS) $< -o $@

clean:
	@echo Cleaning build directory: $(BUILD_DIR)
	@rm -rf $(BUILD_DIR)

copy_step: all
	@echo copying grub dependencies
