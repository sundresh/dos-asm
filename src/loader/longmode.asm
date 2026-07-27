%include "x86bits.inc"

section .text
bits 16
call_main64:
	; Enters long mode with a bootstrap GDT and a bootstrap PML4, calls main64 (with interrupts
	; disabled), and then returns to real mode.
	; Args: none
	; Returns: none
	push	ebx
	sub	sp, 6
	cli

	; Calculate flat address base of CS
	mov	ebx, cs
	shl	ebx, 4
	; Initialize 16-bit GDT descriptors to use when returning to real mode
	mov	eax, ebx
	shr	eax, 16
	mov	[bootstrap_gdt.code_16_descr_base_0_15], bx
	mov	[bootstrap_gdt.code_16_descr_base_16_23], al
	mov	[bootstrap_gdt.data_16_descr_base_0_15], bx
	mov	[bootstrap_gdt.data_16_descr_base_16_23], al
	; Load GDT
	mov	eax, ebx
	add	eax, bootstrap_gdt
	mov	[esp], word bootstrap_gdt.size
	mov	[esp + 2], eax
	lgdt	[esp]
	; Load PML4
	call	load_bootstrap_pml4
	; Enable long mode (doesn't go into effect until protected mode & paging are enabled)
	mov	ecx, MSR_IA32_EFER_ID
	rdmsr
	or	eax, MSR_IA32_EFER_LME_BIT
	wrmsr
	; Enable protected mode & paging
	mov	eax, cr0
	or	eax, CR0_PE_BIT | CR0_PG_BIT
	mov	cr0, eax
	; Load 64-bit code segment descriptor
	mov	eax, ebx
	add	eax, .begin64
	mov	[esp], eax
	mov	[esp+4], bootstrap_gdt.CODE_64_SEL
	jmp	dword far [esp]
bits 64
.begin64:
	; Load data segment descriptors
	mov	ax, bootstrap_gdt.DATA_64_SEL
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ss, ax
	; Update stack pointer
	add	esp, ebx
	; Call main64(eax = *num_address_range_descriptors, edx = address_range_descriptors)
	mov	eax, [ebx + num_address_range_descriptors]
	mov	edx, ebx
	add	edx, address_range_descriptors
	mov	rcx, main64
	call	rcx
	; Restore code segment descriptor
	mov	[esp], dword .resume16
	mov	[esp+4], bootstrap_gdt.CODE_16_SEL
	jmp	dword far [esp]
bits 16
.resume16:
	; Restore data segment descriptors
	mov	ax, bootstrap_gdt.DATA_16_SEL
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ss, ax
	; Restore stack pointer
	sub	esp, ebx
	; Disable protected mode
	mov	eax, cr0
	and	eax, ~(CR0_PE_BIT | CR0_PG_BIT)
	mov	cr0, eax
	; Unload reference to PML4
	xor	eax, eax
	mov	cr3, eax
	; Disable long mode (affects what happens the next time paging is enabled)
	mov	ecx, MSR_IA32_EFER_ID
	rdmsr
	and	eax, ~MSR_IA32_EFER_LME_BIT
	wrmsr
	; Clear out GDT
	mov	[esp], word 0
	mov	[esp + 2], dword 0
	lgdt	[esp]
	; Restore data segment selectors
	shr	ebx, 4
	mov	ds, bx
	mov	es, bx
	mov	fs, bx
	mov	gs, bx
	mov	ss, bx
	; Restore code segment selector
	mov	[esp], dword .restored_cs
	mov	[esp+4], bx
	jmp	dword far [esp]
.restored_cs:

	sti
	add	sp, 6
	pop	ebx
	ret

%include "gdt.inc"

section .data
align 8
bootstrap_gdt:
.null_descr		dd	0, 0
.code_64_descr:
	.code_64_descr_limit_0_15	dw	0
	.code_64_descr_base_0_15	dw	0
	.code_64_descr_base_16_23	db	0
	.code_64_descr_bits		dw	GDT_DESCR_IS_ACCESSED_BIT | GDT_DESCR_TYPE_CODE_XO \
						| GDT_DESCR_IS_MEMORY_BIT | GDT_DESCR_IS_PRESENT_BIT \
						| GDT_DESCR_IS_CODE_64_BIT
	.code_64_descr_base_24_31	db	0
.data_64_descr:
	.data_64_descr_limit_0_15	dw	0
	.data_64_descr_base_0_15	dw	0
	.data_64_descr_base_16_23	db	0
	.data_64_descr_bits		dw	GDT_DESCR_IS_ACCESSED_BIT | GDT_DESCR_TYPE_DATA_RW \
						| GDT_DESCR_IS_MEMORY_BIT | GDT_DESCR_IS_PRESENT_BIT
	.data_64_descr_base_24_31	db	0
.code_32_descr:
	.code_32_descr_limit_0_15	dw	0xffff
	.code_32_descr_base_0_15	dw	0
	.code_32_descr_base_16_23	db	0
	.code_32_descr_bits		dw	GDT_DESCR_IS_ACCESSED_BIT | GDT_DESCR_TYPE_CODE_XO \
						| GDT_DESCR_IS_MEMORY_BIT | GDT_DESCR_IS_PRESENT_BIT \
						| GDT_DESCR_LIMIT_16_19_MASK | GDT_DESCR_IS_32_BIT \
						| GDT_DESCR_GRANULARITY_BIT
	.code_32_descr_base_24_31	db	0
.data_32_descr:
	.data_32_descr_limit_0_15	dw	0xffff
	.data_32_descr_base_0_15	dw	0
	.data_32_descr_base_16_23	db	0
	.data_32_descr_bits		dw	GDT_DESCR_IS_ACCESSED_BIT | GDT_DESCR_TYPE_DATA_RW \
						| GDT_DESCR_IS_MEMORY_BIT | GDT_DESCR_IS_PRESENT_BIT \
						| GDT_DESCR_LIMIT_16_19_MASK | GDT_DESCR_IS_32_BIT \
						| GDT_DESCR_GRANULARITY_BIT
	.data_32_descr_base_24_31	db	0
.code_16_descr:
	.code_16_descr_limit_0_15	dw	0xffff
	.code_16_descr_base_0_15	dw	0	; Filled in at runtime
	.code_16_descr_base_16_23	db	0	; Filled in at runtime
	.code_16_descr_bits		dw	GDT_DESCR_IS_ACCESSED_BIT | GDT_DESCR_TYPE_CODE_XO \
						| GDT_DESCR_IS_MEMORY_BIT | GDT_DESCR_IS_PRESENT_BIT
	.code_16_descr_base_24_31	db	0
.data_16_descr:
	.data_16_descr_limit_0_15	dw	0xffff
	.data_16_descr_base_0_15	dw	0	; Filled in at runtime
	.data_16_descr_base_16_23	db	0	; Filled in at runtime
	.data_16_descr_bits		dw	GDT_DESCR_IS_ACCESSED_BIT | GDT_DESCR_TYPE_DATA_RW \
						| GDT_DESCR_IS_MEMORY_BIT | GDT_DESCR_IS_PRESENT_BIT
	.data_16_descr_base_24_31	db	0
.end:
.size			equ	.end - bootstrap_gdt
.CODE_64_SEL		equ	.code_64_descr - bootstrap_gdt
.DATA_64_SEL		equ	.data_64_descr - bootstrap_gdt
.CODE_32_SEL		equ	.code_32_descr - bootstrap_gdt
.DATA_32_SEL		equ	.data_32_descr - bootstrap_gdt
.CODE_16_SEL		equ	.code_16_descr - bootstrap_gdt
.DATA_16_SEL		equ	.data_16_descr - bootstrap_gdt
