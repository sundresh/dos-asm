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
KEYBOARD_SCANCODE_PORT		equ 0x60

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
	; Fill in gdt.rm_cs16_descr and gdt.rm_ds16_descr, used when returning to real mode later
	mov	[gdt.rm_cs16_descr_base_15_0], bx
	mov	[gdt.rm_ds16_descr_base_15_0], bx
	mov	ecx, ebx
	shr	ecx, 16
	mov	[gdt.rm_cs16_descr_base_23_16], cl
	mov	[gdt.rm_ds16_descr_base_23_16], cl
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
	mov	[edx+4], word SYS_CS32_SEL
	; Indirect far call to start32 so CS is reloaded
	mov	eax, ebx
	call	dword far [edx]
	; Returned to real mode with segment registers already restored
	sti

	add	sp, 6
	pop	ebx
	ret


[bits 32]
; Far call SYS_CS32_SEL:linear_address(start32) when entering protected mode
; Argument: eax = linear_address(.text section)
start32:
	push	ebx
	push	esi
	push	edi
	sub	esp, 6

	; Save argument: linear_address(.text section)
	mov	ebx, eax
	; Reload data/stack segment descriptors
	mov	ax, SYS_DS32_SEL
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
	mov	edi, base_of_section_text32
	rep	movsb
	; Call main32, ignoring any return value
	mov	eax, main32
	call	eax
	; Return to real mode
	; Switch from IDT to IVT
	mov	[esp], word 0x03ff
	mov	[esp+2], dword 0
	lidt	[esp]
	; Reload data/stack segment descriptors (part 1: switch to 16-bit in protected mode)
	mov	ax, RM_DS16_SEL
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
	sub	eax, ebx	; Make address relative to RM_CS16_SEL
	mov	[esp], eax
	mov	[esp+4], RM_CS16_SEL
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
.sys_cs32_descr		dd	0x0000ffff, 0x00cf9b00
.sys_ds32_descr		dd	0x0000ffff, 0x00cf9300
.rm_cs16_descr:
.rm_cs16_descr_limit	dw	0xffff
.rm_cs16_descr_base_15_0	dw	0	; Fill this in at runtime
.rm_cs16_descr_base_23_16	db	0	; Fill this in at runtime
.rm_cs16_descr_bits	dw	0x009b
.rm_cs16_descr_base_31_24	db	0
.rm_ds16_descr:
.rm_ds16_descr_limit	dw	0xffff
.rm_ds16_descr_base_15_0	dw	0	; Fill this in at runtime
.rm_ds16_descr_base_23_16	db	0	; Fill this in at runtime
.rm_ds16_descr_bits	dw	0x0093
.rm_ds16_descr_base_31_24	db	0
.end:

SYS_CS32_SEL		equ	gdt.sys_cs32_descr - gdt
SYS_DS32_SEL		equ	gdt.sys_ds32_descr - gdt
RM_CS16_SEL		equ	gdt.rm_cs16_descr - gdt
RM_DS16_SEL		equ	gdt.rm_ds16_descr - gdt


align 8
begin_section_text32_in_section_text:

; 32-bit code loaded and run by the 16-bit code
[bits 32]
base_of_section_text32	equ	0x100000
section .text32 vstart=base_of_section_text32


main32:
	sub	esp, 6

	mov	[esp], word (idt.end - idt)
	mov	[esp+2], dword idt
	; TODO: reprogram PIC IRQs to not conflict with CPU exceptions
	lidt	[esp]
	sti

	call	clear_screen
	mov	eax, hello_str.len
	mov	edx, hello_str
	call	print_string
	mov	eax, there_str.len
	mov	edx, there_str
	call	print_string
	call	move_cursor_to_next_line
	; Wait for two scancodes: release of enter key + press of another key.
.loop1:
	cmp	byte [last_key_scancode], 0
	je	.loop1
	mov	[last_key_scancode], 0
.loop2:
	cmp	byte [last_key_scancode], 0
	je	.loop2
	mov	[last_key_scancode], 0

	cli
	add	esp, 6
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


print_dec_u32:
	; eax = number to print

	push	ebx
	; Start ebx at the end of the string space
	mov	ebx, esp
	sub	esp, 10
	; Fill in characters of the string from least to most significant
	mov	ecx, 10
.loop:
	xor	edx, edx
	div	ecx
	add	dl, '0'
	dec	ebx
	mov	[ebx], dl
	test	eax, eax
	jnz	.loop
	; Print string
	mov	eax, esp
	add	eax, 10
	sub	eax, ebx
	mov	edx, ebx
	call	print_string

	add	esp, 10
	pop	ebx
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


; NMI-safe iret macro: If another ISR runs while handling an NMI, we don't want to run iret,
; because it unconditionally unmasks NMIs. So we emulate iret with popfd + ret in that case.
; The way we check that we're handling an NMI is:
; 1. [handling_nmi] is nonzero, and
; 2. The return CS on the stack is the current privileged CS
%macro nmi_safe_iret 0
	; Real iret unless handling_nmi
	cmp	[handling_nmi], 0
	jne	%%emulate_iret1
	iretd
%%emulate_iret1:
	; Emulate iret unless return CS differs from current CS
	push	eax
	mov	ax, cs
	cmp	ax, [esp+8]	; See "From" stack layout below
	je	%%emulate_iret2
	pop	eax
	iretd
%%emulate_iret2:
	; Emulate iret by rearranging the stack and running popfd + ret
	;             From:           To:
	;   ESP+12 -> [ EFLAGS: 32 ]  [ CS    : 32 ]
	;   ESP+8  -> [ CS    : 32 ]  [ EIP   : 32 ]
	;   ESP+4  -> [ EIP   : 32 ]  [ EFLAGS: 32 ]
	;   ESP    -> [ EAX   : 32 ]  [ EAX   : 32 ]
	mov	eax, [esp+12]
	xchg	eax, [esp+4]
	xchg	eax, [esp+8]
	mov	[esp+12], eax
	pop	eax
	popfd
	retfd
%endmacro


nmi_isr:
	mov	[handling_nmi], 1
	mov	[handling_nmi], 0
	; No need to use nmi_safe_iret because NMIs shouldn't nest
	iretd


timer_isr:
	push	eax

	; TODO: Check for spurious interrupts
	mov	al, 0x20
	;out	0xa0, al	; Re-enable the secondary programmable interrupt controller
	out	0x20, al	; Re-enable the primary programmable interrupt controller

	pop	eax
	nmi_safe_iret


keyboard_isr:
	pushad

	; Save the scancode
	in	al, KEYBOARD_SCANCODE_PORT
	mov	byte [last_key_scancode], al
	; Print out the scancode: "key ###"
	xor	ebx, ebx
	mov	bl, al
	mov	eax, key_space_str.len
	mov	edx, key_space_str
	call	print_string
	mov	eax, ebx
	call	print_dec_u32
	call	move_cursor_to_next_line
	; TODO: Check for spurious interrupts
	mov	al, 0x20
	;out	0xa0, al	; Re-enable the secondary programmable interrupt controller
	out	0x20, al	; Re-enable the primary programmable interrupt controller

	popad
	nmi_safe_iret


generic_isr:
	; Stack args: 1 byte interrupt number
	pushad

	mov	eax, int_space_str.len
	mov	edx, int_space_str
	call	print_string
	xor	eax, eax
	mov	ax, [esp + 8*4]
	call	print_dec_u32
	call	move_cursor_to_next_line

	popad
	add	esp, 2
	nmi_safe_iret


generic_isr_with_error_code:
	; Stack args (in address order): byte interrupt number, word CPU error code
	pushad

	mov	eax, int_space_str.len
	mov	edx, int_space_str
	call	print_string
	xor	eax, eax
	mov	ax, [esp + 8*4]
	call	print_dec_u32
	call	move_cursor_to_next_line

	popad
	add	esp, 2+4
	nmi_safe_iret


; Interrupt service routines are called by interrupts
interrupt_service_routines:
.begin:
%assign i 0
%rep 256
	; TODO: Reconfigure PIC so the timer interrupt doesn't conflict with #DF Double Fault
	%if (i = 8) || (i = 10) || (i = 11) || (i = 12) || (i = 13) || (i = 14) || (i = 17) || (i = 18) || (i = 21)
		push	word i
		jmp	generic_isr_with_error_code
	%else
		push	word i
		jmp	generic_isr
	%endif
	%assign i i+1
%endrep
.end:

; Address in memory of the first interrupt service routine
isr_start	equ	interrupt_service_routines - $$ + base_of_section_text32
; Number of bytes between the start addresses of if each ISR and the one following it
isr_stride	equ	(interrupt_service_routines.end - interrupt_service_routines.begin)/256


%macro idt_entry 1
	; TODO: Define a struc and instantiate it here.
	dw	%1 & 0xffff
	dw	SYS_CS32_SEL
	dw	0x8e00
	dw	%1 >> 16
%endmacro


; Interrupt descriptor table definition
idt:
%assign i 0
%rep 256
	; TODO: Reconfigure PIC so the timer interrupt doesn't conflict with #DF Double Fault
	%if i = 2
		idt_entry	nmi_isr - $$ + base_of_section_text32
	%elif i = 8
		idt_entry	timer_isr - $$ + base_of_section_text32
	%elif i = 9
		idt_entry	keyboard_isr - $$ + base_of_section_text32
	%else
		idt_entry	isr_start + i * isr_stride
	%endif
	%assign i i+1
%endrep
.end:


handling_nmi		dw	0
cursor_position		dd	0
last_key_scancode	db	0
hello_str		db	"Hello"
.len			equ	5
there_str		db	" there"
.len			equ	6
int_space_str		db	"int "
.len			equ	4
key_space_str		db	"key "
.len			equ	4


end_section_text32:

len_section_text32	equ	end_section_text32 - $$
