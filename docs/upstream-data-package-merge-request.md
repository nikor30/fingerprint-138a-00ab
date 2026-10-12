
Title:
138a:00ab: use HP's reset_blob (provisioned a factory-empty 0x969 sensor)

Description:
138a:00ab still carried the Lenovo `reset.bin` inherited from 06cb:009a; the
README already suspected that was wrong. This confirms it on hardware and
switches 00ab to HP's payload (the 06cb:00cb set, same aliasing as 06cb:00d2).
`src/blobs_ab.py` is no longer read by the generator and is removed.

Hardware: HP ZBook 17 G5, sensor 138a:00ab, "57K0 FM-154-123 (type=0x0969)",
ROM firmware 6.7, flash factory-empty (0 partitions).
Software: libfprint MR !626 at 1cf22b89, this repo at 687c5ea, fprintd 1.94.5,
Arch-based (CachyOS), kernel 7.2.9.

With the Lenovo payload (as shipped):

    Flash info: size=1048576 (blocks=4096 × bs=256), partitions=0
    Flash has 0 partitions — device needs pairing
    reset_blob failed: status=0x0404
    Pairing failed: The driver encountered a protocol error with the device. -- continuing to the TLS key read
    Open failed: Could not read the sensor's TLS keys: TLS flash read: status 0x04af

Nothing was written; the sensor was unchanged afterwards.

With HP's payload (06cb_00b7/reset.bin copied over 138a_00ab/reset.bin, i.e.
exactly what this change generates — same sha256 065c3f79…aabac):

    Sending partition_flash (CMD 0x4f): 1393 bytes
    Received server certificate: 184 bytes
    Erasing partition 1 (step 1/5) … 5/5
    Open failed: Device rebooting after pairing            (expected)

    Flash has 5 partitions — verifying TLS keys
    TLS keys verified on flash — pairing not needed
    TLS session established (secure_rx=1 secure_tx=1)
    Firmware extension not loaded — starting upload via TLS
    Found firmware file: /usr/share/libfprint/validity/6_07f_hp_cmit_mis_qm.xpfwext
    Firmware file loaded: 196512 bytes payload, 256 bytes signature
    Firmware extension uploaded successfully — device rebooting

    Firmware extension is loaded
    Device: 57K0 FM-154-123 (type=0x0969)
    Sensor calibration complete
    Enroll result: enroll-stage-passed (x9) → enroll-completed

Enroll and verify work (fprintd-enroll, pam_fprintd for sudo/polkit/login).
The firmware file is the one from HP SoftPaq sp135736
(sha256 2b68b33668215cfc2a08c80a1f2c0e66c4c02927895d70a7d5f237e5201d5d2f);
its INF lists USB\VID_138A&PID_00AB.

One open, right after the first successful one, failed with
"Sensor calibration failed: calibration capture 1/3 returned status 0x0450";
a finger was probably resting on the sensor. The following opens were fine.

`make generate && make verify`: 38 OK, 0 FAILED; the generated 138a_00ab/ files
are byte-identical to 06cb_00cb/.
