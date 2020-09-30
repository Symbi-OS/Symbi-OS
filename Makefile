# https://www.zachpfeffer.com/single-post/Build-the-Linux-kernel-and-Busybox-and-run-on-QEMU

# in a VM:
# userspace (shell, basic commands [ls, top, mkdir]) <- busybox is providing this.
# =======
# kernel

# when we boot QEMU (our vm) we can pass 2 files:
# 1) The kernel binary
# 2) initrd a.k.a. initramfs: compressed cpio archive which defines the filesystem contents for the userspace

# Provides basic userspace programs as a single executable.
# busybox: misc/busybox_build
# 	cd $< && make -j48 && make install

TOP=./misc
# Linux expects initrd to define the FS contents at boot time.
initrd:
	mkdir -pv $(TOP)/initramfs/x86-busybox
#	cd $(TOP)/initramfs/x86-busybox &&
	bash -c 'mkdir -pv $(TOP)/initramfs/x86-busybox/{bin,dev,sbin,etc,proc,sys/kernel/debug,usr/{bin,sbin},lib,lib64,mnt/root,root}'
	bash -c 'cp -av $(TOP)/busybox_build/_install/* $(TOP)/initramfs/x86-busybox'
	bash -c 'sudo cp -av /dev/{null,console,tty,sda1} $(TOP)/initramfs/x86-busybox/dev/'

print:
	bash -c 'echo {bin,dev,sbin,etc,proc,sys/kernel/debug,usr/{bin,sbin},lib,lib64,mnt/root,root}'



clean:
	- sudo rm -rf ./misc/initramfs

