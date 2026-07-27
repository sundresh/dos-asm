%ifndef	__CR_BITS__INC__
%define	__CR_BITS__INC__

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

%endif	; __CR_BITS__INC__
