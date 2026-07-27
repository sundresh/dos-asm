%include "x86bits.inc"

BOOTSTRAP_PML4_OFFSET	equ	0
BOOTSTRAP_PML4_SIZE	equ	0x1000
BOOTSTRAP_PDPT_0_OFFSET	equ	0x1000
BOOTSTRAP_PDPT_0_SIZE	equ	0x1000
BOOTSTRAP_PD_0_OFFSET	equ	0x2000
BOOTSTRAP_PD_0_SIZE	equ	0x1000

section .text
bits 16
load_bootstrap_pml4:
	; Set up a PML4 and downstream paging data structures and configure CR3 and CR4.
	; We configure it to use 2MB pages to identity map the first 1GB.
	; Args: none
	; Returns: none
	push	edi

	; Allocate 4kB aligned memory for bootstrap_pml4, bootstrap_pdpt_0 and bootstrap_pd_0
	; edx = linear address of bootstrap_pml4
	; di = DS-relative address of bootstrap_pml4
	mov	edx, ds
	shl	edx, 4
	mov	eax, edx
	add	edx, end_of_bss + (BOOTSTRAP_PML4_SIZE - 1)
	and	edx, ~(BOOTSTRAP_PML4_SIZE - 1)
	mov	edi, edx
	sub	edi, eax
	; Clear bootstrap_pml4 and bootstrap_pdpt_0 (vs. bootstrap_pd_0 is fully populated below)
	xor	eax, eax
	mov	cx, (BOOTSTRAP_PML4_SIZE + BOOTSTRAP_PDPT_0_SIZE)/4
	cld
	rep stosd
	sub	di, (BOOTSTRAP_PML4_SIZE + BOOTSTRAP_PDPT_0_SIZE)
	; Add one entry in bootstrap_pml4 for bootstrap_pdpt_0
	mov	eax, edx
	add	eax, BOOTSTRAP_PDPT_0_OFFSET
	or	eax, PxE_PRESENT_BIT | PxE_WRITABLE_BIT
	mov	[di + BOOTSTRAP_PML4_OFFSET], eax
	; mov	[di + BOOTSTRAP_PML4_OFFSET + 4], 0x1000 >> 32		; Already set to 0
	; Add one entry in bootstrap_pdpt_0 for bootstrap_pd_0
	mov	eax, edx
	add	eax, BOOTSTRAP_PD_0_OFFSET
	or	eax, PxE_PRESENT_BIT | PxE_WRITABLE_BIT
	mov	[di + BOOTSTRAP_PDPT_0_OFFSET], eax
	; mov	[di + BOOTSTRAP_PDPT_0_OFFSET + 4], 0x2000 >> 32	; Already set to 0
	; Add one entry in bootstrap_pd_0 for the first 2MB
	; Fill bootstrap_pd_0 with 2MB pages that together identity map the first 1GB
	add	di, BOOTSTRAP_PD_0_OFFSET
	xor	ecx, ecx
.loop_pd_0:
	mov	eax, ecx
	shl	eax, 21
	or	eax, dword PxE_PRESENT_BIT | PxE_WRITABLE_BIT | PDE_2MB_PAGE_BIT
	mov	[di], eax
	mov	[di + 4], dword 0
	inc	cx
	add	di, 8
	cmp	cx, 512
	jb	.loop_pd_0
	; Here di = DS-relative address of the byte after bootstrap_pd_0
	; Enable PAE and PSE
	mov	eax, cr4
	or	eax, CR4_PAE_BIT | CR4_PSE_BIT
	mov	cr4, eax
	; Load PML4 into CR3
	mov	cr3, edx

.exit:
	pop	edi
	ret
