JOBS ?= 1
MAKEFLAGS += -j$(JOBS)

CACHE_SIZE ?= 10G

CHAINBOOT_LIMINE_VERSION ?= 12.3.3
CHAINBOOT_LIMINE_URL ?= https://github.com/Limine-Bootloader/Limine/releases/download/v$(CHAINBOOT_LIMINE_VERSION)/limine-binary.tar.xz

CHAINBOOT_BUILDROOT_VERSION ?= 2026.05
CHAINBOOT_BUILDROOT_URL ?= https://buildroot.org/downloads/buildroot-$(CHAINBOOT_BUILDROOT_VERSION).tar.xz

.PHONY: all boot image isoroot default clean isoclean buildrootclean cacheclean bindir

default: all

all: boot image
	@echo "Build done!"

boot: bin/chainboot.efi

image: bin/chainboot.iso

bindir:
	@mkdir -p bin

bin/limine.tar.xz: bindir
	@echo "Downloading Limine binaries"
	@wget -O $@ $(CHAINBOOT_LIMINE_URL)

bin/limine-binary/limine: bin/limine.tar.xz
	tar -xf bin/limine.tar.xz -C bin
	@$(MAKE) -C bin/limine-binary limine

bin/chainboot.iso: bin/limine-binary/limine isoroot
	@echo "Creating ISO image"
	@bin/buildroot/host/bin/xorriso -as mkisofs -R -r -J -b boot/limine-bios-cd.bin \
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

bin/chainboot.efi: buildroot
	@echo "Copying kernel image to EFI boot file"
	cp bin/buildroot/images/rootfs.cpio bin/initramfs.cpio
	cp bin/buildroot/images/rootfs.cpio.zst bin/initramfs.cpio.zst
	cp bin/buildroot/images/bzImage bin/chainboot.efi

bin/buildroot.tar.xz: bindir
	@echo "Downloading Buildroot"
	@wget -O $@ $(CHAINBOOT_BUILDROOT_URL)

BUILDROOT_ARGS := BR2_EXTERNAL=$(CURDIR)/buildroot
BUILDROOT_ARGS += BR2_CCACHE_DIR=$(CURDIR)/bin/cache/ccache
BUILDROOT_ARGS += BR2_DL_DIR=$(CURDIR)/bin/cache/downloads
BUILDROOT_ARGS += BR2_JLEVEL=$(JOBS)
BUILDROOT_ARGS += CCACHE_OPTIONS="--max-size=$(CACHE_SIZE)"

bin/buildroot/Makefile: bin/buildroot.tar.xz
	@echo "Extracting buildroot"
	tar -xf bin/buildroot.tar.xz -C bin
	mkdir -p bin/buildroot
	mkdir -p bin/cache/ccache
	mkdir -p bin/cache/downloads

	@echo "Preparing buildroot environment"
	@$(MAKE) -C bin/buildroot-$(CHAINBOOT_BUILDROOT_VERSION) \
		O=$(CURDIR)/bin/buildroot \
		$(BUILDROOT_ARGS) \
		chainboot_defconfig

.PHONY: buildroottoolchain buildroot

buildroottoolchain: bin/buildroot/Makefile
	@echo "Building toolchain"
	@$(MAKE) -C bin/buildroot \
		$(BUILDROOT_ARGS) \
		ccache-options

	@$(MAKE) -C bin/buildroot \
		$(BUILDROOT_ARGS) \
		toolchain

buildroot: buildroottoolchain
	@echo "Building system"
	@$(MAKE) -C bin/buildroot \
		$(BUILDROOT_ARGS) \
		all

cacheclean:
	rm -rf bin/cache

clean: isoclean buildrootclean
	rm -f bin/initramfs.cpio
	rm -f bin/initramfs.cpio.zst
	rm -f bin/chainboot.efi

isoclean: bindir
	rm -f bin/limine.tar.xz
	rm -rf bin/limine-binary
	rm -rf bin/isoroot
	rm -f bin/chainboot.iso

buildrootclean: bindir
	rm -f bin/buildroot.tar.xz

	@test -f bin/buildroot/Makefile && $(MAKE) -C bin/buildroot distclean || true
	rm -rf bin/buildroot
	rm -rf bin/buildroot-$(CHAINBOOT_BUILDROOT_VERSION)