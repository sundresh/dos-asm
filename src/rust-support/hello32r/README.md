How this was initially set up:

1. Install the nightly Rust toolchain:
  ```bash
  rustup default nightly
  rustup component add rust-src --toolchain nightly-x86_64-unknown-linux-gnu
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

4. Add a custom target specification (for example `i686-flat.json`) describing a 32-bit x86,
  freestanding target using the ELF linker. You can create the file with:
    ```bash
    rustc -Zunstable-options --print target-spec-json --target i686-unknown-linux-gnu
    ```
  (on nightly Rust) and then modify it by changing os to "none", removing Linux-specific options,
  and setting the linker configuration shown above.  For most hobby OS projects, though, the minimal
  JSON above is sufficient.

5. Write a linker script (`link.ld`) that:
  * Sets the load address to `0x0010_0000`
  * Places `_start` first by ensuring it is emitted into `.text._start`.

6. Tell Rust to use the linker script by creating `.cargo/config.toml`

7. Build the ELF executable: `cargo build -Zbuild-std=core -Zjson-target-spec --target i686-flat.json --release`

8. Convert the ELF to a flat binary: `llvm-objcopy -O binary target/i686-flat/release/kernel kernel.bin`

9. Verify the result:
  * Confirm the ELF entry point is `0x00100000`: `readelf -h target/i686-flat/release/kernel`
  * Confirm `_start` is at `0x00100000`: `nm -n target/i686-flat/release/kernel`
  * Confirm the binary begins with `_start`'s machine code: `xxd kernel.bin | head`

The resulting `kernel.bin` is a raw flat binary intended to be loaded at physical address `0x100000`;
byte `0` of the file is the first instruction of `_start`.
