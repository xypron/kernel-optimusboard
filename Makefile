TAG=4.5

all: prepare build copy

prepare:
	test -d linux || git clone -v \
	https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git \
	linux
	cd linux && git fetch
	gpg --list-keys 79BE3E4300411886 || \
	gpg --keyserver keys.gnupg.net --recv-key 79BE3E4300411886
	gpg --list-keys 38DBBDC86092693E || \
	gpg --keyserver keys.gnupg.net --recv-key 38DBBDC86092693E

build:
	cd linux && git verify-tag v$(TAG) 2>&1 | \
	grep '647F 2865 4894 E3BD 4571  99BE 38DB BDC8 6092 693E' || \
	git verify-tag v$(TAG) 2>&1 | \
	grep 'ABAF 11C6 5A29 70B1 30AB  E3C4 79BE 3E43 0041 1886'
	cd linux && git checkout v$(TAG)
	cd linux && ( git branch -D build || true )
	cd linux && git checkout -b build
	cd linux && (test ! -x ../patch/patch-$(TAG) || ../patch/patch-$(TAG) )
	cp config/config-$(TAG) linux/.config
	cd linux && make oldconfig
	rm -f linux/arch/arm/boot/zImage
	cd linux && make -j6 zImage modules dtbs
	cat linux/arch/arm/boot/dts/sun9i-a80-optimus.dtb >> \
	linux/arch/arm/boot/zImage
	cd linux && make LOADADDR=0x40008000 uImage

clean:
	cd linux && make clean

copy:
	rm linux/deploy -rf
	mkdir -p linux/deploy
	VERSION=$$(cd linux && make --no-print-directory kernelversion) && \
	cp linux/.config linux/deploy/config-$$VERSION
	VERSION=$$(cd linux && make --no-print-directory kernelversion) && \
	cp linux/arch/arm/boot/uImage linux/deploy/$$VERSION.uImage
	dd if=/dev/zero of=linux/deploy/dummy bs=1024 count=4
	VERSION=$$(cd linux && make --no-print-directory kernelversion) && \
	cat linux/deploy/dummy >> linux/deploy/$$VERSION.uImage
	cd linux && make modules_install INSTALL_MOD_PATH=deploy
	cd linux && make headers_install INSTALL_HDR_PATH=deploy/usr
	VERSION=$$(cd linux && make --no-print-directory kernelversion) && \
	mkdir -p -m 755 linux/deploy/lib/firmware/$$VERSION; true
	VERSION=$$(cd linux && make --no-print-directory kernelversion) && \
	mv linux/deploy/lib/firmware/* \
	linux/deploy/lib/firmware/$$VERSION; true
	VERSION=$$(cd linux && make --no-print-directory kernelversion) && \
	cd linux/deploy && tar -czf $$VERSION-modules-firmware.tar.gz lib
	VERSION=$$(cd linux && make --no-print-directory kernelversion) && \
	cd linux/deploy && tar -czf $$VERSION-headers.tar.gz usr

install:
	mkdir -p -m 755 $(DESTDIR)/boot;true
	VERSION=$$(cd linux && make --no-print-directory kernelversion) && \
	cp linux/deploy/$$VERSION.uImage $(DESTDIR)/boot;true
	VERSION=$$(cd linux && make --no-print-directory kernelversion) && \
	cp linux/deploy/config-$$VERSION $(DESTDIR)/boot;true
	VERSION=$$(cd linux && make --no-print-directory kernelversion) && \
	cp linux/deploy/$$VERSION-modules-firmware.tar.gz $(DESTDIR)/boot;true
	VERSION=$$(cd linux && make --no-print-directory kernelversion) && \
	cp linux/deploy/$$VERSION-headers.tar.gz $(DESTDIR)/boot;true
	VERSION=$$(cd linux && make --no-print-directory kernelversion) && \
	tar -xzf linux/deploy/$$VERSION-modules-firmware.tar.gz -C $(DESTDIR)/

clean:
	test -d linux && cd linux && rm -f .config || true
	test -d linux && cd linux git clean -df || true

