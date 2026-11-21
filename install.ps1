# Copies the built DLL to %LOCALAPPDATA%\AgentHere and registers each menu command as
# its own sparse package. Developer Mode must be on (the packages are unsigned).
# Running it again updates: the old packages are removed and registered again.
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$build = Join-Path $root 'build'
$base = Join-Path $env:LOCALAPPDATA 'AgentHere'
$version = '1.0.0.0'

if (-not (Test-Path (Join-Path $build 'AgentHere.dll'))) { & (Join-Path $root 'build.ps1') }

Add-Type -AssemblyName System.Drawing

function Find-DesktopExe {
  $pkg = Get-AppxPackage -Name Claude | Where-Object PackageFamilyName -eq 'Claude_pzs8sxrjxfjjc' | Select-Object -First 1
  if ($pkg) { $exe = Join-Path $pkg.InstallLocation 'app\Claude.exe'; if (Test-Path $exe) { return $exe } }
  # Per-user Squirrel install (the downloadable setup exe); claude.exe here is a stable launcher.
  $exe = Join-Path $env:LOCALAPPDATA 'AnthropicClaude\claude.exe'
  if (Test-Path $exe) { return $exe }
  return $null
}

function Find-ClaudeCli {
  $p = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
  if (Test-Path $p) { return $p }
  $c = Get-Command claude.exe -ErrorAction SilentlyContinue
  if ($c) { return $c.Source }
  return $null
}

function Find-AgyCli {
  $p = Join-Path $env:LOCALAPPDATA 'agy\bin\agy.exe'
  if (Test-Path $p) { return $p }
  $c = Get-Command agy.exe -ErrorAction SilentlyContinue
  if ($c) { return $c.Source }
  return $null
}

# The app that registers the antigravity:// protocol.
function Find-Antigravity {
  $exe = Join-Path $env:LOCALAPPDATA 'Programs\antigravity\Antigravity.exe'
  if (Test-Path $exe) { return $exe }
  return $null
}

# Icon for the CLI entry: the Antigravity IDE's dark tile sets it apart from the app entry, as the
# Claude CLI's dark tile does from Claude Desktop. agy.exe has no icon of its own.
function Find-AgyIcon {
  $ide = Join-Path $env:LOCALAPPDATA 'Programs\Antigravity IDE\Antigravity IDE.exe'
  if (Test-Path $ide) { return $ide }
  return Find-Antigravity
}

function Get-ExeIcon([string]$exe) {
  $icon = try { [System.Drawing.Icon]::ExtractIcon($exe, 0, 256) } catch { $null }
  if (-not $icon) { $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($exe) }
  return $icon
}

# The exes' own icons have different built-in padding (the Claude CLI's is smaller), so menu
# icons and package logos are cropped to the visible area and centred on a square: they then
# fill the same share of their slot.
function Get-VisibleRect([System.Drawing.Bitmap]$src) {
  $minX = $src.Width; $minY = $src.Height; $maxX = -1; $maxY = -1
  for ($y = 0; $y -lt $src.Height; $y++) {
    for ($x = 0; $x -lt $src.Width; $x++) {
      if ($src.GetPixel($x, $y).A -gt 20) {
        if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
        if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
      }
    }
  }
  if ($maxX -lt 0) { $minX = 0; $minY = 0; $maxX = $src.Width - 1; $maxY = $src.Height - 1 }
  return New-Object System.Drawing.RectangleF $minX, $minY, ($maxX - $minX + 1), ($maxY - $minY + 1)
}

# $round > 0 clips the result to a rounded square (corner radius = $round * size).
function New-IconSquare([System.Drawing.Bitmap]$src, [System.Drawing.RectangleF]$rect, [int]$size, [double]$round = 0) {
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $scale = $size / [Math]::Max($rect.Width, $rect.Height)
  $w = $rect.Width * $scale; $h = $rect.Height * $scale
  $dest = New-Object System.Drawing.RectangleF (($size - $w) / 2), (($size - $h) / 2), $w, $h
  $g.DrawImage($src, $dest, $rect, [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose()
  if ($round -le 0) { return $bmp }

  # Fill an anti-aliased rounded square with the drawn image as texture: smooth corners.
  $out = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($out)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $d = 2 * $round * $size
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddArc(0, 0, $d, $d, 180, 90)
  $path.AddArc($size - $d, 0, $d, $d, 270, 90)
  $path.AddArc($size - $d, $size - $d, $d, $d, 0, 90)
  $path.AddArc(0, $size - $d, $d, $d, 90, 90)
  $path.CloseFigure()
  $brush = New-Object System.Drawing.TextureBrush $bmp
  $g.FillPath($brush, $path)
  $brush.Dispose(); $path.Dispose(); $g.Dispose(); $bmp.Dispose()
  return $out
}

# The menu icon, written as a multi-size ICO of PNG frames.
function Write-MenuIcon([string]$exe, [string]$path, [double]$round = 0) {
  $icon = Get-ExeIcon $exe
  $src = $icon.ToBitmap()
  $rect = Get-VisibleRect $src
  $frames = foreach ($size in 16, 20, 24, 32, 40, 48, 64, 256) {
    $bmp = New-IconSquare $src $rect $size $round
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    , @($size, $ms.ToArray())
  }
  $out = New-Object System.IO.MemoryStream
  $bw = New-Object System.IO.BinaryWriter $out
  $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$frames.Count)
  $offset = 6 + 16 * $frames.Count
  foreach ($f in $frames) {
    $dim = if ($f[0] -ge 256) { 0 } else { $f[0] }
    $bw.Write([byte]$dim); $bw.Write([byte]$dim); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32)
    $bw.Write([uint32]$f[1].Length); $bw.Write([uint32]$offset)
    $offset += $f[1].Length
  }
  foreach ($f in $frames) { $bw.Write([byte[]]$f[1]) }
  $bw.Flush()
  [IO.File]::WriteAllBytes($path, $out.ToArray())
  $src.Dispose(); $icon.Dispose()
}

# Package logos (shown on the App extensions settings page) are made from the exe's icon.
function Write-Logos([string]$exe, [string]$assets, [double]$round = 0) {
  New-Item -ItemType Directory -Force $assets | Out-Null
  $icon = Get-ExeIcon $exe
  $src = $icon.ToBitmap()
  $rect = Get-VisibleRect $src
  foreach ($logo in @{ 'StoreLogo.png' = 50; 'Square44x44Logo.png' = 44; 'Square150x150Logo.png' = 150 }.GetEnumerator()) {
    $bmp = New-IconSquare $src $rect $logo.Value $round
    $bmp.Save((Join-Path $assets $logo.Key), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
  }
  $src.Dispose(); $icon.Dispose()
}

# Package names (App extensions page) follow the Windows display language at install time;
# the DLL picks the menu titles itself every time the menu opens.
$tr = (Get-UICulture).TwoLetterISOLanguageName -eq 'tr'
$commands = @(
  @{ Name = 'AgentHere.Terminal'; Folder = 'Terminal'; Verb = 'ClaudeCode'
     Display = $(if ($tr) { 'Claude Code (sağ tık)' } else { 'Claude Code (context menu)' })
     Clsid = '0f55b8ab-4947-4eab-b1f7-4e8c0db27ac9'; Exe = Find-ClaudeCli },
  @{ Name = 'AgentHere.Desktop'; Folder = 'Desktop'; Verb = 'ClaudeDesktop'
     Display = $(if ($tr) { 'Claude Masaüstü (sağ tık)' } else { 'Claude Desktop (context menu)' })
     Clsid = '59847620-2a77-4b45-ad83-ef512e443b3b'; Exe = Find-DesktopExe },
  @{ Name = 'AgentHere.AntigravityCli'; Folder = 'AntigravityCli'; Verb = 'AntigravityCli'
     Display = $(if ($tr) { 'Antigravity CLI (sağ tık)' } else { 'Antigravity CLI (context menu)' })
     Clsid = 'abc40dd4-5780-41df-84ea-cd2008a2578d'; Exe = Find-AgyCli; IconExe = Find-AgyIcon
     # The IDE's tile has square corners; round them like the Claude CLI's tile (~22 % radius).
     Round = 0.22 },
  @{ Name = 'AgentHere.Antigravity'; Folder = 'Antigravity'; Verb = 'Antigravity'
     Display = $(if ($tr) { 'Antigravity IDE (sağ tık)' } else { 'Antigravity IDE (context menu)' })
     Clsid = '7d7030d2-a5b9-4d8f-bb1e-da9b44981025'; Exe = Find-Antigravity }
)

# Stop the surrogate (dllhost) processes holding the DLL, or the copy hits a locked file.
Get-Process dllhost -ErrorAction SilentlyContinue | Where-Object {
  try { $_.Modules.FileName -like "$base\*" } catch { $false }
} | Stop-Process -Force

$template = Get-Content (Join-Path $root 'package\AppxManifest.template.xml') -Raw -Encoding utf8

foreach ($c in $commands) {
  $old = Get-AppxPackage -Name $c.Name
  if ($old) { Remove-AppxPackage -Package $old.PackageFullName }

  if (-not $c.Exe) {
    Write-Warning "$($c.Display): target app not found, skipping."
    continue
  }

  $dir = Join-Path $base $c.Folder
  $pkg = Join-Path $dir 'package'
  New-Item -ItemType Directory -Force $pkg | Out-Null
  Copy-Item (Join-Path $build 'AgentHere.dll'), (Join-Path $build 'AgentHereStub.exe') $dir -Force
  $iconExe = if ($c.IconExe) { $c.IconExe } else { $c.Exe }
  # Registration looks for the logos next to the manifest, but Windows resolves them against the
  # external location (Settings showed a placeholder icon otherwise), so they go to both.
  $round = if ($c.Round) { $c.Round } else { 0 }
  Write-Logos $iconExe (Join-Path $pkg 'Assets') $round
  Copy-Item (Join-Path $pkg 'Assets') $dir -Recurse -Force
  Write-MenuIcon $iconExe (Join-Path $dir 'icon.ico') $round

  $manifest = $template.Replace('{{NAME}}', $c.Name).Replace('{{DISPLAY}}', $c.Display).
    Replace('{{VERB}}', $c.Verb).Replace('{{CLSID}}', $c.Clsid).Replace('{{VERSION}}', $version)
  $manifestPath = Join-Path $pkg 'AppxManifest.xml'
  [IO.File]::WriteAllText($manifestPath, $manifest, (New-Object System.Text.UTF8Encoding $false))

  Add-AppxPackage -Register $manifestPath -ExternalLocation $dir
  Write-Host "Registered: $($c.Name)"
}
