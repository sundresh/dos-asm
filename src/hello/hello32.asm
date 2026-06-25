; Enter protected mode and output "Hello" via direct hardware access, move the hardware cursor,
; then exit to real mode DOS, updating the BIOS cursor position along the way.

CR0_PE_BIT			equ 1

VIDEO_BUFFER			equ 0xb8000
TEXT_STYLE_WHITE_ON_BLACK	equ 0x07
NUM_TEXT_CHARS_ON_SCREEN	equ 80 * 25
CURSOR_POS_INDEX_PORT		equ 0x3d4
CURSOR_POS_VALUE_PORT		equ CURSOR_POS_INDEX_PORT + 1
CURSOR_POS_INDEX_HIGH		equ 0x0e
CURSOR_POS_INDEX_LOW		equ 0x0f

INT_BIOS_SET_CURSOR_POS_INT	equ 0x10
INT_BIOS_SET_CURSOR_POS_AH	equ 0x02
INT_DOS_EXIT_INT		equ 0x21
INT_DOS_EXIT_AH			equ 0x00


; 16-bit code run by DOS as a .COM file
[bits 16]
section .text vstart=0x100


start16:
	call	call_main32_in_protected_mode
	call	update_bios_cursor_position_16
	mov	ah, INT_DOS_EXIT_AH
	int	INT_DOS_EXIT_INT


call_main32_in_protected_mode:
	push	ebx
	sub	sp, 6

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
	; Set up GDT
	mov	eax, ebx
	add	eax, gdt
	xor	edx, edx
	mov	dx, sp
	mov	[edx], word (gdt.end - gdt)
	mov	[edx+2], eax
	lgdt	[edx]
	; Enable protected mode
	mov	eax, cr0
	or	eax, CR0_PE_BIT
	mov	cr0, eax
	; Calculate and fill in protected mode far address of start32
	mov	eax, ebx
	add	eax, start32
	xor	edx, edx
	mov	dx, sp
	mov	[edx], eax
	mov	[edx+4], word CS32_SEL
	; Indirect far call to start32 so CS is reloaded
	mov	eax, ebx
	call	dword far [edx]
	; Returned to real mode with segment registers already restored
	sti

	add	sp, 6
	pop	ebx
	ret


[bits 32]
; Far call CS32_SEL:linear_address(start32) when entering protected mode
; Argument: eax = linear_address(.text section)
start32:
	push	ebx
	push	esi
	push	edi
	sub	esp, 6

	; Save argument: linear_address(.text section)
	mov	ebx, eax
	; Reload data/stack segment descriptors
	mov	ax, DS32_SEL
	mov	ds, ax
	mov	ss, ax
	add	esp, ebx
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	; Copy 32-bit code to 1MB
	mov	esi, ebx
	add	esi, begin_section_text32_in_section_text
	mov	ecx, len_section_text32
	mov	edi, virtual_begin_section_text32
	rep	movsb
	; Call main32, ignoring any return value
	mov	eax, main32
	call	eax
	; Return to real mode
	; Reload data/stack segment descriptors (part 1: switch to 16-bit in protected mode)
	mov	ax, DS16_SEL
	mov	ds, ax
	mov	ss, ax
	sub	esp, ebx
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	; Reload CS (part 1: switch to 16-bit in protected mode)
	call	dword .push_ip
.push_ip:
	pop	eax
	add	eax, .cs_is_now_16_bits - .push_ip
	sub	eax, ebx	; Make address relative to CS16_SEL
	mov	[esp], eax
	mov	[esp+4], CS16_SEL
	jmp	dword far [esp]
[bits 16]
.cs_is_now_16_bits:
	; Disable protected mode
	mov	eax, cr0
	and	eax, ~CR0_PE_BIT
	mov	cr0, eax
	; Reload data/stack segment selectors (part 2: switch back to real mode segment selectors)
	mov	eax, ebx
	shr	eax, 4
	mov	ds, ax
	mov	ss, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	; Reload CS (part 2: switch back to real mode segment selector)

	add	esp, 6
	pop	edi
	pop	esi
	pop	ebx
	retfd


load_hardware_cursor_position_16:
	; Load high byte of cursor position
	mov	dx, CURSOR_POS_INDEX_PORT
	mov	al, CURSOR_POS_INDEX_HIGH
	out	dx, al
	inc	dx
	in	al, dx
	mov	ah, al
	dec	dx
	; Load low byte of cursor position
	mov	al, CURSOR_POS_INDEX_LOW
	out	dx, al
	inc	dx
	in	al, dx

	ret


update_bios_cursor_position_16:
	push	bx

	call	load_hardware_cursor_position_16
	mov	bl, 80
	div	bl
	; At this point, al = row, ah = col
	; Call BIOS with row and col in expected argument registers
	mov	dh, al
	mov	dl, ah
	xor	bh, bh
	mov	ah, INT_BIOS_SET_CURSOR_POS_AH
	int	INT_BIOS_SET_CURSOR_POS_INT

	pop	bx
	ret


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


align 8
begin_section_text32_in_section_text:

; 32-bit code loaded and run by the 16-bit code
[bits 32]
virtual_begin_section_text32	equ	0x100000
section .text32 vstart=virtual_begin_section_text32
file_begin_section_text32:


main32:
	call	clear_screen
	mov	eax, HELLO_LEN
	mov	edx, hello
	call	print_string
	mov	eax, THERE_LEN
	mov	edx, there
	call	print_string
	ret


clear_screen:
	push	edi

	; Set the text video buffer to all null chars with style non-bold white on black
	mov	edi, VIDEO_BUFFER
	mov	eax, (TEXT_STYLE_WHITE_ON_BLACK << 24) | (TEXT_STYLE_WHITE_ON_BLACK << 8)
	mov	cx, (NUM_TEXT_CHARS_ON_SCREEN*(1+1)/4)	; (per char: 1 char byte + 1 style byte) / 4 bytes eax
	rep	stosd

	pop	edi
	ret


print_string:
	; eax = string length
	; edx = string contents
	push	esi
	push	edi
	mov	esi, edx

	; Set ecx = edi = cursor position
	mov	ecx, [cursor_position]
	mov	edi, ecx
	; Clamp string length to not go past end of text video buffer
	add	ecx, eax
	xor	edx, edx
	sub	ecx, NUM_TEXT_CHARS_ON_SCREEN
	cmovb	ecx, edx		; Negative -> 0
	sub	eax, ecx
	; Set ecx = cursor position after write
	mov	ecx, edi
	add	ecx, eax
	; Set edi = first byte to write to
	shl	edi, 1
	add	edi, VIDEO_BUFFER
	; Write characters with style non-bold white on black
	mov	dh, TEXT_STYLE_WHITE_ON_BLACK
.loop:
	test	eax, eax
	jz	.loop_done
	; Write character
	mov	dl, [esi]
	mov	[edi], dx
	; Increment & loop
	dec	eax
	inc	esi
	add	edi, 2
	jmp	.loop
.loop_done:
	; Move cursor
	mov	[cursor_position], ecx
	call	update_hardware_cursor_position

	pop	edi
	pop	esi
	ret


update_hardware_cursor_position:
	mov	ecx, [cursor_position]
	; Set high byte of cursor position
	mov	dx, CURSOR_POS_INDEX_PORT
	mov	al, CURSOR_POS_INDEX_HIGH
	mov	ah, ch
	out	dx, ax
	; Set low byte of cursor position
	mov	al, CURSOR_POS_INDEX_LOW
	mov	ah, cl
	out	dx, ax

	ret


cursor_position		dd	0
hello			db	"Hello"
HELLO_LEN		equ	5
there			db	" there"
THERE_LEN		equ	6


file_end_section_text32:

len_section_text32	equ	file_end_section_text32 - file_begin_section_text32
