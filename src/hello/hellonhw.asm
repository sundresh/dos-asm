; Clear screen and output "Hello" followed by a hexadecimal integer, move hardware cursor, enter
; and exit protected mode, update BIOS cursor position, wait for a keypress and then exit to DOS. 
; Everything except for updating the BIOS cursor position and exiting to DOS is dnoe via direct
; hardware access, which sets us up to do more in protected mode.

org 0x100


CR0_PE_BIT			equ 1
CR0_PG_BIT			equ 1 << 31

EFLAGS_VM_BIT			equ 1 << 17

GRAPHICS_SEGMENT		equ 0xb800
TEXT_STYLE_WHITE_ON_BLACK	equ 0x07
TWO_SECONDS_IN_MICROSECONDS	equ 0x001e8480
NUM_TEXT_CHARS_ON_SCREEN	equ 80 * 25
CURSOR_POS_INDEX_PORT		equ 0x3d4
CURSOR_POS_VALUE_PORT		equ CURSOR_POS_INDEX_PORT + 1
CURSOR_POS_INDEX_HIGH		equ 0x0e
CURSOR_POS_INDEX_LOW		equ 0x0f

INT_BIOS_SET_CURSOR_POS_INT	equ 0x10
INT_BIOS_SET_CURSOR_POS_AH	equ 0x02
INT_BIOS_WAIT_INT		equ 0x15
INT_BIOS_WAIT_AH		equ 0x86
INT_DOS_EXIT_INT		equ 0x21
INT_DOS_EXIT_AH			equ 0x00


start:
	;call	load_hardware_cursor_position
	call	clear_screen

	mov	ax, HELLO_STR_LEN
	mov	bx, hello_str
	call	print_string

	mov	ax, cs
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

	call	enter32

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
	sub	sp, 4

	mov	cx, ax

	; Convert nibbles in cx to chars
	mov	al, ch
	shr	al, 4
	call	bits_to_hex_char
	mov	[esp], al

	mov	al, ch
	and	al, 0x0f
	call	bits_to_hex_char
	mov	[esp+1], al

	mov	al, cl
	shr	al, 4
	call	bits_to_hex_char
	mov	[esp+2], al

	mov	al, cl
	and	al, 0x0f
	call	bits_to_hex_char
	mov	[esp+3], al

	; Print string
	mov	ax, 4
	mov	bx, sp
	call	print_string

	add	sp, 4
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
	mov	bx, sp
	sub	sp, 5

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
	mov	ax, sp
	add	ax, 5
	sub	ax, bx
	call	print_string

	add	sp, 5
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
	mov	dx, CURSOR_POS_INDEX_PORT
	mov	al, CURSOR_POS_INDEX_LOW
	mov	ah, cl
	out	dx, ax

	; Set high byte of cursor position
	mov	al, CURSOR_POS_INDEX_HIGH
	mov	ah, ch
	out	dx, ax

	ret


load_hardware_cursor_position:
	; Load low byte of cursor position
	mov	dx, CURSOR_POS_INDEX_PORT
	mov	al, CURSOR_POS_INDEX_LOW
	out	dx, al
	inc	dx
	in	al, dx
	mov	cl, al
	dec	dx

	; Load high byte of cursor position
	mov	al, CURSOR_POS_INDEX_HIGH
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

	; Use strict to ensure each interrupt handler is the same size, so we can easily fill in
	; pointers to the interrupt handlers in the interrupt vector table.
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

backup_ivt		dw	256 dup (0, 0)


gdtr:
.limit			dw	gdt.end - gdt
.base			dd	0

align 8
gdt:
.unused_first_descr	dd	0, 0
.cs32_descr		dd	0x0000ffff, 0x00cf9b00
.ds32_descr		dd	0x0000ffff, 0x00cf9300
.cs16_descr:
.cs16_descr_limit	dw	0xffff
.cs16_descr_base_15_0	dw	0	; Fill this in at runtime
.cs16_descr_base_23_16	db	0	; Fill this in at runtime
.cs16_descr_bits	dw	0x009b
.cs16_descr_base_31_24	db	0
.ds16_descr:
.ds16_descr_limit	dw	0xffff
.ds16_descr_base_15_0	dw	0	; Fill this in at runtime
.ds16_descr_base_23_16	db	0	; Fill this in at runtime
.ds16_descr_bits	dw	0x0093
.ds16_descr_base_31_24	db	0
.end:

CS32_SEL		equ	gdt.cs32_descr - gdt
DS32_SEL		equ	gdt.ds32_descr - gdt
CS16_SEL		equ	gdt.cs16_descr - gdt
DS16_SEL		equ	gdt.ds16_descr - gdt

start32_far_ptr:
.offset			dd	0
.selector		dw	CS32_SEL


enter32:
	cli

	; Calculate flat address base of CS
	mov	ebx, cs
	shl	ebx, 4
	; Fill in gdt.cs16_descr and gdt.ds16_descr, used when returning to real mode later
	mov	[gdt.cs16_descr_base_15_0], bx
	mov	[gdt.ds16_descr_base_15_0], bx
	mov	ecx, ebx
	shr	ecx, 16
	mov	[gdt.cs16_descr_base_23_16], cl
	mov	[gdt.ds16_descr_base_23_16], cl
	; Calculate and fill in flat address of start32
	mov	eax, ebx
	add	eax, start32
	mov	[start32_far_ptr.offset], eax
	; Set up GDT
	mov	eax, ebx
	add	eax, gdt
	mov	[gdtr.base], eax
	lgdt	[gdtr]
	; Enable protected mode
	mov	eax, cr0
	or	eax, CR0_PE_BIT
	mov	cr0, eax
	; Reload CS
	call	dword far [start32_far_ptr]
	; Returned to real mode with CS, DS & SS already restored

	sti
	ret


[bits 32]
; Far call start32 via [start32_far_ptr] when entering protected mode
start32:
	; Reload DS & SS
	mov	ax, DS32_SEL
	mov	ds, ax
	mov	ss, ax
	add	esp, ebx
	; TODO: Run something useful in protected mode
.return_to_real_mode:
	; Reload DS & SS (part 1: switch back to 16-bit while still in protected mode)
	mov	ax, DS16_SEL
	mov	ds, ax
	mov	ss, ax
	sub	esp, ebx
	; Reload CS (part 1: switch back to 16-bit while still in protected mode)
	call	dword .push_ip
.push_ip:
	pop	eax
	add	eax, .cs_is_now_16_bits - .push_ip
	sub	eax, ebx
	push	dword CS16_SEL	; retfd below pops 32 bits for CS, discarding the high order 16 bits
	push	eax
	retfd
[bits 16]
.cs_is_now_16_bits:
	; Disable protected mode
	mov	eax, cr0
	and	eax, ~CR0_PE_BIT
	mov	cr0, eax
	; Reload DS & SS (part 2: switch back to the real mode segment)
	mov	eax, ebx
	shr	eax, 4
	mov	ds, ax
	mov	ss, ax
	; Reload CS (part 2: switch back to the real mode segment)
	retfd
