[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, HelpMessage="Prelude Token")]
    [String]$preludeToken
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$PRELUDE_API=if ($Env:PRELUDE_API) { $Env:PRELUDE_API } else { "https://api.preludesecurity.com" }
$TEST_ID="b74ad239-2ddd-4b1e-b608-8397a43c7c54"

$dos = "windows-" + $Env:PROCESSOR_ARCHITECTURE

$TempFile = [System.IO.Path]::GetTempFileName() | Rename-Item -NewName { [System.IO.Path]::ChangeExtension($_, "exe") } -PassThru

$Headers = @{
    'token' = $preludeToken
    'dos' = $dos
    'id' = $TEST_ID
}

$symbols = [PSCustomObject] @{
    CHECKMARK = ([char]8730)
}

function CheckRelevance {
    Write-Host -ForegroundColor Green "`r`n[$($symbols.CHECKMARK)] Result: Success - server or workstation detected"
}

function DownloadTest {
    try {
        Invoke-WebRequest -URI $PRELUDE_API -UseBasicParsing -Headers $Headers -MaximumRedirection 1 -OutFile $TempFile -PassThru | Out-Null
    } catch {
        $StatusCode = $_.Exception.Response.StatusCode.value__
        Write-Host -ForegroundColor Red "`r`n[!] Failed to download test. Http response code: $StatusCode"
        Exit 1
    }
    Write-Host -ForegroundColor Green "`r`n[$($symbols.CHECKMARK)] Wrote to temporary file: $TempFile"
}

function ExecuteTest {
    try {
        $p = Start-Process -FilePath $TempFile -Wait -NoNewWindow -PassThru
        if ($p.ExitCode -in 100,9,17,18,105,127 ) {
            Write-Host -ForegroundColor Green "`r`n[$($symbols.CHECKMARK)] Result: control test passed"
        } else {
            Write-Host -ForegroundColor Red "`r`n[!] Result: control test failed"
        }
        return $p.ExitCode
    } catch [System.InvalidOperationException] {
        Write-Host -ForegroundColor Red $_
        Write-Host -ForegroundColor Green "`r`n[$($symbols.CHECKMARK)] Result: control test passed"
        return 127
    } catch {
        Write-Host -ForegroundColor Red "`r`n[!] Unexpected error occurred:`r`n"
        Write-Host -ForegroundColor Red  $_
        return 1
    }
}

function ExecuteCleanup {
    try {
        $p = Start-Process -FilePath $TempFile -ArgumentList "clean" -Wait -NoNewWindow -PassThru
        if ($p.ExitCode -eq 100 ) {
            Write-Host -ForegroundColor Green "`r`n[$($symbols.CHECKMARK)] Clean up is complete"
        } else {
            Write-Host -ForegroundColor Red "`r`n[!] Clean up failed"
        }
    } catch [System.InvalidOperationException] {
        Write-Host -ForegroundColor Red $_
        Write-Host -ForegroundColor Red "`r`n[!] Clean up failed"
    } catch {
        Write-Host -ForegroundColor Red "`r`n[!] Unexpected error occurred:`r`n"
        Write-Host -ForegroundColor Red  $_
    }
}

function PostResults {
    param([string]$testresult)
    $Headers.dat = $TEST_ID + ":" + $testresult
    Invoke-WebRequest -URI $PRELUDE_API -UseBasicParsing -Headers $Headers -MaximumRedirection 1 | Out-Null
}

function InstallProbe {
    Write-Host "`r`n[+] Downloading installation script"
    $temp = [System.IO.Path]::GetTempFileName() | Rename-Item -NewName { [System.IO.Path]::ChangeExtension($_, "ps1") } -PassThru

    try {
        Invoke-WebRequest -URI $PRELUDE_API/download/install -UseBasicParsing -Headers $Headers -MaximumRedirection 1 -OutFile $temp -PassThru | Out-Null
    } catch {
        $StatusCode = $_.Exception.Response.StatusCode.value__
        Write-Host -ForegroundColor Red "`r`n[!] Failed to download installation script. Http response code: $StatusCode"
        Exit 1
    }

    $account_id = Read-Host -Prompt "Enter your Prelude Account ID"
    $account_token = Read-Host -Prompt "Enter your Prelude Account token"
    & $temp $account_id $account_token
}

Write-Host "
###########################################################################################################

Welcome to Prelude!

Malicious files are used to gain entry and conduct cyberattacks against corporate systems through seemingly
innocuous email attachments or direct downloads. For example - a malicious macro was used by the BlueNoroff
group in a ransomware attack (Dec. 2022)

Rules are specific defensive practices that are meant to protect you from certain types of malicious behavior.
Prelude runs tests designed to challenge the effectiveness of these defenses and check if your system is
configured to restrict malicious behavior from happening

Rule: Malicious files should quarantine when written to disk
Test: Will your computer quarantine a malicious Office document?

[+] Applicable CVE(s): CVE-2017-0199
[+] ATT&CK mappings: T1204.002

###########################################################################################################
"
Read-Host -Prompt "Press ENTER to continue"

Write-Host "Starting test at: $(Get-Date -UFormat %T)

-----------------------------------------------------------------------------------------------------------
[0] Conducting relevance test"
Start-Sleep -Seconds 3
CheckRelevance

Write-Host "-----------------------------------------------------------------------------------------------------------
[1] Downloading test"
DownloadTest

Write-Host "-----------------------------------------------------------------------------------------------------------
[2] Executing test
"
Start-Sleep -Seconds 3
$TestResult = ExecuteTest

Write-Host "-----------------------------------------------------------------------------------------------------------
[3] Running cleanup
"
Start-Sleep -Seconds 3
if ($TestResult -eq 127) {
    Write-Host -ForegroundColor Green "`r`n[$($symbols.CHECKMARK)] Clean up is complete"
} else {
    ExecuteCleanup
}

PostResults $TestResult

Write-Host "
###########################################################################################################
"

if ($TestResult -in 100,9,17,18,105,127 ) {
    Write-Host -ForegroundColor Green "[$($symbols.CHECKMARK)] Good job! Your computer detected and responded to a malicious Office document dropped on the disk"
} elseif ($TestResult -eq 101) {
    Write-Host -ForegroundColor Red "[!] This test was able to verify the existence of this vulnerability on your machine, as well as drop a malicious
Office document on the disk. If you have security controls in place that you suspect should have protected your
host, please review the logs"
} else {
    Write-Host -ForegroundColor Red "[!] This test encountered an unexpected error during execution. Please try again"
}

Write-Host "
###########################################################################################################
"

$msg = "[Optional] Would you like to install the probe on this endpoint? This will allow you to run this test, and others, on a continuous schedule (y/n)"
do {
    $response = Read-Host -Prompt $msg
    if ($response -eq 'y') {
        InstallProbe
        $extra = "and enable continuous scheduling for this test"
    }
} until ($response -eq 'n' -or $response -eq 'y')

Write-Host "
[*] Return to the Prelude Platform to view your results $extra
"
