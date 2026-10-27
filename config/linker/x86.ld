OUTPUT_FORMAT(elf32-i386)
OUTPUT_ARCH(i386)
ENTRY(_start)

SECTIONS
{
    /*
     * Kernel load address: 1 MiB
     */
    . = 0x00100000;

    /*
     * Multiboot2 header
     *
     * Must be located within the first 32768 bytes
     * of the kernel image and aligned to 8 bytes.
     */
    .multiboot ALIGN(8) :
    {
        KEEP(*(.multiboot))
    }

    /*
     * Executable code
     */
    .text ALIGN(4096) :
    {
        *(.text)
        *(.text.*)
    }

    /*
     * Read-only data
     */
    .rodata ALIGN(4096) :
    {
        *(.rodata)
        *(.rodata.*)
    }

    /*
     * Initialized data
     */
    .data ALIGN(4096) :
    {
        *(.data)
        *(.data.*)
    }

    /*
     * Uninitialized data
     */
    .bss ALIGN(4096) (NOLOAD) :
    {
        *(COMMON)
        *(.bss)
        *(.bss.*)
    }

    /*
     * End of kernel image in memory
     */
    . = ALIGN(4096);
    __kernel_end = .;
}