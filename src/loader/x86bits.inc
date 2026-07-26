%ifndef	__X86_BITS__INC__
%define	__X86_BITS__INC__

CR0_PE_BIT			equ 1 << 0	; PE = Protection Enabled
CR0_WP_BIT			equ 1 << 16	; WP = Write Protect pages even in supervisor mode
CR0_PG_BIT			equ 1 << 31	; PG = PaGing enabled
CR3_PWT_BIT			equ 1 << 3	; PWT = Page Write Through
CR3_PCD_BIT			equ 1 << 4	; PCD = Page Cache Disabled
CR3_32_PDB_MASK			equ 0xfffff000	; PDB = Page Directory Base
CR3_PAE_PDPTB_MASK		equ 0xffffffe0	; PDPTB = Page Directory Pointer Table Base
CR3_PML4_MASK			equ 0x1fffffff_fffff000	; PML4 = Page Map Level 4
CR3_LAM57_BIT			equ 0x20000000_00000000	; LAM57 = Linear Address Masked to 57 bits
CR3_LAM48_BIT			equ 0x40000000_00000000	; LAM48 = Linear Address Masked to 48 bits
CR4_TSD_BIT			equ 1 << 2	; TSD = Time Stamp Disable (restricts RDTSC to PL 0)
CR4_PSE_BIT			equ 1 << 4	; PSE = Page Size Extension
CR4_PAE_BIT			equ 1 << 5	; PAE = Physical Address Extension
CR4_PGE_BIT			equ 1 << 7	; PGE = Page Global Enable
MSR_IA32_EFER_ID		equ 0xc0000080	; IA32_EFER = Extended FEatuRes
MSR_IA32_EFER_SCE_BIT		equ 1 << 0	; SCE = SysCall/sysret Enabled
MSR_IA32_EFER_LME_BIT		equ 1 << 8	; LME = Long Mode Enabled
MSR_IA32_EFER_LMA_BIT		equ 1 << 10	; LMA = Long Mode Active
MSR_IA32_EFER_NXE_BIT		equ 1 << 10	; NXE = No-eXecute bit Enabled

; Page [Map Level 4/Directory Pointer Table/Directory/Table] Entry bits
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

%endif	; __X86_BITS__INC__
