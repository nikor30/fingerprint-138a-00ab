
Hardware report for 138a:00ab on the 0x969 silicon (the case validity_fwext.c
marks "NOT verified"): HP ZBook 17 G5, "57K0 FM-154-123 (type=0x0969)", ROM
firmware 6.7, factory-empty flash (0 partitions). Built from 1cf22b89.

- With the data package as shipped (Lenovo reset.bin for 138a_00ab) provisioning
  stops at `reset_blob failed: status=0x0404`; nothing is written.
- With HP's reset.bin (the 06cb:00b7/00cb payload) the sensor provisions:
  partition_flash OK, 5 partitions, reboot, TLS session, then
  `6_07f_hp_cmit_mis_qm.xpfwext` (HP SoftPaq sp135736, 196512 bytes payload)
  uploads through this driver's path, reboot, "Firmware extension is loaded",
  calibration complete, enroll (9 stages) and verify via fprintd/pam_fprintd work.
- So for 00ab on 0x969 the fwext upload is now seen working, and
  `{ 0x138a, 0x00ab, &fwext_hp_cmit_mis_qm }` is the right file. The ZBook 17 G5
  can be added next to the ZBook Studio x360 G5 in the 0x969 comments.
- One oddity: a single open failed with "calibration capture 1/3 returned
  status 0x0450" (finger probably on the sensor during calibration); later
  opens were fine.

Matching change for the data package: <link to the libfprint-validity-data merge request>
