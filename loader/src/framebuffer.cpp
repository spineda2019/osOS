/*
 * Copyright 2024 Sebastian Pineda
 */

#include "include/framebuffer.hpp"

namespace {
char* frame_buffer{reinterpret_cast<char*>(0x000B8000)};
constexpr int HALF_BYTE{4};
constexpr unsigned char WELCOME_SIZE{18};
constexpr const unsigned char WELCOME_MESSAGE[]{"Welcome to osOS!!"};
}  // namespace

Cell::Cell(unsigned char character, FrameBufferColor background_color,
           FrameBufferColor text_color)
    : character_{character},
      meta_data_{static_cast<unsigned char>(
          ((static_cast<unsigned char>(text_color) & 0x0F) << HALF_BYTE) |
          (static_cast<unsigned char>(background_color) & 0x0F))} {}

void Cell::Set(unsigned int location) const {
    frame_buffer[location] = character_;
    frame_buffer[location + 1] = meta_data_;
}

FrameBuffer::FrameBuffer() {}

int FrameBuffer::WriteCell(unsigned char row, unsigned char column,
                           Cell&& cell) {
    if (row > 25 || column > 80) {
        return -1;
    } else {
        int cell_location{(row * 2 * 80) + (column * 2)};
        cell.Set(cell_location);
        return 0;
    }
}

extern "C" {
void frame_buffer_write_cell(unsigned int location, unsigned char c,
                             unsigned char foreground,
                             unsigned char background) {
    Cell cell{c, static_cast<FrameBufferColor>(foreground),
              static_cast<FrameBufferColor>(background)};
    cell.Set(location);
}

void clear_screen() {
    constexpr unsigned int frame_buffer_size{80 * 25 * 2};
    for (unsigned int cell{0}; cell < frame_buffer_size; cell += 2) {
        Cell c{' ', FrameBufferColor::Green, FrameBufferColor::Red};
        c.Set(cell);
    }
}

void welcome_message() {
    FrameBuffer fb{};
    unsigned char index{0};
    for (unsigned int cell{40 - WELCOME_SIZE - 1}; cell < 80; cell++) {
        (void)fb.WriteCell(12, cell,
                           Cell{WELCOME_MESSAGE[index], FrameBufferColor::Green,
                                FrameBufferColor::Black});
        index++;
        if (index >= WELCOME_SIZE) {
            break;
        }
    }
}

void dummy_buffer_write() {
    frame_buffer[0] = 'S';
    frame_buffer[1] = ((2 & 0x0F) << 4) | (4 & 0x0F);

    frame_buffer[2] = 'e';
    frame_buffer[3] = ((2 & 0x0F) << 4) | (4 & 0x0F);

    frame_buffer[4] = 'b';
    frame_buffer[5] = ((2 & 0x0F) << 4) | (4 & 0x0F);
}
}
