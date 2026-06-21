org 0x100

start:
	mov	ah, 0x09
	mov	dx, hello_string
	int	0x21

	; Directly set VGA text cursor position to second column of second row
	mov	dx, 0x3d4
	mov	al, 0x0f		; Register: low byte of cursor position
	out	dx, al
	inc	dx
	mov	al, 81			; The actual low byte of cursor position
	out	dx, al

	dec	dx
	mov	al, 0x0e		; Register: high byte of cursor position
	out	dx, al
	inc	dx
	mov	al, 0			; The actual high byte of cursor position
	out	dx, al

	; Wait two seconds (2M microseconds)
	mov	ah, 0x86
	mov	al, 0
	mov	cx, 0x001e
	mov	dx, 0x8480
	int	0x15

	mov	ah, 0x00
	int	0x21

hello_string:
	db	`Hello\r\n$`
