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
etc
```

## Running

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
