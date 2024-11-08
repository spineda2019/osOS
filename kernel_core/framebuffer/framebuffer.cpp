/*
 * Copyright 2024 Sebastian Pineda
 */

#include "include/framebuffer.hpp"

namespace {
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

Cell::Cell()
    : character_{'T'},
      meta_data_{static_cast<unsigned char>(
          ((static_cast<unsigned char>(FrameBufferColor::Green) & 0x0F)
           << HALF_BYTE) |
          (static_cast<unsigned char>(FrameBufferColor::Black) & 0x0F))} {}

void Cell::SetCharacter(unsigned char c) { character_ = c; }

void Cell::Draw(unsigned int location) const {
    char* frame_buffer{reinterpret_cast<char*>(FRAME_BUFFER_START)};
    frame_buffer[location] = character_;
    frame_buffer[location + 1] = meta_data_;
}

void Cell::SetBackground(FrameBufferColor background) {
    unsigned char raw{static_cast<unsigned char>(background)};
    // clear lower 4 bits
    meta_data_ = meta_data_ & 0b11110000;
    // now set them
    meta_data_ = (raw & 0x0F) | meta_data_;
}

void Cell::SetTextColor(FrameBufferColor text_color) {
    unsigned char raw{static_cast<unsigned char>(text_color)};
    // clear upper 4 bits
    meta_data_ = meta_data_ & 0b00001111;
    // now set them
    meta_data_ = ((raw & 0x0F) << 4) | meta_data_;
}

FrameBuffer::FrameBuffer() {}

int FrameBuffer::DrawCell(unsigned char row, unsigned char column, Cell cell) {
    if (row > 25 || column > 80) {
        return -1;
    } else {
        int offset{(row * 2 * 80) + (column * 2)};
        cell.Draw(offset);
        return 0;
    }
}

extern "C" {
void frame_buffer_write_cell(unsigned int location, unsigned char c,
                             unsigned char foreground,
                             unsigned char background) {
    Cell cell{c, static_cast<FrameBufferColor>(foreground),
              static_cast<FrameBufferColor>(background)};
    cell.Draw(location);
}

void test_corners() {
    FrameBuffer internal_global_framebuffer{};
    internal_global_framebuffer.DrawCell(0, 0, Cell{});
    internal_global_framebuffer.DrawCell(0, 79, Cell{});
    internal_global_framebuffer.DrawCell(24, 79, Cell{});
    internal_global_framebuffer.DrawCell(24, 0, Cell{});
}

void clear_screen() {
    FrameBuffer internal_global_framebuffer{};
    for (unsigned char row{0}; row < 25; row++) {
        for (unsigned char col{0}; col < 80; col++) {
            internal_global_framebuffer.DrawCell(
                row, col,
                Cell{' ', FrameBufferColor::Green, FrameBufferColor::Red});
        }
    }
}

void welcome_message() {
    FrameBuffer internal_global_framebuffer{};
    unsigned char index{0};
    for (unsigned int cell{40 - WELCOME_SIZE - 1}; cell < 80; cell++) {
        internal_global_framebuffer.DrawCell(
            12, cell,
            Cell{WELCOME_MESSAGE[index], FrameBufferColor::Red,
                 FrameBufferColor::Green});
        index++;
        if (index >= WELCOME_SIZE) {
            break;
        }
    }
}
}
