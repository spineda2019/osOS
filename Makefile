BUILD_DIR = $(shell pwd)/build
ISO_DIR := $(BUILD_DIR)/iso
BOOT_DIR := $(ISO_DIR)/boot
GRUB_DIR := $(BOOT_DIR)/grub
SUBDIRS := kernel_core
GRUB_REQUIREMENTS := menu.lst stage2_eltorito

export BUILD_DIR

.PHONY: clean all run $(SUBDIRS)

all: $(BUILD_DIR) $(SUBDIRS) osOS.iso
	@echo -e "bochs -f ../bochs.config" > $(BUILD_DIR)/run.sh
	@chmod +x $(BUILD_DIR)/run.sh

osOS.iso: $(GRUB_REQUIREMENTS) copystep
	genisoimage                  \
	-R                           \
	-b boot/grub/stage2_eltorito \
	-no-emul-boot                \
	-boot-load-size 4            \
	-A osOS                      \
	-input-charset utf8          \
	-quiet                       \
	-boot-info-table             \
	-o $(BUILD_DIR)/osOS.iso     \
	$(ISO_DIR)

copystep: loader
	cp $(BUILD_DIR)/loader/kernel.elf $(BOOT_DIR)


$(GRUB_REQUIREMENTS): $(GRUB_DIR)
	cp $@ $(GRUB_DIR)

$(GRUB_DIR): $(BOOT_DIR)
	mkdir -p $@

$(BOOT_DIR): $(ISO_DIR)
	mkdir -p $@

$(ISO_DIR): $(BUILD_DIR)
	mkdir -p $@

$(BUILD_DIR): $@
	mkdir -p $@

$(SUBDIRS):
	@$(MAKE) -C $@

just_loader: framebuffer
	@$(MAKE) -C loader

just_framebuffer:
	@$(MAKE) -C framebuffer

clean:
	@echo Cleaning build directory: $(BUILD_DIR)
	@rm -rf $(BUILD_DIR)
