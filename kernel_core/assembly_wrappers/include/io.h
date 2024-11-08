/*
 * Copyright 2024 Sebastian Pineda
 */

#ifndef ASSEMBLY_WRAPPERS_SRC_INCLUDE_IO_H_
#define ASSEMBLY_WRAPPERS_SRC_INCLUDE_IO_H_

#ifdef __cplusplus
extern "C" {
#endif

void out_wrapper(unsigned short port, unsigned char data);

#ifdef __cplusplus
}

#endif
#endif  // ASSEMBLY_WRAPPERS_SRC_INCLUDE_IO_H_
