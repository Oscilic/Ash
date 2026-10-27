.set MULTIBOOT2_HEADER_MAGIC, 0xE85250D6
.set MULTIBOOT2_ARCHITECTURE_I386, 0
.set MULTIBOOT2_BOOT_MAGIC, 0x36D76289

.section .multiboot
.balign 8

header_start:
    .long MULTIBOOT2_HEADER_MAGIC
    .long MULTIBOOT2_ARCHITECTURE_I386
    .long header_end - header_start
    .long -(MULTIBOOT2_HEADER_MAGIC + MULTIBOOT2_ARCHITECTURE_I386 + (header_end - header_start))

    .balign 8
    .short 0
    .short 0
    .long 8

header_end:

.section .bss
.balign 16

stack_bottom:
    .skip 16384

stack_top:

.section .text
.global _start
.extern kernel_main

.type _start, @function

_start:

    cli
    mov $stack_top, %esp
    push %ebx
    push %eax

    call kernel_main

.Lhang:
    cli
    hlt
    jmp .Lhang