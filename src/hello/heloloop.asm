; Repeatedly output "Hello" and "there." using a DOS system call.

org 0x100

start:
	; Notice that ^C still works in the loop below because `int 0x21` re-enables interrupts for
	; most of the duration of its execution.
	cli
	mov	si, 0			; Loop has to run 64k times
.loop:
	mov	ah, 0x09
	mov	dx, hello_string
	int	0x21
	mov	dx, there_string
	int	0x21
	dec	si
	jnz	.loop

	mov	ah, 0x00
	int	0x21

hello_string:
	db	`Hello\r\n$`

there_string:
	db	`there.\r\n$`
