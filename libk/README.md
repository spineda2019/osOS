# libk
This directory holds modules (not neccessarily linked libraries, either static
or dynamic, since zig can do everything in one single compilation unit) that is
to be used only by the kernel in kernel space. These modules are intended to be
architecture agnostic, and can be used by the kernel either before or after
jumping to kmain.
