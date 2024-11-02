/*
 * Copyright 2024 Sebastian Pineda
 */

#ifndef LOADER_SRC_INCLUDE_FRAMEBUFFER_HPP_
#define LOADER_SRC_INCLUDE_FRAMEBUFFER_HPP_

enum class FrameBufferColor : unsigned char {
    Black = 0,
    Blue = 1,
    Green = 2,
    Cyan = 3,
    Red = 4,
    Magenta = 5,
    Brown = 6,
    LightGrey = 7,
    DarkGrey = 8,
    LightBlue = 9,
    LightGreen = 10,
    LightCyan = 11,
    LightRed = 12,
    LightMagenta = 13,
    LightBrown = 14,
    White = 15,
};

class Cell final {
 public:
    Cell(unsigned char character, FrameBufferColor background_color,
         FrameBufferColor text_color);
    void Set(unsigned int location) const;

 private:
    unsigned char character_;
    unsigned char meta_data_;
};

class FrameBuffer final {
 public:
    FrameBuffer();

    [[nodiscard("This may fail, and the result must be checked")]]
    int WriteCell(unsigned char row, unsigned char column, Cell&& cell);
};

#endif  // LOADER_SRC_INCLUDE_FRAMEBUFFER_HPP_
