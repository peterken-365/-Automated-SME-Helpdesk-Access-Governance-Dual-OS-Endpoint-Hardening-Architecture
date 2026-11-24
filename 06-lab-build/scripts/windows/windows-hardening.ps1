# windows-hardening.ps1 - WIN-FIN01 security baseline (Windows 10)
# Implements 03-hardening-baselines/windows-baseline.md rows 1,3-11.
# Run from elevated PowerShell:
#   powershell -ExecutionPolicy Bypass -File .\windows-hardening.ps1
#Requires -RunAsAdministrator

$Mgmt = "192.168.56.0/24"

Write-Host "=== [1/9] Windows Defender ==="
Set-MpPreference -DisableRealtimeMonitoring $false -DisableBehaviorMonitoring $false
try { Set-MpPreference -MAPSReporting 2 -SubmitSamplesConsent 1 } catch { Write-Warning "Cloud MAPS settings unavailable in this VM: $_" }
Get-MpComputerStatus | Select-Object AntivirusEnabled, RealTimeProtectionEnabled | Format-Table

Write-Host "=== [2/9] Firewall profiles ON, default-deny inbound ==="
Set-NetFirewallProfile -All -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow
Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction | Format-Table

Write-Host "=== [3/9] Scoped inbound rules (management subnet only) ==="
New-NetFirewallRule -DisplayName "Allow RDP from IT mgmt subnet" -Direction Inbound -Protocol TCP -LocalPort 3389 -RemoteAddress $Mgmt -Action Allow | Out-Null
New-NetFirewallRule -DisplayName "Allow ICMPv4 echo from IT mgmt subnet" -Direction Inbound -Protocol ICMPv4 -RemoteAddress $Mgmt -Action Allow | Out-Null
Get-NetFirewallRule -DisplayName "Allow *" | Select-Object DisplayName, Enabled, Action | Format-Table

Write-Host "=== [4/9] Disable SMBv1 ==="
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Confirm:$false
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue

Write-Host "=== [5/9] Disable guest account ==="
net user guest /active:no

Write-Host "=== [6/9] Disable AutoRun/AutoPlay on all drives ==="
New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name NoDriveTypeAutoRun -Value 255 -Type DWord

Write-Host "=== [7/9] UAC verified ON (secure-desktop prompt) ==="
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name EnableLUA -Value 1 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name ConsentPromptBehaviorAdmin -Value 2 -Type DWord

Write-Host "=== [8/9] Password + lockout policy ==="
net accounts /lockoutthreshold:5 /lockoutduration:30 /lockoutwindow:30 /minpwlen:12 /maxpwage:90 /uniquepw:5

Write-Host "=== [9/9] Screen lock after 10 minutes inactivity ==="
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name InactivityTimeoutSecs -Value 600 -Type DWord

Write-Host "=== BitLocker status (design + escrow process: see windows-baseline.md) ==="
try { Get-BitLockerVolume | Select-Object MountPoint, VolumeStatus, ProtectionStatus | Format-Table }
catch { Write-Warning "BitLocker cmdlets unavailable: $_" }

Write-Host "Hardening complete. Compare output against 03-hardening-baselines/windows-baseline.md."
