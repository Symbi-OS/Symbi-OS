SHELL := /bin/bash
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

KERN_VER=5.14.0-symbiote_ist+
CONT=linux_builder35
CONFIG=/root/Symbi-OS/linuxConfigs/5.14/depricate/golden_config_bnx2_pnp
LINUX_PATH=/root/Symbi-OS/linux


# When in doubt, blow it all away and start over.
l_mrproper:
	docker exec $(CONT) make -C $(LINUX_PATH) mrproper

l_config:
	docker exec $(CONT) cp $(CONFIG) $(LINUX_PATH)/.config
	docker exec $(CONT) make -C $(LINUX_PATH) olddefconfig

l_build:
	docker exec $(CONT) make -C $(LINUX_PATH) -j79

l_ins_mods:
	docker exec $(CONT) make -C $(LINUX_PATH) modules_install -j79

# I think you never want to grab the initrd created in the container.
# But you want the compressed kern w/ the right version. And the sys map.
l_ins_kern:
	docker exec $(CONT) make -C $(LINUX_PATH) install


l_ins:
	make l_ins_mods
	make l_ins_kern

l_cp_kern:
	sudo docker cp $(CONT):/boot/vmlinuz-$(KERN_VER) /boot/

l_cp_mods:
	sudo docker cp $(CONT):/lib/modules/$(KERN_VER) /lib/modules/

l_cp_sys_map:
	sudo docker cp $(CONT):/boot/System.map-$(KERN_VER) /boot/

l_cp:
	make l_cp_mods
	make l_cp_kern
	make l_cp_sys_map

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
	make l_build
	make l_ins_kern
	make l_cp_kern
	make l_cp_sys_map

l_update_kern_and_reboot:
	sudo echo hi
	make l_update_kern
	sudo reboot

# Long path that does it all.
l_all:
	sudo echo hi
	make l_mrproper
	make l_config
	make l_build
	make l_ins
	make l_cp
	make l_initrd

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
	@printf "\t grubby_rm_arg kp=<kernel_path> arg=<arg>\n"
	@printf "\t grubby_add_arg kp=<kernel_path> arg=<arg>\n"
	@printf "\t grubby_rm_kern kp=<kernel_path>\n"
	@printf "\t grubby_cp_default kp=<kernel_path> init=<initramfs_path>\n"
	@printf '\n'

help:
	@make help_grubby
	@make help_linux

grubby_rm_kern:
	sudo grubby --remove-kernel $(kp)

grubby_cp_default:
	sudo grubby --add-kernel=$(kp) --copy-default --title="sym_test" --initrd=$(init)

grubby_rm_arg:
	sudo grubby --update-kernel=$(kp) --remove-arg=$(arg)

grubby_add_arg:
	sudo grubby --update-kernel=$(kp) --arg=$(arg)


# Linux install already created the entry, we just edit it.
config_grub_sym: /boot/vmlinuz-5.14.0-symbiote+
	sudo grubby --remove-args="" --args="mitigations=off nosmep nosmap isolcpus=0" --update-kernel /boot/vmlinuz-5.14.0-symbiote+

# ====================================================

linux_kernel_clean:
	cd linux && make clean

clean: linux_kernel_clean

build_expt:
	make -C Symlib/ clean
	make -C Symlib/
	make -C Tools/ clean
	make -C Tools/
	make -C Tools/ mitigate

run_taskset_long:
	taskset -c 0 bash -c 'make -C LinuxPrototypes/write_loop run_elev_sc_wr_only_long'

run_taskset_elev_long:
	taskset -c 0 bash -c 'make -C LinuxPrototypes/write_loop run_elev_long'

run_taskset: build_expt
	taskset -c 0 bash -c 'make -C LinuxPrototypes/write_loop '

run_taskset_no_build: 
	taskset -c 0 bash -c 'make -C LinuxPrototypes/write_loop all'

run_write_expt: build_expt
	make -C LinuxPrototypes/write_loop all

run_read_expt: build_expt
	make -C LinuxPrototypes/read_loop all

install_prereqs:
	sudo apt-get install gcc flex bison build-essential libelf-dev libssl-dev

REDIS_CMD=artifacts/redis/fed36/redis-server --protected-mode no --save '' --appendonly no

TASKSET_CMD=taskset -c 0 bash -c

run_redis:
	${TASKSET_CMD} '${REDIS_CMD}' 

run_redis_passthrough:
	${TASKSET_CMD} 'shortcut.sh -p --- ${REDIS_CMD}' 

run_redis_interpose:
	${TASKSET_CMD} 'shortcut.sh --- ${REDIS_CMD}' 

run_redis_elev:
	${TASKSET_CMD} 'shortcut.sh -be --- ${REDIS_CMD}' 

run_redis_sc_write:
	${TASKSET_CMD} 'shortcut.sh -be -s "write->__x64_sys_write" --- ${REDIS_CMD}' 

run_redis_sc_read:
	${TASKSET_CMD} 'shortcut.sh -be -s "read->__x64_sys_read" --- ${REDIS_CMD}' 

run_redis_sc_rw:
	${TASKSET_CMD} 'shortcut.sh -be -s "write->__x64_sys_write" -s "read->__x64_sys_read" --- ${REDIS_CMD}' 

run_redis_tcp:
	${TASKSET_CMD} 'shortcut.sh -be -s "write->tcp_sendmsg" --- ${REDIS_CMD}' 

prepare:
	ip addr add 192.168.122.238/24 dev enp1s0
	ip link set up enp1s0
	sudo systemctl mask systemd-journald
	sudo systemctl stop systemd-journald
	sudo systemctl stop systemd-udevd
	. prep_envt.sh
	mitigate all
cmd:
	LD_LIBRARY_PATH=/home/sym/Symbi-OS/Symlib/dynam_build  BEGIN_ELE=1 SHORTCUT_write_TO_ksys_write=1 SHORTCUT_read_TO_ksys_read=1 LD_PRELOAD=/home/sym/Symbi-OS/Tools/bin/shortcut/sc_lib.so  artifacts/redis/redis-server --protected-mode no --save  --appendonly no

fix:
	sudo systemctl unmask systemd-journald
	sudo systemctl start systemd-journald

#taskset -c 0 bash -c shortcut.sh -p --- ./LinuxPrototypes/getpid/getpid 1000000

