// Configuring `rustup` for cross compilation
//   rustup toolchain install stable
//   rustup target add i686-unknown-linux-gnu
// Build:
//   rustc -O test32.rs --target=i686-unknown-linux-gnu -C panic=abort -C linker=rust-lld -C link-arg=-nostdlib -C relocation-model=static
// Disassemble:
//   objdump -d -M intel test32
// Not done yet: linker script to create a raw binary with a particular base address

#![no_std]
#![no_main]

use core::panic::PanicInfo;

//#[unsafe(naked)]  // Used to write a function with no prologue/epilogue and just a single `naked_asm!` block
#[unsafe(no_mangle)]
pub extern "C" fn _start() {
    unsafe {
        core::arch::asm!(
            "mov eax, 1", // sys_exit
            "xor ebx, ebx",
            "int 0x80",
            //options(noreturn)  // Disabled so we can call `f()` below
        );
    }
    f();
}

#[inline(never)]
#[unsafe(no_mangle)]
pub extern "C" fn f() {
    loop {}
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
