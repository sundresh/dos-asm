[org 0x100]
[bits 16]

main:
	call	loadAddressRangeDescriptors
	call	callMain32
	xor	ah, ah
	int	0x21

%include "smap.asm"
%include "protmode.asm"
%include "main32.asm"
