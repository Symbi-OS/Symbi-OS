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
get_linux_configs:
	git clone git@github.com:Symbi-OS/linuxConfigs.git

get_sym_linux:
	git clone --depth 5 -b 5.14-config git@github.com:Symbi-OS/linux.git


build_linux_kernel: linux linuxConfigs
	cp ./linuxConfigs/5.14/golden_config_bnx2_pnp ./linux/.config
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

REDIS_CMD=artifacts/redis/redis-server --protected-mode no --save '' --appendonly no
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
	${TASKSET_CMD} 'shortcut.sh -be -s "write->ksys_write" --- ${REDIS_CMD}' 

run_redis_sc_read:
	${TASKSET_CMD} 'shortcut.sh -be -s "read->ksys_read" --- ${REDIS_CMD}' 

run_redis_sc_rw:
	${TASKSET_CMD} 'shortcut.sh -be -s "write->ksys_write" -s "read->ksys_read" --- ${REDIS_CMD}' 