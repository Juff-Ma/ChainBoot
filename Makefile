GO := go

.PHONY: all default clean bindir

default: all

all: bin/chainboot.efi

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

bin/chainboot.efi: bindir bin/initramfs.cpio.zst
	@echo "Building $@"
	touch $@

clean: urootclean
	rm -f bin/initramfs.cpio
	rm -f bin/initramfs.cpio.zst
	rm -f bin/chainboot.efi

urootclean:
	cd uroot && $(GO) clean