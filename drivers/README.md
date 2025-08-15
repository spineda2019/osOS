# drivers
This directory holds architecture agnostic drivers for various aspects of the
kernel, such as devices (e.g. PS/2 keyboard). These modules are intended to be
hooked in to by architecture specific setup modules (i.e. when the x86 setup
module constructs its HAL and passes it to kmain).
