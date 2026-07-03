org 0x100

start:
	call	enter_unreal_mode
	; The instruction below would hang in standard real mode due to a General Protection Fault
	; (interrupt 0x0B) calling the IRQ3 16-bit PC interrupt handler, which returns back to this
	; instruction (not the instruction after it, as with a non-fault interrupt), which again
	; results in a GPF, and so on.
	mov	eax, [dword blah + 0x100000]
	call	exit_unreal_mode
.exit:
	mov	ah, 0x00
	int	0x21

blah	dd	0x12345678

%include "unreal_mode.inc"
