ENTRY(_start)

SECTIONS {
    . = 0x100000;

    .text : {
	// Put section .text._start first. Don't omit it even if nothing else references it. The
	// _start() function must explicitly be placed in this section.
        KEEP(*(.text._start))	
        *(.text*)
    }
    .rodata : { *(.rodata*) }
    .data   : { *(.data*) }
    .bss    : { *(.bss*) *(COMMON) }
    /DISCARD/ :
    {
        *(.comment*)
        *(.eh_frame*)
        *(.gcc_except_table*)
        *(.note*)
    }
}
