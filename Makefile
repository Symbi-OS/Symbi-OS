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

build_all: linux_kernel busybox_exe initrd
	make -C Apps
	make -C Run run_vm

MISC_DIR=./misc
INITRD_DIR=$(MISC_DIR)/initramfs/x86-busybox
# Linux expects initrd to define the FS contents at boot time.
initrd:
	mkdir -pv $(INITRD_DIR)
	bash -c 'mkdir -pv $(MISC_DIR)/initramfs/x86-busybox/{bin,dev,sbin,etc,proc,sys/kernel/debug,usr/{bin,sbin},lib,lib64,mnt/root,root}'
	bash -c 'cp -av $(MISC_DIR)/busybox_build/_install/* $(MISC_DIR)/initramfs/x86-busybox'
# Don't think we need these?
# bash -c 'sudo cp -av /dev/{null,console,tty,sda1} $(MISC_DIR)/initramfs/x86-busybox/dev/'

initrd_clean:
	rm -rf $(MISC_DIR)/initramfs

print:
	bash -c 'echo {bin,dev,sbin,etc,proc,sys/kernel/debug,usr/{bin,sbin},lib,lib64,mnt/root,root}'

linux_kernel:
	cd linux && make defconfig
	cd linux && make -j$(nproc)

linux_kernel_clean:
	cd linux && make clean

BB_BUILD_DIR=$(MISC_DIR)/busybox_build
busybox_exe:
	mkdir $(BB_BUILD_DIR)
	cd busybox && make O=../$(BB_BUILD_DIR) defconfig
	cp $(MISC_DIR)/busybox_config/config $(BB_BUILD_DIR)/.config
	cd $(BB_BUILD_DIR) && make -j$(nproc)
	cd $(BB_BUILD_DIR) && make install

busybox_clean:
	rm -rf $(BB_BUILD_DIR)


clean: linux_kernel_clean busybox_clean initrd_clean
	make -C Run clean

