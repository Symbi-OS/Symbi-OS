SHELL := /bin/bash
.PHONY: help all master install_docker docker_start_service docker_enable_service check-start-service

# Common variables
CONT=linux_builder35
RUN_IN_CONT=sudo docker exec $(CONT)

SERVICE_NAME := docker

KERN_VER=5.14.0-kElevate+
#CONFIG=/root/Symbi-OS/linuxConfigs/5.14/depricate/golden_config_bnx2_pnp

HOME=/root
CONFIG=$(HOME)/linuxConfigs/5.14/USE_ME/symbiote_config
BASELINE_CONFIG=$(HOME)/linuxConfigs/5.14/USE_ME/symbiote_config_off
LINUX_PATH=$(HOME)/linux
NUM_CPUS=$(shell nproc)

help:
	@$(MAKE) help_grubby
	@$(MAKE) help_linux

install_prereqs:
	sudo dnf install -y gcc

# Symlib has to be built first
run_ex: 
	$(MAKE) -C Symlib
	$(MAKE) -C Tools
run_ex:
	rm -rf Symlib Tools LinuxPrototypes
	git clone https://github.com/Symbi-OS/LinuxPrototypes.git
	git clone https://github.com/Symbi-OS/Symlib.git
	git clone https://github.com/Symbi-OS/Tools.git
	$(MAKE) install_prereqs
	$(MAKE) -C Symlib
	$(MAKE) -C Tools

disable_sudo_pw_checking:
	sudo cp /etc/sudoers /etc/sudoers.bak
	echo 'kele ALL=(ALL) NOPASSWD:ALL' | sudo tee -a /etc/sudoers

enable_sudo_pw_checking:
	sudo sed -i.bak '/exampleuser ALL=(ALL) NOPASSWD:ALL/d' /etc/sudoers

master:
	$(MAKE) disable_sudo_pw_checking
	$(MAKE) docker_setup_and_start
	$(MAKE) l_all_kelevate
	$(MAKE) grubby_set_kele_default_reboot
	$(MAKE) enable_sudo_pw_checking

# ====================================================
# Jupyter
# ====================================================

# sudo dnf install python3-notebook mathjax sscg
# pip3 install ipykernel
# sudo dnf install python3-seaborn python3-lxml python3-basemap python3-scikit-image python3-scikit-learn python3-sympy python3-dask+dataframe python3-nltk
# python3 -m ipykernel install --user --name=sym
# jupyter notebook
# Put url into Notebook: Select Notebook kernel


# ====================================================
# Docker
# ====================================================


install_docker:
	sudo dnf install dnf-plugins-core -y
	sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo -y
	sudo dnf install docker-ce docker-ce-cli containerd.io -y

docker_run:
	sudo docker run --network host --privileged -idt --name linux_builder35 fedora:35

docker_restart:
	sudo docker restart linux_builder35

docker_group_install:
	$(RUN_IN_CONT) dnf group install "C Development Tools and Libraries" "Development Tools" -y
	$(RUN_IN_CONT) dnf install -y fedpkg fedora-packager rpmdevtools ncurses-devel pesign grubby openssl-devel bc \
									openssl htop the_silver_searcher redis psmisc ncurses-devel flex bison \
									elfutils-libelf-devel dwarves

# This was on the 2nd line, but why would we need virtualization in the container?
#libvirt @virtualization -y

docker_git_make:
	$(RUN_IN_CONT) dnf install git make -y

# Why would we need symbiote stuff in the container that's just building our kernel?
docker_clone_sym:
	$(RUN_IN_CONT) git clone --recurse-submodules git@github.com:Symbi-OS/Symbi-OS.git

docker_attach:
	sudo docker attach linux_builder35

check-start-service:
	@STATUS=$$(systemctl is-active $(SERVICE_NAME)); \
	if [ "$$STATUS" != "active" ]; then \
		echo "Starting $(SERVICE_NAME)..."; \
		sudo systemctl start $(SERVICE_NAME); \
	else \
		echo "$(SERVICE_NAME) is already running"; \
	fi

docker_start_service:
	$(MAKE) check-start-service

docker_enable_service:
	sudo systemctl enable docker

docker_setup_and_start:
	$(MAKE) install_docker
	$(MAKE) docker_start_service
	$(MAKE) docker_run
	$(MAKE) docker_git_make
	$(MAKE) docker_group_install

# ====================================================
# Linux
# ====================================================



# This is just for building, if you want to develop, you may as well
# pull the whole Symbi-OS repo. 
docker_prep_linux_kelevate_build_only:
	$(RUN_IN_CONT) git clone --branch 5.14-config --single-branch --depth 1 https://github.com/Symbi-OS/linux.git $(HOME)/linux
	$(RUN_IN_CONT) git clone https://github.com/Symbi-OS/linuxConfigs.git  $(HOME)/linuxConfigs

# When in doubt, blow it all away and start over.
l_mrproper:
	$(RUN_IN_CONT) $(MAKE) -C $(LINUX_PATH) mrproper

l_config:
	$(RUN_IN_CONT) cp $(CONFIG) $(LINUX_PATH)/.config
	$(RUN_IN_CONT) $(MAKE) -C $(LINUX_PATH) olddefconfig

l_build:
	$(RUN_IN_CONT) $(MAKE) -C $(LINUX_PATH) EXTRAVERSION='-kElevate' -j$(NUM_CPUS)

l_ins_mods:
	$(RUN_IN_CONT) $(MAKE) -C $(LINUX_PATH) modules_install -j$(NUM_CPUS)

# I think you never want to grab the initrd created in the container.
# But you want the compressed kern w/ the right version. And the sys map.
l_ins_kern:
	$(RUN_IN_CONT) $(MAKE) -C $(LINUX_PATH) install

l_ins:
	$(MAKE) l_ins_mods
	$(MAKE) l_ins_kern

l_cp_kern:
	sudo docker cp $(CONT):/boot/vmlinuz-$(KERN_VER) /boot/

l_cp_mods:
	sudo docker cp $(CONT):/lib/modules/$(KERN_VER) /lib/modules/

l_cp_sys_map:
	sudo docker cp $(CONT):/boot/System.map-$(KERN_VER) /boot/

l_cp_src:
	sudo docker cp $(CONT):$(LINUX_PATH) .

l_chmod_chgrp_src:
	sudo chown -R $(USER) linux
	sudo chgrp -R $(USER) linux

l_cp:
	$(MAKE) l_cp_mods
	$(MAKE) l_cp_kern
	$(MAKE) l_cp_sys_map

# I've been seeing the following error when I run this...
# ERROR: src/skipcpio/skipcpio.c:191:main(): fwrite
l_initrd:
	sudo dracut --kver=$(KERN_VER) --force

# I tested using these with grubby and it failed.
# I think it might be worth a closer look if you want this degree of freedom.
l_sl:
	sudo rm -f /boot/sym_vmlinuz /boot/sym_initramfs
	sudo ln -s /boot/vmlinuz-$(KERN_VER) /boot/sym_vmlinuz
	sudo ln -s /boot/initramfs-$(KERN_VER).img /boot/sym_initramfs

# This is good for a quick rebuild of the kernel.
# You don't need to rebuild modules.
# Trigger sudo early so we don't have to wait for the build.
l_update_kern:
	sudo echo hi
	$(MAKE) l_build
	$(MAKE) l_ins_kern
	$(MAKE) l_cp_kern
	$(MAKE) l_cp_sys_map

l_update_kern_and_reboot:
	sudo echo hi
	$(MAKE) l_update_kern
	sudo reboot

# Long path that does it all.
l_all_kelevate:
	sudo echo hi
	$(MAKE) docker_prep_linux_kelevate_build_only
	$(MAKE) l_mrproper
	$(MAKE) l_config
	$(MAKE) l_build
	$(MAKE) l_ins
	$(MAKE) l_cp
	$(MAKE) l_initrd

l_cp_vmlinux:
	docker cp $(CONT):$(LINUX_PATH)/vmlinux .

grubby_info:
	sudo grubby --info=ALL

boldprint = @printf '\e[1m%s\e[0m\n' $1
help_linux:
	$(call boldprint, 'help_linux')
	@printf '\tl_update_kern\n'
	@printf '\tl_update_kern_and_reboot\n'
	@printf '\tl_cp_vmlinux\n'
	@printf '\n'

help_grubby:
	$(call boldprint, 'help_grubby')
	@printf "\t grubby_info\n"
	@printf "\t grubby_rm_arg kp=<kernel_path> arg=<arg>\n"
	@printf "\t grubby_add_arg kp=<kernel_path> arg=<arg>\n"
	@printf "\t grubby_rm_kern kp=<kernel_path>\n"
	@printf "\t grubby_cp_default kp=<kernel_path> init=<initramfs_path>\n"
	@printf '\n'

grubby_rm_kern:
	sudo grubby --remove-kernel $(kp)

grubby_cp_default:
	sudo grubby --add-kernel=$(kp) --copy-default --title="sym_test" --initrd=$(init)

grubby_set_kele_default_reboot:
	sudo grubby --add-kernel=vmlinuz-5.14.0-kElevate+ --copy-default --title="kele" --initrd=initramfs-5.14.0-kElevate+.img --args="nosmep nosmap nokaslr"
	sudo grubby --set-default=vmlinuz-5.14.0-kElevate+
	sudo reboot

grubby_get_default:
	sudo grubby --default-kernel

grubby_rm_arg:
	sudo grubby --update-kernel=$(kp) --remove-arg=$(arg)

grubby_add_arg:
	sudo grubby --update-kernel=$(kp) --arg=$(arg)

# Linux install already created the entry, we just edit it.
config_grub_sym: /boot/vmlinuz-5.14.0-symbiote+
	sudo grubby --remove-args="" --args="mitigations=off nosmep nosmap isolcpus=0" --update-kernel /boot/vmlinuz-5.14.0-symbiote+

# ====================================================
