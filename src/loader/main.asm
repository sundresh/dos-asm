org 0x100

section .text
bits 16
main:
	mov	ax, (BIOS_A20_AH << 8) | BIOS_A20_ENABLE_AL
	int	BIOS_A20_INT
	call	load_address_range_descriptors
	call	call_main64
	mov	ax, (BIOS_A20_AH << 8) | BIOS_A20_DISABLE_AL
	int	BIOS_A20_INT
	xor	ah, ah
	int	0x21

%include "a20.inc"
%include "smap.asm"
%include "longmode.asm"
%include "paging.asm"
%include "main64.asm"

section .bss
end_of_bss:	; paging.asm dynamically locates data at a 4kB-aligned address after .bss
