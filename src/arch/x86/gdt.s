.section .text, "ax", @progbits
.code32

.global ash_gdt_flush
.type ash_gdt_flush, @function

ash_gdt_flush:
    # Argumento C: puntero al GDTR.
    movl 4(%esp), %eax

    # Instalar nuestra GDT.
    lgdt (%eax)

    # Recargar CS mediante salto lejano.
    ljmp $0x08, $.Lreload_segments

.Lreload_segments:
    # Recargar segmentos de datos.
    movw $0x10, %ax

    movw %ax, %ds
    movw %ax, %es
    movw %ax, %fs
    movw %ax, %gs
    movw %ax, %ss

    ret

.size ash_gdt_flush, .-ash_gdt_flush
