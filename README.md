# ChainBoot

ChainBoot is a (currently x64 only) out of the box way to run [LinuxBoot](linuxboot.org) as a chainloader. Easily boot in ways unsupported by your builtin firmware.

## What is LinuxBoot?

LinuxBoot is a project initiated by Google, Facebook and some other companies to try and use Linux as a BIOS/UEFI replacement. It would be flashed as firmware and take care of booting by combining the mainboard BIOS and bootloader into one..

## Why use LinuxBoot as a chainloader?

Usually LinuxBoot's kernels are very minimal since they only need to do the job of a common BIOS. However, sometimes a BIOS isn't enough. Linux usually ships a bootloader like GRUB since almost no BIOS is capable of reading Linux filesystems. Also sometimes, especially on complex systems, the BIOS doesn't support the hardware you want to boot from.

On a system which supports LinuxBoot directly you can just add the necessary drivers to the Kernel and be done. On a UEFI system that could theoretically be possible with EFI drivers but many UEFI implementations are too locked down. On BIOS it's pretty much impossible without shipping a custom option ROM.

So how can we solve this problem? We just load LinuxBoot, a firmware whose drivers we can easily augment, using the computer's builtin firmware. We chainload. LinuxBoot does not replace the BIOS but rather the bootloader like GRUB.

## How can I use ChainBoot?

This depends on how your system boots. In all cases you need to grab `chainboot.efi` or `chainboot.iso` from a release or build it yourself.

### My system has a modern UEFI (easy)

Just put chainboot on a FAT formattet media/any media your integrated firmware will boot from and add a boot entry using your UEFI boot manager. This allows it to be directly loaded without any man in the middle.

If your UEFI doesn't have a boot manager that can work with files (many consumer boards) you need to rename the file and put it in the following path: `\EFI\BOOT\BOOTX64.EFI`, this way it will be autodetected.

Of course the Limine based image also works if you don't want to manually create boot files. See next step.

### My system has a legacy (32bit) EFI or only BIOS (also easy)

In this case things are a bit more complex. Since ChainBoot is a Linux kernel you need to somehow boot it using a bootloader.

Since version 1.1 ChainBoot includes a fully premade image for this usecase. The iso image can be burnt to a DVD or flashed to a USB/Hard drive. It is powered by [Limine](https://github.com/Limine-Bootloader/Limine) and works both in BIOS and UEFI mode.

Just a note: even though ChainBoot is more or less a replacement for systems like [DUET](https://github.com/tianocore/tianocore.github.io/wiki/DuetPkg), there's also the option of adding a UEFI environment using it. However this doesn't make much sense.

### My system doesn't support any of this (advanced)

If you really can't put ChainBoot on a local drive (USB/SD Card/etc.) for some reason and still need to use it always remember what was already described: `chainboot.efi` is both an EFI executable and a Linux kernel file!

If your system has ANY way of booting a Linux kernel (no initrd required) then it can boot ChainBoot.

Here are a few ideas:

- Is your system a server? Maybe it can boot over iSCSI.
- Also for servers: IPMI, some of them can permanently store an image.
- Does your system support PXE or HTTP boot? Use something like [iPXE](https://ipxe.org).

## What are some usecases?

### NVMe booting

Many older firmwares do not support booting from NVMe devices. LinuxBoot can detect the drive an boot from it.

### Unsupported RAID/HBA cards

Server firmware is really picky about which adapter you can use for booting your OS. LinuxBoot can detect the adapter and boot just fine.

### Many more

Linux is really flexible when it comes to storage devices. If Linux recognizes it, LinuxBoot will boot from it.

## How does it work?

As already said ChainBoot uses LinuxBoot (Linux + u-root) under the hood. u-root is a minimal environment that facilitates a few bootloaders (the local disk one runs by default) and a shell environment. The Linux kernel is just a current kernel configured with many drivers.

That's the key difference between vanilla LinuxBoot and ChainBoot (Well in adition to not being flashed to firmware): LinuxBoot kernels are usually minimal. They only include a few SATA and CDROM drivers and that's it since they need to work with limited flash.

ChainBoot does not have this limitation since it's loaded from elsewhere. It includes almost all Linux storage drivers. (If one is missing go open an issue) Therefore it can boot of almost anything that could even remotely be considered storage and even more if you boot manually instead of using the boot menu.

## What about my OS? Can I still use it's bootloader?

No. LinuxBoot uses kexec. That means it runs the Linux kernel to boot directly. Any OS that can't be loaded like a Linux kernel won't work (e.g. Windows) some OS like FreeBSD are working on compatiblity, others may already work (some ESXi) but everything else needs to wait for upstream to support it.

This also means, even for Linux distros, the bootloader is not run. However you should/must still install it. LinuxBoot reads the Syslinux/GRUB configuration in order to know how to boot the kernel. That also means you can continue using the same tools you previously used for configuring your boot process and almost any distro should work out of the box. (Note: systemd-boot is at least currently not supported by LinuxBoot, please use GRUB if you have a choice)

## How can I build ChainBoot?

First you need to install dependencies. That means Go (v1.22+ recommended, yes, the warning is wrong). Use your preferred way of installing Go.

In addition you need the kernel dependencies. For Ubuntu this currently means:

`apt install gcc git build-essential ncurses-dev gawk flex xz-utils zstd bc bison openssl libssl-dev libelf-dev libudev-dev libpci-dev libiberty-dev autoconf pahole xorriso`

Now you need to get the ChainBoot source, we use `git` for that:

`git clone --recurse-submodules --shallow-submodules https://github.com/Juff-Ma/ChainBoot.git`

Then you can just go ahead and run the following in the ChainBoot directory:

`make -j$(nproc)`

This will build the u-root and the Linux kernel. If everything worked you should find a `chainboot.efi` and a `chainboot.iso` in the `bin` folder. Building is only supported on Linux. Theoretically it could work on other Unix OS (including MinGW) as well but that's not tested. If running Windows you can use WSL as an easy workaround.

If you want to test ChainBoot Qemu is the easiest way to do so:

`qemu-system-x86_64 -m 4G -smp 2 -kernel chainboot.efi -cdrom <path to a Linux iso>`

## Known Issues

### Linux KERNEL only

Anything that's not a driver in the Linux kernel won't boot. LVM for example is a userspace configuration.
ChainBoot includes all necessary drivers for LVM to work but without the userspace utilities it can't recognize a LVM partition.

This means that systems like Proxmox which utilize LVM cannot boot. (For Proxmox you can go around this by using BTRFS as a filesystem, since it doesn't require LVM and therefore can be booted)

Same goes for 3rd party kernel modules. ZFS is such an example since it requires the OpenZFS module which needs to be loaded via the initrd.

### Only basic bootloader support

ChainBoot pulls its config from your bootloader (e.g. GRUB) for its own boot menu. Without this you'd need to manually select the kernel path, initrd and cmd line each boot which isn't feasable.

The GRUB parser in LinuxBoot is very basic though and will choke on more complex GRUB configuration files. This isn't a problem for 90% of distros but notably some RedHat family LiveCDs choke on this (the installed OS and netinstall like Fedora Everything work fine).
