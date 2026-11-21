param(
    [string]$BaseUrl = 'http://127.0.0.1:8080',
    [int]$Requests = 5,
    [int]$TimeoutSec = 15
)

$ErrorActionPreference = 'Stop'
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

$before = @(Get-ChildItem -Path (Get-Location) -Filter 'hs_err_pid*.log' -ErrorAction SilentlyContinue).Count

"health:    $(Invoke-Hit "$BaseUrl/health" $cred)"
"baseline:  $(Invoke-Hit "$BaseUrl/login" $cred)"
for ($i = 1; $i -le $Requests; $i++) {
    "trigger $i: $(Invoke-Hit "$BaseUrl/login" $trigger)"
    Start-Sleep -Milliseconds 200
}

$after = @(Get-ChildItem -Path (Get-Location) -Filter 'hs_err_pid*.log' -ErrorAction SilentlyContinue).Count
if ($after -gt $before) {
    'RESULT: crash log created - memory corruption reproduced.'
} else {
    'RESULT: no crash log. Check JDK version, AVX-512 VBMI support, and that C2 compiled the intrinsic.'
}
