$ErrorActionPreference = 'Stop'

$stateDir = $env:WEZTERM_CONFIG_ROOT
$stateFile = Join-Path $stateDir '.topmost-state'

if (-not (Test-Path $stateDir)) {
  New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
}

$makeTopmost = $true
if (Test-Path $stateFile) {
  $currentState = (Get-Content $stateFile -Raw).Trim()
  $makeTopmost = $currentState -ne '1'
}

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class Win32 {
  [DllImport("user32.dll", SetLastError = true)]
  public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
}
"@

$hwndTopmost = [IntPtr](-1)
$hwndNotTopmost = [IntPtr](-2)
$flags = 0x0001 -bor 0x0002 -bor 0x0004 -bor 0x0010

Get-Process -Name 'wezterm-gui' -ErrorAction SilentlyContinue |
  Where-Object { $_.MainWindowHandle -ne 0 } |
  ForEach-Object {
    [Win32]::SetWindowPos(
      $_.MainWindowHandle,
      $(if ($makeTopmost) { $hwndTopmost } else { $hwndNotTopmost }),
      0,
      0,
      0,
      0,
      [uint32]$flags
    ) | Out-Null
  }

Set-Content -Path $stateFile -Value $(if ($makeTopmost) { '1' } else { '0' }) -NoNewline