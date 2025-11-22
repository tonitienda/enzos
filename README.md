# enzos
EnzOS - tiny OS for learning purposes

## EnzOS — Milestone 0

“Boots, prints text, builds in CI, releases ISO”


---

1️⃣ Prepare Environment (15–20 min)

[ ] Install build tools

[ ] build-essential

[ ] grub-pc-bin and grub-common

[ ] xorriso

[ ] qemu-system-x86


[ ] Create project structure


enzos/
 ├── src/
 │    ├── kernel_entry.s
 │    └── kernel.c
 ├── linker.ld
 ├── grub/
 │    └── grub.cfg
 └── scripts/
      └── build-iso.sh


---

2️⃣ Implement Minimal Kernel (60–120 min)

kernel_entry.s

[ ] Add Multiboot or Multiboot2 header

[ ] Define _start

[ ] Set up stack

[ ] Call kmain()

[ ] Halt in infinite loop


kernel.c

[ ] Implement kmain()

[ ] Get VGA buffer pointer (0xB8000)

[ ] Write string: "EnzOS boot OK!"

[ ] Infinite loop


linker.ld

[ ] Define ENTRY(_start)

[ ] Place .text, .rodata, .data, .bss

[ ] Set load address (e.g. 0x100000)



---

3️⃣ Bootloader Configuration (10–15 min)

grub/grub.cfg

[ ] Set timeout to 0

[ ] Create menu entry "EnzOS"

[ ] Use multiboot2 /boot/enzos.elf (or multiboot)

[ ] Call boot



---

4️⃣ Build Script (20–40 min)

scripts/build-iso.sh

[ ] Create build/ and iso-root/ directories

[ ] Assemble kernel_entry.s → kernel_entry.o

[ ] Compile kernel.c → kernel.o

[ ] Link → build/enzos.elf with linker.ld

[ ] Copy enzos.elf into iso-root/boot/

[ ] Copy grub.cfg into iso-root/boot/grub/

[ ] Run grub-mkrescue -o enzos.iso iso-root/



---

5️⃣ Local Test (5–10 min)

[ ] Boot locally in QEMU:


qemu-system-x86_64 -cdrom enzos.iso -serial stdio -no-reboot -no-shutdown

[ ] Verify "EnzOS boot OK!" appears



---

6️⃣ CI Integration (30–60 min)

CI Setup

[ ] Install build dependencies in workflow

[ ] Run unit tests (if any)

[ ] Run scripts/build-iso.sh

[ ] Run scripts/qemu-smoketest.sh enzos.iso


scripts/qemu-smoketest.sh

[ ] Run QEMU headless with timeout

[ ] Capture serial output

[ ] Check for "EnzOS boot OK!"

[ ] Exit 0 if found, else exit 1

[ ] Verify CI goes red → fix → green



---

7️⃣ Release Workflow (15–30 min)

[ ] Add tag-based workflow:


on:
  push:
    tags:
      - 'v*'

[ ] Build ISO

[ ] Run QEMU smoke test

[ ] Create GitHub Release

[ ] Upload enzos.iso

[ ] Create first release tag:


git tag v0.0.1
git push origin v0.0.1


---

⭐ Optional Extras

[ ] Add ASCII boot text

[ ] Colorize VGA output

[ ] Add serial output logging

[ ] Add a simple GRUB theme



---

🎉 End of Milestone 0

Once all tasks are checked, EnzOS can:

Boot via GRUB

Run your kernel

Print text

Build reproducibly

Boot automatically in CI

Release tagged ISOs


You’re officially an OS developer 🚀
