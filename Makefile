GO := go

.PHONY: all default clean bindir urootclean kernelclean

default: all

all: bin/chainboot.efi
	@echo "Build done!"

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

clean: urootclean kernelclean bindir
	rm -f bin/initramfs.cpio
	rm -f bin/initramfs.cpio.zst
	rm -f bin/chainboot.efi

kernelclean:
	rm -f kernel/arch/x86/configs/chainboot_defconfig
	@$(MAKE) -C kernel mrproper

urootclean:
	cd uroot && $(GO) clean