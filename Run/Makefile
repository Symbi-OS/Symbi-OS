fs: ../misc/initramfs/x86-busybox/
	sudo cp -ar $< ./fs

# Take filesystem and create cpio archive of it
fs.cpio: fs
# Would love somone to explain why this must be done from inside the dir
	cd $< && find . | cpio -H newc -o > ../fs.cpio

INITRD=fs.igz
# Needs to be compressed
fs.igz: fs.cpio
	cat $< | gzip > $(INITRD)

KERNEL=kernel-image
kernel:	../linux/arch/x86/boot/bzImage 
	cp $< $(KERNEL)

run_vm: fs.igz
	sudo qemu-system-x86_64 -s -enable-kvm -smp 1 -m 10G -kernel $(KERNEL) -initrd $(INITRD) -nodefaults -nographic -serial stdio -append "console=ttyS0 root=/dev/ram0 rw mds=off -- 100000000"

clean:
	rm -rf fs.cpio fs.igz kernel-image fs
