org 0x100


start:
	mov	ax, 5
	mov	bx, hello
	call	print_string

	; Wait two seconds (2M microseconds)
	mov	ah, 0x86
	mov	al, 0
	mov	cx, 0x001e
	mov	dx, 0x8480
	int	0x15

	mov	ah, 0x00
	int	0x21


print_string:
	; ax = string length
	; ds:bx = string contents

	push	cx
	push	di
	push	gs

	; Set gs to point to the text video buffer
	mov	di, 0xb800
	mov	gs, di

	; Set di to point to the first char to write to
	mov	di, [cursor_position]

	; Clamp string length to not go past end of text video buffer (2,000 chars)
	push	di
	add	di, ax
	sub	di, 2000
	jbe	.after_ax_is_clamped
	sub	ax, di
.after_ax_is_clamped:
	pop	di
	shl	di, 1

	; Write characters with style 0x07
.loop:
	cmp	ax, 0
	je	.loop_done

	mov	cx, [bx]
	mov	[gs:di], cx
	mov	[gs:di+1], 0x07

	dec	ax
	inc	bx
	add	di, 2
	jmp	.loop
.loop_done:

	; Move cursor
	shr	di, 1
	mov	[cursor_position], di
	call	update_hardware_cursor_position

	pop	gs
	pop	di
	pop	cx

	ret


update_hardware_cursor_position:
	; no args

	push	ax
	push	cx
	push	dx

	mov	cx, [cursor_position]

	; Set low byte of cursor position
	mov	dx, 0x3d4
	mov	al, 0x0f
	out	dx, al
	inc	dx
	mov	al, cl
	out	dx, al

	; Set high byte of cursor position
	dec	dx
	mov	al, 0x0e
	out	dx, al
	inc	dx
	mov	al, ch
	out	dx, al

	pop	dx
	pop	cx
	pop	ax
	ret


cursor_position:
	dw	0x0000

hello:
	db	`Hello`
