# Architecture
Below find the intended architecture for osOS. It is intended to be somewhat
layered, with each layer being more abstracted from the hardware than the layer
above it.

## Graph
This isn't a true mathematical "graph" per-se, but this lays out what I had
in mind for how the dependencies should be mapped out. An out going arrow
indicates a dependency, with the source node depending on the sink node.
Each node in the graph indicates a module in the zig build system's module set.

```
--------------------------------------------------------------------------------
|                                 Kernel Space                                 |
--------------------------------------------------------------------------------
 ___________________       ______________________
|                   |     |                      |
|  x86 Entry Point  |     | RISC-V32 Entry Point |     ...(modules in /arch)...
|___________________|     |______________________|
     |         |              |       |
     |         |              |       |                       
 ____V______   |   ___________V____   |                                 
|           |  |  |                |  |
|  x86 APIs |  |  |  RISC-V32 APIs |  |  ...(arch specific API modules/files)...
|___________|  |  |________________|  |                         
               |                      |
               |______________________| _______ ...(any other architecture)...
                                       |
                                Arch Agnostic HAL
                                       |
                                    ___V___
                                   |       |
                                   | kmain |
                                   |_______|
                                       |
       ________________________________V_________________________________
      |                                                                  |
      |          Agnostic API (Format, Memory, Procees, etc...)          |
      |__________________________________________________________________|
                                       ^
                                       |
--------------------------------------------------------------------------------
|                                  User Space                                  |
--------------------------------------------------------------------------------
                                       |
                                       |
                                    Syscall
                                       |
                _______________________|________________________
               |                                                |
               | osOS Standard Library (like linux <sys/foo.h>) |
               |________________________________________________|
                   ^
 _______           |
|       |-----------     ...(other processes)...
| Shell |
|_______|

```

