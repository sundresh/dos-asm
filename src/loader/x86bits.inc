%ifndef	__X86_BITS__INC__
%define	__X86_BITS__INC__

CR0_PE_BIT			equ 1 << 0
CR0_WP_BIT			equ 1 << 16
CR0_PG_BIT			equ 1 << 31
CR3_PWT_BIT			equ 1 << 3	; PWT = Page Write Through
CR3_PCD_BIT			equ 1 << 4	; PCD = Page Cache Disabled
CR3_32_PDB_MASK			equ 0xfffff000	; PDB = Page Directory Base
CR3_PAE_PDPTB_MASK		equ 0xffffffe0	; PDPTB = Page Directory Pointer Table Base
CR3_PML4_MASK			equ 0xfffff000	; PML4 = Page Map Level 4 (TODO: but CR3 is actually 64 bits in long mode...)
CR4_TSD_BIT			equ 1 << 2	; TSD = Time Stamp Disable (restricts RDTSC to PL 0)
CR4_PSE_BIT			equ 1 << 4	; PSE = Page Size Extension
CR4_PAE_BIT			equ 1 << 5	; PAE = Physical Address Extension
CR4_PGE_BIT			equ 1 << 7	; PGE = Page Global Enable
IA32_EFER_MSR_ID		equ 0xc0000080	; IA32_EFER = Extended FEatuRes
IA32_EFER_MSR_SCE_BIT		equ 1 << 0	; SCE = SysCall/sysret Enabled
IA32_EFER_MSR_LME_BIT		equ 1 << 8	; LME = Long Mode Enabled
IA32_EFER_MSR_LMA_BIT		equ 1 << 10	; LMA = Long Mode Active
IA32_EFER_MSR_NXE_BIT		equ 1 << 10	; NXE = No-eXecute bit Enabled

; TODO: Add constants for 1GB and 2MB pages

; Page [Map Level 4/Directory Pointer Table/Directory/Table] Entry bits
PxE_PRESENT_BIT			equ 1 << 0
PxE_WRITABLE_BIT		equ 1 << 1
PxE_USER_BIT			equ 1 << 2	; At least one page is user-accessible
PxE_PWT_BIT			equ 1 << 3	; PWT = Page Write Through
PxE_PCD_BIT			equ 1 << 4	; PCD = Page Cache Disabled
PxE_ACCESSED_BIT		equ 1 << 5
PxE_D0_LOW_ADDR_MASK		equ 0xfffff000	; And with mask then shift to get low bits of addr
PxE_D0_LOW_ADDR_SHIFT		equ 0
PxE_D1_HIGH_ADDR_MASK		equ 0x000fffff	; And with mask then shift to get high bits of addr
PxE_D1_HIGH_ADDR_SHIFT		equ 32

; Page Table Entry bits
PTE_PAGE_DIRTY_BIT		equ 1 << 6
PTE_PAGE_IS_GLOBAL_BIT		equ 1 << 8

%endif	; __X86_BITS__INC__
