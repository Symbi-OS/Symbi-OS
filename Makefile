SHELL := /bin/bash

DEV_PACKAGES := fedpkg fedora-packager rpmdevtools ncurses-devel pesign grubby openssl-devel bc \
					openssl htop the_silver_searcher redis psmisc ncurses-devel flex bison \
					elfutils-libelf-devel dwarves

install_dev_tools_fedora:
	sudo dnf group install "C Development Tools and Libraries" "Development Tools" -y
	sudo dnf install -y $(DEV_PACKAGES)

clone_core_repos:
	git clone git@github.com:Symbi-OS/Symlib.git
	git clone git@github.com:Symbi-OS/Tools.git

clone_experimental_repos:
	git clone git@github.com:Symbi-OS/LinuxPrototypes.git
	git clone git@github.com:Symbi-OS/libforku.git

clone_symbiote_linux:
	git clone git@github.com:Symbi-OS/linuxConfigs.git
	git clone git@github.com:Symbi-OS/linux.git -b 5.14-config-gcc12-fix

copy_linux_config:
	cp ./linuxConfigs/5.14/depricate/golden_config_bnx2_pnp ./linux/.config

compile_symbiote_kernel:
	echo "\n" | make -C linux/ oldconfig
	make -C linux/ bzImage -j$$(($$(nproc) - 2))
	make -C linux/ modules
	sudo make -C linux/ modules_install
	sudo make -C linux/ install

grubby_set_kernel_cmdline:
	sudo grubby --update-kernel=/boot/vmlinuz-5.14.0symbiote+ --args="nosmap nosmep nokaslr mitigations=off"

grubby_set_default_kernel:
	sudo grubby --set-default="/boot/vmlinuz-5.14.0symbiote+"

build_core_repos:
	$(MAKE) -C Symlib/
	$(MAKE) -C Tools/

setup_first_time_environment:
	sudo echo "---- Building Symbiote Ecosystem ----"

	$(MAKE) install_dev_tools_fedora

	$(MAKE) clone_core_repos
	$(MAKE) build_core_repos

	$(MAKE) clone_symbiote_linux
	$(MAKE) copy_linux_config
	$(MAKE) compile_symbiote_kernel
	$(MAKE) grubby_set_default_kernel
	$(MAKE) grubby_set_kernel_cmdline

