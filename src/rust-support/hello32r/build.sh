#!/bin/bash
set -eux -o pipefail

cargo build -Zjson-target-spec --release
objcopy -O binary target/i686-flat/release/hello32r target/i686-flat/release/hello32r.bin
