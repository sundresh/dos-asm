; Trigger a GPF in real mode.

org 0x100

start:
	; Attempting to read past the end of a segment triggers a General Protection Fault, even in
	; real mode.
	mov	eax, [dword 65537]
	; Does not actually exit due to the GPF above.
	mov	ah, 0x00
	int	0x21

hello_string:
	db	`Hello\r\n$`
