SHELL := /bin/bash
.PHONY: help all master install_docker docker_start_service docker_enable_service check-start-service

# ========================
# Help targets
# ========================
help: help_all help_docker help_linux help_grubby

boldprint = @printf '\e[1m%s\e[0m\n' $1

help_all:
	$(call boldprint, '===== Kernels to Build =====')
	@printf '\tall_master - Build all kernels\n'
	@printf '\t5.14.0\t\t\t- 5.14.0 kernel\n'
	@printf '\t5.14.0-kelevate\t\t\t- 5.14.0 kernel with kelevate\n'
	@printf '\t6.3.0\t\t\t- 6.3.0 kernel\n'
	@printf '\t6.3.0-kelevate\t\t\t- 6.3.0 kernel with kelevate\n'

# ========================
# Master target
# ========================
all_master: 5.14.0 5.14.0-kElevate 6.3.0

master: disable_sudo_pw_checking docker_setup_and_start l_all grubby_add_kern enable_sudo_pw_checking

master_clean:
	- sudo rm -rf /lib/modules/5.14.0+
	- sudo rm -rf /lib/modules/5.14.0-kElevate+
	- sudo rm -rf /lib/modules/6.3.0
	- sudo rm -rf /lib/modules/6.3.0-kElevate
	- sudo rm /boot/*5.14.0*
	- sudo rm /boot/*6.3.0*
	- $(MAKE) grubby_rm_kern kp=/boot/vmlinuz-5.14.0+
	- $(MAKE) grubby_rm_kern kp=/boot/vmlinuz-5.14.0-kElevate+
	- $(MAKE) grubby_rm_kern kp=/boot/vmlinuz-6.3.0
	- $(MAKE) grubby_rm_kern kp=/boot/vmlinuz-6.3.0-kElevate

# ========================
# Kernel targets
# ========================
6.3.0: FEDORA_RELEASE=38
6.3.0: KERN_REL=6.3.0
6.3.0: KERN_EXTRAVERSION=
6.3.0: LINUX_BUILD=--branch 6.3 --single-branch --depth 1 
6.3.0: KERN_VER=$(KERN_REL)$(KERN_EXTRAVERSION) # No "+" because it's on a tagged commit
6.3.0: CONFIG=$(HOME)/linuxConfigs/5.14/USE_ME/symbiote_config_off

6.3.0: master

# Not yet implemented in the kernel
6.3.0-kElevate: FEDORA_RELEASE=38
6.3.0-kElevate: KERN_REL=6.3.0
6.3.0-kElevate: KERN_EXTRAVERSION=-kElevate
6.3.0-kElevate: LINUX_BUILD=--branch 6.3 --single-branch --depth 1
6.3.0-kElevate: KERN_VER=$(KERN_REL)$(KERN_EXTRAVERSION)+
6.3.0-kElevate: CONFIG=$(HOME)/linuxConfigs/5.14/USE_ME/symbiote_config

6.3.0-kElevate: master

# Baseline 5.14 kernel. Tested up & not including boot.
5.14.0: FEDORA_RELEASE=35
5.14.0: KERN_REL=5.14.0
5.14.0: KERN_EXTRAVERSION=
5.14.0: LINUX_BUILD=--branch 5.14-config --single-branch --depth 1 
5.14.0: KERN_VER=$(KERN_REL)$(KERN_EXTRAVERSION)+
5.14.0: CONFIG=$(HOME)/linuxConfigs/5.14/USE_ME/symbiote_config_off

5.14.0: master

# 5.14 kernel with kElevate patches
# Tested this one, works up to trying to boot the kernel.
5.14.0-kElevate: FEDORA_RELEASE=35
5.14.0-kElevate: KERN_REL=5.14.0
5.14.0-kElevate: KERN_EXTRAVERSION=-kElevate
5.14.0-kElevate: LINUX_BUILD=--branch 5.14-config --single-branch --depth 1 
5.14.0-kElevate: KERN_VER=$(KERN_REL)$(KERN_EXTRAVERSION)+
5.14.0-kElevate: CONFIG=$(HOME)/linuxConfigs/5.14/USE_ME/symbiote_config

5.14.0-kElevate: master

# Note, I think the + is appended to the kernel if 1) there are uncomitted changes in the 
# git repo where it was built, or if it was built on a non-tagged commit.
# I'm using the convention here that there will only be an extraversion if we're building a
# kelevate kernel. Otherwise assuming it's a tagged baseline kernel.

armport: FEDORA_RELEASE=35
armport: KERN_REL=5.14.0
armport: KERN_EXTRAVERSION=-kElevate
armport: LINUX_BUILD=--branch aarch64 --single-branch --depth 1
armport: KERN_VER=$(KERN_REL)$(KERN_EXTRAVERSION)+
armport: CONFIG=$(HOME)/linuxConfigs/5.14/USE_ME/ARLO_DEFCONFIG_PLUS
armport: VICTIM=root@192.168.122.161

armport: disable_sudo_pw_checking l_config l_build l_ins l_cp l_initrd enable_sudo_pw_checking
#armport: disable_sudo_pw_checking l_mrproper l_config l_build l_ins l_cp l_initrd grubby_add_kern_arm enable_sudo_pw_checking

# ========================
# Common variables
# ========================
CONT=linux_builder$(FEDORA_RELEASE)
RUN_IN_CONT=sudo docker exec $(CONT)

HOME=/root
LINUX_PATH=$(HOME)/linux
NUM_CPUS=$(shell nproc)

install_prereqs:
	sudo dnf install -y gcc

# Symlib has to be built first
build_symlib_tools:
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
	sudo sed -i.bak '/kele ALL=(ALL) NOPASSWD:ALL/d' /etc/sudoers

# ====================================================
# Docker
# ====================================================

# [root@fedora linux]# git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
# [root@fedora linux]# git fetch --unshallow

CONTAINER_PACKAGES=fedpkg fedora-packager rpmdevtools ncurses-devel pesign grubby openssl-devel bc \
					openssl htop the_silver_searcher redis psmisc ncurses-devel flex bison \
					elfutils-libelf-devel dwarves

help_docker:
	$(call boldprint, '===== Docker Management Targets =====')
	@printf '\tinstall_docker\t\t\t- Install Docker and its dependencies\n'
	@printf '\tdocker_start_service\t\t- Start the Docker service\n'
	@printf '\tdocker_enable_service\t\t- Enable the Docker service\n'
	@printf '\tdocker_setup_and_start\t\t- Install Docker, start and enable the service, and create a container\n'
	@printf '\n'

install_docker:
	sudo dnf install dnf-plugins-core -y
	sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo -y
	sudo dnf install docker-ce docker-ce-cli containerd.io -y

docker_run:
	@if [ -z "$$(sudo docker ps -a -q -f name=$(CONT))" ]; then \
		sudo docker run --network host --privileged -idt --name $(CONT) fedora:$(FEDORA_RELEASE); \
	else \
		echo "Container $(CONT) already exists."; \
		sudo docker restart $(CONT); \
	fi

docker_restart:
	sudo docker restart $(CONT)

docker_install_dev_packages:
	$(RUN_IN_CONT) dnf group install "C Development Tools and Libraries" "Development Tools" -y
	$(RUN_IN_CONT) dnf install -y $(CONTAINER_PACKAGES)

docker_install_git_make:
	$(RUN_IN_CONT) dnf install git make -y

docker_attach:
	sudo docker attach $(CONT)

docker_rm:
	sudo docker rm $(CONT)

SERVICE_NAME := docker
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

add_to_docker_group:
	@if ! groups $${USER} | grep -q -w "docker"; then \
		echo "Adding $${USER} to the docker group..."; \
		sudo usermod -aG docker $${USER}; \
		echo "Done! Log out and log back in for the changes to take effect."; \
	else \
		echo "User $${USER} is already in the docker group."; \
	fi

docker_setup_and_start: install_docker docker_start_service docker_enable_service add_to_docker_group docker_run docker_install_git_make docker_install_dev_packages

# ====================================================
# Linux
# ====================================================

help_linux:
	$(call boldprint, '===== Linux Build and Update Targets =====')
	@printf '\tl_update_kern\t\t\t- Build and update the kernel\n'
	@printf '\tl_update_kern_and_reboot\t\t- Build and update the kernel, then reboot\n'
	@printf '\tl_cp_vmlinux\t\t\t- Copy vmlinux from the container to the host\n'
	@printf '\n'

# This is a bit of a mess, we're just trying to pull the repo if it doesn't alreay exist.
# Maybe easier to just ignore the error?
docker_prepare_linux_build:
	$(RUN_IN_CONT) sh -c 'if [ ! -d "$(HOME)/linux" ]; then \
		git clone $(LINUX_BUILD) https://github.com/Symbi-OS/linux.git $(HOME)/linux; \
	else \
		echo "$(HOME)/linux directory already exists."; \
	fi'
	$(RUN_IN_CONT) sh -c 'if [ ! -d "$(HOME)/linuxConfigs" ]; then \
		git clone https://github.com/Symbi-OS/linuxConfigs.git $(HOME)/linuxConfigs; \
	else \
		echo "$(HOME)/linuxConfigs directory already exists."; \
	fi'

# When in doubt, blow it all away and start over.
l_mrproper:
	$(RUN_IN_CONT) $(MAKE) -C $(LINUX_PATH) mrproper

l_config:
	$(RUN_IN_CONT) cp $(CONFIG) $(LINUX_PATH)/.config
	$(RUN_IN_CONT) $(MAKE) -C $(LINUX_PATH) olddefconfig

# XXX we're using defconfig for now for a fast build.
# l_config:
# 	$(RUN_IN_CONT) $(MAKE) -C $(LINUX_PATH) defconfig

l_build:
	$(RUN_IN_CONT) $(MAKE) -C $(LINUX_PATH) EXTRAVERSION='$(KERN_EXTRAVERSION)' -j$(NUM_CPUS)
	$(RUN_IN_CONT) $(MAKE) -C $(LINUX_PATH) EXTRAVERSION='$(KERN_EXTRAVERSION)' -j$(NUM_CPUS) modules

l_ins_mods:
	$(RUN_IN_CONT) $(MAKE) -C $(LINUX_PATH) modules_install -j$(NUM_CPUS)

# I think you never want to grab the initrd created in the container.
# But you want the compressed kern w/ the right version. And the sys map.
l_ins_kern:
	$(RUN_IN_CONT) $(MAKE) -C $(LINUX_PATH) install

l_ins: l_ins_mods l_ins_kern

l_cp_src:
	sudo docker cp $(CONT):$(LINUX_PATH) .

l_chmod_chgrp_src:
	sudo chown -R $(USER) linux
	sudo chgrp -R $(USER) linux

l_cp:
	sudo docker cp $(CONT):/lib/modules/$(KERN_VER) /lib/modules/
	sudo docker cp $(CONT):/boot/vmlinuz-$(KERN_VER) /boot/
	sudo docker cp $(CONT):/boot/System.map-$(KERN_VER) /boot/

l_scp:
	sudo rsync --progress -av -e ssh /lib/modules/$(KERN_VER) $(VICTIM):/lib/modules/
	sudo scp /boot/vmlinuz-$(KERN_VER) $(VICTIM):/boot/
	sudo scp /boot/System.map-$(KERN_VER) $(VICTIM):/boot/
	sudo scp /boot/initramfs-$(KERN_VER).img $(VICTIM):/boot/

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
l_update_kern: l_build l_ins_kern l_cp_kern l_cp_sys_map

l_update_kern_and_reboot: l_update_kern
	sudo reboot

# Long path that does it all.
l_all: docker_prepare_linux_build l_mrproper l_config l_build l_ins l_cp l_initrd

l_cp_vmlinux:
	docker cp $(CONT):$(LINUX_PATH)/vmlinux .

# ====================================================
# Grubby
# ====================================================

help_grubby:
	$(call boldprint, '===== Grubby Management Targets =====')
	@printf "\tgrubby_info\t\t\t- Display information about all available kernels\n"
	@printf "\tgrubby_rm_kern kp=<kernel_path>\t- Remove the specified kernel\n"
	@printf "\tgrubby_cp_default kp=<kernel_path> init=<initramfs_path>\t- Copy default kernel with specified initramfs\n"
	@printf "\tgrubby_set_kele_default_and_reboot\t- Add kele kernel, set it as default and reboot\n"
	@printf "\tgrubby_get_default\t\t- Display the default kernel\n"
	@printf "\tgrubby_rm_arg kp=<kernel_path> arg=<arg>\t- Remove an argument from the specified kernel\n"
	@printf "\tgrubby_add_arg kp=<kernel_path> arg=<arg>\t- Add an argument to the specified kernel\n"
	@printf '\n'

grubby_info:
	sudo grubby --info=ALL

grubby_rm_kern:
	sudo grubby --remove-kernel $(kp)

grubby_cp_default:
	sudo grubby --add-kernel=$(kp) --copy-default --title="sym_test" --initrd=$(init)

grubby_add_kern:
	sudo grubby --add-kernel=vmlinuz-$(KERN_VER) --copy-default --title="$(KERN_VER)" --initrd=initramfs-$(KERN_VER).img --args="nosmep nosmap nokaslr nopti"

grubby_add_kern_arm:
	sudo grubby --add-kernel=vmlinuz-$(KERN_VER) --copy-default --title="$(KERN_VER)" --initrd=initramfs-$(KERN_VER).img

grubby_set_kele_default_and_reboot:
	sudo grubby --add-kernel=vmlinuz-$(KERN_VER) --copy-default --title="$(KERN_VER)" --initrd=initramfs-$(KERN_VER).img --args="nosmep nosmap nokaslr nopti"
	sudo grubby --set-default=vmlinuz-$(KERN_VER)
	sudo reboot

grubby_get_default:
	sudo grubby --default-kernel

grubby_rm_arg:
	sudo grubby --update-kernel=$(kp) --remove-arg=$(arg)

grubby_add_arg:
	sudo grubby --update-kernel=$(kp) --arg=$(arg)

# ====================================================

# ====================================================
# Jupyter
# ====================================================

# sudo dnf install python3-notebook mathjax sscg
# pip3 install ipykernel
# sudo dnf install python3-seaborn python3-lxml python3-basemap python3-scikit-image python3-scikit-learn python3-sympy python3-dask+dataframe python3-nltk
# python3 -m ipykernel install --user --name=sym
# jupyter notebook
# Put url into Notebook: Select Notebook kernel
