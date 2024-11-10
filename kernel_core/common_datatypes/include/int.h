/*
 * Copyright 2024 Sebastian Pineda
 */

#ifndef KERNEL_CORE_COMMON_DATATYPES_INCLUDE_INT_H_
#define KERNEL_CORE_COMMON_DATATYPES_INCLUDE_INT_H_

#ifdef __cplusplus
extern "C" {
#endif

struct u8 {
    unsigned char inner_ : 8;
    explicit u8(unsigned char i);
} __attribute__((packed));

struct i8 {
    signed char inner_ : 8;
    explicit i8(signed char i);
} __attribute__((packed));

struct u16 {
    unsigned int inner_ : 16;
    explicit u16(unsigned int i);
} __attribute__((packed));

struct i16 {
    signed int inner_ : 16;
    explicit i16(signed int i);
} __attribute__((packed));

#ifdef __cplusplus
}
#endif

#endif  // KERNEL_CORE_COMMON_DATATYPES_INCLUDE_INT_H_
