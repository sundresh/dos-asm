ENTRY(_start)

PHDRS
{
    text PT_LOAD FLAGS(5);   /* R + X */
    data PT_LOAD FLAGS(6);   /* R + W */
}

SECTIONS
{
    . = 0x100000;

    _text_start = .;
    .text : ALIGN(4K)
    {
	// Put section .text._start first. Don't omit it even if nothing else references it. The
	// _start() function must explicitly be placed in this section.
        KEEP(*(.text._start))
        *(.text*)
    } :text
    _text_end = .;

    _rodata_start = .;
    .rodata : ALIGN(4K)
    {
        *(.rodata*)
    } :text
    _rodata_end = .;

    _data_start = .;
    .data : ALIGN(4K)
    {
        *(.data*)
    } :data
    _data_end = .;

    _bss_start = .;
    .bss (NOLOAD) : ALIGN(4K)
    {
        *(.bss*)
        *(COMMON)
    } :data
    _bss_end = .;

    /DISCARD/ :
    {
        *(.comment*)
        *(.eh_frame*)
        *(.gcc_except_table*)
        *(.note*)
    }
}
