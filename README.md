# osOS
Oso's Os, or BearOS

## Common Tools I've Used
If an update to zig breaks (one of) the loader, the bundled llvm assembler
may be placing symbols at wonky addresses. Use the readelf tool to ensure
symbols are loaded where you would expect
