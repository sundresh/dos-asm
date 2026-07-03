org 0x100

start:
	call	enter_unreal_mode
	mov	eax, [dword blah + 0x100000]
.exit:
	mov	ah, 0x00
	int	0x21

blah	dd	0x12345678

%include "enter_unreal_mode.inc"
