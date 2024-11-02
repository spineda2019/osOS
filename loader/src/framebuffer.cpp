/*
 * Copyright 2024 Sebastian Pineda
 */

namespace {
char* frame_buffer{reinterpret_cast<char*>(0x000B8010)};
}

extern "C" {
void frame_buffer_write_cell(unsigned int location, char c,
                             unsigned char foreground,
                             unsigned char background) {
    frame_buffer[location] = c;
    frame_buffer[location + 1] =
        ((foreground & 0x0F) << 4) | (background & 0x0F);
}
}
