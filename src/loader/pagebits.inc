%ifndef	__PAGEBITS__INC__
%define	__PAGEBITS__INC__

; Page [Map Level 4/Directory Pointer Table/Directory/Table] Entry bits
PxE_32_SIZE			equ 4		; i386 Page [...] Entry size is 4 bytes = 32 bits
PxE_64_SIZE			equ 8		; x86-64 Page [...] Entry size is 8 bytes = 64 bits
PxE_PRESENT_BIT			equ 1 << 0
PxE_WRITABLE_BIT		equ 1 << 1
PxE_USER_BIT			equ 1 << 2	; At least one page is user-accessible
PxE_PWT_BIT			equ 1 << 3	; PWT = Page Write Through
PxE_PCD_BIT			equ 1 << 4	; PCD = Page Cache Disabled
PxE_ACCESSED_BIT		equ 1 << 5
PxE_PAGE_DIRTY_BIT		equ 1 << 6	; Only used if the entry refers to a page
PDPTE_1GB_PAGE_BIT		equ 1 << 7	; Entry is a 1GB page, not a page directory
PDE_2MB_PAGE_BIT		equ 1 << 7	; Entry is a 2MB page, not a page table
PxE_PAGE_IS_GLOBAL_BIT		equ 1 << 8	; Only used if the entry refers to a page
PxE_D0_LOW_ADDR_MASK		equ 0xfffff000	; And with mask then shift to get low bits of addr
PxE_D0_LOW_ADDR_SHIFT		equ 0
PxE_D1_HIGH_ADDR_MASK		equ 0x000fffff	; And with mask then shift to get high bits of addr
PxE_D1_HIGH_ADDR_SHIFT		equ 32

%endif	; __PAGEBITS__INC__
