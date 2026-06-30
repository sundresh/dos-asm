; Enter protected mode and output "Hello there" via direct hardware access, move the hardware
; cursor, wait for a keystroke, then update the BIOS cursor position and exit to real mode DOS.

CR0_PE_BIT			equ 1 << 0
CR0_WP_BIT			equ 1 << 16
CR0_PG_BIT			equ 1 << 31
CR3_32_PWT_BIT			equ 1 << 3	; PWT = Page Write Through
CR3_32_PCD_BIT			equ 1 << 4	; PCD = Page Cache Disabled
CR3_32_PDB_MASK			equ 0xfffff000	; PDB = Page Directory Base
CR3_PAE_PDPTB_MASK		equ 0xffffffe0	; PDPTB = Page Directory Pointer Table Base
CR4_TSD_BIT			equ 1 << 2	; TSD = Time Stamp Disable (restricts RDTSC to PL 0)
CR4_PSE_BIT			equ 1 << 4	; PSE = Page Size Extension
CR4_PAE_BIT			equ 1 << 5	; PAE = Physical Address Extension
CR4_PGE_BIT			equ 1 << 7	; PGE = Page Global Enable

; Page Directory Pointer Table Entry bits
; Each entry is 64 bits = 2 dwords, which we refer to as PDPTE_D0 and PDPTE_D1
PDPTE_D0_PRESENT_BIT		equ 1 << 0
PDPTE_D0_PWT_BIT		equ 1 << 3	; PWT = Page Write Through
PDPTE_D0_PCD_BIT		equ 1 << 4	; PCD = Page Cache Disabled
PDPTE_D0_LOW_ADDR_MASK		equ 0xfffff000	; And with mask then shift to get low bits of addr
PDPTE_D0_LOW_ADDR_SHIFT		equ 0
PDPTE_D1_HIGH_ADDR_MASK		equ 0xffffffff	; And with mask then shift to get high bits of addr
PDPTE_D1_HIGH_ADDR_SHIFT	equ 32

; Page [Directory or Table] Entry bits
PxE_PRESENT_BIT			equ 1 << 0
PxE_WRITABLE_BIT		equ 1 << 1
PxE_USER_BIT			equ 1 << 2
PxE_PWT_BIT			equ 1 << 3	; PWT = Page Write Through
PxE_PCD_BIT			equ 1 << 4	; PCD = Page Cache Disabled
PxE_ACCESSED_BIT		equ 1 << 5
PxE_PAGE_DIRTY_BIT		equ 1 << 6	; Only meaningful when the entry specifies a page
PxE_PAGE_IS_GLOBAL_BIT		equ 1 << 8	; Only meaningful when the entry specifies a page

; Page Directory Entry bits
PDE_IS_4MB_PAGE_BIT		equ 1 << 7
PDE_PAGE_TABLE_ADDR_MASK	equ 0xfffff000	; And with mask to get addr
PDE_4MB_PAGE_LOW_ADDR_MASK	equ 0xffc00000	; And with mask then shift to get low bits of addr
PDE_4MB_PAGE_LOW_ADDR_SHIFT	equ 0
PDE_4MB_PAGE_HIGH_ADDR_MASK	equ 0x001fe000	; And with mask then shift to get high bits of addr
PDE_4MB_PAGE_HIGH_ADDR_SHIFT	equ 19

; Page Table Entry bits
PTE_PAGE_ADDR_MASK		equ 0xfffff000	; And with mask to get addr

MIN_USER_PAGE_ADDR		equ page_table + 4096
MAX_USER_PAGE_ADDR		equ 0x001fffff

VIDEO_BUFFER			equ 0xb8000
TEXT_STYLE_WHITE_ON_BLACK	equ 0x07
NUM_TEXT_CHARS_ON_SCREEN	equ 80 * 25
CURSOR_POS_INDEX_PORT		equ 0x3d4
CURSOR_POS_VALUE_PORT		equ CURSOR_POS_INDEX_PORT + 1
CURSOR_POS_INDEX_HIGH		equ 0x0e
CURSOR_POS_INDEX_LOW		equ 0x0f
KEYBOARD_SCANCODE_PORT		equ 0x60
; Classic 8259 programmable interrupt controllers, not modern APIC/IOAPIC
PIC1_COMMAND_PORT		equ 0x20
PIC1_DATA_PORT			equ 0x21
PIC2_COMMAND_PORT		equ 0xa0
PIC2_DATA_PORT			equ 0xa1
PIC_EOI_COMMAND			equ 0x20
PIC_ICW1_OPT_ICW4_COMMAND	equ 0x01	; Set to indicate ICW4 will be sent
PIC_ICW1_INIT_COMMAND		equ 0x10	; Must be set in ICW1; other bits above are optional
PIC_ICW4_OPT_8086_MODE_COMMAND	equ 0x01	; Set for 8086 mode, clear for 8080 mode
PIC1_IRQ_CASCADE_TO_PIC2	equ 2
IO_WAIT_PORT			equ 0x80	; Send a byte to this port to wait for another device to catch up

BIOS_ENABLE_A20_INT		equ 0x15
BIOS_ENABLE_A20_AX		equ 0x2401
BIOS_DISABLE_A20_INT		equ 0x15
BIOS_DISABLE_A20_AX		equ 0x2400
BIOS_SET_CURSOR_POS_INT		equ 0x10
BIOS_SET_CURSOR_POS_AH		equ 0x02
DOS_EXIT_INT			equ 0x21
DOS_EXIT_AH			equ 0x00

PM_TIMER_INT			equ 0x20
PM_KEYBOARD_INT			equ 0x21


; 16-bit code run by DOS as a .COM file
[bits 16]
section .text vstart=0x100


start16:
	mov	ax, BIOS_ENABLE_A20_AX
	int	BIOS_ENABLE_A20_INT
	call	call_main32_in_protected_mode
	call	update_bios_cursor_position_16
	mov	ax, BIOS_DISABLE_A20_AX
	int	BIOS_DISABLE_A20_INT
	mov	ah, DOS_EXIT_AH
	int	DOS_EXIT_INT


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
	; Disable protected mode and paging
	mov	eax, cr0
	and	eax, ~(CR0_PG_BIT | CR0_WP_BIT | CR0_PE_BIT)
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
	mov	ah, BIOS_SET_CURSOR_POS_AH
	int	BIOS_SET_CURSOR_POS_INT

	pop	bx
	ret


align 8
gdt:
.unused_first_descr	dd	0, 0
.sys_cs32_descr		dd	0x0000ffff, 0x00cf9b00
.sys_ds32_descr		dd	0x0000ffff, 0x00cf9300
.usr_cs32_descr		dd	0x0000ffff, 0x00cffb00
.usr_ds32_descr		dd	0x0000ffff, 0x00cff300
.tss32_descr:
.tss32_descr_limit	dw	0x0063	; Minimum size, no I/O map
.tss32_descr_base_15_0	dw	0	; Fill this in at runtime
.tss32_descr_base_23_16	db	0	; Fill this in at runtime
.tss32_descr_bits	dw	0x0089
.tss32_descr_base_31_24	db	0
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
USR_CS32_SEL		equ	(gdt.usr_cs32_descr - gdt) | 3
USR_DS32_SEL		equ	(gdt.usr_ds32_descr - gdt) | 3
TSS32_SEL		equ	gdt.tss32_descr - gdt
RM_CS16_SEL		equ	gdt.rm_cs16_descr - gdt
RM_DS16_SEL		equ	gdt.rm_ds16_descr - gdt


align 32
begin_section_text32_in_section_text:

; 32-bit code loaded and run by the 16-bit code
[bits 32]
base_of_section_text32	equ	0x100000
section .text32 vstart=base_of_section_text32


main32:
	sub	esp, 6

	call	reprogram_pics_for_protected_mode

	mov	[esp], word (idt.end - idt)
	mov	[esp+2], dword idt
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
	call	enable_paging
	; Call user code
	call	run_user_process
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
	call	reprogram_pics_for_real_mode
	call	print_partial_cpu_state

	add	esp, 6
	ret


reprogram_pics_for_protected_mode:
	mov	eax, 0x20
	mov	edx, 0x28
	call	reprogram_pics_offsets
	ret


reprogram_pics_for_real_mode:
	mov	eax, 0x08
	mov	edx, 0x70
	call	reprogram_pics_offsets
	ret


%macro outk 2
	mov	al, %2
	out	%1, al
%endmacro


%macro io_wait 0
	outk	IO_WAIT_PORT, 0
%endmacro


%macro outkw 2
	outk	%1, %2
	io_wait
%endmacro


reprogram_pics_offsets:
	; eax = new interrupt base for PIC1 IRQs
	; edx = new interrupt base for PIC2 IRQs
	push	ebx

	mov	ebx, eax
	mov	ecx, edx

	; Reinitialize both PICs
	outkw	PIC1_COMMAND_PORT, PIC_ICW1_INIT_COMMAND | PIC_ICW1_OPT_ICW4_COMMAND
	outkw	PIC2_COMMAND_PORT, PIC_ICW1_INIT_COMMAND | PIC_ICW1_OPT_ICW4_COMMAND
	outkw	PIC1_DATA_PORT, bl
	outkw	PIC2_DATA_PORT, cl
	outkw	PIC1_DATA_PORT, 1 << PIC1_IRQ_CASCADE_TO_PIC2
	outkw	PIC2_DATA_PORT, PIC1_IRQ_CASCADE_TO_PIC2
	outkw	PIC1_DATA_PORT, PIC_ICW4_OPT_8086_MODE_COMMAND
	outkw	PIC2_DATA_PORT, PIC_ICW4_OPT_8086_MODE_COMMAND
	; Unmask both PICs
	outkw	PIC1_DATA_PORT, 0
	outkw	PIC2_DATA_PORT, 0

	pop	ebx
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


print_partial_cpu_state:
	; Print "CS=...,"
	mov	eax, cs_eq_str.len
	mov	edx, cs_eq_str
	call	print_string
	mov	eax, cs
	call	print_dec_u32
	mov	eax, comma_str.len
	mov	edx, comma_str
	call	print_string
	; Print "DS=...,"
	mov	eax, ds_eq_str.len
	mov	edx, ds_eq_str
	call	print_string
	mov	eax, ds
	call	print_dec_u32
	mov	eax, comma_str.len
	mov	edx, comma_str
	call	print_string
	; Print "SS=...,"
	mov	eax, ss_eq_str.len
	mov	edx, ss_eq_str
	call	print_string
	mov	eax, ss
	call	print_dec_u32
	mov	eax, comma_str.len
	mov	edx, comma_str
	call	print_string
	; Print "ESP=...,"
	mov	eax, esp_eq_str.len
	mov	edx, esp_eq_str
	call	print_string
	mov	eax, esp
	call	print_dec_u32
	call	move_cursor_to_next_line

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


print_char:
	; al = character to print
	push	bx

	; Set ecx to point to the first char to write to
	mov	ecx, [cursor_position]
	shl	ecx, 1
	add	ecx, VIDEO_BUFFER
	; Write character with style non-bold white on black
	mov	ah, TEXT_STYLE_WHITE_ON_BLACK
	mov	[ecx], ax
	; Move cursor
	inc	[cursor_position]
	call	update_hardware_cursor_position

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


%include "hexdump32.asm"


enable_paging:
	push	edi

	; Initialize page directory
	; - Clear page directory
	mov	edi, page_directory
	xor	eax, eax
	mov	ecx, 1024
	rep	stosd
	; - Write entry for page table.
	;   Important: user bit must be set if any pages in the page table
	;   are user-accessible. It does not automatically make all pages
	;   user-accessible.
	mov	dword [page_directory], (page_table & PDE_PAGE_TABLE_ADDR_MASK) | PxE_USER_BIT | PxE_WRITABLE_BIT | PxE_PRESENT_BIT
	; Initialize page table
	; - Clear page table
	xor	eax, eax
	mov	edi, page_table
	mov	ecx, 1024
	rep	stosd
	; - Write entries for pages 0 through the page table itself (the last page we use)
	xor	edi, edi
.loop:
	mov	eax, edi
	shl	eax, 9
	or	eax, PxE_PAGE_IS_GLOBAL_BIT | PxE_WRITABLE_BIT | PxE_PRESENT_BIT
	mov	dword [page_table+edi], eax
	mov	dword [page_table+edi+4], 0
	add	edi, 8
	cmp	edi, (page_table >> 9)
	jbe	.loop
.done:
	; Debug log paging data structures
	; - Page Directory Pointer Table
	mov	eax, page_dir_ptr_tbl_str.len
	mov	edx, page_dir_ptr_tbl_str
	call	print_string
	call	move_cursor_to_next_line
	mov	eax, 32
	mov	edx, page_directory_pointer_table
	call	hexdump
	; - Page Directory
	mov	eax, page_directory_str.len
	mov	edx, page_directory_str
	call	print_string
	call	move_cursor_to_next_line
	mov	eax, 64
	mov	edx, page_directory
	call	hexdump
	; - Page Table
	mov	eax, page_table_str.len
	mov	edx, page_table_str
	call	print_string
	call	move_cursor_to_next_line
	mov	eax, 64
	mov	edx, page_table
	call	hexdump
	mov	eax, ellipsis_str.len
	mov	edx, ellipsis_str
	call	print_string
	call	move_cursor_to_next_line
	mov	eax, 64
	mov	edx, page_table+2048
	call	hexdump
	call	move_cursor_to_next_line
	; Enable PAE and PGE
	mov	eax, cr4
	or	eax, CR4_PSE_BIT | CR4_PGE_BIT | CR4_PAE_BIT
	mov	cr4, eax
	; Load PDPT into CR3, which then caches the four PDPTEs
	mov	eax, page_directory_pointer_table
	mov	cr3, eax
	; Enable paging
	mov	eax, cr0
	or	eax, CR0_PG_BIT | CR0_WP_BIT
	mov	cr0, eax

	pop	edi
	ret


run_user_process:
	pusha
	push	ds
	push	es
	push	fs
	push	gs
	sub	esp, 6

	; Setup TSS
	mov	[tss.esp0], esp
	mov	[tss.ss0], SYS_DS32_SEL
	; Setup TSS descriptor in GDT
	sgdt	[esp]		; Stores [limit: 16 bits][base: 32 bits] to stack
	mov	eax, [esp+2]	; eax = GDT base
	mov	[eax + gdt.tss32_descr_base_15_0 - gdt], word (tss_addr & 0xffff)
	mov	[eax + gdt.tss32_descr_base_23_16 - gdt], byte ((tss_addr >> 16) & 0xff)
	; Load TSS
	mov	ax, TSS32_SEL
	ltr	ax
	; Copy user code to first user page
	mov	esi, start_user_code
	mov	edi, MIN_USER_PAGE_ADDR
	mov	ecx, end_user_code - start_user_code
	rep	movsb
	; Load user DS
	mov	ax, USR_DS32_SEL
	mov	ds, ax
	; Call user code
	push	dword USR_DS32_SEL		; User SS
	push	dword MAX_USER_PAGE_ADDR+1-8	; User SP
	push	dword 0x202			; User eflags
	push	dword USR_CS32_SEL		; User CS
	push	dword MIN_USER_PAGE_ADDR	; User code entrypoint
	iretd
	; System call 1 (exit user code) jumps here
.user_process_exited:

	add	esp, 6
	pop	gs
	pop	fs
	pop	es
	pop	ds
	popa
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
	mov	al, PIC_EOI_COMMAND
	out	PIC1_COMMAND_PORT, al	; Re-enable the primary programmable interrupt controller

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
	mov	al, PIC_EOI_COMMAND
	out	PIC1_COMMAND_PORT, al	; Re-enable the primary programmable interrupt controller

	popad
	nmi_safe_iret


; Currently this page fault ISR just exists to test that when main32 tries to access an unmapped
; page in the first 4MB, we can map the page and continue execution.
page_fault_isr:
	; Stack args (in address order): byte interrupt number, word CPU error code
	pushad
	mov	esi, [esp+4*8+4]
	push	ds

	; Load supervisor DS
	mov	ax, SYS_DS32_SEL
	mov	ds, ax
	; Load page fault address
	mov	ebx, cr2
	; Report page fault
	mov	eax, page_fault_at_str.len
	mov	edx, page_fault_at_str
	call	print_string
	mov	eax, ebx
	call	print_dec_u32
	mov	eax, at_str.len
	mov	edx, at_str
	call	print_string
	mov	eax, esi
	call	print_dec_u32
	call	move_cursor_to_next_line
	; Map page if it's within the first 2MB and either
	; (a) it's the page table or an earlier page and the caller is in supervisor mode, or
	; (b) it's after the page table and the caller is either user or supervisor
	; - Page must be within the first 2MB
	cmp	ebx, 0x200000
	ja	.wont_map
	; - Caller must be in supervisor mode if page is <= page table
	cmp	ebx, MIN_USER_PAGE_ADDR
	jae	.is_user_page
	mov	eax, [esp + 8*4 + 2*4]
	and	eax, 3
	cmp	eax, 0
	jne	.wont_map
	mov	ecx, PxE_PAGE_IS_GLOBAL_BIT | PxE_WRITABLE_BIT | PxE_PRESENT_BIT
	jmp	.map_page
.is_user_page:
	mov	ecx, PxE_PAGE_IS_GLOBAL_BIT | PxE_USER_BIT | PxE_WRITABLE_BIT | PxE_PRESENT_BIT
.map_page:
	; - Direct map the page (physical address = logical address)
	and	ebx, PTE_PAGE_ADDR_MASK
	mov	eax, ebx
	or	eax, ecx
	mov	ecx, ebx
	shr	ecx, 9
	mov	[page_table+ecx], eax
	invlpg	[ebx]
.wont_map:

	pop	ds
	popad
	add	esp, 4
	nmi_safe_iret


system_call_isr:
	pushad

	; Confirm that the system call was from user mode
	mov	ebx, [esp+32+4]		; ebx = caller's CS
	and	ebx, 3
	cmp	ebx, 3
	jne	.error
.dispatch:
	; System call number dispatch from eax
	cmp	eax, 1
	je	.exit
	cmp	eax, 2
	je	.print_string
	jmp	.error
.exit:				; Exit system call
	add	esp, 4*(8 + 5)
	sti
	jmp	run_user_process.user_process_exited
.print_string:			; Print string system call
	; TODO: Check address and length
	mov	eax, ecx
	call	print_string
	call	move_cursor_to_next_line
	popad
	iretd	; Returning to user mode, nmi_safe_iret would just end up as iretd anyway.
.error:		; Error: invalid system call
	mov	esi, eax	; Save system call number
	mov	eax, invalid_syscall_str.len
	mov	edx, invalid_syscall_str
	call	print_string
	mov	eax, esi
	call	print_dec_u32
	mov	eax, from_pl_str.len
	mov	edx, from_pl_str
	call	print_string
	mov	eax, ebx
	call	print_dec_u32
	call	move_cursor_to_next_line
	popad
	nmi_safe_iret


generic_isr:
	; Stack args: 1 byte interrupt number
	pushad

	mov	eax, interrupt_num_str.len
	mov	edx, interrupt_num_str
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

	mov	eax, interrupt_num_str.len
	mov	edx, interrupt_num_str
	call	print_string
	xor	eax, eax
	mov	ax, [esp + 8*4]
	call	print_dec_u32
	mov	eax, with_error_code_str.len
	mov	edx, with_error_code_str
	call	print_string
	mov	eax, [esp + 8*4 + 2]
	call	print_dec_u32
	mov	al, ' '
	call	print_char
	mov	eax, cr2
	call	print_dec_u32
	mov	eax, at_str.len
	mov	edx, at_str
	call	print_string
	mov	eax, [esp + 8*4 + 2 + 4]
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

%macro system_call_idt_entry 1
	; TODO: Define a struc and instantiate it here.
	dw	%1 & 0xffff
	dw	SYS_CS32_SEL
	dw	0xee00
	dw	%1 >> 16
%endmacro


; Interrupt descriptor table definition
idt:
%assign i 0
%rep 256
	%if i = 2
		idt_entry	nmi_isr - $$ + base_of_section_text32
	%elif i = 14
		idt_entry	page_fault_isr - $$ + base_of_section_text32
	%elif i = 0x20
		idt_entry	timer_isr - $$ + base_of_section_text32
	%elif i = 0x21
		idt_entry	keyboard_isr - $$ + base_of_section_text32
	%elif i = 0x80
		system_call_idt_entry	system_call_isr - $$ + base_of_section_text32
	%else
		idt_entry	isr_start + i * isr_stride
	%endif
	%assign i i+1
%endrep
.end:


align 32
page_directory_pointer_table:
.pdpte0			dd	page_directory | PDPTE_D0_PRESENT_BIT, 0
.pdpte1			dd	0, 0
.pdpte2			dd	0, 0
.pdpte3			dd	0, 0


tss:
			dd	0
.esp0			dd	0		; Fill this in at runtime
.ss0			dd	0		; Fill this in at runtime
.esp1			dd	0
.ss1			dd	0
.esp2			dd	0
.ss2			dd	0
times 17		dd	0
			dw	0, 0x64		; No I/O map because it's past the TSS's limit


tss_addr		equ	tss - $$ + base_of_section_text32


%macro dstr 1
			db	%1
.len			equ	%strlen(%1)
%endmacro


handling_nmi		dw	0
cursor_position		dd	0
last_key_scancode	db	0
hello_str		dstr	"Hello"
there_str		dstr	" there"
key_space_str		dstr	"key "
page_fault_at_str	dstr	"Page fault at "
interrupt_num_str	dstr	"Interrupt #"
with_error_code_str	dstr	" with error code "
ellipsis_str		dstr	"..."
page_dir_ptr_tbl_str	dstr	"Page Directory Pointer Table bytes:"
page_directory_str	dstr	"Page Directory bytes:"
page_table_str		dstr	"Page Table bytes:"
invalid_syscall_str	dstr	"Error: Invalid system call #"
from_pl_str		dstr	" from PL "
at_str			dstr	" at "
exiting_str		dstr	"Exiting..."
esp_str			dstr	"ESP: "
cs_eq_str		dstr	"CS="
comma_str		dstr	", "
ds_eq_str		dstr	"DS="
ss_eq_str		dstr	"SS="
esp_eq_str		dstr	"ESP="


; User-mode code embedded in the .text32 section is later copied to user pages and run in user mode.
start_user_code:
user_entry:
	call	user_function
	mov	eax, 1
	int	0x80


user_function:
	mov	eax, 2
	mov	ecx, user_hello_str.len
	mov	edx, user_hello_str - start_user_code + MIN_USER_PAGE_ADDR
	int	0x80
	ret


user_hello_str		dstr	"Hello from user mode"
end_user_code:


end_section_text32:

len_section_text32	equ	end_section_text32 - $$

; Basic paging setup: the page directory + one page table (covering the first 4MB)
page_directory		equ	(end_section_text32 - $$ + base_of_section_text32 + 4095) & (~4095)
page_table		equ	page_directory + 4096
