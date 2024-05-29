# S3 sleep in Acer Swift 3 SF314-43

This laptop is designed for Windows and [modern standby](https://docs.microsoft.com/en-us/windows-hardware/design/device-experiences/modern-standby),
and the firmware does not advertise S3 sleep state by default:

```
# dmesg | grep ACPI | grep supports
kernel: ACPI: PM: (supports S0 S4 S5)

# cat /sys/power/mem_sleep
[s2idle]
```
This means that Linux never uses [suspend-to-RAM](https://www.kernel.org/doc/html/latest/admin-guide/pm/sleep-states.html#suspend-to-ram)
but only [suspend-to-idle](https://www.kernel.org/doc/html/latest/admin-guide/pm/sleep-states.html#suspend-to-idle)
which uses more battery power when sleeping.

There is a way to fix this: booting into an [UEFI program](#is-this-your-program) that exposes all internal AMD PBS/CBS settings from the firmware and allows them to be changed, including choosing between modern sleep and S3.

## Requirements

This should theoretically work in any AMD computer, however I have **only** tested it with the following combination:

- Laptop model: Acer Swift 3 SF314-43
- Firmware versions:
  - [1.08](https://global-download.acer.com/GDFiles/BIOS/BIOS/BIOS_Acer_1.08_A_A.zip?acerid=638301863132363694)&nbsp;(2023-09-13, "Add Acer battery battery information...")
  - [1.06](https://global-download.acer.com/GDFiles/BIOS/BIOS/BIOS_Acer_1.06_A_A.zip?acerid=637998440494605648)&nbsp;(2022-09-27, "Support Win11 SV2")

## Be aware!

- If your system does not match **exactly** the requirements described above, I don't know what will happen and you **may brick your computer**.
- The UEFI program allows you to change all sorts of other settings which are potentially dangerous and result in malfunctions or **may brick your computer**. Just don't.
- The UEFI program is not mine, and to my knowledge the source is not available. From a security standpoint, running such unaudited, low-level tool that could potentially do anything is probably not the wisest choice. 
- Acer firmware setup does not allow you to change from modern sleep to S3. By doing so, you are putting the computer into an untested/unsupported state which may expose firmware bugs.
- If you intend to keep dual booting with Windows 10, Microsoft [claims](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/modern-standby#:~:text=Switching%20the%20power%20model%20is%20not%20supported%20in%20Windows%20without%20a%20complete%20OS%20re%2Dinstall) that:
  > Switching between S3 and Modern Standby cannot be done by changing a setting in the BIOS. Switching the power model is not supported in Windows without a complete OS re-install.

It goes without saying, but I am not responsible for anything you do with your own computer. This did work for me but you are on your own.

## Instructions

1. Get the program by cloning this repo, or downloading it from [releases](https://github.com/lbschenkel/acer-sf314_43-acpi-fix/releases/) and uncompressing it.

0. Format a USB stick with FAT32.

0. Copy the files from `copy-to-usb-stick` to the USB stick.

0. Make sure that you have Secure Boot disabled: reboot, press F2 to enter firmware setup, make sure that *Secure Boot* (under *Boot*) is set to *disabled*, then exit and save changes.

0. While booting press F12 to enter the boot menu and choose the USB stick.

0. In the menu that appears, go to *Device Manager* and then *AMD PBS*.

0. Scroll down to *S3/Modern Standby Support* and change it to *S3 Enable*.

0. Make absolutely sure that you did not touch anything else! (In doubt, press Esc, answer *Yes* to *Exist discarding changes?* and try again.) If you are sure, press F10 to save.

0. Press Esc twice to return to the main menu, then choose *Reset*.

0. Re-enable Secure Boot if desired.

If everything worked as it should, after you boot into Linux you will see the following:

```
# dmesg | grep ACPI | grep supports
ACPI: PM: (supports S0 S3 S4 S5)

# cat /sys/power/mem_sleep
s2idle [deep]
```

Now your laptop can enjoy a good night of S3 sleep!

## Known issues

None so far.

## FAQs

### Is this your program?

No. I found it at https://github.com/DavidS95/Smokeless_UMAF and I claim no credit. This repository contains a known-good copy of the files from there which I have personally verified that work with my laptop.
(This also makes sure to have another copy in case that repository disappears.)

### Can I safely revert this change?

Yes, it looks like it. I have extracted the ACPI tables before trying the change for the first time. I changed the settings, verified that the ACPI tables did change, then changed back and confirmed that the ACPI tables went back to the exact same original ones, byte-for-byte.

### Can't I make Linux load patched ACPI tables?

Yes, that would indeed be better because (1) it wouldn't require doing an unsupported change of firmware settings and (2) does not risk upsetting an existing insallation of Windows. That was my first choice and in fact used to be my previous approach.[^previous]

[^previous]: The previous approach patched the ACPI DSDT table to simply expose the S3 state, without any other changes. However, now that I had the chance to compare the [changes](stock106-and-s3.diff) when S3 is properly exposed in the firmware, there are considerable differences (ironically, the place that the patch changed is not among them). For this reason alone I no longer recommend that route and I moved it into the branch [`old-hack`](https://github.com/lbschenkel/acer-sf314_43-acpi-fix/tree/old-hack).

I did try it and realized that it was not as trivial. An explanation follows, for the technically inclined:

I've decompiled the ACPI tables exposed when S3 is on, bumped their version (required step), recompiled and created an initramfs for Linux to load them. I then reverted the settings to stock and I have confirmed that the kernel was loading the overridden tables, but S3 support was still not exposed.

By inspecting the [diff](stock106-and-s3.diff) of the tables before and after the change, I realized that the tables were dynamically relying on a number of settings that are not part of the tables themselves, but mapped from a specific region in memory. The settings in that memory region are not captured in the tables themselves, so the overridden tables with a stock environment were not really invoking the same code paths as the ones taken when the UEFI tool is used, because that memory region ends up having different values as well.

It may actually be possible to extract the relevant values from that memory region and set the values as constants in the ACPI tables instead. That remains an exercise for the future.[^devmem]

[^devmem]: Extracting the necessary values from the memory region requires a custom kernel compiled without `CONFIG_STRICT_DEVMEM` to allow reading `/dev/mem`. Recompiling a custom kernel and going through this experiment required more time than I had in my hands.
