; Simply output "Hello" using a DOS system call.

org 0x100

start:
	mov	ah, 0x09
	mov	dx, hello_string
	int	0x21
	mov	ah, 0x00
	int	0x21

hello_string:
	db	`Hello\r\n$`
