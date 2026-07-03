enter_unreal_mode:
	mov	al, _enter_or_exit_unreal_mode.BIOS_A20_ENABLE_AL
	mov	dx, UNREAL_MODE_DS_SELECTOR
	call	_enter_or_exit_unreal_mode
	ret

exit_unreal_mode:
	mov	al, _enter_or_exit_unreal_mode.BIOS_A20_DISABLE_AL
	mov	dx, REAL_MODE_DS_SELECTOR
	call	_enter_or_exit_unreal_mode
	ret

_enter_or_exit_unreal_mode:
	; Args:
	;   al = 1 to enable A20 line, 2 to disable A20 line
	;   dx = Segment selector to use from GDT: REAL_MODE_DS_SELECTOR or UNREAL_MODE_DS_SELECTOR
.BIOS_A20_INT		equ	0x15
.BIOS_A20_AH		equ	0x24
.BIOS_A20_ENABLE_AL	equ	0x01
.BIOS_A20_DISABLE_AL	equ	0x02
	cli
	; Backup segment bases
	push	ds
	push	es
	push	fs
	push	gs
	mov	cx, ss
	; Enable A20 line
	mov	ah, .BIOS_A20_AH
	int	.BIOS_A20_INT
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
	mov	ds, dx
	mov	es, dx
	mov	fs, dx
	mov	gs, dx
	mov	ss, dx
	; Notice that we never actually reload CS
	; Exit protected mode
	mov	eax, cr0
	and	eax, ~1
	mov	cr0, eax
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
.unused_first_descr		dd	0, 0
.rm_ds_descr:			dd	0x0000ffff, 0x00009300
.urm_ds_descr:			dd	0x0000ffff, 0x008f9300
.end:

REAL_MODE_DS_SELECTOR		equ	unreal_mode_gdt.rm_ds_descr - unreal_mode_gdt
UNREAL_MODE_DS_SELECTOR		equ	unreal_mode_gdt.urm_ds_descr - unreal_mode_gdt
