%ifndef	__MSR_BITS__INC__
%define	__MSR_BITS__INC__

MSR_IA32_EFER_ID		equ 0xc0000080	; IA32_EFER = Extended FEatuRes
MSR_IA32_EFER_SCE_BIT		equ 1 << 0	; SCE = SysCall/sysret Enabled
MSR_IA32_EFER_LME_BIT		equ 1 << 8	; LME = Long Mode Enabled
MSR_IA32_EFER_LMA_BIT		equ 1 << 10	; LMA = Long Mode Active
MSR_IA32_EFER_NXE_BIT		equ 1 << 10	; NXE = No-eXecute bit Enabled

%endif	; __MSR_BITS__INC__
