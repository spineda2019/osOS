# HAL (Hardware Abstraction Layer)
This module contains definitions for each architecture entry module to be able
to construct an arch agnostic HAL. Each architecture entry module will have to
construct their own arch <i>specific</i> HAL (basically a struct full of
instances of various types that are able to do hardware level work, like
outputting to the screen), then construct the generic HAL defined in this
module using that. The arch agnostic HAL uses comptime to construct a HAL
type at comptime, checking that the arch specific HAL implemented everything
it needed to, then finally storing all the instance pointers for itself.
