#![no_std]
#![no_main]

use core::panic::PanicInfo;
use itoa;

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

#[repr(u32)]
#[derive(Clone, Copy, Eq, PartialEq)]
enum AddressRangeType {
    Memory = 1,
    Reserved = 2,
    ACPI = 3,
    NVS = 4,
    Unusable = 5,
    Disabled = 6,
    PersistentMemory = 7,
}

#[repr(C, packed)]
#[derive(Clone, Copy, Eq, PartialEq)]
struct AddressRangeDescriptor {
    base_addr: u64,
    length: u64,
    tag: AddressRangeType,
}

#[unsafe(no_mangle)]
#[unsafe(link_section = ".text._start")]
pub extern "C" fn _start(num_address_range_descriptors: usize, address_range_descriptors: *const AddressRangeDescriptor) -> () {
    unsafe {
        zero_bss();
    }
    let tag = unsafe { *address_range_descriptors }.tag;
    let base_addr = unsafe { *address_range_descriptors }.base_addr;
    let length = unsafe { *address_range_descriptors }.length;
    if tag == AddressRangeType::Memory {
        print_string("Hello from x86-64 Rust code!");
        let mut buffer = itoa::Buffer::new();
        unsafe { CURSOR_POSITION = 80 };
        print_string("The number of AddressRangeDescriptors is: ");
        print_string(buffer.format(num_address_range_descriptors));
        print_string(" ");
        unsafe { CURSOR_POSITION = 160 };
        print_string("The first AddressRangeDescriptor is: ");
        print_string(buffer.format(base_addr));
        print_string(" ");
        print_string(buffer.format(length));
        print_string(" ");
        print_string(buffer.format(tag as u32));
        print_string(" ");
    } else {
        print_string("Error");
    }
}

unsafe fn zero_bss() {
    let start = core::ptr::addr_of_mut!(_bss_start);
    let end = core::ptr::addr_of_mut!(_bss_end);
    let len = end.offset_from(start) as usize;
    core::ptr::write_bytes(start, 0, len);
}

static mut CURSOR_POSITION: usize = 0;

fn get_text_mode_video_buffer() -> &'static mut [u8] {
    unsafe {
        core::slice::from_raw_parts_mut(0xb8000 as *mut u8, 80*25*2)
    }
}

fn print_string(s: &str) {
    let text_mode_video_buffer = get_text_mode_video_buffer();
    for c in s.bytes() {
        text_mode_video_buffer[unsafe { CURSOR_POSITION*2 } % (80*25*2)] = c;
        text_mode_video_buffer[unsafe { CURSOR_POSITION*2 + 1 } % (80*25*2)] = 0x1b;
        unsafe { CURSOR_POSITION = (CURSOR_POSITION + 1) % (80 * 25) };
    }
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
