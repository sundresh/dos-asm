#!/bin/bash
set -eux -o pipefail

cargo build --target x86_64-unknown-none --release
objcopy -O binary target/x86_64-unknown-none/release/hello64r target/x86_64-unknown-none/release/hello64r.bin
