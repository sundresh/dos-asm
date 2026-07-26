[bits 16]

; From https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/15_System_Address_Map_Interfaces/Sys_Address_Map_Interfaces.html
ADDRESS_RANGE_TYPE:
.MEMORY			equ	1
.RESERVED		equ	2
.ACPI			equ	3
.NVS			equ	4
.UNUSABLE		equ	5
.DISABLED		equ	6
.PERSISTENT_MEMORY	equ	7

; See https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/15_System_Address_Map_Interfaces/int-15h-e820h---query-system-address-map.html
struc address_range_descriptor
	.base_addr_low		resd	1
	.base_addr_high		resd	1
	.length_low		resd	1
	.length_high		resd	1
	.type			resd	1
endstruc

load_address_range_descriptors:
	push	eax
	push	ebx
	push	ecx
	push	edx
	push	di

	mov	ebx, 0
.loop:
	mov	di, [num_address_range_descriptors]
	cmp	di, MAX_NUM_ADDRESS_RANGE_DESCRIPTORS
	ja	.exit
	imul	di, di, address_range_descriptor_size
	add	di, address_range_descriptors
	mov	eax, 0xe820
	mov	ecx, 20
	mov	edx, "PAMS"	; "SMAP" written backwards
	int	0x15
	jc	.exit
	; Continue the loop
	inc	[num_address_range_descriptors]
	test	ebx, ebx
	jnz	.loop

.exit:
	pop	di
	pop	edx
	pop	ecx
	pop	ebx
	pop	eax
	ret

MAX_NUM_ADDRESS_RANGE_DESCRIPTORS	equ	100

num_address_range_descriptors	dd	0
address_range_descriptors times MAX_NUM_ADDRESS_RANGE_DESCRIPTORS resb address_range_descriptor_size
