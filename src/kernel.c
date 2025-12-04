#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "drivers/terminal.h"

/* Check if the compiler thinks you are targeting the wrong operating system. */
#if defined(__linux__) && !defined(ALLOW_HOST_TOOLCHAIN)
#error "You are not using a cross-compiler, you will most certainly run into trouble"
#endif

/* This tutorial will only work for the 32-bit ix86 targets. */
#if !defined(__i386__)
#error "This tutorial needs to be compiled with a ix86-elf compiler"
#endif


void kernel_main(void) 
{
	/* Initialize terminal interface */
	terminal_initialize();
	terminal_setcolor(vga_entry_color(VGA_COLOR_LIGHT_BLUE, VGA_COLOR_BLACK));
	terminal_writestring("\n");	                         
	terminal_writestring("EEEEE N   N ZZZZZ  OOO   SSSS \n");
	terminal_writestring("E     NN  N    Z  O   O S     \n");
	terminal_writestring("EEEE  N N N   Z   O   O  SSS  \n");
	terminal_writestring("E     N  NN  Z    O   O     S \n");
	terminal_writestring("EEEEE N   N ZZZZZ  OOO  SSSS  \n");
                          
	terminal_setcolor(vga_entry_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK));
	terminal_writestring("EnzOS booted successfully.\n");
	terminal_writestring("\n");
	terminal_writestring("$ _");
}
