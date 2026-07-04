GO := go

.PHONY: all boot image isoroot default clean bindir urootclean kernelclean isoclean

default: all

all: boot image
	@echo "Build done!"

boot: bin/chainboot.efi

image: bin/chainboot.iso

bin/chainboot.iso: bin/limine-binary/limine isoroot
	@echo "Creating ISO image"
	@xorriso -as mkisofs -R -r -J -b boot/limine-bios-cd.bin \
		-no-emul-boot -boot-load-size 4 -boot-info-table -hfsplus \
		-apm-block-size 2048 --efi-boot boot/limine-uefi-cd.bin \
		-efi-boot-part --efi-boot-image --protective-msdos-label \
		bin/isoroot -o $@

	@echo "Making ISO bootable with Limine"
	bin/limine-binary/limine bios-install bin/chainboot.iso

isoroot: bin/chainboot.efi
	@echo "Preparing ISO root directory"
	mkdir -p bin/isoroot
	cp bin/chainboot.efi bin/isoroot/chainboot.efi
	cp limine.conf bin/isoroot/limine.conf

	mkdir -p bin/isoroot/boot

	cp bin/limine-binary/limine-uefi-cd.bin bin/isoroot/boot/limine-uefi-cd.bin
	cp bin/limine-binary/limine-bios-cd.bin bin/isoroot/boot/limine-bios-cd.bin
	cp bin/limine-binary/limine-bios.sys bin/isoroot/boot/limine-bios.sys

	mkdir -p bin/isoroot/EFI/BOOT

	cp bin/limine-binary/BOOTX64.EFI bin/isoroot/EFI/BOOT/BOOTX64.EFI
	cp bin/limine-binary/BOOTIA32.EFI bin/isoroot/EFI/BOOT/BOOTIA32.EFI


bin/limine-binary/limine: bin/limine.tar.xz
	tar -xf bin/limine.tar.xz -C bin
	@$(MAKE) -C bin/limine-binary limine

bin/limine.tar.xz: bindir
	@echo "Downloading Limine binaries"
	@wget -O bin/limine.tar.xz https://github.com/Limine-Bootloader/Limine/releases/download/v12.4.0/limine-binary.tar.xz

bindir:
	@mkdir -p bin

uroot/u-root:
	cd uroot && $(GO) build .

bin/initramfs.cpio: bindir uroot/u-root
	@echo "Building $@ from u-root"
	cd uroot && GOOS=linux GOARCH=amd64 ./u-root -o ../$@ -build=bb -uinitcmd="boot" core ./cmds/boot/*

bin/initramfs.cpio.zst: bin/initramfs.cpio
	@echo "Compressing to $@"
	@zstd -f -19 --long=30 --check $< -o $@

kernel/.config: kernel.config
	@echo "Configuring kernel"
	cp kernel.config kernel/arch/x86/configs/chainboot_defconfig
	@$(MAKE) -C kernel chainboot_defconfig
	@$(MAKE) -C kernel olddefconfig

kernel/arch/x86/boot/bzImage: bin/initramfs.cpio.zst kernel/.config
	@echo "Building kernel"
	@$(MAKE) -C kernel bzImage

bin/chainboot.efi: kernel/arch/x86/boot/bzImage
	@echo "Copying kernel image to EFI boot file"
	cp kernel/arch/x86/boot/bzImage bin/chainboot.efi

clean: urootclean kernelclean bindir isoclean
	rm -f bin/initramfs.cpio
	rm -f bin/initramfs.cpio.zst
	rm -f bin/chainboot.efi

isoclean:
	rm -f bin/limine.tar.xz
	rm -rf bin/limine-binary
	rm -rf bin/isoroot
	rm -f bin/chainboot.iso

kernelclean:
	rm -f kernel/arch/x86/configs/chainboot_defconfig
	@$(MAKE) -C kernel mrproper

urootclean:
	cd uroot && $(GO) clean
