org 0x100

section .text
bits 16
main:
	mov	ax, (BIOS_A20_AH << 8) | BIOS_A20_ENABLE_AL
	int	BIOS_A20_INT
	call	load_address_range_descriptors
	call	call_main32
	mov	ax, (BIOS_A20_AH << 8) | BIOS_A20_DISABLE_AL
	int	BIOS_A20_INT
	xor	ah, ah
	int	0x21

%include "a20.inc"
%include "main32.asm"
%include "protmode.asm"
%include "smap.asm"
