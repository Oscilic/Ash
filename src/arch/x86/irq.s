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

    pusha
    pushl %ds
    pushl %es
    pushl %fs
    pushl %gs

    movl 48(%esp), %eax

    movl %esp, %ebx

    movw $0x10, %dx
    movw %dx, %ds
    movw %dx, %es
    movw %dx, %fs
    movw %dx, %gs

    andl $-16, %esp

    subl $512, %esp

    fxsave (%esp)

    subl $16, %esp

    movl %eax, 0(%esp)

    call ash_irq_handler

    addl $16, %esp

    fxrstor (%esp)

    movl %ebx, %esp

    popl %gs
    popl %fs
    popl %es
    popl %ds

    popa

    addl $4, %esp

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
