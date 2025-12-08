OUTPUT_FORMAT(elf32-i386)
OUTPUT_ARCH(i386)
ENTRY(_start)

SECTIONS
{
    /* Place the kernel at 1 MiB, above the real-mode interrupt vector table
       and BIOS data areas. */
    . = 1M;

    /* Keep the multiboot header near the start of the image so GRUB finds it. */
    .multiboot ALIGN(4) :
    {
        KEEP(*(.multiboot))
    }

    /* Executable code. */
    .text ALIGN(4K) :
    {
        *(.text)
    }

    /* Read-only data such as constants and jump tables. */
    .rodata ALIGN(4K) :
    {
        *(.rodata*)
    }

    /* Writable data. */
    .data ALIGN(4K) :
    {
        *(.data)
    }

    /* Zero-initialized data and the kernel stack live here. */
    .bss ALIGN(4K) :
    {
        __bss_start = .;
        *(.bss*)
        *(COMMON)
        __bss_end = .;
    }

    /* Ensure the linker discards metadata sections the bootloader does not need. */
    /DISCARD/ :
    {
        *(.eh_frame)
        *(.comment)
    }
}
