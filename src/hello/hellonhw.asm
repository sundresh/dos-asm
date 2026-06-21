org 0x100


TWO_SECONDS_IN_MICROSECONDS	equ 0x001e8480
GRAPHICS_SEGMENT		equ 0xb800
INT_BIOS_SET_CURSOR_POS_INT	equ 0x10
INT_BIOS_SET_CURSOR_POS_AH	equ 0x02
INT_BIOS_WAIT_INT		equ 0x15
INT_BIOS_WAIT_AH		equ 0x86
INT_DOS_EXIT_INT		equ 0x21
INT_DOS_EXIT_AH			equ 0x00


start:
	;call	load_hardware_cursor_position
	call	clear_screen

	mov	ax, HELLO_LEN
	mov	bx, hello
	call	print_string

	mov	ax, 0x7ec4	; Just an arbitrary hexadecimal number to display
	call	print_hex_u16

	call	update_bios_cursor_position

	; Wait two seconds (2M microseconds)
	mov	cx, (TWO_SECONDS_IN_MICROSECONDS >> 16)
	mov	dx, (TWO_SECONDS_IN_MICROSECONDS & 0xffff)
	mov	ah, INT_BIOS_WAIT_AH
	int	INT_BIOS_WAIT_INT

	mov	ah, INT_DOS_EXIT_AH
	int	INT_DOS_EXIT_INT


clear_screen:
	push	eax
	push	cx
	push	di
	push	es
	
	; Set es to point to the text video buffer
	mov	di, GRAPHICS_SEGMENT
	mov	es, di

	; Set the text video buffer to all null chars with style 0x07 (non-bold white on black)
	mov	di, 0
	mov	eax, 0x07000700
	mov	cx, 1000
	rep	stosd

	pop	es
	pop	di
	pop	cx
	pop	eax
	ret


print_hex_u16:
	; ax = number to print

	push	bp
	push	bx
	sub	sp, 4			; Space for string
	mov	bp, sp

	mov	bx, ax

	; Convert nibbles in bx to chars
	mov	al, bh
	shr	al, 4
	call	bits_to_hex_char
	mov	[ss:bp], al

	mov	al, bh
	and	al, 0x0f
	call	bits_to_hex_char
	mov	[ss:bp+1], al

	mov	al, bl
	shr	al, 4
	call	bits_to_hex_char
	mov	[ss:bp+2], al

	mov	al, bl
	and	al, 0x0f
	call	bits_to_hex_char
	mov	[ss:bp+3], al

	; Print string
	mov	ax, 4
	mov	bx, bp
	call	print_string

	add	sp, 4
	pop	bx
	pop	bp
	ret


bits_to_hex_char:
	; al = input/output

	cmp	al, 0x0a
	ja	.letter
.digit:
	add	al, '0'
	ret
.letter:
	and	al, 0x0f
	add	al, ('a' - 0x0a)
	ret


print_string:
	; ax = string length
	; ds:bx = string contents

	push	cx
	push	di
	push	gs

	; Set gs to point to the text video buffer
	mov	di, GRAPHICS_SEGMENT
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


load_hardware_cursor_position:
	push	ax
	push	cx
	push	dx

	; Load low byte of cursor position
	mov	dx, 0x3d4
	mov	al, 0x0f
	out	dx, al
	inc	dx
	in	al, dx
	mov	cl, al

	; Load high byte of cursor position
	dec	dx
	mov	al, 0x0e
	out	dx, al
	inc	dx
	in	al, dx
	mov	ch, al

	mov	[cursor_position], cx

	pop	dx
	pop	cx
	pop	ax
	ret


update_bios_cursor_position:
	push	ax
	push	bx
	push	dx

	mov	ax, [cursor_position]
	mov	bl, 80
	div	bl
	; al = row, ah = col

	mov	dh, al
	mov	dl, ah
	mov	bh, 0
	mov	ah, INT_BIOS_SET_CURSOR_POS_AH
	int	INT_BIOS_SET_CURSOR_POS_INT

	pop	dx
	pop	bx
	pop	ax
	ret


cursor_position		dw	0x0000
hello			db	`Hello 0x`
HELLO_LEN		equ	$ - hello
