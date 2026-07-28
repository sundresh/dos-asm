#![no_std]
#![no_main]

use core::panic::PanicInfo;

unsafe extern "C" {
    static _text_start: u8;
    static _text_end: u8;
    static _rodata_start: u8;
    static _rodata_end: u8;
    static _data_start: u8;
    static _data_end: u8;
    static mut _bss_start: u8;
    static mut _bss_end: u8;
}

#[unsafe(no_mangle)]
#[unsafe(link_section = ".text._start")]
pub extern "C" fn _start() -> () {
    unsafe {
        zero_bss();
    }
}

unsafe fn zero_bss() {
    let start = core::ptr::addr_of_mut!(_bss_start);
    let end = core::ptr::addr_of_mut!(_bss_end);
    let len = end.offset_from(start) as usize;
    core::ptr::write_bytes(start, 0, len);
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
