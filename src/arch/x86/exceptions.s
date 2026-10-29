.section .text, "ax", @progbits
.code32

.extern ash_exception_handler

.macro ISR_NOERR num
.global isr_\num
.type isr_\num, @function
isr_\num:
    pushl $0
    pushl $\num
    jmp isr_common
.size isr_\num, .-isr_\num
.endm

.macro ISR_ERR num
.global isr_\num
.type isr_\num, @function
isr_\num:
    pushl $\num
    jmp isr_common
.size isr_\num, .-isr_\num
.endm

ISR_NOERR 0
ISR_NOERR 1
ISR_NOERR 2
ISR_NOERR 3
ISR_NOERR 4
ISR_NOERR 5
ISR_NOERR 6
ISR_NOERR 7
ISR_ERR   8
ISR_NOERR 9
ISR_ERR   10
ISR_ERR   11
ISR_ERR   12
ISR_ERR   13
ISR_ERR   14
ISR_NOERR 15
ISR_NOERR 16
ISR_ERR   17
ISR_NOERR 18
ISR_NOERR 19
ISR_NOERR 20
ISR_ERR   21
ISR_NOERR 22
ISR_NOERR 23
ISR_NOERR 24
ISR_NOERR 25
ISR_NOERR 26
ISR_NOERR 27
ISR_NOERR 28
ISR_ERR   29
ISR_ERR   30
ISR_NOERR 31

.global isr_common
.type isr_common, @function
isr_common:
    cld
    pusha

    # Pasar puntero al contexto guardado
    pushl %esp
    call ash_exception_handler

1:
    cli
    hlt
    jmp 1b

.size isr_common, .-isr_common

.section .rodata, "a", @progbits
.balign 4

.global ash_isr_table
.type ash_isr_table, @object
ash_isr_table:
    .long isr_0,  isr_1,  isr_2,  isr_3
    .long isr_4,  isr_5,  isr_6,  isr_7
    .long isr_8,  isr_9,  isr_10, isr_11
    .long isr_12, isr_13, isr_14, isr_15
    .long isr_16, isr_17, isr_18, isr_19
    .long isr_20, isr_21, isr_22, isr_23
    .long isr_24, isr_25, isr_26, isr_27
    .long isr_28, isr_29, isr_30, isr_31
.size ash_isr_table, .-ash_isr_table
