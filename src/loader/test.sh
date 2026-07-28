#!/bin/bash
set -eux -o pipefail

nasm main.asm -o load64.com
nasm main64.asm -o main64.bin
../../run_qemu_with_files.sh load64.com main64.bin
