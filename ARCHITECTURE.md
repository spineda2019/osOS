# Architecture
There are 3 types of modules that exist in the osOS kernel (soon to be 4).
These are:

* entry_points
    * The architecture dependent entry points for the kernel.
    * These are confined to the "entry_points" folder
    * Depends on: arch_api (for implementation details)
* arch_api
    * Contains architecture dependent APIs for low level operations, like
      memory allocation and raw screen printing
    * Confined to "arch_api" folder
    * Depends on: theoretically nothing. This should be depended on. Currently
      an issue being tracked. I may create a 4th special module for super
      common kernel code that is not userland facing (like memset).
      Unfortunately, some dependencies of userland modules exist
* arch_agnostic_api
    * This module contains APIs that are agnostic to the target architecture.
      Should be usable by userland apps (like unistd.h in linux)
    * in generic folders, like "memory" or "format"
* kcommon (experimental)
    * contains modules so common, they're used by both arch_api's and
      arch_agnostic_apis (like converting a number to a string)
    * I'm still designing this, but this should live in "kcommon"
    * should have absolutely 0 dependencies


## Graph
This isn't a true mathematical "graph" per-se, but this lays out what I had
in mind for how the dependencies should be mapped out. An out going arrow
indicates a dependencies, with the source node depending on the sink node.
Each node in the graph indicates a module in the zig build system's module set.

```
 ___________________       ______________________
|                   |     |                      |
|  x86 Entry Point  |     | RISC-V32 Entry Point |     ...
|___________________|     |______________________|
     |                        |
     |                        |
 ____V______       ___________V__
|           |     |              |
|  x86 API  |     | RISC-V32 API |     ...
|___________|     |______________|
      ^                   ^
      |                   |            ...
 _____|___________________|_______________________________
|                                                         |
|          Agnostic API (Format, Memory, etc...)          |
|_________________________________________________________|


```

## Shortcomigs
There are currently some arch_api modules that depend on the agnostic API.
In a vacuum, this sounds logical, as there would be generic code it relies
on, but this breaks our graph. This is actively being worked on.
