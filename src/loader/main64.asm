section .text
bits 64
main64:
	; In 64-bit mode, the code below will clear eax and ecx and then return, while in 32-bit
	; mode, it will hang. So if this function returns, we are in 64-bit mode.
	xor	ecx, ecx
	mov	eax, ecx
	; In 32-bit mode, the encoding of `mov rax, rax` instead decodes to `dec eax; mov eax, eax`
	mov	rax, rax
	cmp	eax, ecx
.loop:
	jne	.loop
	ret
