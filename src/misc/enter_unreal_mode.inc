
enter_unreal_mode:
.BIOS_ENABLE_A20_INT	equ	0x15
.BIOS_ENABLE_A20_AX	equ	0x2401
	cli
	; Backup segment bases
	push	ds
	push	es
	push	fs
	push	gs
	mov	bx, ss
	; Enable A20 line
	mov	ax, .BIOS_ENABLE_A20_AX
	int	.BIOS_ENABLE_A20_INT
	; Load GDT
	mov	eax, ds
	shl	eax, 4
	add	eax, unreal_mode_gdt	; eax = Linear address of GDT
	sub	esp, 6
	mov	[esp], word (unreal_mode_gdt.end - unreal_mode_gdt)
	mov	[esp+2], eax
	lgdt	[esp]
	add	esp, 6
	; Enter protected mode
	mov	eax, cr0
	or	eax, 1
	mov	cr0, eax
	; Set segment limits
	mov	ax, UNREAL_MODE_DS_SELECTOR
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ss, ax
	; Notice that we never actually reload CS
	; Exit protected mode
	mov	eax, cr0
	and	eax, ~1
	mov	cr0, eax
	; Restore segment bases
	mov	ss, bx
	pop	gs
	pop	fs
	pop	es
	pop	ds
	sti
	ret

align 8
unreal_mode_gdt:
.unused_first_descr		dd	0, 0
.urm_ds_descr:
.urm_ds_descr_limit		dw	0xffff
.urm_ds_descr_base_15_0		dw	0
.urm_ds_descr_base_23_16	db	0
.urm_ds_descr_bits		dw	0x8f93
.urm_ds_descr_base_31_24	db	0
.end:

UNREAL_MODE_DS_SELECTOR		equ	unreal_mode_gdt.urm_ds_descr - unreal_mode_gdt
