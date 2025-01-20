export fn boot() linksection(".text") callconv(.Naked) noreturn {
    while (true) {
        asm volatile ("");
    }
}
