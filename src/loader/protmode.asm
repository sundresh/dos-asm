[bits 16]

callMain32:
	push	ebx
	sub	sp, 6
	cli

	; Calculate flat address base of CS
	mov	ebx, cs
	shl	ebx, 4
	; Initialize 16-bit GDT descriptors to use when returning to real mode
	mov	eax, ebx
	shr	eax, 16
	mov	[bootstrapGDT.code16DescriptorBase0to15], bx
	mov	[bootstrapGDT.code16DescriptorBase16to23], al
	mov	eax, ebx
	mov	[bootstrapGDT.data16DescriptorBase0to15], bx
	mov	[bootstrapGDT.data16DescriptorBase16to23], al
	; Load GDT
	mov	eax, ebx
	add	eax, bootstrapGDT
	mov	[esp], word bootstrapGDT.size
	mov	[esp + 2], eax
	lgdt	[esp]
	; TODO: Set up bootstrap page table
	; Enable protected mode
	mov	eax, cr0
	or	eax, 1
	mov	cr0, eax
	; Load data segment descriptors
	mov	ax, bootstrapGDT.Data32Selector
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ss, ax
	; Update stack pointer
	add	esp, ebx
	; Load code segment descriptor
	mov	eax, ebx
	add	eax, .begin32
	mov	[esp], eax
	mov	[esp+4], bootstrapGDT.Code32Selector
	jmp	dword far [esp]
[bits 32]
.begin32:
	; Call main32
	; TODO: call main64 instead, with a bootstrap 4-level page table
	call	main32
	; Restore data segment descriptors
	mov	ax, bootstrapGDT.Data16Selector
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ss, ax
	; Restore stack pointer
	sub	esp, ebx
	; Restore code segment descriptor
	mov	[esp], dword .resume16
	mov	[esp+4], bootstrapGDT.Code16Selector
	jmp	dword far [esp]
[bits 16]
.resume16:
	; Disable protected mode
	mov	eax, cr0
	and	eax, ~1
	mov	cr0, eax
	; Restore data segment selectors
	shr	ebx, 4
	mov	ds, bx
	mov	es, bx
	mov	fs, bx
	mov	gs, bx
	mov	ss, bx
	; Restore code segment selector
	mov	[esp], dword .restoredCS
	mov	[esp+4], bx
	jmp	dword far [esp]
.restoredCS:

	sti
	add	sp, 6
	pop	ebx
	ret

align 8
bootstrapGDT:
; TODO: struc GDTDescriptor
.nullDescriptor		dd	0, 0
.code64Descriptor	dd	0, 0x00a09b00
.data64Descriptor	dd	0, 0x00a09300
.code32Descriptor	dd	0x0000ffff, 0x00cf9b00
.data32Descriptor	dd	0x0000ffff, 0x00cf9300
.code16Descriptor:
	.code16DescriptorLimit		dw	0xffff
	.code16DescriptorBase0to15	dw	0	; Filled in at runtime
	.code16DescriptorBase16to23	db	0	; Filled in at runtime
	.code16DescriptorBitfields	dw	0x009b
	.code16DescriptorBase24to31	db	0
.data16Descriptor:
	.data16DescriptorLimit		dw	0xffff
	.data16DescriptorBase0to15	dw	0	; Filled in at runtime
	.data16DescriptorBase16to23	db	0	; Filled in at runtime
	.data16DescriptorBitfields	dw	0x0093
	.data16DescriptorBase24to31	db	0
.end:
.size			equ	.end - bootstrapGDT
.Code64Selector	equ	.code64Descriptor - bootstrapGDT
.Data64Selector	equ	.data64Descriptor - bootstrapGDT
.Code32Selector	equ	.code32Descriptor - bootstrapGDT
.Data32Selector	equ	.data32Descriptor - bootstrapGDT
.Code16Selector	equ	.code16Descriptor - bootstrapGDT
.Data16Selector	equ	.data16Descriptor - bootstrapGDT
