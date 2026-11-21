# java4shell lab (CVE-2026-114938)

Authorized, isolated lab for reproducing the OpenJDK Base64 intrinsic memory
corruption ("Java4Shell"). Use only against systems you own or have written
permission to test.

## What this is

A minimal Java HTTP service that Base64-decodes the `Authorization: Basic ...`
header on `POST/GET /login`. The decode call is looped so C2 compiles the
HotSpot intrinsic. Sending the public malformed trigger (64 x `A` followed by
`=`) exercises the vulnerable code path described by Calif.

This repo is a **lab harness**, not a weaponized exploit. It sends only the
public crash/short-read trigger. There is no universal RCE exploit, and the
application-specific chains are not published.

## Hardware requirement (read this first)

The bug only fires when all of these are true:

| Requirement | Check |
|---|---|
| OpenJDK 17.0.6+ *before* the Nov 17 2026 fix | `java -version` |
| x86-64 CPU with `avx512f`, `avx512bw`, `avx512vbmi`, `bmi2` | Linux: `grep -oE 'avx512f\|avx512bw\|avx512vbmi\|bmi2' /proc/cpuinfo \| sort -u` / Windows: `coreinfo.exe -f` |
| App decodes attacker-controlled Base64 | this service does |
| Base64 intrinsic actually compiled by C2 | `-XX:+PrintCompilation` |

**This host (i7-1255U, Alder Lake consumer) does NOT expose AVX-512** — Intel
fuses it off on consumer 12th-gen parts, and VMware guests inherit that. On
this machine the lab will run, accept requests, and return 400s, but it will
**not crash**. To actually reproduce the memory corruption you need a host such
as an Ice Lake / Sapphire Rapids / Emerald Rapids / Granite Rapids Xeon, or an
AMD Zen 4+, with AVX-512 passed through to the guest. ARM64 cannot reproduce it.

## Layout

```
victim/  DecodeServer.java      minimal vulnerable target
         setup-guest.ps1        install vulnerable JDK, compile, verify
         run-server.ps1         launch vulnerable / mitigated / no-AVX512
         test-local.ps1         local crash test inside the guest
host/    attack.ps1             orchestrate the trigger from the Windows host
tools/   check-cpu.ps1          AVX-512 capability check for the guest
```

## 1. Prepare the Windows VM (Viktor-VictimWin10)

1. Power the VM off, then confirm it is on an **isolated** network (NAT or
   host-only), not bridged.
2. VMware shared folders should expose this repo. In the guest it appears at
   `\\vmware-host\Shared Folders\java4shell-lab`.
3. Log in to the guest and run, in an elevated PowerShell:

```powershell
cd "\\vmware-host\Shared Folders\java4shell-lab\victim"
powershell -ExecutionPolicy Bypass -File .\setup-guest.ps1 -Download
```

`-Download` fetches Temurin 21.0.5 (pre-fix, vulnerable) from the Adoptium
archive. If the guest has no internet, download the Windows x64 JDK zip on the
host and pass `-JdkZip "\\vmware-host\Shared Folders\java4shell-lab\jdk.zip"`.

4. Verify the CPU inside the guest:

```powershell
powershell -ExecutionPolicy Bypass -File "\\vmware-host\Shared Folders\java4shell-lab\tools\check-cpu.ps1"
```

## 2. Start the target in the guest

```powershell
cd "\\vmware-host\Shared Folders\java4shell-lab\victim"
.\run-server.ps1 -Port 8080 -Mode vulnerable -HotLoop 20000
```

`-Mode` options:

| Mode | JVM flags | Purpose |
|---|---|---|
| `vulnerable` | none | reproduces the bug (on capable hardware) |
| `no-intrinsic` | `-XX:-UseBASE64Intrinsics` | mitigation: no intrinsic, no bug |
| `no-avx512` | `-XX:UseAVX=2` | mitigation: no AVX-512 code path |

## 3. Orchestrate from the Windows host

Find the VM IP (guest `ipconfig`, or `vmrun getGuestIPAddress "<vmx>"`), then:

```powershell
cd D:\MIDAS\research\java4shell-lab\host
.\attack.ps1 -Target 192.168.x.x -Port 8080 -Requests 10
```

The script checks TCP reachability, `/health`, a valid Basic credential, then
sends the malformed trigger and reports whether the JVM stayed up.

Expected on capable hardware: the JVM aborts and writes `hs_err_pid*.log` in the
server working directory. Expected on this host (no AVX-512): HTTP 400/401
responses, no crash log.

## 4. Compare and clean up

- Re-run with `-Mode no-intrinsic` / `-Mode no-avx512`; a trigger that crashes
  `vulnerable` must not crash these.
- Re-run against the fixed JDK (17.0.21.1 / 21.0.13.1 / 25.0.5.1 / 27.0.1.1)
  and confirm no crash.
- Delete `hs_err_pid*.log`, `*.class`, and use the VM snapshot to roll back.

## Safety

- Keep the VM on NAT/host-only. Never bridge it or port-forward to the internet.
- Snapshot before installing the old JDK.
- Do not send the trigger to anything you do not own.

## References

- Calif write-up: https://calif.io/java4shell/
- Oracle CSPU Nov 2026: https://www.oracle.com/security-alerts/cspunov2026.html
- OpenJDK advisory: https://openjdk.org/groups/vulnerability/advisories/2026-11-17
- CISA alert: https://www.cisa.gov/news-events/alerts/2026/11/17/critical-java-vulnerability-requires-immediate-patching
- Tenable FAQ: https://www.tenable.com/blog/java4shell-cve-2026-114938-frequently-asked-questions-about-openjdk-rce-vulnerability
