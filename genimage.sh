genisoimage                  \
-R                           \
-b boot/grub/stage2_eltorito \
-no-emul-boot                \
-boot-load-size 4            \
-A osOS                      \
-input-charset utf8          \
-quiet                       \
-boot-info-table             \
-o osOS.iso                  \
iso
