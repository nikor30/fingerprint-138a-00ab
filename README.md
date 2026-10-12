# Fingerprint reader 138a:00ab on Linux (HP ZBook 17 G5)

How to get the Validity/Synaptics fingerprint sensor `138a:00ab` working on
Linux with `fprintd`, using the not-yet-merged libfprint Validity driver
([libfprint merge request 626](https://gitlab.freedesktop.org/libfprint/libfprint/-/merge_requests/626))
and its data package
([ggiesen/libfprint-validity-data](https://gitlab.freedesktop.org/ggiesen/libfprint-validity-data)).

This is a record of what worked on one machine, not a supported package.

## Tested on

| | |
|---|---|
| Machine | HP ZBook 17 G5 |
| Sensor | `138a:00ab`, reports `57K0 FM-154-123 (type=0x0969)`, ROM firmware 6.7 |
| Sensor state before | factory-empty (0 flash partitions) |
| OS | CachyOS (Arch-based), kernel 7.2.9, fprintd 1.94.5 |
| Driver | libfprint MR 626 at commit `1cf22b89` |
| Data package | `libfprint-validity-data` at commit `687c5ea` + the patch in `patches/` |
| Date | 2026-10-12 |

Result: pairing, firmware upload, calibration, enrolment and verification work;
fingerprint is used for `sudo`, polkit prompts and login.

## Read this first

- **The sensor's flash is written.** On first open the driver partitions the
  flash and stores pairing keys; with the firmware file present it also uploads
  the firmware extension. Neither can be undone from here.
- **Only tested on a factory-empty sensor.** If the sensor was set up under
  Windows, the driver refuses to re-pair it (that would erase it) and this guide
  does not cover the factory reset that would be needed.
- **Unmerged code.** The driver is a merge request under review. It can change
  or break; the commits are pinned here for that reason.
- The scripts are Arch/pacman specific.
- `scripts/01` and `scripts/02` are cleaned-up versions of the scripts that were
  actually run; `scripts/03` and the patch step inside `02` replace steps that
  were done by hand. The cleaned-up versions have been syntax-checked only.

## The finding

The data package ships Lenovo's `reset.bin` for `138a:00ab`. An HP sensor
rejects it, so a factory-empty sensor cannot be provisioned:

```
Flash has 0 partitions — device needs pairing
reset_blob failed: status=0x0404
Open failed with error: Could not read the sensor's TLS keys: TLS flash read: status 0x04af
```

With HP's `reset.bin` (the one the package already carries for `06cb:00cb` /
`06cb:00b7`) the same sensor provisions normally. `patches/` contains that
change; `docs/` contains the report prepared for upstream.

## Steps

Run from a checkout of this repository.

1. Check the sensor: `lsusb -d 138a:00ab`
2. Remove other fingerprint stacks if present (`python-validity`,
   `open-fprintd`, repo `libfprint`).
3. Build and install the driver:
   `sudo ./scripts/01-build-libfprint.sh`
4. Build and install the data files (with the HP reset blob for `138a:00ab`):
   `sudo ./scripts/02-install-data.sh`
5. Fetch HP's firmware extension from HP SoftPaq sp135736 (not redistributed
   here): `sudo ./scripts/03-install-hp-firmware.sh`
6. Provision. Keep your finger **off** the sensor and run `fprintd-enroll`
   up to three times:
   - 1st run ends with `Device rebooting after pairing`
   - 2nd run ends with `Device rebooting after firmware upload`
   - 3rd run asks for your finger; 9 touches complete the enrolment
7. Check: `fprintd-list $USER` and `fprintd-verify`

To watch what the driver does, run fprintd with debug output:

```
sudo mkdir -p /run/systemd/system/fprintd.service.d
printf '[Service]\nEnvironment=G_MESSAGES_DEBUG=all\n' | sudo tee /run/systemd/system/fprintd.service.d/debug.conf
sudo systemctl daemon-reload && sudo systemctl stop fprintd
journalctl -fu fprintd
```

## Using it for sudo, polkit and login

Install the lid check, so that with the lid closed (docked) the fingerprint
step is skipped and the password prompt comes immediately:

```
sudo install -m755 scripts/fprint-lid-open /usr/local/bin/fprint-lid-open
```

Then add these two lines as the first `auth` lines of `/etc/pam.d/sudo`, of
`/etc/pam.d/polkit-1` (copy it from `/usr/lib/pam.d/polkit-1` first) and, for
greeters that use the `login` service, after `pam_nologin.so` in
`/etc/pam.d/login`:

```
auth       [success=ignore default=1]  pam_exec.so quiet /usr/local/bin/fprint-lid-open
auth       sufficient   pam_fprintd.so max-tries=2 timeout=10
```

- Lid open: fingerprint is asked first; the password prompt follows after
  10 seconds without a touch.
- Lid closed: `fprint-lid-open` exits 1, `default=1` jumps over the
  `pam_fprintd` line, and the password is asked right away.

The two lines belong together: the first one skips exactly the one line after
it. Keep a root shell open while editing PAM files.

## Troubleshooting

| Message | Meaning |
|---|---|
| `Device data files not found for 138a:00ab` | data package not installed (step 4) |
| `reset_blob failed: status=0x0404` | Lenovo `reset.bin` in use; step 4 installs HP's |
| `Firmware file '…xpfwext' not found` | step 5 missing |
| `calibration capture 1/3 returned status 0x0450` | seen once, with a finger on the sensor while it opened; lift it and retry |
| `paired to a different host identity` | sensor was set up by another OS; not covered here |

## Undo

`sudo pacman -Rns libfprint-validity-data libfprint-validity-git fprintd`,
remove `/usr/share/libfprint/validity/6_07f_hp_cmit_mis_qm.xpfwext` and the
`pam_fprintd` lines. The sensor itself stays provisioned.

## Credits

The driver is by the authors of libfprint MR 626; the data package by
Gary T. Giesen and contributors, based on
[python-validity](https://github.com/uunicorn/python-validity). This repository
only adds the `138a:00ab` finding and the install notes.
