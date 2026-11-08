	.file	"ash_arithmetic.adb"
	.text
	.align 2
	.globl	ash_arithmetic__division_resultIP
	.type	ash_arithmetic__division_resultIP, @function
ash_arithmetic__division_resultIP:
.LFB2:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register 6
	popq	%rbp
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE2:
	.size	ash_arithmetic__division_resultIP, .-ash_arithmetic__division_resultIP
	.align 2
	.globl	ash_arithmetic__divide_unsigned
	.type	ash_arithmetic__divide_unsigned, @function
ash_arithmetic__divide_unsigned:
.LFB3:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register 6
	movq	%rdi, -56(%rbp)
	movq	%rsi, -64(%rbp)
	movq	$0, -8(%rbp)
	movq	$0, -16(%rbp)
	movl	$63, -20(%rbp)
.L6:
	cmpl	$0, -20(%rbp)
	js	.L3
	movl	-20(%rbp), %ecx
	movq	-56(%rbp), %rsi
	shrq	%cl, %rsi
	movq	%rsi, %rcx
	andl	$1, %ecx
	movq	%rcx, -32(%rbp)
	movq	-16(%rbp), %rcx
	shrq	$63, %rcx
	movb	%cl, -33(%rbp)
	movq	-16(%rbp), %rcx
	addq	%rcx, %rcx
	orq	-32(%rbp), %rcx
	movq	%rcx, -16(%rbp)
	cmpb	$0, -33(%rbp)
	jne	.L4
	movq	-16(%rbp), %rcx
	cmpq	-64(%rbp), %rcx
	jb	.L5
.L4:
	movq	-64(%rbp), %rcx
	subq	%rcx, -16(%rbp)
	movl	-20(%rbp), %ecx
	movl	$1, %esi
	salq	%cl, %rsi
	movq	%rsi, %rcx
	orq	%rcx, -8(%rbp)
.L5:
	subl	$1, -20(%rbp)
	jmp	.L6
.L3:
	movq	-8(%rbp), %rax
	movq	-16(%rbp), %rdx
	popq	%rbp
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE3:
	.size	ash_arithmetic__divide_unsigned, .-ash_arithmetic__divide_unsigned
	.globl	ash_arithmetic_E
	.data
	.align 2
	.type	ash_arithmetic_E, @object
	.size	ash_arithmetic_E, 2
ash_arithmetic_E:
	.zero	2
	.ident	"GCC: (GNAT-FSF-builds) 16.1.0"
	.section	.note.GNU-stack,"",@progbits
