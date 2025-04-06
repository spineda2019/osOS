# osOS
Oso's Os, or BearOS

## The Main Goal
osOS is mainly a passion project for fun and to learn about hardcore low-level
development. Currently, the end goal for this project (for now, we'll see after
1.0.0) is as such:

Be able to compile (theoretically can be done on a different machine, this
would be easier) and run a program on the OS that plays "honeyfish".

"Honeyfish" is just fizzbuzz, but with the words "honey" and "fish", because
osos (bears) obviously love those things. To accomplish this, there are a few
things that have to be done besides bare-bones booting into the OS:

* Keyboard input for pretty much anything
* A proper shell program to utilize said keyboard input and pass command line
  arguments to honeyfish
* A proper filesystem so that the binary program can be stored somewhere and
  invoked (e.g. ./path/to/honeyfish)
* A system call interface so that the honeyfish program (and shell) can be run
  from userland
* Proper process management so that the kernel can load the binary properly and
  set it up to be executed. Probably will just need to be barebones with no
  multitasking.

There may (probably will) be more, so I'll add them as they come up!

## Common Tools I've Used
If an update to zig breaks (one of) the loader, the bundled llvm assembler
may be placing symbols at wonky addresses. Use the readelf tool to ensure
symbols are loaded where you would expect. Examples:

* readelf -s FILE.elf
    * views symbols in the elf file, like the ones we define in the linker
      script and some global func symbols, like boot.
* readelf -S FILE.elf
    * views headers/sections of an elf file.

## Zig Version Used
I try to use the most up to date zig version from the ziglang project's master
branch: <a href=https://ziglang.org/download/>Zig Release Page</a>. This is
quite important as this project uses modules in it's build system, which I
believe (I could be wrong) don't exist in zig 0.13 and earlier. I have also
encountered buggy code generation from some versions of 0.14 causing some triple
faults. If you want to build this, please use the zig-master.

## Building
The kernel currently uses the zig build system (and only the zig build system)
for building. I sometimes will forget to add new options and target to this
README. For a proper most up to date set of options, just run
<code>zig build -h</code>

To build the kernel for all supported architectures
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

The x86 kernel has comptime options on what boot protocol to use for startup.
Multiboot1 is used by default, but this can be changed with 
<code> -Dboot_specification</code>. Multiboot1 is the only one that works
currently, but I have plans to add support for Limine and Multiboot2.
For details, search through the custome options in <code>zig build -h</code>.

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
