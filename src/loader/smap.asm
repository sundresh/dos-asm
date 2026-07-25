[bits 16]

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

loadAddressRangeDescriptors:
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
	mov	edx, "PAMS"	; "SMAP" written backwards
	int	0x15
	jc	.exit
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

MaxNumAddressRangeDescriptors	equ	100

numAddressRangeDescriptors	dd	0
addressRangeDescriptors times MaxNumAddressRangeDescriptors resb AddressRangeDescriptor_size
