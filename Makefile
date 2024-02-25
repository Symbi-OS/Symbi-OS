SHELL := /bin/bash

# ANSI color codes
RED := "\033[1;31m"
GREEN := "\033[1;32m"
YELLOW := "\033[1;33m"
BOLD := "\033[1m"
NO_COLOR := "\033[0m"

DEV_PACKAGES := fedpkg fedora-packager rpmdevtools ncurses-devel pesign grubby openssl-devel bc \
					openssl htop the_silver_searcher redis psmisc ncurses-devel flex bison \
					elfutils-libelf-devel dwarves

help:
	@printf "%b%b######################################################################%b\n" $(BOLD) $(YELLOW) $(NO_COLOR)
	@printf "%b%b#       [+] ------ Welcome to the Symbiote Project ------ [+]        #%b\n" $(BOLD) $(YELLOW) $(NO_COLOR)
	@printf "%b%b######################################################################%b\n\n" $(BOLD) $(YELLOW) $(NO_COLOR)

	@printf "########################################################################\n"
	@printf "#%b%b setup_first_time_environment:%b                                        #\n" $(BOLD) $(YELLOW) $(NO_COLOR)
	@printf "# - Description: Performs all necessary steps to set up a new Symbiote #\n"
	@printf "#   development environment, including installing development tools,   #\n"
	@printf "#   cloning core and experimental repositories, building the Symbiote  #\n"
	@printf "#   kernel, and configuring boot arguments.                            #\n"
	@printf "########################################################################%b\n\n" $(NO_COLOR)

	@printf "########################################################################\n"
	@printf "#%b%b clone_and_build_symbiote_kernel:%b                                     #\n" $(BOLD) $(YELLOW) $(NO_COLOR)
	@printf "# - Description: Clones the Symbiote Linux kernel and configuration,   #\n"
	@printf "#   compiles the kernel, and updates the GRUB bootloader to use the    #\n"
	@printf "#   newly compiled kernel with specific command line arguments.        #\n"
	@printf "########################################################################\n\n"

	@printf "########################################################################\n"
	@printf "#%b%b install_dev_tools_fedora:%b                                            #\n" $(BOLD) $(YELLOW) $(NO_COLOR)
	@printf "# - Description: Installs the C development tools and libraries,       #\n"
	@printf "#   along with other necessary development packages listed in          #\n"
	@printf "#   DEV_PACKAGES, on a Fedora system.                                  #\n"
	@printf "########################################################################%b\n\n" $(NO_COLOR)

	@printf "\n"

install_dev_tools_fedora:
	sudo dnf group install "C Development Tools and Libraries" "Development Tools" -y
	sudo dnf install -y $(DEV_PACKAGES)

clone_core_repos:
	git clone git@github.com:Symbi-OS/Symlib.git
	git clone git@github.com:Symbi-OS/Tools.git
	git clone git@github.com:Symbi-OS/testing-hub.git

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
	sudo grubby --update-kernel=/boot/vmlinuz-5.14.0+ --args="nosmap nosmep nokaslr mitigations=off"

grubby_set_default_kernel:
	sudo grubby --set-default="/boot/vmlinuz-5.14.0+"

build_core_repos:
	$(MAKE) -C Symlib/
	$(MAKE) -C Tools/

clone_and_build_symbiote_kernel:
	$(MAKE) clone_symbiote_linux
	$(MAKE) copy_linux_config
	$(MAKE) compile_symbiote_kernel
	$(MAKE) grubby_set_default_kernel
	$(MAKE) grubby_set_kernel_cmdline

setup_first_time_environment:
	sudo echo "---- Building Symbiote Ecosystem ----"

	$(MAKE) install_dev_tools_fedora

	$(MAKE) clone_core_repos
	$(MAKE) build_core_repos

	$(MAKE) clone_and_build_symbiote_kernel

