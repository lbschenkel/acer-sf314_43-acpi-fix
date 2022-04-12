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
	patch -F0 -t -N -o $@ acpi/dsdt.dsl dsdt.patch \
	|| (rm -f $@; echo; echo 'ABORTED: not possible to patch the ACPI tables; wrong BIOS version or already patched?'; exit 1)

acpi/dsdt.dsl: acpi/*.dat
	iasl -we -w3 -e acpi/*.dat -d acpi/dsdt.dat \
	|| (echo; echo 'ABORTED: errors/warnings decompiling the ACPI tables; acpica package too old?'; exit 1)

acpi/*.dat:
	mkdir -p acpi
	cd acpi; sudo acpidump -b
