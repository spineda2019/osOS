# Build Time Tools
Sometimes, for better or worse (or perhaps my own skill issue), run-time steps
depend on files to be generated or copied at build time. This is quite common
in large projects (the linux kernel generates a lot of code at build time,
google generates a lot of stuff at build time with protobuf, etc etc).

This project is neither as large or complex as any of those examples, so while
we still need to do that stuff, we can do it a bit more simple and all with zig!

This folder just hosts all the build time tools needed for various parts of the
project:

* build_iso
    * Creates folders and copies files in the structure expected by cdrtool to
      create an iso image from our build
* setup_bochs
    * Generates bochs configuration files and copies them to the build output.
      Bochs configuration files need to point to various VGA files. These files
      are hosted in source, and need to be generated if a source build is chosen
