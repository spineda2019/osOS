CC = gcc
CXX = g++

.PHONY: clean all loader framebuffer

all: loader framebuffer

loader: framebuffer
	@$(MAKE) -C loader

framebuffer:
	@$(MAKE) -C framebuffer

clean:
	@rm -rf build
