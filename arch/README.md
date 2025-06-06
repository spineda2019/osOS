# osOS Entry Points
Each architecture specific directory will contain their own entry point, wherein
the kernel will do arch dependent setup (interrupt vector setup, memory
segmenting if applicable, etc), then jump to the kmain routing (aptly stored
in kmain). Each architecture will construct an architecture agnostic HAL (see
the HAL module for details) to pass to kmain.

TODO: Architecture diagram
