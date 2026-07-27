section .text
bits 16
enter_unreal_mode:
	; Give the data segment descriptors 4GB limits. The caller must enable the A20 line.
	mov	ax, unreal_mode_gdt.UNREAL_MODE_DS_SELECTOR
	call	_enter_or_exit_unreal_mode
	ret

exit_unreal_mode:
	; Give the data segment descriptors 64kB limits. The caller must disable the A20 line.
	mov	ax, unreal_mode_gdt.REAL_MODE_DS_SELECTOR
	call	_enter_or_exit_unreal_mode
	ret

_enter_or_exit_unreal_mode:
	; Args:
	;   ax = Segment selector to use from GDT: REAL_MODE_DS_SELECTOR or UNREAL_MODE_DS_SELECTOR
	; Returns: none
	cli
	; Backup segment bases
	push	ds
	push	es
	push	fs
	push	gs
	mov	cx, ss

	; Load GDT
	mov	edx, ds
	shl	edx, 4
	add	edx, unreal_mode_gdt	; edx = Linear address of GDT
	sub	esp, 6
	mov	[esp], word unreal_mode_gdt.size
	mov	[esp+2], edx
	lgdt	[esp]
	add	esp, 6
	; Enter protected mode
	mov	edx, cr0
	or	edx, 1
	mov	cr0, edx
	; Set segment limits
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ss, ax
	; Notice that we never actually reload CS
	; Exit protected mode
	mov	edx, cr0
	and	edx, ~1
	mov	cr0, edx

	; Restore segment bases
	mov	ss, cx
	pop	gs
	pop	fs
	pop	es
	pop	ds
	sti
	ret

align 8
unreal_mode_gdt:
.unused_first_descr				dd	0, 0
.real_mode_data_descr:
	.real_mode_data_descr_limit_0_15	dw	0xffff
	.real_mode_data_descr_base_0_15		dw	0
	.real_mode_data_descr_base_16_23	db	0
	.real_mode_data_descr_bits		dw	GDT_DESCR_IS_ACCESSED_BIT \
						| GDT_DESCR_TYPE_DATA_RW \
						| GDT_DESCR_IS_MEMORY_BIT \
						| GDT_DESCR_IS_PRESENT_BIT
	.real_mode_data_descr_base_24_31	db	0
.unreal_mode_data_descr:
	.unreal_mode_data_descr_limit_0_15	dw	0xffff
	.unreal_mode_data_descr_base_0_15	dw	0
	.unreal_mode_data_descr_base_16_23	db	0
	.unreal_mode_data_descr_bits		dw	GDT_DESCR_IS_ACCESSED_BIT \
						| GDT_DESCR_TYPE_DATA_RW \
						| GDT_DESCR_IS_MEMORY_BIT \
						| GDT_DESCR_IS_PRESENT_BIT \
						| GDT_DESCR_LIMIT_16_19_MASK \
						| GDT_DESCR_GRANULARITY_BIT
	.unreal_mode_data_descr_base_24_31	db	0
.end:
.size				equ	.end - unreal_mode_gdt
.REAL_MODE_DS_SELECTOR		equ	unreal_mode_gdt.real_mode_data_descr - unreal_mode_gdt
.UNREAL_MODE_DS_SELECTOR	equ	unreal_mode_gdt.unreal_mode_data_descr - unreal_mode_gdt
