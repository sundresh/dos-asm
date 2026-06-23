; Clear screen and output "Hello" followed by a hexadecimal integer, all via direct hardware
; access, move hardware cursor, update BIOS cursor position, call BIOS to wait 2 seconds.

org 0x100


GRAPHICS_SEGMENT		equ 0xb800
TEXT_STYLE_WHITE_ON_BLACK	equ 0x07
TWO_SECONDS_IN_MICROSECONDS	equ 0x001e8480
NUM_TEXT_CHARS_ON_SCREEN	equ 80 * 25

INT_BIOS_SET_CURSOR_POS_INT	equ 0x10
INT_BIOS_SET_CURSOR_POS_AH	equ 0x02
INT_BIOS_WAIT_INT		equ 0x15
INT_BIOS_WAIT_AH		equ 0x86
INT_DOS_EXIT_INT		equ 0x21
INT_DOS_EXIT_AH			equ 0x00

CR0_PE_BIT			equ 1
CR0_PG_BIT			equ 1 << 31

EFLAGS_VM_BIT			equ 1 << 17


start:
	;call	load_hardware_cursor_position
	call	clear_screen

	mov	ax, HELLO_STR_LEN
	mov	bx, hello_str
	call	print_string

	mov	ax, 0x7ec4	; Just an arbitrary hexadecimal number to display
	call	print_hex_u16

	mov	ax, ' '
	call	print_char

	mov	ax, 386		; Just an arbitrary decimal number to display
	call	print_dec_u16

	call	move_cursor_to_next_line

	; Check if we're in protected mode, and if so, whether paging is enabled
	mov	eax, cr0
	test	eax, CR0_PE_BIT
	jz	.cr0_checks_done
	push	eax
	mov	ax, PE_ENABLED_STR_LEN
	mov	bx, pe_enabled_str
	call	print_string
	call	move_cursor_to_next_line
	pop	eax
	test	eax, CR0_PG_BIT
	jz	.cr0_checks_done
	mov	ax, PG_ENABLED_STR_LEN
	mov	bx, pg_enabled_str
	call	print_string
	call	move_cursor_to_next_line
.cr0_checks_done:

	; Check if we're in virtual 8086 mode
	pushfd
	pop	eax
	call	print_hex_u16
	call	move_cursor_to_next_line
	pushfd
	pop	eax
	test	eax, EFLAGS_VM_BIT
	jz	.eflags_checks_done
	mov	ax, V86_ENABLED_STR_LEN
	mov	bx, v86_enabled_str
	call	print_string
	call	move_cursor_to_next_line
.eflags_checks_done:

	; Wait for *two* keyboard scan codes (the first one is the key-up event from pressing
	; [Enter] to run the program)
	call	install_interrupt_handlers
.wait_for_key1:
	mov	ax, [keyboard_scan_code]
	cmp	ax, 0
	je	.wait_for_key1
	mov	[keyboard_scan_code], 0
.wait_for_key2:
	mov	ax, [keyboard_scan_code]
	cmp	ax, 0
	je	.wait_for_key2
	call	move_cursor_to_next_line
	call	uninstall_interrupt_handlers

	call	update_bios_cursor_position

	; Wait two seconds (2M microseconds)
	;mov	cx, (TWO_SECONDS_IN_MICROSECONDS >> 16)
	;mov	dx, (TWO_SECONDS_IN_MICROSECONDS & 0xffff)
	;mov	ah, INT_BIOS_WAIT_AH
	;int	INT_BIOS_WAIT_INT

	mov	ah, INT_DOS_EXIT_AH
	int	INT_DOS_EXIT_INT


clear_screen:
	push	di
	push	es
	
	; Set es to point to the text video buffer
	mov	cx, GRAPHICS_SEGMENT
	mov	es, cx

	; Set the text video buffer to all null chars with style non-bold white on black
	xor	di, di
	mov	eax, (TEXT_STYLE_WHITE_ON_BLACK << 24) | (TEXT_STYLE_WHITE_ON_BLACK << 8)
	mov	cx, (NUM_TEXT_CHARS_ON_SCREEN*(1+1)/4)	; (per char: 1 char byte + 1 style byte) / 4 bytes eax
	rep	stosd

	pop	es
	pop	di
	ret


print_hex_u16:
	; ax = number to print
	push	bx

	mov	cx, ax

	; Convert nibbles in cx to chars
	mov	al, ch
	shr	al, 4
	call	bits_to_hex_char
	mov	[num_str_buf], al

	mov	al, ch
	and	al, 0x0f
	call	bits_to_hex_char
	mov	[num_str_buf+1], al

	mov	al, cl
	shr	al, 4
	call	bits_to_hex_char
	mov	[num_str_buf+2], al

	mov	al, cl
	and	al, 0x0f
	call	bits_to_hex_char
	mov	[num_str_buf+3], al

	; Print string
	mov	ax, 4
	mov	bx, num_str_buf
	call	print_string

	pop	bx
	ret


bits_to_hex_char:
	; al = input/output

	cmp	al, 0x0a
	jae	.letter
.digit:
	add	al, '0'
	ret
.letter:
	and	al, 0x0f
	add	al, ('a' - 0x0a)

	ret


print_dec_u16:
	; ax = number to print

	push	bx

	; Start bx at the end of the string space
	mov	bx, num_str_buf+5

	; Fill in characters of the string from least to most significant
	mov	cx, 10
.loop:
	xor	dx, dx
	div	cx
	add	dl, '0'
	dec	bx
	mov	[bx], dl
	test	ax, ax
	jnz	.loop

	; Print string
	mov	ax, num_str_buf+5
	sub	ax, bx
	call	print_string

	pop	bx
	ret


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
	cmp	ax, 0
	je	.loop_done

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


print_char:
	; al = character to print

	push	bx
	push	es

	; Set es to point to the text video buffer
	mov	bx, GRAPHICS_SEGMENT
	mov	es, bx

	; Set bx to point to the first char to write to
	mov	bx, [cursor_position]
	shl	bx, 1

	; Write character with style non-bold white on black
	mov	[es:bx], al
	mov	[es:bx+1], TEXT_STYLE_WHITE_ON_BLACK

	; Move cursor
	inc	[cursor_position]
	call	update_hardware_cursor_position

	pop	es
	pop	bx

	ret


move_cursor_to_next_line:
	; Get row
	mov	ax, [cursor_position]
	mov	cl, 80
	div	cl
	; Next row
	inc	al
	cmp	al, 25
	jb	.set_row
	mov	al, 0
.set_row:
	; Set position
	mul	cl
	mov	[cursor_position], ax

	call	update_hardware_cursor_position
	ret


update_hardware_cursor_position:
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

	ret


load_hardware_cursor_position:
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

	ret


update_bios_cursor_position:
	push	bx

	mov	ax, [cursor_position]
	mov	bl, 80
	div	bl
	; al = row, ah = col

	mov	dh, al
	mov	dl, ah
	xor	bh, bh
	mov	ah, INT_BIOS_SET_CURSOR_POS_AH
	int	INT_BIOS_SET_CURSOR_POS_INT

	pop	bx
	ret


install_interrupt_handlers:
	push	si
	push	di
	push	es

	cli

	; ES := DS (for movsd)
	mov	di, ds
	mov	es, di

	; Backup old interrupt vector table
	mov	si, 0
	mov	ds, si
	mov	di, backup_ivt
	mov	ecx, 256
	rep	movsd

	; DS := ES
	mov	di, es
	mov	ds, di

	; Install new interrupt vector table
	mov	si, interrupt_handlers.begin
	mov	di, 0
	mov	es, di
.loop:
	mov	[es:di], si
	mov	[es:di+2], cs
	add	si, interrupt_handler_size
	add	di, 4
	cmp	di, 256*4
	jb	.loop

	sti

	pop	es
	pop	di
	pop	si
	ret


uninstall_interrupt_handlers:
	push	si
	push	di
	push	es

	cli

	; Restore backup interrupt vector table
	mov	si, backup_ivt
	mov	di, 0
	mov	es, di
	mov	ecx, 256
	rep	movsd

	sti

	pop	es
	pop	di
	pop	si
	ret


shared_interrupt_handler:
	push	bx
	push	cx
	push	dx
	push	ds

	; Skip printing timer interrupt (8)
	cmp	ax, 8
	je	.exit

	; Consume, print & save scan code for keyboard interrupt (9)
	cmp	ax, 9
	jne	.default_interrupt
.keyboard_interrupt:
	mov	ax, cs
	mov	ds, ax		; DS := CS (because this is a .COM file)
	mov	al, '['
	call	print_char
	in	al, 0x60	; Get the buffered keyboard scan code
	xor	ah, ah
	mov	[keyboard_scan_code], ax
	call	print_hex_u16
	mov	al, ']'
	call	print_char
	jmp	.exit

	; Print out any other interrupt
.default_interrupt:
	push	ax		; Save interrupt number to print it out later
	mov	ax, cs
	mov	ds, ax		; DS := CS (because this is a .COM file)
	mov	ax, INTERRUPT_NUM_STR_LEN
	mov	bx, interrupt_num_str
	call	print_string
	pop	ax
	call	print_dec_u16
	call	move_cursor_to_next_line


.exit:
	mov	al, 0x20
	out	0xa0, al	; Re-enable the secondary programmable interrupt controller
	out	0x20, al	; Re-enable the primary programmable interrupt controller

	pop	ds
	pop	dx
	pop	cx
	pop	bx
	ret


interrupt_handlers:
.begin:
%assign interrupt_num 0
%rep 256
	cli
	push	ax

	; Use strict to ensure each interrupt handler is the same size
	mov	ax, strict word interrupt_num
	call	shared_interrupt_handler

	pop	ax
	sti
	iret
%assign interrupt_num interrupt_num+1
%endrep
.end:

interrupt_handler_size	equ	(interrupt_handlers.end - interrupt_handlers.begin)/256


cursor_position		dw	0
keyboard_scan_code	dw	0

hello_str		db	"Hello 0x"
HELLO_STR_LEN		equ	$ - hello_str
pe_enabled_str		db	"Protection enabled"
PE_ENABLED_STR_LEN	equ	$ - pe_enabled_str
pg_enabled_str		db	"Paging enabled"
PG_ENABLED_STR_LEN	equ	$ - pg_enabled_str
v86_enabled_str		db	"Virtual 8086 mode enabled"
V86_ENABLED_STR_LEN	equ	$ - v86_enabled_str
interrupt_num_str	db	"Interrupt #"
INTERRUPT_NUM_STR_LEN	equ	$ - interrupt_num_str

; num_str_buf is reserved in data space since print_string doesn't take a far pointer tha could be
; used to locate a temporary string on the stack.
NUM_STR_BUF_LEN		equ	16
num_str_buf		times	NUM_STR_BUF_LEN db 0

backup_ivt		dw	256 dup (0, 0)
