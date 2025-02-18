# osOS
Oso's Os, or BearOS

## Common Tools I've Used
If an update to zig breaks (one of) the loader, the bundled llvm assembler
may be placing symbols at wonky addresses. Use the readelf tool to ensure
symbols are loaded where you would expect

## Building
The kernel currently uses the zig build system (and only the zig build system)
for building. To build the kernel for all supported architectures
(x86 and RISC-V32 at the moment), run:

```
zig build
```

More details for other targets can be seen with:

```
zig build -h
```

In general, (and I intend to keep this pattern the same), you can run
<code>zig build ARCH</code> where ARCH is the target architecture:

```
zig build riscv-32
zig build x86
```

etc

## Running
To emulate hardware running the kernel, you'll have to have either bochs or
qemu installed on your system. Currently, the riscv32 kernel is only setup for
qemu, while I have targets for x86 on both bochs and qemu. To run the x86
kernel using qemu:

```
zig build run_x86_qemu
```

or using bochs:

```
zig build run_x86_bochs
```

The riscv32 kernel is only able to be run on qemu (using the virt machine). You
can do so with:

```
zig build run_riscv32
```

## License
Not including the GPLv3 compatible licensed binaries packaged with osOS that I
have not built, the osOS kernel in its entirety is licensed under the GPLv3.
See the LICENSE file for information.

## License Notice
Copyright (C) 2025 Sebastian Pineda (spineda.wpi.alum@gmail.com)

## Architecture
For a breakdown of the architecture, see ARCHITECTURE.md. TL;DR, I want to
make the kernel as general as possible and keep only what I must in an
architecure dependent API.

## Legacy Code
This codebase uses a few resources as guides for development. The x86 kernel
took a lot of inspiration from
<i>
<a href=https://littleosbook.github.io/>The little book about OS development</a>
</i> by Erik Helin and Adam Renberg. That however was in C, and this kernel
will continue to be in Zig. My original C implementation (didn't get farther
than moving the cursor with I/O instructions) can be found in the git branch
<code>legacy</code>.
