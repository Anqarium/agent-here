# Removes the context menu packages and deletes %LOCALAPPDATA%\AgentHere.
$ErrorActionPreference = 'Stop'
$base = Join-Path $env:LOCALAPPDATA 'AgentHere'

foreach ($name in 'AgentHere.Terminal', 'AgentHere.Desktop', 'AgentHere.AntigravityCli', 'AgentHere.Antigravity') {
  $pkg = Get-AppxPackage -Name $name
  if ($pkg) { Remove-AppxPackage -Package $pkg.PackageFullName; Write-Host "Removed: $name" }
}

Get-Process dllhost -ErrorAction SilentlyContinue | Where-Object {
  try { $_.Modules.FileName -like "$base\*" } catch { $false }
} | Stop-Process -Force

if (Test-Path $base) { Remove-Item $base -Recurse -Force }
