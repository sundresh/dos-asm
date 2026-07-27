%include "x86bits.inc"

BOOTSTRAP_PML4_OFFSET	equ	0
BOOTSTRAP_PML4_SIZE	equ	0x1000
BOOTSTRAP_PDPT_0_OFFSET	equ	0x1000
BOOTSTRAP_PDPT_0_SIZE	equ	0x1000
BOOTSTRAP_PD_0_OFFSET	equ	0x2000
BOOTSTRAP_PD_0_SIZE	equ	0x1000

section .text
bits 16
load_pml4:
	push	edi

	; Allocate 4kB aligned memory for bootstrap_pml4, bootstrap_pdpt_0 and bootstrap_pd_0
	; edx = linear address of bootstrap_pml4
	; edi = DS-relative address of bootstrap_pml4
	mov	edx, ds
	shl	edx, 4
	mov	eax, edx
	add	edx, end_of_bss + (BOOTSTRAP_PML4_SIZE - 1)
	and	edx, ~(BOOTSTRAP_PML4_SIZE - 1)
	mov	edi, edx
	sub	edi, eax
	; Clear bootstrap_pml4, bootstrap_pdpt_0 and bootstrap_pd_0
	xor	eax, eax
	mov	cx, (BOOTSTRAP_PML4_SIZE + BOOTSTRAP_PDPT_0_SIZE + BOOTSTRAP_PD_0_SIZE)/4
	cld
	rep stosd
	sub	edi, (BOOTSTRAP_PML4_SIZE + BOOTSTRAP_PDPT_0_SIZE + BOOTSTRAP_PD_0_SIZE)
	; Add one entry in bootstrap_pml4 for bootstrap_pdpt_0
	mov	eax, edx
	add	eax, BOOTSTRAP_PDPT_0_OFFSET
	or	eax, PxE_PRESENT_BIT | PxE_WRITABLE_BIT
	mov	[edi + BOOTSTRAP_PML4_OFFSET], eax
	; mov	[edi + BOOTSTRAP_PML4_OFFSET + 4], 0x1000 >> 32		; Already set to 0
	; Add one entry in bootstrap_pdpt_0 for bootstrap_pd_0
	mov	eax, edx
	add	eax, BOOTSTRAP_PD_0_OFFSET
	or	eax, PxE_PRESENT_BIT | PxE_WRITABLE_BIT
	mov	[edi + BOOTSTRAP_PDPT_0_OFFSET], eax
	; mov	[edx + BOOTSTRAP_PDPT_0_OFFSET + 4], 0x2000 >> 32	; Already set to 0
	; Add one entry in bootstrap_pd_0 for the first 2MB
	mov	[edi + BOOTSTRAP_PD_0_OFFSET], dword PxE_PRESENT_BIT | PxE_WRITABLE_BIT | PDE_2MB_PAGE_BIT
	; mov	[edx + BOOTSTRAP_PD_0_OFFSET + 4], dword 0		; Already set to 0
	; Enable PAE and PSE
	mov	eax, cr4
	or	eax, CR4_PAE_BIT | CR4_PSE_BIT
	mov	cr4, eax
	; Load PML4 into CR3
	mov	cr3, edx

.exit:
	pop	edi
	ret
