// rustc -O --target=i686-unknown-linux-gnu -C panic=abort -C linker=rust-lld -C link-arg=-nostdlib -C relocation-model=static hexdump.rs
#![no_std]
#![no_main]

use core::mem;
use core::panic::PanicInfo;

const USIZE_HEX_DIGITS: usize = mem::size_of::<usize>() * 2;
const OUT_BUF_SIZE: usize = 2 + USIZE_HEX_DIGITS + 1 + 16 * 3;

const HEX: &[u8; 16] = b"0123456789abcdef";

extern "C" {
    fn print_string(len: usize, data: *const u8);
    fn move_cursor_to_next_line();
}

pub fn to_hex<const N: usize>(value: u128) -> [u8; N] {
    let mut out_buf = [0u8; N];

    for i in 0..N {
        let shift = (N - 1 - i) * 4;
        out_buf[i] = HEX[((value >> shift) & 0x0f) as usize];
    }

    out_buf
}

pub fn u8_to_hex(value: u8) -> [u8; 2] {
    to_hex::<2>(value as u128)
}

pub fn u16_to_hex(value: u16) -> [u8; 4] {
    to_hex::<4>(value as u128)
}

pub fn u32_to_hex(value: u32) -> [u8; 8] {
    to_hex::<8>(value as u128)
}

pub fn u64_to_hex(value: u64) -> [u8; 16] {
    to_hex::<16>(value as u128)
}

pub fn u128_to_hex(value: u128) -> [u8; 32] {
    to_hex::<32>(value)
}

pub fn usize_to_hex(value: usize) -> [u8; USIZE_HEX_DIGITS] {
    to_hex::<USIZE_HEX_DIGITS>(value as u128)
}

/// Prints lines of the form:
///
/// 0x12345678: 01 23 45 67 ...
///
/// # Safety
///
/// - `data` must be valid to read `len` bytes.
/// - `print_string` and `move_cursor_to_next_line` must satisfy their own
///   safety requirements.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn hexdump(len: usize, data: *const u8) {
    let mut out_buf = [0u8; OUT_BUF_SIZE];
    out_buf[0] = b'0';
    out_buf[1] = b'x';

    let end = data.add(len);
    let mut in_ptr = ((data as usize) & !0x0fusize) as *const u8;

    while in_ptr < end {
        let mut out_index = 2;

        out_buf[out_index..out_index + USIZE_HEX_DIGITS]
            .copy_from_slice(&usize_to_hex(in_ptr as usize));
        out_index += USIZE_HEX_DIGITS;

        out_buf[out_index] = b':';
        out_index += 1;

        for _ in 0..16 {
            if in_ptr >= end {
                break;
            }

            out_buf[out_index] = b' ';
            out_index += 1;

            if in_ptr >= data {
                out_buf[out_index..out_index + 2].copy_from_slice(&u8_to_hex(*in_ptr));
            } else {
                out_buf[out_index..out_index + 2].copy_from_slice(b"  ");
            }

            out_index += 2;
            in_ptr = in_ptr.add(1);
        }

        print_string(out_index, out_buf.as_ptr());
        move_cursor_to_next_line();
    }
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
