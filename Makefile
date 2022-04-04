# This is disconnected and fubar, but serves as rough documentation
# about how to get a symbiote kernel ready to run.

# Download kern and config.
all: get_all
get_all: get_sym_linux get_linux_configs get_apps_dir

build_all: linux_kernel build_sym_lib
# ====================================================
# Apps
# ====================================================
get_apps_dir:
	git clone git@github.com:Symbi-OS/Apps.git

build_sym_lib:
	make -C ./Apps/include

# ====================================================
# Linux
# ====================================================
get_linux_configs:
	git clone git@github.com:Symbi-OS/linuxConfigs.git

get_sym_linux:
	git clone --depth 5 -b clean-sym-5.14 git@github.com:Symbi-OS/linux.git


build_linux_kernel: linux linuxConfigs
	cp ./linuxConfigs/5.14/defconfig_debug_virtio ./linux/.config
	cd linux && make oldconfig
	cd linux && make -j$(nproc) bzImage
	cd linux && make -j$(nproc) modules

# Creates initrd modules dir and copies kern into /boot.
linux_install: ./linux/arch/x86/boot/bzImage
	cd linux && sudo make modules_install
	cd linux && sudo make install

# Linux install already created the entry, we just edit it.
config_grub_sym: /boot/vmlinuz-5.14.0-symbiote+
	sudo grubby --remove-args="" --args="mitigations=off nosmep nosmap isolcpus=0" --update-kernel /boot/vmlinuz-5.14.0-symbiote+

#now just reboot via console and pick the symbiote entry

linux_kernel_clean:
	cd linux && make clean

clean: linux_kernel_clean
