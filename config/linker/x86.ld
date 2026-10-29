OUTPUT_FORMAT(elf32-i386)
OUTPUT_ARCH(i386)
ENTRY(_start)

PHDRS
{
    kernel PT_LOAD FLAGS(7);
}

SECTIONS
{
    . = 0x00100000;

    .multiboot ALIGN(8) :
    {
        KEEP(*(.multiboot))
    } :kernel

    .text ALIGN(4096) :
    {
        *(.text)
        *(.text.*)
    } :kernel

    .rodata ALIGN(4096) :
    {
        *(.rodata)
        *(.rodata.*)
    } :kernel

    .data ALIGN(4096) :
    {
        *(.data)
        *(.data.*)
    } :kernel

    .bss ALIGN(4096) (NOLOAD) :
    {
        *(COMMON)
        *(.bss)
        *(.bss.*)
    } :kernel

    . = ALIGN(4096);
    __kernel_end = .;
}