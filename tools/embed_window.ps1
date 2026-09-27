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
	[DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError=true)] public static extern IntPtr SetWindowLongPtr(IntPtr h, int i, IntPtr p);
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
	[DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
	[DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
	[DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
	[DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
	[DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint f);
	[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
	[DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
	[DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
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
$WS_EX_TOOLWINDOW = 0x00000080
$GWLP_HWNDPARENT = -8
$SWP_NOSIZE = 0x0001
$SWP_NOMOVE = 0x0002
$SWP_SHOWWINDOW = 0x0040
$HWND_TOPMOST = [IntPtr](-1)

function Write-Result([string]$text) {
	if ($ResultFile -ne "") {
		try { [System.IO.File]::WriteAllText($ResultFile, $text) } catch {}
	}
}

# After cross-process SetParent, keyboard focus stays on Godot's input queue.
# Attach the FNF child thread to the Godot parent thread, then SetFocus(child),
# so keyboard goes to FNF (mouse is routed by position, so it already worked).
function Enable-ChildKeyboard {
	try {
		[uint32]$cpid = 0
		[uint32]$ppid = 0
		$childThread = [Win]::GetWindowThreadProcessId($child, [ref]$cpid)
		$parentThread = [Win]::GetWindowThreadProcessId($parent, [ref]$ppid)
		if ($childThread -eq 0 -or $parentThread -eq 0) { return }
		if ($script:kbChildThread -ne $childThread) {
			[Win]::AttachThreadInput($parentThread, $childThread, $true) | Out-Null
			$script:kbChildThread = $childThread
		}
		$myThread = [Win]::GetCurrentThreadId()
		[Win]::AttachThreadInput($myThread, $childThread, $true) | Out-Null
		[Win]::SetFocus($child) | Out-Null
		[Win]::AttachThreadInput($myThread, $childThread, $false) | Out-Null
	} catch {}
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

# overlay window covers the whole parent window (title bar included) so it looks like one window
function Resize-Overlay {
	$r = New-Object Win+RECT
	[Win]::GetWindowRect($parent, [ref]$r) | Out-Null
	$w = [Math]::Max(1, $r.Right - $r.Left)
	$h = [Math]::Max(1, $r.Bottom - $r.Top)
	[Win]::MoveWindow($child, $r.Left, $r.Top, $w, $h, $true) | Out-Null
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
	[Win]::SetWindowLong($child, $GWL_EXSTYLE, $ex -bor $WS_EX_TOPMOST -bor $WS_EX_TOOLWINDOW) | Out-Null
	# own the window by the parent: always above it, and hidden from taskbar/alt-tab
	# -> visually and in the taskbar it behaves like a single window
	[Win]::SetWindowLongPtr($child, $GWLP_HWNDPARENT, $parent) | Out-Null
	# geometry comes from Resize-Overlay; here only mark topmost + show
	[Win]::SetWindowPos($child, $HWND_TOPMOST, 0, 0, 0, 0, ($SWP_NOMOVE -bor $SWP_NOSIZE -bor $SWP_SHOWWINDOW)) | Out-Null
}

[Win]::ShowWindow($child, $SW_SHOW) | Out-Null
if ($mode -eq "embed") {
	Resize-Embed
	Enable-ChildKeyboard
} else {
	Resize-Overlay
}
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
		# keep keyboard focus on the embedded FNF while Godot is foreground
		$fg = [Win]::GetForegroundWindow()
		if ([Win]::GetAncestor($fg, 2) -eq $parent) {
			Enable-ChildKeyboard
		}
	} else {
		Resize-Overlay
	}
	Start-Sleep -Milliseconds 200
}

Write-Output "EXIT:child_gone"
exit 0
