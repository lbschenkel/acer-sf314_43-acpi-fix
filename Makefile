ifndef VERBOSE
.SILENT:
endif

.PHONY: run clean
run: /boot/acpi-override.img
	echo
	echo SUCCESS!
	echo Now you have to instruct your boot loader to:
	echo '1. load an (additional) initrd:   ' $^
	echo '2. add to the kernel command line:' mem_sleep_default=deep
	echo
	echo GRUB:
	echo ' 1. Add to /etc/default/grub:'
	echo '    GRUB_EARLY_INITRD_LINUX_CUSTOM="acpi-override.img"'
	echo '    GRUB_CMDLINE_LINUX_DEFAULT="... mem_sleep_default=deep"'
	echo ' 2. Run update-grub'
	echo systemd-boot:
	echo ' Add to /boot/loader/entries/*.conf:'
	echo '  initrd  /acpi-override.img'
	echo '  options ... mem_sleep_default=deep'
	echo rEFInd:
	echo ' 1. Add to /boot/refind-linux.conf: "Boot with default options" "initrd=acpi-override.img ..."'
	echo ' 2. Add to manual stanzas:          options "initrd=acpi-override.img ... mem_sleep_default=deep"'

clean:
	rm -Rf acpi kernel *.img

/boot/acpi-override.img: acpi-override.img
	sudo cp $? /boot/

acpi-override.img: acpi/dsdt-patched.aml
	mkdir -p kernel/firmware/acpi
	cp $? kernel/firmware/acpi/dsdt.aml
	find kernel | cpio -H newc --create > $@

acpi/dsdt-patched.aml: acpi/dsdt-patched.dsl
	iasl -ve $?

acpi/dsdt-patched.dsl: dsdt.patch acpi/dsdt.dsl
	patch -N -o $@ acpi/dsdt.dsl dsdt.patch \
	|| ([ $$? == 1 ] && cp -v acpi/dsdt.dsl $@) \
	|| exit $$?

acpi/dsdt.dsl: acpi/*.dat
	iasl -e acpi/*.dat -d acpi/dsdt.dat

acpi/*.dat:
	mkdir -p acpi
	cd acpi; sudo acpidump -b
