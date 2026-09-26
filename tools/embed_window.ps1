param(
	[Parameter(Mandatory=$true)][long]$ParentHwnd,
	[Parameter(Mandatory=$true)][int]$ChildPid,
	[string]$ResultFile = "",
	[int]$FindTimeoutSec = 45,
	[switch]$Overlay
)

$ErrorActionPreference = "Stop"

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class Win {
	[DllImport("user32.dll", SetLastError=true)] public static extern IntPtr SetParent(IntPtr c, IntPtr p);
	[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
	[DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
	[DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int i, int v);
	[DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int ht, bool repaint);
	[DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int ht, uint flags);
	[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
	[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
	[DllImport("user32.dll")] public static extern IntPtr SetFocus(IntPtr h);
	[DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
	[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
	[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
	[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
	[DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
	[DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
	[DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
	[DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
	[DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint f);
	public struct RECT { public int Left, Top, Right, Bottom; }
	public struct POINT { public int X, Y; }
	public delegate bool EnumProc(IntPtr h, IntPtr l);

	public static IntPtr FindMain(uint target) {
		IntPtr best = IntPtr.Zero;
		long bestArea = -1;
		EnumWindows((h, l) => {
			uint pid; GetWindowThreadProcessId(h, out pid);
			if (pid != target) return true;
			if (!IsWindowVisible(h)) return true;
			if (GetParent(h) != IntPtr.Zero) return true;
			var sb = new StringBuilder(256); GetWindowText(h, sb, 256);
			if (sb.Length == 0) return true;
			RECT r; GetWindowRect(h, out r);
			long area = (long)(r.Right - r.Left) * (r.Bottom - r.Top);
			if (area > bestArea) { bestArea = area; best = h; }
			return true;
		}, IntPtr.Zero);
		return best;
	}
}
"@

$SW_HIDE = 0
$SW_SHOW = 5
$GWL_STYLE = -16
$GWL_EXSTYLE = -20
$WS_CHILD = 0x40000000
$WS_VISIBLE = 0x10000000
$WS_CLIPCHILDREN = 0x02000000
$WS_CLIPSIBLINGS = 0x04000000
$WS_POPUP = 0x80000000
$WS_CAPTION = 0x00C00000
$WS_THICKFRAME = 0x00040000
$WS_SYSMENU = 0x00080000
$WS_MINIMIZEBOX = 0x00020000
$WS_MAXIMIZEBOX = 0x00010000
$WS_EX_TOPMOST = 0x00000008
$SWP_SHOWWINDOW = 0x0040
$HWND_TOPMOST = [IntPtr](-1)

function Write-Result([string]$text) {
	if ($ResultFile -ne "") {
		try { [System.IO.File]::WriteAllText($ResultFile, $text) } catch {}
	}
}

$parent = [IntPtr]$ParentHwnd
if (-not [Win]::IsWindow($parent)) {
	Write-Result "ERROR:parent_invalid"
	Write-Output "ERROR:parent_invalid"
	exit 2
}

# ---- wait for child main window ----
$child = [IntPtr]::Zero
$deadline = (Get-Date).AddSeconds($FindTimeoutSec)
while ((Get-Date) -lt $deadline) {
	$child = [Win]::FindMain([uint32]$ChildPid)
	if ($child -ne [IntPtr]::Zero) { break }
	if (-not (Get-Process -Id $ChildPid -ErrorAction SilentlyContinue)) {
		Write-Result "ERROR:child_exited_early"
		Write-Output "ERROR:child_exited_early"
		exit 1
	}
	Start-Sleep -Milliseconds 250
}
if ($child -eq [IntPtr]::Zero) {
	Write-Result "ERROR:no_window"
	Write-Output "ERROR:no_window"
	exit 1
}

$mode = "embed"

function Resize-Embed {
	$r = New-Object Win+RECT
	[Win]::GetClientRect($parent, [ref]$r) | Out-Null
	$w = [Math]::Max(1, $r.Right - $r.Left)
	$h = [Math]::Max(1, $r.Bottom - $r.Top)
	[Win]::MoveWindow($child, 0, 0, $w, $h, $true) | Out-Null
}

function Resize-Overlay {
	$sw = [Win]::GetSystemMetrics(0)
	$sh = [Win]::GetSystemMetrics(1)
	[Win]::MoveWindow($child, 0, 0, $sw, $sh, $true) | Out-Null
}

if ($Overlay) {
	$mode = "overlay"
} else {
	# ---- embed ----
	[Win]::SetParent($child, $parent) | Out-Null
	$style = [Win]::GetWindowLong($child, $GWL_STYLE)
	$style = $style -band (-bnot ($WS_POPUP -bor $WS_CAPTION -bor $WS_THICKFRAME -bor $WS_SYSMENU -bor $WS_MINIMIZEBOX -bor $WS_MAXIMIZEBOX))
	$style = $style -bor $WS_CHILD -bor $WS_VISIBLE -bor $WS_CLIPCHILDREN -bor $WS_CLIPSIBLINGS
	[Win]::SetWindowLong($child, $GWL_STYLE, $style) | Out-Null
	$ex = [Win]::GetWindowLong($child, $GWL_EXSTYLE)
	[Win]::SetWindowLong($child, $GWL_EXSTYLE, $ex -band (-bnot $WS_EX_TOPMOST)) | Out-Null
	$nowParent = [Win]::GetParent($child)
	if ($nowParent -ne $parent) {
		# embedding failed -> fall back to overlay
		[Win]::SetParent($child, [IntPtr]::Zero) | Out-Null
		$mode = "overlay"
	}
}

if ($mode -eq "overlay") {
	$style = [Win]::GetWindowLong($child, $GWL_STYLE)
	$style = $style -band (-bnot ($WS_CAPTION -bor $WS_THICKFRAME -bor $WS_SYSMENU -bor $WS_MINIMIZEBOX -bor $WS_MAXIMIZEBOX))
	$style = $style -bor $WS_POPUP -bor $WS_VISIBLE
	[Win]::SetWindowLong($child, $GWL_STYLE, $style) | Out-Null
	$ex = [Win]::GetWindowLong($child, $GWL_EXSTYLE)
	[Win]::SetWindowLong($child, $GWL_EXSTYLE, $ex -bor $WS_EX_TOPMOST) | Out-Null
	[Win]::SetWindowPos($child, $HWND_TOPMOST, 0, 0, [Win]::GetSystemMetrics(0), [Win]::GetSystemMetrics(1), $SWP_SHOWWINDOW) | Out-Null
}

[Win]::ShowWindow($child, $SW_SHOW) | Out-Null
if ($mode -eq "embed") { Resize-Embed } else { Resize-Overlay }
[Win]::SetForegroundWindow($child) | Out-Null
[Win]::SetFocus($child) | Out-Null

Write-Result "OK:$mode"
Write-Output "OK:$mode"

# ---- follow parent size + wait for child exit ----
while ($true) {
	if (-not (Get-Process -Id $ChildPid -ErrorAction SilentlyContinue)) { break }
	if (-not [Win]::IsWindow($child)) { break }
	if ($mode -eq "embed") {
		[Win]::ShowWindow($child, $SW_SHOW) | Out-Null
		Resize-Embed
	} else {
		Resize-Overlay
	}
	Start-Sleep -Milliseconds 200
}

Write-Output "EXIT:child_gone"
exit 0
