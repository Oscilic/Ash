    .set MULTIBOOT2_HEADER_MAGIC, 0xE85250D6
    .set MULTIBOOT2_ARCHITECTURE_I386, 0
    .set MULTIBOOT2_BOOT_MAGIC, 0x36D76289

    .section .multiboot, "a", @progbits
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

        # Comprobar FXSR, SSE y SSE2.
        movl $1, %eax
        cpuid

        # EDX bits 24, 25 y 26 deben estar activos.
        movl %edx, %ecx
        andl $0x07000000, %ecx
        cmpl $0x07000000, %ecx
        jne .Lno_sse

        # Configurar CR0.
        movl %cr0, %eax
        orl $0x00000002, %eax
        andl $0xFFFFFFF3, %eax
        movl %eax, %cr0

        # Configurar CR4.
        movl %cr4, %eax
        orl $0x00000600, %eax
        movl %eax, %cr4

        fninit

        jmp .Lsse_ready

        .Lno_sse:
            cli
        .Lno_sse_halt:
            hlt
            jmp .Lno_sse_halt

        .Lsse_ready:
        call kernel_main

    .Lhang:
        cli
        hlt
        jmp .Lhang
