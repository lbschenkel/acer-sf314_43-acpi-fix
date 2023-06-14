# ACPI DSDT patch for Acer Swift 3 SF314-43

This laptop is designed for Windows and [modern standby](https://docs.microsoft.com/en-us/windows-hardware/design/device-experiences/modern-standby),
and the firmware does not advertise S3 sleep state by default:

```
# dmesg | grep ACPI | grep supports
kernel: ACPI: PM: (supports S0 S4 S5)
```
```
# cat /sys/power/mem_sleep
[s2idle]
```
This means that Linux never uses [suspend-to-RAM](https://www.kernel.org/doc/html/latest/admin-guide/pm/sleep-states.html#suspend-to-ram)
but only [suspend-to-idle](https://www.kernel.org/doc/html/latest/admin-guide/pm/sleep-states.html#suspend-to-idle)
which uses more battery power when sleeping.


However, it's possible to patch the firmware's ACPI DSDT table to restore S3 support and
[instruct Linux to load it at boot](https://www.kernel.org/doc/html/latest/admin-guide/acpi/initrd_table_override.html):
```
# dmesg | grep ACPI | grep supports
kernel: ACPI: PM: (supports S0 S3 S4 S5)
```
```
# cat /sys/power/mem_sleep
s2idle [deep]
```

This repository contains the [patch to the DSDT](dsdt.patch) and a Makefile to automate the process.

## Requirements

- Laptop model: Acer Swift 3 SF314-43
- BIOS version: [1.06](https://global-download.acer.com/GDFiles/BIOS/BIOS/BIOS_Acer_1.06_A_A.zip?acerid=637998440494605648)&nbsp;(2022-09-27, "Support Win11 SV2")
             or [1.04](https://global-download.acer.com/GDFiles/BIOS/BIOS/BIOS_Acer_1.04_A_A.zip?acerid=637659969200273816)&nbsp;(2021-08-31, "Enable fTPM support for China")
- `acpica` package (personally tested only with versions 2021 or higher)

## Building initrd with patched ACPI DSDT

### Automatically

To automatically patch the ACPI DSDT and generate an initrd image, just run `make`.
If everything goes well, it will end with a "SUCCESS!" message.

### Manually
1. Install the `acpica` package
2. Run `acpidump -b` to dump all ACPI tables to `*.dat` files
3. Run `iasl -we -w3 -e *.dat -d dsdt.dat` to decompile the DSDT to `dsdt.dsl`
   - read next section if you want to try out without `-we`
4. Patch the DSDT via `patch -F0 -N < dsdt.patch`
   - read next section if you want to try out without `-F0`
5. Recompile the DSDT via `iasl -ve dsdt.dsl`
6. Generate initrd image:
   1. `mkdir -p kernel/firmware/acpi`
   2. `cp dsdt.aml kernel/firmware/acpi/`
   3. `find kernel | cpio -H newc --create > /boot/acpi-override.img`

### In case of failure

The process will fail if:
1. Issues were encountered while decompiling the ACPI tables
2. the BIOS is not an exact match (check requirements above)

To minimize the chance of issues caused by mismatches, the Makefile and
instructions are very strict regarding DSDT decompilation and patching:
1. warnings during decompilation are treated as errors
2. patching will not allow any "fuzz" (only exact matches)

Depending on the installed version of `acpica`, it may not be able to decompile
the DSDT without warnings and/or the output might be slightly different which
would cause failures during patching.

In this case it is possible to try (by changing the Makefile):
1. decompiling with `iasl` without the `-we` argument
2. patching with `patch` without the `-F0` argument

When attempting this, then analyze *very carefully* any warnings produced by
`iasl`. If it looks like the decompilation was only partially successful, then
do not attempt to proceed even if patching works — the new DSDT may be incorrect
and cause system instability.

## Configuring boot loader

Two things need to be set up in the boot loader:
1. Load `/boot/acpi-override.img` as an (additional) initrd.\
   This will make Linux use the patched ACPI DSDT with S3 support instead of the one from the firmware.
2. Add `mem_sleep_default=deep` to the
   [kernel's command line parameters](https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html).\
   This will make Linux use S3 when going to sleep (otherwise it will still default to `s2idle`, suspend-to-idle).

### GRUB

1. Change [`/etc/default/grub`](https://www.gnu.org/software/grub/manual/grub/html_node/Simple-configuration.html):
   ```
   GRUB_CMDLINE_LINUX_DEFAULT = "... mem_sleep_default=deep"
   GRUB_EARLY_INITRD_LINUX_CUSTOM = "... acpi-override.img"
   ```
2. Run `update-grub`

### systemd-boot

Change entries in [`/boot/loader/entries/*.conf`](https://www.freedesktop.org/software/systemd/man/loader.conf.html):
```
title    ...
linux    ...
initrd   /acpi-override.img
initrd   ...
options  ... mem_sleep_default=deep
```

### rEFInd

Change [`/boot/refind-linux.conf`](https://www.rodsbooks.com/refind/linux.html#refind_linux):
```
"Boot with standard options" "initrd=acpi-override.img ... mem_sleep_default=deep"
```
Change [manual boot stanzas](https://www.rodsbooks.com/refind/configfile.html#stanzas):
```
menuentry "..." {
  ostype Linux
  loader ...
  initrd ...
  options "initrd=acpi-override.img ... mem_sleep_default=deep"
}
```
Note that multiple `initrd` entries *do not work*, and any additional initrd files
must be declared in `options`.

## Known issues

- If the value of `/sys/power/mem_sleep` is changed after boot then the laptop
  does not successfully wake up from standby: fans, lights and the display backlight turn on but the display remains black.
  - This happens even when `amdgpu.gpu_recovery=1`.
  - Does not apply when `mem_sleep_default` is used, this method works fine.
  - Tested on Linux 5.15, not tested on earlier kernels.


## FAQs

**Q: Why not simply providing a `.img` file with the DSDT override?**

**A:** Because:
1. Then there's no risk of somebody mistakenly using the DSDT override in a
   machine with a different BIOS version (or worse: a different machine
   altogether) and getting unpredictable results.
2. This repository avoids redistributing portions of Acer's BIOS, staying
   clear of any potential legal issues.

**Q: Why not including the `.dsl` file with the decompiled DSDT?**

**A:** See previous answer.
