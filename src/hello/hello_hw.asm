; Output "Hello" via direct hardware access, move hardware cursor, call BIOS to wait 2 seconds.

org 0x100


GRAPHICS_SEGMENT		equ 0xb800
TEXT_STYLE_WHITE_ON_BLACK	equ 0x07
TWO_SECONDS_IN_MICROSECONDS	equ 0x001e8480
NUM_TEXT_CHARS_ON_SCREEN	equ 80 * 25
CURSOR_POS_INDEX_PORT		equ 0x3d4
CURSOR_POS_VALUE_PORT		equ CURSOR_POS_INDEX_PORT + 1
CURSOR_POS_INDEX_HIGH		equ 0x0e
CURSOR_POS_INDEX_LOW		equ 0x0f

INT_BIOS_WAIT_INT		equ 0x15
INT_BIOS_WAIT_AH		equ 0x86
INT_DOS_EXIT_INT		equ 0x21
INT_DOS_EXIT_AH			equ 0x00


start:
	mov	ax, HELLO_LEN
	mov	bx, hello
	call	print_string

	; Wait two seconds (2M microseconds)
	mov	cx, (TWO_SECONDS_IN_MICROSECONDS >> 16)
	mov	dx, (TWO_SECONDS_IN_MICROSECONDS & 0xffff)
	mov	ah, INT_BIOS_WAIT_AH
	int	INT_BIOS_WAIT_INT

	mov	ah, INT_DOS_EXIT_AH
	int	INT_DOS_EXIT_INT


print_string:
	; ax = string length
	; ds:bx = string contents

	push	di
	push	es

	; Set es to point to the text video buffer
	mov	di, GRAPHICS_SEGMENT
	mov	es, di

	; Set di to point to the first char to write to
	mov	di, [cursor_position]

	; Clamp string length to not go past end of text video buffer
	push	di
	add	di, ax
	sub	di, NUM_TEXT_CHARS_ON_SCREEN
	jbe	.after_ax_is_clamped
	sub	ax, di
.after_ax_is_clamped:
	pop	di
	shl	di, 1

	; Write characters with style non-bold white on black
	mov	dh, TEXT_STYLE_WHITE_ON_BLACK
.loop:
	test	ax, ax
	jz	.loop_done

	mov	dl, [bx]
	mov	[es:di], dx

	dec	ax
	inc	bx
	add	di, 2
	jmp	.loop
.loop_done:

	; Move cursor
	shr	di, 1
	mov	[cursor_position], di
	call	update_hardware_cursor_position

	pop	es
	pop	di

	ret


update_hardware_cursor_position:
	mov	cx, [cursor_position]

	; Set low byte of cursor position
	mov	dx, CURSOR_POS_INDEX_PORT
	mov	al, CURSOR_POS_INDEX_LOW
	mov	ah, cl
	out	dx, ax

	; Set high byte of cursor position
	mov	al, CURSOR_POS_INDEX_HIGH
	mov	ah, ch
	out	dx, ax

	ret


cursor_position		dw	0x0000
hello			db	`Hello`
HELLO_LEN		equ	$ - hello
