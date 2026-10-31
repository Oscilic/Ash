.section .text, "ax", @progbits
.code32

.extern ash_irq_handler

.macro IRQ_STUB num
.global irq_\num
.type irq_\num, @function
irq_\num:
    pushl $\num
    jmp irq_common
.size irq_\num, .-irq_\num
.endm

IRQ_STUB 0
IRQ_STUB 1
IRQ_STUB 2
IRQ_STUB 3
IRQ_STUB 4
IRQ_STUB 5
IRQ_STUB 6
IRQ_STUB 7
IRQ_STUB 8
IRQ_STUB 9
IRQ_STUB 10
IRQ_STUB 11
IRQ_STUB 12
IRQ_STUB 13
IRQ_STUB 14
IRQ_STUB 15


.global irq_common
.type irq_common, @function

irq_common:
    cld

    # 1. Guardar registros generales y segmentos.
    pusha
    pushl %ds
    pushl %es
    pushl %fs
    pushl %gs

    # 2. Obtener número de IRQ.
    # 16 bytes segmentos + 32 bytes PUSHA.
    movl 48(%esp), %eax

    # 3. Guardar ESP original en EBX.
    # EBX es callee-saved en la ABI i386 C.
    movl %esp, %ebx

    # 4. Activar segmentos de datos del kernel.
    movw $0x10, %dx
    movw %dx, %ds
    movw %dx, %es
    movw %dx, %fs
    movw %dx, %gs

    # 5. Alinear la pila a 16 bytes.
    andl $-16, %esp

    # 6. Reservar 512 bytes para FPU/SSE.
    subl $512, %esp

    # Guardar el estado extendido.
    fxsave (%esp)

    # 7. Reservar espacio para llamada C.
    subl $16, %esp

    # Primer argumento: número de IRQ.
    movl %eax, 0(%esp)

    # Llamar al manejador Zig.
    call ash_irq_handler

    # 8. Recuperar área FXSAVE.
    addl $16, %esp

    # Restaurar estado FPU/SSE.
    fxrstor (%esp)

    # 9. Restaurar ESP original.
    movl %ebx, %esp

    # 10. Restaurar segmentos.
    popl %gs
    popl %fs
    popl %es
    popl %ds

    # Restaurar registros generales.
    popa

    # Retirar número de IRQ.
    addl $4, %esp

    # Regresar al contexto interrumpido.
    iret

.size irq_common, .-irq_common

.section .rodata, "a", @progbits
.balign 4

.global ash_irq_table
.type ash_irq_table, @object
ash_irq_table:
    .long irq_0,  irq_1,  irq_2,  irq_3
    .long irq_4,  irq_5,  irq_6,  irq_7
    .long irq_8,  irq_9,  irq_10, irq_11
    .long irq_12, irq_13, irq_14, irq_15
.size ash_irq_table, .-ash_irq_table
