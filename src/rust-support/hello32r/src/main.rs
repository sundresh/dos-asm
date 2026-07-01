#![no_std]
#![no_main]

use core::panic::PanicInfo;

#[unsafe(no_mangle)]
#[unsafe(link_section = ".text._start")]
pub extern "C" fn _start() -> () {
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
