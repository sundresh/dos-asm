How this was initially set up:

1. Install the nightly Rust toolchain:
  ```bash
  rustup default nightly
  rustup component add rust-src --toolchain nightly-x86_64-unknown-linux-gnu
  rustup target add x86_64-unknown-none
  ```

2. Create a new binary crate: `cargo new --bin kernel`

3. Configure Cargo to build a freestanding executable:
  * In `Cargo.toml`, set:
    ```toml
    [profile.dev]
    panic = "abort"

    [profile.release]
    panic = "abort"
    ```
  * In `src/main.rs`, replace `main` with:
    ```rust
    #![no_std]
    #![no_main]

    use core::panic::PanicInfo;

    #[unsafe(no_mangle)]
    #[unsafe(link_section = ".text._start")]
    pub extern "C" fn _start() -> ! {
        loop {}
    }

    #[panic_handler]
    fn panic(_: &PanicInfo) -> ! {
        loop {}
    }
    ```

4. Install `rust-src` so we can compile core from source: `rustup component add rust-src`

5. Write a linker script (`link.ld`) that:
  * Sets the load address to `0x0010_0000`
  * Places `_start` first by ensuring it is emitted into `.text._start`
  * Creates section start and end symbols
  * Omits some sections we're not interested in

6. Tell Rust to use the linker script and some other linker options by creating `.cargo/config.toml`

7. Build the ELF executable: `cargo build --target x86_64-unknown-none --release`

8. Convert the ELF to a flat binary:
   `objcopy -O binary target/x86_64-unknown-none/release/hello64r target/x86_64-unknown-none/release/hello64r.bin`

9. Verify the result:
  * Confirm the ELF entry point is `0x00100000`: `readelf -h target/i686-flat/release/kernel`
  * Confirm `_start` is at `0x00100000`: `nm -n target/i686-flat/release/kernel`
  * Confirm the binary begins with `_start`'s machine code: `xxd hello64r.bin | head`

The resulting `hello64r.bin` is a raw flat binary intended to be loaded at physical address `0x100000`;
byte `0` of the file is the first instruction of `_start`.
