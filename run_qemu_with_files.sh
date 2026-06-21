#!/bin/bash
set -eux -o pipefail

cleanup() {
    if [[ -f "${TMP_FLOPPY_PATH}" ]]; then
        rm "${TMP_FLOPPY_PATH}"
    fi
}
trap cleanup EXIT

TMP_FLOPPY_PATH=$(mktemp /tmp/floppy.XXXXXXXXXX.img)
truncate -s 1440K "${TMP_FLOPPY_PATH}"
mformat -i "${TMP_FLOPPY_PATH}" -f 1440 ::
mcopy -i "${TMP_FLOPPY_PATH}" "$@" ::
mdir -i "${TMP_FLOPPY_PATH}" ::

qemu-system-x86_64 -hda ~/Documents/VM/freedos.qcow2 -fda "${TMP_FLOPPY_PATH}" -boot c -enable-kvm -nic none
