/*
 * Copyright 2024 Sebastian Pineda
 */

#include <int.h>
#include <io.h>

namespace {
// constexpr unsigned int SERIAL_COM1_BASE{0x3F8};

// inline unsigned int SERIAL_DATA_PORT(unsigned int base) { return base; }

// inline unsigned int SERIAL_FIFO_COMMAND_PORT(unsigned int base) {
//     return base + 2;
// }

inline unsigned int SERIAL_LINE_COMMAND_PORT(unsigned int base) {
    return base + 3;
}

// inline unsigned int SERIAL_MODEM_COMMAND_PORT(unsigned int base) {
//     return base + 4;
// }

// inline unsigned int SERIAL_LINE_STATUS_PORT(unsigned int base) {
//     return base + 5;
// }

/*
 * Tells serial port to expecy highest 8 bits on port, then lowest 8 bits
 */
constexpr unsigned int SERIAL_LINE_ENABLE_DLAB{0x80};

}  // namespace

extern "C" {
inline void ConfigureSerialBaudRate(uint16 com_port, uint16 divisor) {
    out_wrapper(SERIAL_LINE_COMMAND_PORT(com_port.Raw()),
                SERIAL_LINE_ENABLE_DLAB);
    out_wrapper(com_port.Raw(), (divisor.Raw() >> 8) & 0x00FF);
    out_wrapper(com_port.Raw(), divisor.Raw() & 0x00FF);
}
}
