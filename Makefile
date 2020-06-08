CROSS_FLAGS = ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
CROSS_FLAGS_BOOT = CROSS_COMPILE=aarch64-linux-gnu-
CROSS_FLAGS_SCP = HOST_COMPILE=aarch64-linux-gnu- CROSS_COMPILE=or1k-elf-

all: pine64-pinephone.img.xz pine64-pinetab.img.xz


pine64-pinephone.img: fat-pine64-pinephone.img u-boot-sunxi-with-spl.bin
	rm -f $@
	truncate --size 50M $@
	parted -s $@ mktable msdos
	parted -s $@ mkpart primary fat32 2048s 100%
	parted -s $@ set 1 boot on
	dd if=u-boot-sunxi-with-spl.bin of=$@ bs=8k seek=1
	dd if=fat-$@ of=$@ seek=1024 bs=1k

fat-pine64-pinephone.img: initramfs-pine64-pinephone.gz kernel-sunxi.gz pine64-pinephone.scr dtbs/sunxi/sun50i-a64-pinephone.dtb
	@echo "MKFS  $@"
	@rm -f $@
	@truncate --size 40M $@
	@mkfs.fat -F32 $@
	
	@mcopy -i $@ kernel-sunxi.gz ::Image.gz
	@mcopy -i $@ dtbs/sunxi/sun50i-a64-pinephone.dtb ::sun50i-a64-pinephone.dtb
	@mcopy -i $@ initramfs-pine64-pinephone.gz ::initramfs.gz
	@mcopy -i $@ pine64-pinephone.scr ::boot.scr

pine64-pinetab.img: fat-pine64-pinetab.img u-boot-sunxi-with-spl.bin
	rm -f $@
	truncate --size 50M $@
	parted -s $@ mktable msdos
	parted -s $@ mkpart primary fat32 2048s 100%
	parted -s $@ set 1 boot on
	dd if=u-boot-sunxi-with-spl.bin of=$@ bs=8k seek=1
	dd if=fat-$@ of=$@ seek=1024 bs=1k

fat-pine64-pinetab.img: initramfs-pine64-pinetab.gz kernel-sunxi.gz pine64-pinetab.scr dtbs/sunxi/sun50i-a64-pinetab.dtb
	@echo "MKFS  $@"
	@rm -f $@
	@truncate --size 40M $@
	@mkfs.fat -F32 $@
	
	@mcopy -i $@ kernel-sunxi.gz ::Image.gz
	@mcopy -i $@ dtbs/sunxi/sun50i-a64-pinetab.dtb ::sun50i-a64-pinetab.dtb
	@mcopy -i $@ initramfs-pine64-pinetab.gz ::initramfs.gz
	@mcopy -i $@ pine64-pinetab.scr ::boot.scr

pine64-pinebookpro.img: fat-pine64-pinebookpro.img u-boot-rk3399.bin
	rm -f $@
	truncate --size 50M $@
	parted -s $@ mktable msdos
	parted -s $@ mkpart primary fat32 32768s 100%
	parted -s $@ set 1 boot on
	dd if=u-boot-rk3399.bin of=$@ bs=32k seek=1
	dd if=fat-$@ of=$@ seek=32768 bs=512

fat-pine64-pinebookpro.img: initramfs-pine64-pinebookpro.gz kernel-rockchip.gz src/pine64-pinebookpro.conf dtbs/rockchip/rk3399-pinebook-pro.dtb
	@echo "MKFS  $@"
	@rm -f $@
	@truncate --size 40M $@
	@mkfs.fat -F32 $@
	
	@mcopy -i $@ kernel-rockchip.gz ::Image.gz
	@mcopy -i $@ dtbs/rockchip/rk3399-pinebook-pro.dtb ::rk3399-pinebook-pro.dtb
	@mcopy -i $@ initramfs-pine64-pinebookpro.gz ::initramfs.gz
	@mmd   -i $@ extlinux
	@mcopy -i $@ src/pine64-pinebookpro.conf ::extlinux/extlinux.conf

%.img.xz: %.img
	@echo "XZ    $@"
	@xz -c $< > $@

initramfs/bin/busybox: src/busybox src/busybox_config
	@echo "MAKE  $@"
	@mkdir -p build/busybox
	@cp src/busybox_config build/busybox/.config
	@$(MAKE) -C src/busybox O=../../build/busybox $(CROSS_FLAGS)
	@cp build/busybox/busybox initramfs/bin/busybox
	
splash/%.ppm.gz: splash/%.ppm
	@echo "GZ    $@"
	@gzip < $< > $@
	
initramfs-%.cpio: initramfs/bin/busybox initramfs/init initramfs/init_functions.sh splash/%.ppm.gz splash/%-error.ppm.gz
	@echo "CPIO  $@"
	@rm -rf initramfs-$*
	@cp -r initramfs initramfs-$*
	@cp src/info-$*.sh initramfs-$*/info.sh
	@cp splash/$*.ppm.gz initramfs-$*/splash.ppm.gz
	@cp splash/$*-error.ppm.gz initramfs-$*/error.ppm.gz
	@cp src/info-$*.sh initramfs-$*/info.sh
	@cd initramfs-$*; find . | cpio -H newc -o > ../$@
	
initramfs-%.gz: initramfs-%.cpio
	@echo "GZ    $@"
	@gzip < $< > $@
	
kernel-sunxi.gz dtbs/sunxi/sun50i-a64-pinephone.dtb dtbs/sunxi/sun50i-a64-pinetab.dtb &: src/linux_config_sunxi
	@echo "MAKE  kernel-sunxi.gz"
	@mkdir -p build/linux-sunxi
	@mkdir -p dtbs/sunxi
	@cp src/linux_config_sunxi build/linux-sunxi/.config
	@$(MAKE) -C src/linux O=../../build/linux-sunxi $(CROSS_FLAGS) olddefconfig
	@$(MAKE) -C src/linux O=../../build/linux-sunxi $(CROSS_FLAGS)
	@cp build/linux-sunxi/arch/arm64/boot/Image.gz kernel-sunxi.gz
	@cp build/linux-sunxi/arch/arm64/boot/dts/allwinner/*.dtb dtbs/sunxi/

kernel-rockchip.gz: src/linux_config_rockchip src/linux-rockchip
	@echo "MAKE  $@"
	@mkdir -p build/linux-rockchip
	@mkdir -p dtbs/rockchip
	@cp src/linux_config_rockchip build/linux-rockchip/.config
	@$(MAKE) -C src/linux-rockchip O=../../build/linux-rockchip $(CROSS_FLAGS) olddefconfig
	@$(MAKE) -C src/linux-rockchip O=../../build/linux-rockchip $(CROSS_FLAGS)
	@cp build/linux-rockchip/arch/arm64/boot/Image.gz $@
	@cp build/linux-rockchip/arch/arm64/boot/dts/rockchip/*.dtb dtbs/rockchip/

%.scr: src/%.txt
	@echo "MKIMG $@"
	@mkimage -A arm -O linux -T script -C none -n "U-Boot boot script" -d $< $@
	
build/atf/sun50i_a64/bl31.bin:
	@echo "MAKE  $@"
	@mkdir -p build/atf/sun50i_a64
	@cd src/arm-trusted-firmware; make $(CROSS_FLAGS_BOOT) PLAT=sun50i_a64 bl31
	@cp src/arm-trusted-firmware/build/sun50i_a64/release/bl31.bin "$@"

build/crust/scp/scp.bin:
	@echo "MAKE  $@"
	@mkdir -p build/crust/scp
	@cd src/crust; make $(CROSS_FLAGS_SCP) pinephone_defconfig
	@cd src/crust; make $(CROSS_FLAGS_SCP) scp
	@cp src/crust/build/scp/scp.bin "$@"

u-boot-sunxi-with-spl.bin: build/atf/sun50i_a64/bl31.bin build/crust/scp/scp.bin
	@echo "MAKE  $@"
	@mkdir -p build/u-boot/sun50i_a64
	@BL31=../../../build/atf/sun50i_a64/bl31.bin SCP=../../../build/crust/scp/scp.bin $(MAKE) -C src/u-boot O=../../build/u-boot/sun50i_a64 $(CROSS_FLAGS_BOOT) pinephone_defconfig
	@BL31=../../../build/atf/sun50i_a64/bl31.bin SCP=../../../build/crust/scp/scp.bin $(MAKE) -C src/u-boot O=../../build/u-boot/sun50i_a64 $(CROSS_FLAGS_BOOT) ARCH=arm all
	@cp build/u-boot/sun50i_a64/u-boot-sunxi-with-spl.bin "$@"

build/atf/rk3399/bl31.elf:
	@echo "MAKE  $@"
	@mkdir -p build/atf/rk3399
	@cd src/arm-trusted-firmware; make $(CROSS_FLAGS_BOOT) PLAT=rk3399 bl31
	@cp src/arm-trusted-firmware/build/sun50i_a64/release/bl31/bl31.elf "$@"

u-boot-rk3399.bin: build/atf/rk3399/bl31.elf
	@echo "MAKE  $@"
	@mkdir -p build/u-boot/rk3399
	@BL31=../../../build/atf/rk3399/bl31.elf $(MAKE) -C src/u-boot O=../../build/u-boot/rk3399 $(CROSS_FLAGS_BOOT) rockpro64-rk3399_defconfig
	@BL31=../../../build/atf/rk3399/bl31.elf $(MAKE) -C src/u-boot O=../../build/u-boot/rk3399 $(CROSS_FLAGS_BOOT) all
	@cp build/u-boot/rk3399/u-boot "$@"

src/linux-rockchip:
	@echo "WGET  linux-rockchip"
	@mkdir src/linux-rockchip
	@wget https://gitlab.manjaro.org/tsys/linux-pinebook-pro/-/archive/v5.6/linux-pinebook-pro-v5.6.tar.gz
	@tar -xvf linux-pinebook-pro-v5.6.tar.gz --strip-components 1 -C src/linux-rockchip


.PHONY: clean cleanfast

cleanfast:
	@rm -rvf build
	@rm -rvf initramfs-*/
	@rm -vf *.img
	@rm -vf *.img.xz
	@rm -vf *.apk
	@rm -vf *.bin
	@rm -vf *.cpio
	@rm -vf *.gz
	@rm -vf *.scr
	@rm -vf splash/*.gz

clean: cleanfast
	@rm -vf kernel*.gz
	@rm -vf initramfs/bin/busybox
	@rm -vrf dtbs
