org 0x100
bits 16

; From https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/15_System_Address_Map_Interfaces/Sys_Address_Map_Interfaces.html
AddressRangeType:
.memory			equ	1
.reserved		equ	2
.acpi			equ	3
.nvs			equ	4
.unusable		equ	5
.disabled		equ	6
.persistentMemory	equ	7

; See https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/15_System_Address_Map_Interfaces/int-15h-e820h---query-system-address-map.html
struc AddressRangeDescriptor
	.baseAddrLow		resd	1
	.baseAddrHigh		resd	1
	.lengthLow		resd	1
	.lengthHigh		resd	1
	.type			resd	1
endstruc

main:
	call	getAddressRangeDescriptors
	mov	ah, 0x09
	mov	dx, crLfString$
	int	0x21
	mov	eax, [numAddressRangeDescriptors]
	call	printHexU32
	mov	eax, addressRangeDescriptors
	call	printHexU32
	xor	ah, ah
	int	0x21

getAddressRangeDescriptors:
	push	eax
	push	ebx
	push	ecx
	push	edx
	push	di

	mov	ebx, 0
.loop:
	mov	di, [numAddressRangeDescriptors]
	cmp	di, MaxNumAddressRangeDescriptors
	ja	.exit
	imul	di, di, AddressRangeDescriptor_size
	add	di, addressRangeDescriptors
	mov	eax, 0xe820
	mov	ecx, 20
	mov	edx, "PAMS"	; "SMAP" needs to be written backwards for NASM to order it correctly
	int	0x15
	jc	.exit
	; Print 64-bit base address
	mov	eax, [di + AddressRangeDescriptor.baseAddrHigh]
	call	printHexU32
	mov	eax, [di + AddressRangeDescriptor.baseAddrLow]
	call	printHexU32
	mov	ah, 0x09
	mov	dx, spaceString$
	int	0x21
	; Print 64-bit length
	mov	eax, [di + AddressRangeDescriptor.lengthHigh]
	call	printHexU32
	mov	eax, [di + AddressRangeDescriptor.lengthLow]
	call	printHexU32
	mov	ah, 0x09
	mov	dx, spaceString$
	int	0x21
	; Print type
	mov	eax, [di + AddressRangeDescriptor.type]
	call	printHexU32
	mov	ah, 0x09
	mov	dx, crLfString$
	int	0x21
	; Continue the loop
	inc	[numAddressRangeDescriptors]
	test	ebx, ebx
	jnz	.loop

.exit:
	pop	di
	pop	edx
	pop	ecx
	pop	ebx
	pop	eax
	ret

printHexU32:
	; eax = number to print
	push	di
	sub	sp, 9

	; Convert nibbles in al to chars
	mov	cx, 8
	xor	edx, edx
	mov	di, sp
.loop:
	rol	eax, 4
	mov	dl, al
	and	dl, 0x0f
	mov	dl, [hexChars + edx]
	mov	[di], dl
	inc	di
	loop	.loop

	mov	byte [esp+8], '$'

	; Print string
	mov	ah, 0x09
	mov	dx, sp
	int	0x21

	add	sp, 9
	pop	di
	ret

hexChars			db	"0123456789abcdef"

MaxNumAddressRangeDescriptors	equ	100

numAddressRangeDescriptors	dd	0
addressRangeDescriptors times MaxNumAddressRangeDescriptors resb AddressRangeDescriptor_size

spaceString$			dd	" $"
crLfString$			dd	`\r\n$`
