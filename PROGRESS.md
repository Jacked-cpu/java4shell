# Java4Shell lab — progress tracker

Tracks the lab against the goals in `README.md`. Updated 2026-11-22.

Legend: `[x]` done · `[~]` partial / scripted but not yet run in the guest · `[ ]` not started · `[!]` blocked

## Goals

### G1 — Minimal vulnerable target
- [x] `victim/DecodeServer.java` HTTP service decodes attacker-controlled Base64 on `/login`
- [x] Hot loop forces C2 to compile the Base64 intrinsic
- [x] `-Dlab.hotloop` configurable
- Evidence: local run returns `health 200 / valid 200 / trigger 400` and the JVM stays up (see G5)

### G2 — Guest setup automation
- [x] `victim/setup-guest.ps1` installs Temurin 21.0.5+11 (pre-fix), compiles, adds firewall rule
- [x] Supports `-Download` or offline `-JdkZip` via the VMware shared folder
- [~] Script exists but has **not been executed in the guest** (VM currently powered off)

### G3 — CPU capability gate
- [x] `tools/check-cpu.ps1` checks `AVX512F / AVX512BW / AVX512_VBMI / BMI2`
- [x] Falls back to `coreinfo.exe` and warns on consumer 12th-gen Intel
- [!] Host is **i7-1255U (Alder Lake)** — AVX-512 fused off, so the guest inherits no AVX-512.
      Reproduction is impossible on this machine by design.

### G4 — Start target in guest (three modes)
- [x] `victim/run-server.ps1` with `vulnerable`, `no-intrinsic` (`-XX:-UseBASE64Intrinsics`), `no-avx512` (`-XX:UseAVX=2`)
- [x] `-XX:+PrintCompilation` on by default
- [~] Not yet run in the guest

### G5 — Host orchestration
- [x] `host/attack.ps1` checks TCP, `/health`, baseline credential, then sends the public trigger and probes liveness
- [x] Functional logic validated locally against the same `DecodeServer` (WSL JDK 25.0.3)
- Evidence: `tools/validate-local.sh` output — `health 200`, `valid 200`, `trigger 400`, server alive

### G6 — Reproduce memory corruption
- [!] Blocked: no AVX-512 VBMI on this host/guest
- [ ] Confirm `hs_err_pid*.log` on an AVX-512-capable host (Ice Lake / Sapphire Rapids / Zen 4+)

### G7 — Verify mitigations
- [ ] `no-intrinsic` must survive the trigger
- [ ] `no-avx512` must survive the trigger
- Requires a crash-capable host to be meaningful (on this host everything survives)

### G8 — Verify fixed JDK
- [ ] Run against a fixed build (17.0.21.1 / 21.0.13.1 / 25.0.5.1 / 27.0.1.1) and confirm no crash

### G9 — Cleanup / rollback
- [x] Documented in `README.md` (delete `hs_err_pid*.log`, `*.class`, roll back VM snapshot)
- [x] `.gitignore` covers `*.class`, crash logs, `jdk.zip`, `extract/`

### G10 — Remote guest control (VNC)
- [~] `tools/vnc-*.py` drive the guest over VMware VNC (`172.20.48.1::5901`, password `labvnc`)
- [x] Typing/interaction confirmed working (screenshots `vnc5.png`, `vnc6.png`)
- [!] VM is powered off right now; `vmrun list` reports 0 running VMs and TCP 5901 is closed

## Current environment state

| Item | State |
|---|---|
| Lab repo | `D:\MIDAS\research\java4shell-lab` (remote `Jacked-cpu/java4shell`) |
| VM | `Viktor-VictimWin10` (`D:\others\vmware\Windows 10 x64 (2)`), NAT, VNC 5901 |
| Shared folder | `D:\MIDAS\research\java4shell-lab` → guest `\\vmware-host\Shared Folders\java4shell-lab` |
| VM power | off |
| Host JDK | Java 8 JRE only (no `javac`) |
| WSL | Kali, JDK 25.0.3 (pre-fix build, no AVX-512) |
| Host CPU | i7-1255U, AVX-512 not exposed |

## Blockers

1. **No AVX-512** on the host or guest — the bug cannot fire here. README documents this up front.
2. **VM off** — guest setup and the three-mode comparison cannot run until it is powered on.
3. **No Windows JDK on the host** — compilation happens in the guest (or WSL for the functional check).

## Next steps (in order)

1. Power on the VM and wait for VNC:
   `& 'C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe' -T ws start 'D:\others\vmware\Windows 10 x64 (2)\Windows 10 x64 (2).vmx' nogui`
2. In the guest, run:
   `powershell -ExecutionPolicy Bypass -File "\\vmware-host\Shared Folders\java4shell-lab\victim\setup-guest.ps1" -Download`
3. Run `tools\check-cpu.ps1` in the guest and record the AVX-512 verdict.
4. Start `run-server.ps1 -Mode vulnerable`, then run `host\attack.ps1` from the host.
   Expected here: target survives, HTTP 400s, no crash log.
5. Repeat for `no-intrinsic` and `no-avx512`.
6. On an AVX-512-capable host: repeat step 4, expect `hs_err_pid*.log`; then repeat with a fixed JDK (G8).
7. Clean up crash logs / `.class` and roll back the VM snapshot.

## Reproduce the current functional check

```bash
# WSL/Linux with a JDK on PATH
bash tools/validate-local.sh
```

Expected on this hardware:

```
health:  200
valid:   200
trigger: 400
Expected: health 200, valid 200, trigger 400, server still up (no AVX-512 host).
```

## Changelog

- 2026-11-22 — Added `tools/validate-local.sh`; validated `DecodeServer` routing/status codes on WSL
  (health 200, valid 200, trigger 400, JVM survives). Added this progress tracker.
- 2026-11-21 — VNC automation scripts and screenshots added; guest interaction confirmed.
- 2026-11-20 — Lab harness, guest setup, CPU check, and host orchestration committed.
