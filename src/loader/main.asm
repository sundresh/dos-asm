org 0x100

section .text
bits 16
main:
	; Enable the A20 address line
	mov	ax, (BIOS_A20_AH << 8) | BIOS_A20_ENABLE_AL
	int	BIOS_A20_INT
	; Load address_range_descriptors
	call	load_address_range_descriptors
	; Load file
	call	load_file_on_cmdline_at_1MB
	; Call main64 with num_address_range_descriptors and address_range_descriptors as args.
	call	call_main64
	; Disable the A20 address line
	mov	ax, (BIOS_A20_AH << 8) | BIOS_A20_DISABLE_AL
	int	BIOS_A20_INT
	xor	ah, ah
	int	0x21

main64	equ	file_contents_buf

%include "a20.inc"
%include "unreal_mode.asm"
%include "cli_args.asm"
%include "loadhigh.asm"
%include "smap.asm"
%include "longmode.asm"
%include "paging.asm"

section .bss
end_of_bss:	; paging.asm dynamically locates data at a 4kB-aligned address after .bss
