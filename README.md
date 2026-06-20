# DOS assembly programming just-for-fun repo

## Host setup

1. Install FreeDOS on a 10GB partition, with NASM and anything else
2. Install Ubuntu Linux, then install packages:
   ```bash
   apt install git gnome-tweaks joe linux-firmware nasm
   ```
3. Configure `grub` to dual boot:
   * In `/etc/default/grub`, ensure `GRUB_TIMEOUT_STYLE=menu` and `GRUB_TIMEOUT=5`
   * In `/etc/grub.d`, `mv 30_os-prober 15_os-prober` to move FreeDOS earlier
   * Run `sudo grub-mkconfig && sudo update-grub`

TODO: `qemu` for testing under Linux without rebooting into DOS

## System documentation

* Intel 64 and IA-32 Architectures Software Developer’s Manual
* Ralf Brown's Interrupt List
* NASM documnetation (includes a text version, but note it's 1.1 MB)

## Future ideas

Possibly separate the development workstation from the DOS host. To avoid DOS networking hassles,
install a minimal Linux distribution that boots quickly, supports the host's NIC, and runs SSH. 
Configure `grub` to boot into Linux by default, and use `grub-reboot` to boot into DOS. Create a
script that `scp`s the latest version of the DOS program to the DOS host, copies it to the DOS
partition, and reboots into DOS, running the program from `AUTOEXEC.BAT`. Since we're talking
about assembly language programs assembled with `nasm`, this could also copy the latest assembly
language source code to the DOS partition, to allow for iteration on the DOS host. Later, when
we reboot into Linux, changes from DOS could be copid back to the development workstation.
