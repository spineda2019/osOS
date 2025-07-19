# RISCV32
In the real world, the bootloader should pass a device tree blob (DTB) to the
kernel. DTB parsing is not done yet, so for now the DTS (human readable version)
will be checked in and the device addresses will be hardcoded in. This is not
scalabale to different devices (besides virt, which we're targetting for now),
but will be replaced in the future.
