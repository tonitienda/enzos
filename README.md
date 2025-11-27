# enzos
EnzOS - tiny OS for learning purposes

## EnzOS — Milestone 0

“Boots, prints text, builds in CI, releases ISO”


---

1️⃣ Prepare Environment (15–20 min)

- [x] Install build tools
- [x] build-essential
- [x] grub-pc-bin and grub-common
- [x] xorriso
- [x] qemu-system-x86
- [x] Create project structure

```
enzos/
 ├── src/
 │    ├── kernel_entry.s
 │    └── kernel.c
 ├── linker.ld
 ├── grub/
 │    └── grub.cfg
 └── scripts/
      └── build-iso.sh

```
---

2️⃣ Implement Minimal Kernel (60–120 min)

kernel_entry.s

- [x] Add Multiboot or Multiboot2 header
- [x] Define _start
- [x] Set up stack
- [x] Call kmain()
- [x] Halt in infinite loop


kernel.c

- [x] Implement kmain()
- [x] Get VGA buffer pointer (0xB8000)
- [x] Write string: "EnzOS boot OK!"
- [x] Infinite loop


linker.ld

- [x] Define ENTRY(_start)
- [x] Place .text, .rodata, .data, .bss
- [x] Set load address (e.g. 0x100000)



---

3️⃣ Bootloader Configuration (10–15 min)

grub/grub.cfg

- [x] Set timeout to 0
- [x] Create menu entry "EnzOS"
- [x] Use multiboot2 /boot/enzos.elf (or multiboot)
- [x] Call boot



---

4️⃣ Build Script (20–40 min)

scripts/build-iso.sh

- [x] Create build/ and iso-root/ directories
- [x] Assemble kernel_entry.s → kernel_entry.o
- [x] Compile kernel.c → kernel.o
- [x] Link → build/enzos.elf with linker.ld
- [x] Copy enzos.elf into iso-root/boot/
- [x] Copy grub.cfg into iso-root/boot/grub/
- [x] Run grub-mkrescue -o enzos.iso iso-root/


---

5️⃣ Local Test (5–10 min)

- [ ] Boot locally in QEMU:
```
qemu-system-x86_64 -cdrom enzos.iso -serial stdio -no-reboot -no-shutdown
```
- [ ] Verify "EnzOS boot OK!" appears

## VNC Screenshot Capture

- Set `VNC_SCREENSHOT` when running `scripts/qemu-smoketest.sh` to expose a temporary VNC server while the guest boots and to record what the guest draws. QEMU binds to `${VNC_BIND_ADDR}:${VNC_PORT}` (default `0.0.0.0:1`, which maps to TCP 5901) so the CI runner can connect directly.
- The dev container now installs `vncsnapshot`, so CI runners can capture the framebuffer even when the smoketest runs inside Docker. Install the package locally if you run the smoketest on bare metal.
- When you run the smoketest inside Docker, publish the TCP port so the host can reach VNC: `VNC_SCREENSHOT=qemu-screen.ppm VNC_PORT=1 just smoketest`. Change `VNC_PORT` to avoid clashes and the port mapping follows automatically.
- The script keeps `qemu-vnc-server.log` and `qemu-vnc-client.log` so you can read the handshake attempts and error traces even when the snapshot fails. These logs make it easier to debug why a remote VNC client could not connect.



---

6️⃣ CI Integration (30–60 min)

CI Setup

- [x] Install build dependencies in workflow
- [x] Run unit tests (if any)
- [x] Run scripts/build-iso.sh
- [x] Run scripts/qemu-smoketest.sh enzos.iso


scripts/qemu-smoketest.sh

- [x] Run QEMU headless with timeout
- [ ] Capture serial output
- [ ] Check for "EnzOS boot OK!"
- [x] Exit 0 if found, else exit 1
- [ ] Verify CI goes red → fix → green



---

7️⃣ Release Workflow (15–30 min)

- [x] Add tag-based workflow
- [x] Build ISO
- [x] Run QEMU smoke test
- [x] Create GitHub Release
- [x] Upload enzos.iso
- [ ] Create first release tag (v0.0.1)
---

⭐ Optional Extras

- [ ] Add ASCII boot text
- [ ] Colorize VGA output
- [ ] Add serial output logging
- [ ] Add a simple GRUB theme

---

🎉 End of Milestone 0

Once all tasks are checked, EnzOS can:

- Boot via GRUB
- Run your kernel
- Print text
- Build reproducibly
- Boot automatically in CI
- Release tagged ISOs


You’re officially an OS developer 🚀
