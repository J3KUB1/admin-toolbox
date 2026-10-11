@echo off
setlocal
set "SELF=%~f0"
if /i "%~1"=="/admin" goto :admin
if /i "%~1"=="/user" goto :run
cls
echo.
echo   ==========================================
echo      ADMIN TOOLBOX
echo   ==========================================
echo.
echo     [1]  Uruchom jako ADMINISTRATOR (UAC)
echo     [2]  Uruchom jako UZYTKOWNIK (bez UAC)
echo     [Q]  Wyjscie
echo.
choice /c 12Q /n /m "  Wybierz opcje: "
if errorlevel 3 exit /b
if errorlevel 2 goto :run
:admin
net session >nul 2>&1
if %errorlevel% neq 0 (
  powershell -NoProfile -Command "Start-Process -FilePath $env:SELF -ArgumentList '/admin' -Verb RunAs"
  exit /b
)
:run
start "" /min powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "try { $f=[IO.File]::ReadAllText($env:SELF); $i=$f.IndexOf('#PS'+'START'); Invoke-Expression $f.Substring($i) } catch { $m=$_.Exception.Message+[Environment]::NewLine+$_.InvocationInfo.PositionMessage; try { $d=Join-Path $env:APPDATA 'AdminToolbox'; New-Item -ItemType Directory -Path $d -Force | Out-Null; Add-Content -Path (Join-Path $d 'error.log') -Value ((Get-Date -Format 's')+' STARTUP '+$m) } catch {}; Add-Type -AssemblyName System.Windows.Forms; [void][Windows.Forms.MessageBox]::Show($m,'Admin Toolbox - startup error') }"
exit /b
#PSSTART
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
try { [System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException) } catch {}
$Error.Clear()

# =====================================================================
#  ADMIN TOOLBOX v2
# =====================================================================

# ---------- stan globalny ----------
$global:Proc = $null
$global:LogFile = $null
$global:LogPos = 0
$global:TaskBat = $null
$global:Loaded = @{}
$global:RunDir = Join-Path $env:TEMP 'AdminToolbox_run'
if (-not (Test-Path $global:RunDir)) { New-Item -ItemType Directory -Path $global:RunDir -Force | Out-Null }
Get-ChildItem $global:RunDir -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-1) } | Remove-Item -Force -ErrorAction SilentlyContinue
$global:Enc = [Text.Encoding]::GetEncoding([Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage)
$global:Tip = New-Object Windows.Forms.ToolTip
$global:IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($global:IsAdmin) { $global:ModeText = 'ADMINISTRATOR' } else { $global:ModeText = 'UŻYTKOWNIK (ograniczony)' }
$global:AdminOnly = @('SFC /scannow', 'DISM CheckHealth', 'DISM ScanHealth', 'DISM RestoreHealth', 'CHKDSK C: (odczyt)', 'CHKDSK C: /f /r',
  'Reset Windows Update', 'Punkt przywracania', 'Raport energii (60 s)', 'Wyczyść cache DNS', 'Cache DNS', 'Odnów adres IP', 'Reset Winsock', 'Reset TCP/IP',
  'Start', 'Stop', 'Restart', 'Auto', 'Ręczny', 'Wyłączony', 'Włącz konto', 'Wyłącz konto', 'Włącz zadanie', 'Wyłącz zadanie',
  'Szybki skan Defendera', 'Aktualizuj sygnatury', 'Nieudane logowania (24 h)', 'Skanuj zmiany sprzętu', 'Eksportuj sterowniki')

$global:LogFg     = [Drawing.Color]::FromArgb(205, 214, 205)
$global:LogCyan   = [Drawing.Color]::FromArgb(110, 200, 255)
$global:LogYellow = [Drawing.Color]::FromArgb(240, 210, 110)
$global:LogRed    = [Drawing.Color]::FromArgb(255, 120, 110)

$uiFont   = New-Object Drawing.Font('Segoe UI', 9)
$monoFont = New-Object Drawing.Font('Consolas', 9.5)

# ---------- motyw (jasny / ciemny) ----------
$global:SettingsFile = Join-Path $env:APPDATA 'AdminToolbox\settings.json'
$global:Settings = @{}
$global:IsDark = $false
$global:T = @{}
$global:Header = $null
$global:BtnTheme = $null
$global:ThemeNative = $false
$global:CanThemeTabs = $false

try {
  Add-Type -ReferencedAssemblies 'System.Windows.Forms', 'System.Drawing' -TypeDefinition @'
using System;
using System.Drawing;
using System.Windows.Forms;

public class ThemedTabControl : TabControl
{
    private bool custom;
    public Color BarColor = Color.FromArgb(30, 31, 36);
    public Color TabColor = Color.FromArgb(47, 49, 58);
    public Color SelColor = Color.FromArgb(37, 38, 45);
    public Color TextColor = Color.FromArgb(170, 176, 190);
    public Color SelTextColor = Color.White;
    public Color LineColor = Color.FromArgb(66, 69, 82);
    public Color AccentColor = Color.FromArgb(0, 120, 212);

    public bool Custom
    {
        get { return custom; }
        set
        {
            custom = value;
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, value);
            Invalidate();
        }
    }

    protected override void OnSelectedIndexChanged(EventArgs e)
    {
        base.OnSelectedIndexChanged(e);
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        if (!custom) { base.OnPaint(e); return; }
        Graphics g = e.Graphics;
        g.Clear(BarColor);
        for (int i = 0; i < TabCount; i++)
        {
            Rectangle r = GetTabRect(i);
            bool sel = (i == SelectedIndex);
            using (SolidBrush b = new SolidBrush(sel ? SelColor : TabColor))
            {
                g.FillRectangle(b, r);
            }
            using (Pen p = new Pen(LineColor))
            {
                g.DrawLine(p, r.Right - 1, r.Top, r.Right - 1, r.Bottom - 1);
            }
            if (sel)
            {
                using (SolidBrush a = new SolidBrush(AccentColor))
                {
                    g.FillRectangle(a, r.Left, r.Top, r.Width - 1, 2);
                }
            }
            TextRenderer.DrawText(g, TabPages[i].Text, Font, r, sel ? SelTextColor : TextColor,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPrefix);
        }
        Rectangle d = DisplayRectangle;
        using (Pen p2 = new Pen(LineColor))
        {
            g.DrawRectangle(p2, d.X - 2, d.Y - 2, d.Width + 3, d.Height + 3);
        }
    }
}
'@
  $global:CanThemeTabs = $true
} catch {}

try {
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class Win32Theme
{
    [DllImport("uxtheme.dll", CharSet = CharSet.Unicode)]
    public static extern int SetWindowTheme(IntPtr hWnd, string subAppName, string subIdList);

    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, string lParam);
}
'@
  $global:ThemeNative = $true
} catch {}

$global:FastScan = $false
try {
  Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;

public class DiskScan
{
    public static volatile bool Cancel;
    public long Size;
    public long Files;
    public long Freed;
    public long CollectMin = -1;
    public List<KeyValuePair<long, string>> Top = new List<KeyValuePair<long, string>>();
    public List<KeyValuePair<long, string>> Found = new List<KeyValuePair<long, string>>();
    private int topN;
    private long minTop;

    public DiskScan(int topN) { this.topN = topN; }

    public void Walk(string path)
    {
        Stack<string> st = new Stack<string>();
        st.Push(path);
        while (st.Count > 0)
        {
            if (Cancel) return;
            string d = st.Pop();
            try
            {
                DirectoryInfo di = new DirectoryInfo(d);
                foreach (FileInfo f in di.EnumerateFiles())
                {
                    long len = 0;
                    try { len = f.Length; } catch { continue; }
                    Size += len;
                    Files++;
                    if (topN > 0) AddTop(len, f.FullName);
                    if (CollectMin >= 0 && len >= CollectMin && Found.Count < 300000) Found.Add(new KeyValuePair<long, string>(len, f.FullName));
                }
                foreach (DirectoryInfo sub in di.EnumerateDirectories())
                {
                    if ((sub.Attributes & FileAttributes.ReparsePoint) != 0) continue;
                    st.Push(sub.FullName);
                }
            }
            catch { }
        }
    }

    public void WalkFilter(string dir, string filter)
    {
        try
        {
            foreach (FileInfo f in new DirectoryInfo(dir).EnumerateFiles(filter))
            {
                long len = 0;
                try { len = f.Length; } catch { continue; }
                Size += len;
                Files++;
                if (topN > 0) AddTop(len, f.FullName);
            }
        }
        catch { }
    }

    private void AddTop(long len, string p)
    {
        if (Top.Count >= topN && len <= minTop) return;
        Top.Add(new KeyValuePair<long, string>(len, p));
        if (Top.Count > topN * 2) Trim();
    }

    private void Trim()
    {
        Top.Sort(delegate (KeyValuePair<long, string> a, KeyValuePair<long, string> b) { return b.Key.CompareTo(a.Key); });
        if (Top.Count > topN) Top.RemoveRange(topN, Top.Count - topN);
        if (Top.Count > 0) minTop = Top[Top.Count - 1].Key;
    }

    public void Finish() { Trim(); }

    public void Purge(string dir, string filter, string skip)
    {
        DirectoryInfo di = new DirectoryInfo(dir);
        bool hasFilter = !string.IsNullOrEmpty(filter);
        try
        {
            foreach (FileInfo f in di.EnumerateFiles(hasFilter ? filter : "*"))
            {
                if (Cancel) return;
                try
                {
                    long l = f.Length;
                    if ((f.Attributes & FileAttributes.ReadOnly) != 0) f.Attributes = FileAttributes.Normal;
                    f.Delete();
                    Freed += l;
                    Files++;
                }
                catch { }
            }
        }
        catch { }
        if (hasFilter) return;
        try
        {
            foreach (DirectoryInfo sd in di.EnumerateDirectories())
            {
                if (Cancel) return;
                if (skip != null && string.Equals(sd.FullName.TrimEnd('\\', '/'), skip.TrimEnd('\\', '/'), StringComparison.OrdinalIgnoreCase)) continue;
                if ((sd.Attributes & FileAttributes.ReparsePoint) != 0)
                {
                    try { sd.Delete(); } catch { }
                    continue;
                }
                Purge(sd.FullName, null, skip);
                try { sd.Delete(); } catch { }
            }
        }
        catch { }
    }
}
'@
  $global:FastScan = $true
} catch {}

function RGB($r, $g, $b) { return [Drawing.Color]::FromArgb($r, $g, $b) }

function Get-SystemDark {
  try { return ((Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -ErrorAction Stop).AppsUseLightTheme -eq 0) } catch { return $false }
}

function Load-Settings {
  $global:Settings = @{}
  try {
    if (Test-Path $global:SettingsFile) {
      $o = Get-Content -Raw -Encoding UTF8 $global:SettingsFile | ConvertFrom-Json
      foreach ($pr in $o.PSObject.Properties) { $global:Settings[$pr.Name] = $pr.Value }
    }
  } catch {}
}

function Save-Settings {
  try {
    $dir = Split-Path $global:SettingsFile
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [IO.File]::WriteAllText($global:SettingsFile, (ConvertTo-Json -InputObject $global:Settings), (New-Object Text.UTF8Encoding($true)))
  } catch {}
}

function Set-ThemeColors($dark) {
  $global:IsDark = [bool]$dark
  if ($dark) {
    $global:T = @{
      Bg = (RGB 30 31 36); Page = (RGB 37 38 45); Input = (RGB 47 49 58); Text = (RGB 226 229 236); Muted = (RGB 140 148 165)
      Btn = (RGB 55 58 70); BtnBorder = (RGB 86 90 105); BtnDisBg = (RGB 42 43 50); BtnDisFg = (RGB 104 108 120)
      ListBg = (RGB 31 32 38); HeadBg = (RGB 47 49 58); Line = (RGB 66 69 82); Grid = (RGB 52 54 64); GraphBg = (RGB 31 32 38)
      HeaderBg = (RGB 20 24 33); Sel = (RGB 0 103 184)
    }
  } else {
    $global:T = @{
      Bg = (RGB 240 240 240); Page = (RGB 252 252 253); Input = (RGB 255 255 255); Text = (RGB 30 30 30); Muted = (RGB 110 120 135)
      Btn = (RGB 236 239 244); BtnBorder = (RGB 190 198 210); BtnDisBg = (RGB 225 225 225); BtnDisFg = (RGB 130 130 130)
      ListBg = (RGB 255 255 255); HeadBg = (RGB 240 242 246); Line = (RGB 210 214 222); Grid = (RGB 230 232 236); GraphBg = (RGB 255 255 255)
      HeaderBg = (RGB 30 41 59); Sel = (RGB 0 103 184)
    }
  }
}

Load-Settings
$startDark = $false
if ($global:Settings['Theme'] -eq 'dark') { $startDark = $true }
elseif ($global:Settings['Theme'] -eq 'light') { $startDark = $false }
else { $startDark = Get-SystemDark }
Set-ThemeColors $startDark

function Style-Btn($b) {
  $T = $global:T
  $b.FlatStyle = 'Flat'
  $b.FlatAppearance.BorderSize = 1
  if (-not $b.Enabled) {
    $b.BackColor = $T.BtnDisBg
    $b.ForeColor = $T.BtnDisFg
    $b.FlatAppearance.BorderColor = $T.BtnDisBg
    return
  }
  switch ([string]$b.Tag) {
    'danger'  { $bg = (RGB 192 57 43); $fg = [Drawing.Color]::White; $bd = $bg }
    'primary' { $bg = (RGB 0 103 184); $fg = [Drawing.Color]::White; $bd = $bg }
    'ghost'   { $bg = (RGB 51 65 85); $fg = [Drawing.Color]::White; $bd = (RGB 90 105 128) }
    default   { $bg = $T.Btn; $fg = $T.Text; $bd = $T.BtnBorder }
  }
  $b.BackColor = $bg
  $b.ForeColor = $fg
  $b.FlatAppearance.BorderColor = $bd
}

function Apply-NativeTheme($c) {
  if (-not $global:ThemeNative) { return }
  try {
    if ($global:IsDark) { [void][Win32Theme]::SetWindowTheme($c.Handle, 'DarkMode_Explorer', [NullString]::Value) }
    else { [void][Win32Theme]::SetWindowTheme($c.Handle, [NullString]::Value, [NullString]::Value) }
  } catch {}
}

function Set-TitleBar($f) {
  if (-not $global:ThemeNative) { return }
  try {
    $v = 0
    if ($global:IsDark) { $v = 1 }
    foreach ($a in 19, 20) { [void][Win32Theme]::DwmSetWindowAttribute($f.Handle, $a, [ref]$v, 4) }
  } catch {}
}

function Draw-Header($s, $e) {
  $T = $global:T
  $g = $e.Graphics
  $br = New-Object Drawing.SolidBrush($T.HeadBg)
  $g.FillRectangle($br, $e.Bounds)
  $br.Dispose()
  $pen = New-Object Drawing.Pen($T.Line)
  $g.DrawLine($pen, ($e.Bounds.Right - 1), $e.Bounds.Top, ($e.Bounds.Right - 1), ($e.Bounds.Bottom - 1))
  $g.DrawLine($pen, $e.Bounds.Left, ($e.Bounds.Bottom - 1), $e.Bounds.Right, ($e.Bounds.Bottom - 1))
  $pen.Dispose()
  $r = New-Object Drawing.Rectangle(($e.Bounds.X + 6), $e.Bounds.Y, ([math]::Max(1, $e.Bounds.Width - 10)), $e.Bounds.Height)
  [Windows.Forms.TextRenderer]::DrawText($g, $e.Header.Text, $s.Font, $r, $T.Text, ([Windows.Forms.TextFormatFlags]'Left, VerticalCenter, EndEllipsis, NoPrefix'))
}

function Draw-SubItem($s, $e) {
  $T = $global:T
  $g = $e.Graphics
  $b = $e.Bounds
  $w = $b.Width
  if ($e.ColumnIndex -eq 0) { $w = $s.Columns[0].Width }
  $rect = New-Object Drawing.Rectangle($b.X, $b.Y, $w, $b.Height)
  $bg = $T.ListBg
  $fg = $T.Text
  if ($e.Item.Selected) { $bg = $T.Sel; $fg = [Drawing.Color]::White }
  else {
    switch ([string]$e.SubItem.Name) {
      'ok'   { $fg = (RGB 92 200 120) }
      'warn' { $fg = (RGB 240 190 80) }
      'bad'  { $fg = (RGB 255 115 105) }
    }
  }
  $br = New-Object Drawing.SolidBrush($bg)
  $g.FillRectangle($br, $rect)
  $br.Dispose()
  $pen = New-Object Drawing.Pen($T.Grid)
  $g.DrawLine($pen, $rect.X, ($rect.Bottom - 1), $rect.Right, ($rect.Bottom - 1))
  $pen.Dispose()
  $tr = New-Object Drawing.Rectangle(($rect.X + 4), $rect.Y, ([math]::Max(1, $rect.Width - 6)), $rect.Height)
  [Windows.Forms.TextRenderer]::DrawText($g, $e.SubItem.Text, $s.Font, $tr, $fg, ([Windows.Forms.TextFormatFlags]'Left, VerticalCenter, EndEllipsis, NoPrefix'))
}

function Fit-Last($lv) {
  $n = $lv.Columns.Count
  if ($n -lt 1 -or $lv.ClientSize.Width -lt 50) { return }
  $sum = 0
  for ($i = 0; $i -lt ($n - 1); $i++) { $sum += $lv.Columns[$i].Width }
  $w = $lv.ClientSize.Width - $sum
  if ($w -gt 60 -and [math]::Abs($w - $lv.Columns[$n - 1].Width) -gt 1) { $lv.Columns[$n - 1].Width = $w }
}

function Fit-Visible {
  try {
    foreach ($c in $global:Tabs.SelectedTab.Controls) { if ($c -is [Windows.Forms.ListView]) { Fit-Last $c } }
  } catch {}
}

function Theme-List($lv) {
  $T = $global:T
  $lv.BackColor = $T.ListBg
  $lv.ForeColor = $T.Text
  $lv.GridLines = (-not $global:IsDark)
  $lv.OwnerDraw = $global:IsDark
  if ($lv.IsHandleCreated) { Apply-NativeTheme $lv }
  $lv.Invalidate()
}

function Theme-Control($c) {
  $T = $global:T
  if ([object]::ReferenceEquals($c, $global:Header)) { return }
  if ([object]::ReferenceEquals($c, $global:LogBox)) { return }
  if ($c -is [Windows.Forms.Button]) { Style-Btn $c; return }
  if ($c -is [Windows.Forms.ListView]) { Theme-List $c; return }
  if ($c.GetType().Name -eq 'ThemedTabControl') {
    $c.BarColor = $T.Bg
    $c.TabColor = $T.Input
    $c.SelColor = $T.Page
    $c.TextColor = $T.Muted
    $c.SelTextColor = $T.Text
    $c.LineColor = $T.Line
    $c.Custom = $global:IsDark
  }
  elseif ($c -is [Windows.Forms.TabPage]) {
    $c.UseVisualStyleBackColor = $false
    $c.BackColor = $T.Page
    $c.ForeColor = $T.Text
  }
  elseif ($c -is [Windows.Forms.TextBox]) {
    $c.BackColor = $T.Input
    if ($c.Multiline) { $c.BackColor = $T.ListBg }
    $c.ForeColor = $T.Text
    if ($global:IsDark) { $c.BorderStyle = 'FixedSingle' } else { $c.BorderStyle = 'Fixed3D' }
    if ($c.IsHandleCreated) { Apply-NativeTheme $c }
  }
  elseif ($c -is [Windows.Forms.ComboBox]) {
    $c.BackColor = $T.Input
    $c.ForeColor = $T.Text
    if ($global:IsDark) { $c.FlatStyle = 'Flat' } else { $c.FlatStyle = 'Standard' }
  }
  elseif ($c -is [Windows.Forms.Label]) {
    if ([string]$c.Tag -eq 'muted') { $c.ForeColor = $T.Muted } else { $c.ForeColor = $T.Text }
  }
  elseif ($c -is [Windows.Forms.CheckBox]) { $c.ForeColor = $T.Text }
  elseif ($c -is [Windows.Forms.GroupBox]) { $c.ForeColor = $T.Text }
  elseif ($c -is [Windows.Forms.SplitContainer]) { $c.BackColor = $T.Bg }
  elseif ($c -is [Windows.Forms.ScrollableControl]) {
    $c.BackColor = $T.Page
    if ($c.AutoScroll -and $c.IsHandleCreated) { Apply-NativeTheme $c }
  }
  foreach ($ch in $c.Controls) { Theme-Control $ch }
}

function Apply-Theme {
  $T = $global:T
  $f = $global:Form
  $f.SuspendLayout()
  $f.BackColor = $T.Bg
  $f.ForeColor = $T.Text
  if ($global:Header) { $global:Header.BackColor = $T.HeaderBg }
  foreach ($c in $f.Controls) { Theme-Control $c }
  if ($global:LbSearch) {
    $global:LbSearch.BackColor = $T.Input
    $global:LbSearch.ForeColor = $T.Text
  }
  Update-HeaderLang
  $f.ResumeLayout($true)
  foreach ($gp in $global:GraphPanels) { $gp.Invalidate() }
  if ($f.IsHandleCreated) { Set-TitleBar $f }
  $f.Refresh()
}

function Switch-Theme {
  Set-ThemeColors (-not $global:IsDark)
  $global:Form.Cursor = [Windows.Forms.Cursors]::WaitCursor
  Apply-Theme
  $global:Form.Cursor = [Windows.Forms.Cursors]::Default
  if ($global:IsDark) { $global:Settings['Theme'] = 'dark' } else { $global:Settings['Theme'] = 'light' }
  Save-Settings
}

# ---------- i18n (PL / EN) ----------
$global:Lang = 'pl'
if ($global:Settings['Lang'] -eq 'en') { $global:Lang = 'en' }
elseif ($global:Settings['Lang'] -eq 'pl') { $global:Lang = 'pl' }
elseif ([Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -ne 'pl') { $global:Lang = 'en' }

$global:TrExact = @{
  'Pulpit' = 'Dashboard'
  'Wydajność' = 'Performance'
  'Procesy' = 'Processes'
  'Usługi' = 'Services'
  'Porty' = 'Ports'
  'Sieć' = 'Network'
  'Naprawa' = 'Repair'
  'Użytkownicy' = 'Users'
  'Programy' = 'Programs'
  'Autostart' = 'Startup'
  'Zadania' = 'Tasks'
  'Zdarzenia' = 'Events'
  'Własne' = 'Custom'
  'Narzędzia' = 'Tools'
  'Odśwież' = 'Refresh'
  'Kopiuj' = 'Copy'
  'Publiczny IP' = 'Public IP'
  'Stan dysków (SMART)' = 'Disk health (SMART)'
  'Ostatnie poprawki' = 'Recent hotfixes'
  'Raport HTML' = 'HTML report'
  'Filtr:' = 'Filter:'
  'Zakończ proces' = 'End process'
  'Zakończ drzewo' = 'End process tree'
  'Lokalizacja pliku' = 'File location'
  'Eksport CSV' = 'Export CSV'
  'Tylko uruchomione' = 'Running only'
  'Ręczny' = 'Manual'
  'Wyłączony' = 'Disabled'
  'Tylko nasłuchujące' = 'Listening only'
  'Test portu' = 'Port test'
  'Test połączenia' = 'Connection test'
  'Informacje' = 'Information'
  'Karty sieciowe' = 'Network adapters'
  'Połączenia (netstat)' = 'Connections (netstat)'
  'Tablica ARP' = 'ARP table'
  'Tablica tras' = 'Route table'
  'Profile Wi-Fi (nazwy)' = 'Wi-Fi profiles (names)'
  'Zapora - status' = 'Firewall - status'
  'Udziały sieciowe' = 'Network shares'
  'Naprawa sieci' = 'Network repair'
  'Wyczyść cache DNS' = 'Flush DNS cache'
  'Odnów adres IP' = 'Renew IP address'
  'Skanowanie i naprawa systemu' = 'System scan and repair'
  'CHKDSK C: (odczyt)' = 'CHKDSK C: (read-only)'
  'Czyszczenie' = 'Cleanup'
  'Wyczyść pliki TEMP' = 'Clean TEMP files'
  'Opróżnij kosz' = 'Empty recycle bin'
  'Oczyszczanie dysku' = 'Disk Cleanup'
  'Konserwacja' = 'Maintenance'
  'Punkt przywracania' = 'Restore point'
  'Odśwież zasady grupy' = 'Refresh group policy'
  'Restart Eksploratora' = 'Restart Explorer'
  'Raport baterii' = 'Battery report'
  'Raport energii (60 s)' = 'Energy report (60 s)'
  'Zasilanie' = 'Power'
  'Wyłącz (10 s)' = 'Shut down (10 s)'
  'Anuluj restart/wyłączenie' = 'Cancel restart/shutdown'
  'Włącz konto' = 'Enable account'
  'Wyłącz konto' = 'Disable account'
  'Szczegóły konta' = 'Account details'
  'Administratorzy' = 'Administrators'
  'Zalogowani' = 'Logged-on users'
  'Odinstaluj' = 'Uninstall'
  'Zarządzaj (Menedżer zadań)' = 'Manage (Task Manager)'
  'Uruchom teraz' = 'Run now'
  'Włącz zadanie' = 'Enable task'
  'Wyłącz zadanie' = 'Disable task'
  'Harmonogram (okno)' = 'Task Scheduler (window)'
  'Ukryj zadania Microsoft' = 'Hide Microsoft tasks'
  'Dziennik:' = 'Log:'
  'Poziom:' = 'Level:'
  'Zakres:' = 'Range:'
  'Szukaj:' = 'Search:'
  'Pełny komunikat' = 'Full message'
  'Błędy i krytyczne' = 'Errors and critical'
  'Z ostrzeżeniami' = 'With warnings'
  'Wszystkie' = 'All'
  'Ostatnia godzina' = 'Last hour'
  'Ostatnie 24 godziny' = 'Last 24 hours'
  'Ostatnie 7 dni' = 'Last 7 days'
  'Ostatnie 30 dni' = 'Last 30 days'
  'Dodaj...' = 'Add...'
  'Uruchom' = 'Run'
  'Usuń' = 'Delete'
  'Dwuklik uruchamia. Zapis: %APPDATA%\AdminToolbox\custom.json' = 'Double-click runs. Saved in: %APPDATA%\AdminToolbox\custom.json'
  'Zarządzanie systemem' = 'System management'
  'Informacje i wydajność' = 'Information and performance'
  'Sieć i programy' = 'Network and programs'
  'Konsole' = 'Consoles'
  'Menedżer zadań' = 'Task Manager'
  'Menedżer urządzeń' = 'Device Manager'
  'Zarządzanie dyskami' = 'Disk Management'
  'Podgląd zdarzeń' = 'Event Viewer'
  'Usługi (services.msc)' = 'Services (services.msc)'
  'Harmonogram zadań' = 'Task Scheduler'
  'Zarządzanie komputerem' = 'Computer Management'
  'Użytkownicy lokalni' = 'Local Users'
  'Zasady grup lokalnych' = 'Local Group Policy'
  'Edytor rejestru' = 'Registry Editor'
  'Informacje o systemie' = 'System Information'
  'Monitor zasobów' = 'Resource Monitor'
  'Monitor wydajności' = 'Performance Monitor'
  'Diagnostyka DirectX' = 'DirectX Diagnostics'
  'Zapora zaawansowana' = 'Advanced Firewall'
  'Połączenia sieciowe' = 'Network Connections'
  'Programy i funkcje' = 'Programs and Features'
  'Ustawienia systemu' = 'Windows Settings'
  'Właściwości systemu' = 'System Properties'
  'Wiersz polecenia' = 'Command Prompt'
  'Eksplorator plików' = 'File Explorer'
  'Błędy systemowe (24 h)' = 'System errors (24 h)'
  'Otwórz log błędów' = 'Open error log'
  'Uruchom jako administrator' = 'Run as administrator'
  'Tryb ciemny' = 'Dark mode'
  'Tryb jasny' = 'Light mode'
  'Przełącz motyw jasny / ciemny' = 'Toggle light / dark theme'
  'Uruchamia to narzędzie ponownie z uprawnieniami administratora' = 'Restarts this tool with administrator privileges'
  'Wymaga uprawnień administratora' = 'Requires administrator privileges'
  'Zapisuje raport stanu systemu jako plik HTML' = 'Saves a system status report as an HTML file'
  'Wyświetla pełny tekst zaznaczonego zdarzenia w logu (działa też dwuklik)' = 'Shows the full text of the selected event in the log (double-click also works)'
  'UŻYTKOWNIK (ograniczony)' = 'USER (limited)'
  'Szukaj funkcji... (Ctrl+F)' = 'Search functions... (Ctrl+F)'
  'Brak wyników' = 'No results'
  'Zakładka: ' = 'Tab: '
  'Język / Language' = 'Language / Język'
  'Wyczyść log' = 'Clear log'
  'Kopiuj log' = 'Copy log'
  'Zapisz log...' = 'Save log...'
  'Przerwij zadanie' = 'Stop task'
  'Zawijaj wiersze' = 'Wrap lines'
  'Nazwa' = 'Name'
  'Pamięć (MB)' = 'Memory (MB)'
  'Nazwa wyświetlana' = 'Display name'
  'Stan' = 'State'
  'Typ uruchomienia' = 'Startup type'
  'Adres lokalny' = 'Local address'
  'Adres zdalny' = 'Remote address'
  'Proces' = 'Process'
  'Konto' = 'Account'
  'Włączone' = 'Enabled'
  'Ostatnie logowanie' = 'Last logon'
  'Opis' = 'Description'
  'Wersja' = 'Version'
  'Wydawca' = 'Publisher'
  'Data instalacji' = 'Install date'
  'Polecenie' = 'Command'
  'Lokalizacja' = 'Location'
  'Użytkownik' = 'User'
  'Ścieżka' = 'Path'
  'Autor' = 'Author'
  'Czas' = 'Time'
  'Poziom' = 'Level'
  'Źródło' = 'Source'
  'Komunikat' = 'Message'
  'Typ' = 'Type'
  'Procesor' = 'Processor'
  'Pamięć RAM' = 'RAM'
  'Aktywność dysku' = 'Disk activity'
  'Sieć (wysłane + odebrane)' = 'Network (sent + received)'
  'skala: 0 - ' = 'scale: 0 - '
  'Nowe polecenie' = 'New command'
  'Nazwa:' = 'Name:'
  'Typ:' = 'Type:'
  'Polecenie (może być kilka linii):' = 'Command (can be multiple lines):'
  'Zapisz' = 'Save'
  'Anuluj' = 'Cancel'
  'Zaznacz proces.' = 'Select a process.'
  'Zaznacz usługę.' = 'Select a service.'
  'Zaznacz konto.' = 'Select an account.'
  'Zaznacz program.' = 'Select a program.'
  'Zaznacz wiersz.' = 'Select a row.'
  'Zaznacz zadanie.' = 'Select a task.'
  'Zaznacz zdarzenie.' = 'Select an event.'
  'Zaznacz polecenie.' = 'Select a command.'
  'Zaznacz pozycję.' = 'Select an item.'
  'Podaj poprawny host lub adres IP.' = 'Enter a valid host or IP address.'
  'Podaj port 1-65535.' = 'Enter a port from 1 to 65535.'
  'Poprzednie zadanie jeszcze trwa. Poczekaj lub kliknij "Przerwij".' = 'The previous task is still running. Wait or click "Stop".'
  'Nazwa i polecenie nie mogą być puste.' = 'Name and command cannot be empty.'
  'Nietypowa nazwa konta - użyj narzędzia lusrmgr.msc.' = 'Unusual account name - use lusrmgr.msc.'
  'Tego procesu systemowego nie można zakończyć.' = 'This system process cannot be terminated.'
  'Ten wpis nie ma polecenia odinstalowania.' = 'This entry has no uninstall command.'
  'Brak błędów w ostatnich 24 godzinach (lub brak dostępu).' = 'No errors in the last 24 hours (or no access).'
  'Nie udało się pobrać publicznego IP (brak internetu?).' = 'Could not get the public IP (no internet?).'
  'Opróżnić kosz na wszystkich dyskach?' = 'Empty the recycle bin on all drives?'
  'Uruchomić DISM RestoreHealth? Wymaga internetu i może potrwać długo.' = 'Run DISM RestoreHealth? Requires internet and may take a long time.'
  'Uruchomić SFC /scannow? To może potrwać kilkanaście minut.' = 'Run SFC /scannow? This may take several minutes.'
  'Usunąć zawartość %TEMP% i C:\Windows\Temp?' = 'Delete the contents of %TEMP% and C:\Windows\Temp?'
  'Wyłączyć komputer za 10 sekund?' = 'Shut down the computer in 10 seconds?'
  'Zaplanować CHKDSK /f /r dla C: przy następnym starcie?' = 'Schedule CHKDSK /f /r for C: at the next startup?'
  'Zatrzymać usługi Windows Update i zmienić nazwy folderów cache?' = 'Stop the Windows Update services and rename the cache folders?'
  'Zresetować Winsock? Wymaga restartu komputera.' = 'Reset Winsock? Requires a restart.'
  'Zresetować stos TCP/IP? Wymaga restartu komputera.' = 'Reset the TCP/IP stack? Requires a restart.'
  'Zrestartować komputer za 10 sekund?' = 'Restart the computer in 10 seconds?'
  'Zwolnić i odnowić adres IP? Połączenie zniknie na chwilę.' = 'Release and renew the IP address? The connection will drop briefly.'
  'Zadanie nadal trwa. Zamknąć i przerwać je?' = 'A task is still running. Close and stop it?'
  'Potwierdź' = 'Confirm'
  'Ładowanie...' = 'Loading...'
  'Gotowe' = 'Ready'
  'Gotowe  |  F5 = odśwież bieżącą zakładkę' = 'Ready  |  F5 = refresh current tab'
  'Admin Toolbox gotowy. Wyniki poleceń pojawiają się tutaj. F5 odświeża bieżącą zakładkę.' = 'Admin Toolbox ready. Command results appear here. F5 refreshes the current tab.'
  '!!! Tryb ograniczony: funkcje wymagające administratora są wyłączone (szare przyciski).' = '!!! Limited mode: functions requiring administrator rights are disabled (greyed-out buttons).'
  '!!! Zadanie przerwane przez użytkownika.' = '!!! Task stopped by the user.'
  'Brak pliku logu błędów (nie wystąpiły błędy).' = 'No error log file (no errors have occurred).'
  'Plik error.log zawiera komunikaty diagnostyczne (mogą to być niegroźne, obsłużone błędy). Narzędzia > Otwórz log błędów.' = 'The error.log file contains diagnostic messages (they may be harmless, handled errors). Tools > Open error log.'
  'Plik tekstowy (*.txt)|*.txt' = 'Text file (*.txt)|*.txt'
  'Raport HTML (*.html)|*.html' = 'HTML report (*.html)|*.html'
  'Włącz wpis' = 'Enable entry'
  'Wyłącz wpis' = 'Disable entry'
  'Usuń wpis' = 'Delete entry'
  'Otwórz lokalizację' = 'Open location'
  'Włączony' = 'Enabled'
  'Ta pozycja wymaga uprawnień administratora.' = 'This item requires administrator privileges.'
  'Nie udało się ustalić pliku programu.' = 'Could not determine the program file.'
  'HKCU Run (bieżący użytkownik)' = 'HKCU Run (current user)'
  'HKLM Run (wszyscy użytkownicy)' = 'HKLM Run (all users)'
  'HKLM Run 32-bit' = 'HKLM Run 32-bit'
  'Folder Autostart (bieżący użytkownik)' = 'Startup folder (current user)'
  'Folder Autostart (wszyscy użytkownicy)' = 'Startup folder (all users)'
  'KOMPUTER' = 'COMPUTER'
  'SIEĆ (aktywne karty)' = 'NETWORK (active adapters)'
  'Producent/model' = 'Manufacturer/model'
  'Ostatni start' = 'Last boot'
  ' rdzeni / ' = ' cores / '
  ' wątków)' = ' threads)'
  ' GB wolne z ' = ' GB free of '
  '    Brama: ' = '    Gateway: '
  '  (nie udało się odczytać: ' = '  (could not read: '
  'Dyski' = 'Drives'
  'Najbardziej pamięciożerne procesy (15)' = 'Top memory-consuming processes (15)'
  'Usługi automatyczne, które nie działają' = 'Automatic services that are not running'
  'Błędy systemowe z ostatnich 24 godzin' = 'System errors from the last 24 hours'
  'Ostatnie poprawki Windows' = 'Recent Windows hotfixes'
  'Dysk' = 'Drive'
  'Rozmiar (GB)' = 'Size (GB)'
  'Wolne (GB)' = 'Free (GB)'
  'raport-' = 'report-'
  '<p><i>Brak danych.</i></p>' = '<p><i>No data.</i></p>'
}
$global:TrFrag = @(
  @('Generowanie raportu systemowego...', 'Generating system report...'),
  @('Błędy systemowe z ostatnich 24 h', 'System errors from the last 24 h'),
  @('<<< zakończono (kod wyjścia: ', '<<< finished (exit code: '),
  @('Usunąć pozycję autostartu "', 'Delete startup item "'),
  @('Uruchomiono deinstalator: ', 'Started uninstaller: '),
  @('<h1>Raport stanu systemu: ', '<h1>System status report: '),
  @('BŁĄD (własne polecenia): ', 'ERROR (custom commands): '),
  @('UŻYTKOWNIK (ograniczony)', 'USER (limited)'),
  @('Autostart: wyłączono "', 'Startup: disabled "'),
  @('<<< raport zapisany: ', '<<< report saved: '),
  @('Autostart: włączono "', 'Startup: enabled "'),
  @('Autostart: usunięto "', 'Startup: deleted "'),
  @('Grupa Administratorzy', 'Administrators group'),
  @('Pozycji autostartu: ', 'Startup items: '),
  @('Restart Eksploratora', 'Restart Explorer'),
  @('Usunąć polecenie "', 'Delete command "'),
  @('Punkt przywracania', 'Restore point'),
  @('Zakończyć proces ', 'End process '),
  @('<p>Wygenerowano: ', '<p>Generated: '),
  @('Czyszczenie TEMP', 'Cleaning TEMP'),
  @('Poprawki Windows', 'Windows hotfixes'),
  @('Zakończono PID ', 'Terminated PID '),
  @('BŁĄD (dziennik ', 'ERROR (log '),
  @('BŁĄD (raport): ', 'ERROR (report): '),
  @('Odinstalować "', 'Uninstall "'),
  @('Publiczny IP: ', 'Public IP: '),
  @('Raport baterii', 'Battery report'),
  @('Raport energii', 'Energy report'),
  @('Karty sieciowe', 'Network adapters'),
  @('<title>Raport ', '<title>Report '),
  @('Czy na pewno ', 'Are you sure you want to '),
  @('Odnowienie IP', 'IP renewal'),
  @('Profile Wi-Fi', 'Wi-Fi profiles'),
  @('Zakończono: ', 'Terminated: '),
  @('Zakończyć: ', 'End: '),
  @('Programów: ', 'Programs: '),
  @('  |  tryb: ', '  |  mode: '),
  @('Stan dysków', 'Disk health'),
  @('Test portu ', 'Port test '),
  @('Zapisano: ', 'Saved: '),
  @('Zdarzenie ', 'Event '),
  @('Procesów: ', 'Processes: '),
  @('Wyłączenie', 'Shutdown'),
  @('Zdarzeń: ', 'Events: '),
  @('wyłączyć', 'disable'),
  @(' konto "', ' account "'),
  @('Zadanie ', 'Task '),
  @('Wpisów: ', 'Entries: '),
  @('włączyć', 'enable'),
  @('Usługa ', 'Service '),
  @('Usług: ', 'Services: '),
  @('Zadań: ', 'Tasks: '),
  @('Konto ', 'Account '),
  @('Trwa: ', 'Running: '),
  @('Zapora', 'Firewall'),
  @('Anuluj', 'Cancel'),
  @('BŁĄD', 'ERROR'),
  @('Kosz', 'Recycle bin')
)

# ---------- tłumaczenia: nowe moduły ----------
$global:TrNew = @(
  @('Bezpieczeństwo', 'Security'),
  @('Sprzęt', 'Hardware'),
  @('Sprzątanie', 'Cleanup'),
  @('Dysk', 'Disk'),
  @('Zdalnie', 'Remote'),
  @('Kategoria', 'Category'),
  @('Element', 'Item'),
  @('Szczegóły', 'Details'),
  @('Wartość', 'Value'),
  @('Klasa', 'Class'),
  @('Urządzenie', 'Device'),
  @('Producent', 'Manufacturer'),
  @('Wersja', 'Version'),
  @('Data', 'Date'),
  @('Podpisany', 'Signed'),
  @('Tak', 'Yes'),
  @('Nie', 'No'),
  @('Rozmiar (MB)', 'Size (MB)'),
  @('Pliki', 'Files'),
  @('Uwagi', 'Notes'),
  @('Udział', 'Share'),
  @('Usługa', 'Service'),
  @('Konto', 'Account'),
  @('Linia poleceń', 'Command line'),
  @('Grupa i data', 'Group and date'),
  @('Podzespoły', 'Components'),
  @('Sterowniki', 'Drivers'),
  @('Największe foldery', 'Largest folders'),
  @('Największe pliki', 'Largest files'),
  @('Duplikaty', 'Duplicates'),
  @('(pliki w tym folderze)', '(files in this folder)'),
  @('Widok:', 'View:'),
  @('Komputer:', 'Computer:'),
  @('Folder:', 'Folder:'),
  @('Tryb:', 'Mode:'),
  @('Kategoria:', 'Category:'),
  @('Min. rozmiar duplikatów:', 'Min. duplicate size:'),
  @('Hasło:', 'Password:'),
  @('Użytkownik (DOMENA\login):', 'User (DOMAIN\login):'),
  @('Konto: bieżący użytkownik', 'Account: current user'),
  @('Hasło jest przechowywane tylko w pamięci do zamknięcia programu.', 'The password is kept in memory only until the program is closed.'),
  @('Najpierw kliknij "Skanuj", zaznacz kategorie (Ctrl+klik) i wybierz "Wyczyść zaznaczone".', 'First click "Scan", select categories (Ctrl+click) and choose "Clean selected".'),
  @('Starsze niż 3 lata', 'Older than 3 years'),
  @('Niepodpisane', 'Unsigned'),
  @('Analizuj', 'Analyze'),
  @('Aktualizuj sygnatury', 'Update signatures'),
  @('Szybki skan Defendera', 'Defender quick scan'),
  @('Administratorzy lokalni', 'Local administrators'),
  @('Udziały sieciowe', 'Network shares'),
  @('Nieudane logowania (24 h)', 'Failed logons (24 h)'),
  @('Centrum zabezpieczeń', 'Security Center'),
  @('Windows Update', 'Windows Update'),
  @('Urządzenia z błędami', 'Devices with errors'),
  @('Skanuj zmiany sprzętu', 'Scan for hardware changes'),
  @('Eksportuj sterowniki', 'Export drivers'),
  @('Menedżer urządzeń', 'Device Manager'),
  @('Skanuj', 'Scan'),
  @('Zaznacz bezpieczne', 'Select safe'),
  @('Podgląd plików', 'Preview files'),
  @('Wyczyść zaznaczone', 'Clean selected'),
  @('Przerwij', 'Cancel'),
  @('Wybierz...', 'Browse...'),
  @('Zaznacz duplikaty', 'Select duplicates'),
  @('Do kosza', 'To Recycle Bin'),
  @('Poświadczenia...', 'Credentials...'),
  @('Wczytaj', 'Load'),
  @('Informacje', 'Information'),
  @('Zakończ proces', 'End process'),
  @('Start usługi', 'Start service'),
  @('Stop usługi', 'Stop service'),
  @('Restart usługi', 'Restart service'),
  @('Restart zdalny', 'Remote restart'),
  @('Wyłącz zdalnie', 'Remote shutdown'),
  @('Wyloguj zdalnie', 'Remote log off'),
  @('Udział C$', 'C$ share'),
  @('Pulpit zdalny', 'Remote Desktop'),
  @('Edytuj...', 'Edit...'),
  @('Duplikuj', 'Duplicate'),
  @('Uruchom kategorię', 'Run category'),
  @('Eksport profilu...', 'Export profile...'),
  @('Import profilu...', 'Import profile...'),
  @('Ponownie sprawdza ustawienia bezpieczeństwa systemu', 'Re-checks the security settings of the system'),
  @('Zdarzenia 4625 z dziennika Security (wymaga administratora)', 'Event 4625 from the Security log (requires administrator)'),
  @('Wypisuje w logu urządzenia, które zgłaszają błąd w Menedżerze urządzeń', 'Lists in the log the devices that report an error in Device Manager'),
  @('Zapisuje kopię zainstalowanych sterowników (Export-WindowsDriver)', 'Saves a copy of the installed drivers (Export-WindowsDriver)'),
  @('Oblicza ile miejsca zajmują pliki tymczasowe i cache', 'Calculates how much space temporary files and caches use'),
  @('Wypisuje w logu największe pliki zaznaczonej kategorii', 'Lists the largest files of the selected category in the log'),
  @('Zaznacza wszystkie kopie oprócz najstarszej w każdej grupie', 'Selects all copies except the oldest one in each group'),
  @('Przenosi zaznaczone pliki lub foldery do Kosza (można przywrócić)', 'Moves the selected files or folders to the Recycle Bin (can be restored)'),
  @('Konto używane do połączenia (puste = bieżący użytkownik)', 'Account used to connect (empty = current user)'),
  @('Pobiera listę procesów lub usług z komputera zdalnego', 'Fetches the list of processes or services from the remote computer'),
  @('System, sprzęt, dyski i adresy IP komputera zdalnego (także test połączenia)', 'System, hardware, disks and IP addresses of the remote computer (also a connection test)'),
  @('Uruchamia kolejno wszystkie polecenia z kategorii zaznaczonego wiersza', 'Runs in turn all commands from the category of the selected row'),
  @('Zapisuje polecenia i listę komputerów zdalnych do pliku JSON', 'Saves commands and the list of remote computers to a JSON file'),
  @('Dołącza polecenia z pliku JSON (duplikaty są pomijane)', 'Adds commands from a JSON file (duplicates are skipped)'),
  @('Poświadczenia zdalne', 'Remote credentials'),
  @('Edytuj polecenie', 'Edit command'),
  @('Wybierz folder do analizy', 'Select a folder to analyze'),
  @('Wybierz folder docelowy dla kopii sterowników', 'Select the destination folder for the driver backup'),
  @('Profil Admin Toolbox (*.json)|*.json', 'Admin Toolbox profile (*.json)|*.json'),
  @('Profil Admin Toolbox (*.json)|*.json|Wszystkie pliki (*.*)|*.*', 'Admin Toolbox profile (*.json)|*.json|All files (*.*)|*.*'),
  @('Poprzednia operacja jeszcze trwa. Poczekaj lub kliknij "Przerwij".', 'The previous operation is still running. Wait or click "Cancel".'),
  @('Podaj istniejący folder lub dysk do analizy.', 'Enter an existing folder or drive to analyze.'),
  @('Podaj poprawną nazwę komputera lub adres IP.', 'Enter a valid computer name or IP address.'),
  @('Najpierw uruchom analizę w trybie "Duplikaty".', 'First run the analysis in "Duplicates" mode.'),
  @('Zaznacz kategorię.', 'Select a category.'),
  @('Zaznacz kategorie do wyczyszczenia.', 'Select the categories to clean.'),
  @('Zaznacz pozycje do przeniesienia do kosza.', 'Select the items to move to the Recycle Bin.'),
  @('Zaznacz proces na liście procesów zdalnych.', 'Select a process in the remote process list.'),
  @('Zaznacz usługę na liście usług zdalnych.', 'Select a service in the remote service list.'),
  @('Zaznaczone polecenie nie ma kategorii.', 'The selected command has no category.'),
  @('Nie ma nic do usunięcia w zaznaczeniu.', 'There is nothing to delete in the selection.'),
  @('Nie ma nic do wyczyszczenia w zaznaczonych kategoriach.', 'There is nothing to clean in the selected categories.'),
  @('Nie udało się odczytać pliku profilu (nieprawidłowy format).', 'Could not read the profile file (invalid format).'),
  @('Nie udało się załadować obsługi kosza.', 'Could not load Recycle Bin support.'),
  @('Nie znaleziono pliku lub folderu.', 'File or folder not found.'),
  @('Nie znaleziono usługi.', 'Service not found.'),
  @('Proces już nie istnieje.', 'The process no longer exists.'),
  @('Podgląd plików nie jest dostępny dla kosza.', 'File preview is not available for the Recycle Bin.'),
  @('Brak plików do wyświetlenia.', 'No files to display.'),
  @('Brak urządzeń zgłaszających błędy.', 'No devices reporting errors.'),
  @('Brak zdarzeń lub brak dostępu.', 'No events or no access.'),
  @('Gotowe.', 'Done.'),
  @('Pliki w użyciu zostaną pominięte. Operacji nie można cofnąć.', 'Files in use will be skipped. This cannot be undone.'),
  @('Ta operacja jest zablokowana dla komputera lokalnego (użyj zakładki Naprawa).', 'This operation is blocked for the local computer (use the Repair tab).'),
  @('Sprawdź: czy komputer jest włączony, czy usługa WinRM jest uruchomiona (winrm quickconfig), zapora oraz uprawnienia konta.', 'Check: that the computer is on, that the WinRM service is running (winrm quickconfig), the firewall and the account permissions.'),
  @('Importować polecenia z pliku? Zaimportowane polecenia nie są uruchamiane automatycznie. Uruchamiaj tylko polecenia z zaufanych źródeł.', 'Import commands from the file? Imported commands are not run automatically. Run only commands from trusted sources.'),
  @('Uruchomić szybki skan Microsoft Defender?', 'Run a Microsoft Defender quick scan?'),
  @('Aktualizacja sygnatur', 'Signature update'),
  @('Nieudane logowania', 'Failed logons'),
  @('Skanowanie sprzętu', 'Hardware scan'),
  @('Eksport sterowników', 'Driver export'),
  @('Dysk fizyczny', 'Physical disk'),
  @('Wolumin', 'Volume'),
  @('Antywirus', 'Antivirus'),
  @('Zapora', 'Firewall'),
  @('Aktualizacje', 'Updates'),
  @('Konta i dostęp', 'Accounts and access'),
  @('Sieć', 'Network'),
  @('Szyfrowanie', 'Encryption'),
  @('Procesor', 'Processor'),
  @('Płyta główna', 'Motherboard'),
  @('Pamięć RAM', 'RAM'),
  @('Karta graficzna', 'Graphics card'),
  @('Bateria', 'Battery'),
  @('Temperatura', 'Temperature'),
  @('Microsoft Defender', 'Microsoft Defender'),
  @('Ochrona w czasie rzeczywistym', 'Real-time protection'),
  @('Sygnatury wirusów', 'Virus signatures'),
  @('Ostatni szybki skan', 'Last quick scan'),
  @('Ochrona przed manipulacją', 'Tamper protection'),
  @('Zarejestrowane programy AV', 'Registered AV products'),
  @('Zapora Windows', 'Windows Firewall'),
  @('BitLocker, Secure Boot, TPM', 'BitLocker, Secure Boot, TPM'),
  @('Ostatnia poprawka', 'Latest hotfix'),
  @('Oczekuje restart', 'Restart pending'),
  @('Usługa Windows Update', 'Windows Update service'),
  @('Kontrola konta (UAC)', 'User Account Control (UAC)'),
  @('Automatyczne logowanie', 'Automatic sign-in'),
  @('Pulpit zdalny (RDP)', 'Remote Desktop (RDP)'),
  @('Konto Gość', 'Guest account'),
  @('Wbudowany administrator', 'Built-in administrator'),
  @('Konta bez wymaganego hasła', 'Accounts without a required password'),
  @('Protokół SMBv1', 'SMBv1 protocol'),
  @('Rejestr zdalny', 'Remote Registry'),
  @('Czujniki ACPI', 'ACPI sensors'),
  @('Razem', 'Total'),
  @('Dyski', 'Disks'),
  @('Włączony', 'Enabled'),
  @('Wyłączony', 'Disabled'),
  @('Włączona', 'Enabled'),
  @('Wyłączona', 'Disabled'),
  @('Włączone', 'Enabled'),
  @('Wyłączone', 'Disabled'),
  @('Niedostępny', 'Unavailable'),
  @('Niedostępna', 'Unavailable'),
  @('Niedostępne', 'Unavailable'),
  @('Brak danych', 'No data'),
  @('Brak', 'None'),
  @('Gotowy', 'Ready'),
  @('Obecny, niegotowy', 'Present, not ready'),
  @('Dostępna', 'Available'),
  @('Uruchomiony', 'Running'),
  @('Zatrzymany', 'Stopped'),
  @('Wymaga administratora', 'Requires administrator'),
  @('Brak własnych udziałów', 'No custom shares'),
  @('Brak aktywnej ochrony antywirusowej', 'No active antivirus protection'),
  @('Inny program antywirusowy lub brak dostępu do danych', 'Another antivirus program or no access to the data'),
  @('Nie udało się odczytać profili zapory', 'Could not read the firewall profiles'),
  @('Funkcja nie jest obsługiwana w tej edycji systemu', 'The feature is not supported in this edition of the system'),
  @('System w trybie Legacy BIOS lub brak obsługi', 'System in Legacy BIOS mode or not supported'),
  @('Uruchom narzędzie jako administrator, aby sprawdzić', 'Run the tool as administrator to check'),
  @('Aktualizacje nie będą pobierane', 'Updates will not be downloaded'),
  @('Zainstalowane zmiany wymagają ponownego uruchomienia', 'Installed changes require a restart'),
  @('Zalecane włączenie', 'Enabling is recommended'),
  @('Hasło może być zapisane w rejestrze', 'The password may be stored in the registry'),
  @('Bez uwierzytelniania NLA', 'Without NLA authentication'),
  @('Z uwierzytelnianiem NLA', 'With NLA authentication'),
  @('Przestarzały i podatny na ataki, zalecane wyłączenie', 'Obsolete and vulnerable to attacks, disabling is recommended'),
  @('Umożliwia zdalny odczyt rejestru', 'Allows remote reading of the registry'),
  @('Nie udało się odczytać stanu dysków', 'Could not read the disk status'),
  @('Strefa termiczna ACPI', 'ACPI thermal zone'),
  @('System nie udostępnia temperatur przez WMI (użyj narzędzia producenta)', 'The system does not expose temperatures through WMI (use the manufacturer tool)'),
  @('Pliki tymczasowe użytkownika', 'User temporary files'),
  @('Pliki tymczasowe systemu', 'System temporary files'),
  @('Cache miniatur Eksploratora', 'Explorer thumbnail cache'),
  @('Cache Google Chrome', 'Google Chrome cache'),
  @('Cache Microsoft Edge', 'Microsoft Edge cache'),
  @('Cache Brave', 'Brave cache'),
  @('Cache Mozilla Firefox', 'Mozilla Firefox cache'),
  @('Pobrane aktualizacje Windows', 'Downloaded Windows updates'),
  @('Raporty błędów Windows (WER)', 'Windows Error Reporting (WER) reports'),
  @('Zrzuty pamięci i awarii', 'Memory and crash dumps'),
  @('Poprzednia instalacja Windows (Windows.old)', 'Previous Windows installation (Windows.old)'),
  @('Zamknij przeglądarkę', 'Close the browser'),
  @('Skanowanie...', 'Scanning...'),
  @('Przerwano.', 'Cancelled.'),
  @('Tylko informacja: usuń przez Oczyszczanie dysku', 'Information only: remove with Disk Cleanup')
)
foreach ($p in $global:TrNew) { if (-not $global:TrExact.ContainsKey($p[0])) { $global:TrExact[$p[0]] = $p[1] } }
$global:TrNewFrag = @(
  @(' (ok. ', ' (approx. '),
  @('Pliki w użyciu zostaną pominięte. Operacji nie można cofnąć.', 'Files in use will be skipped. This cannot be undone.'),
  @('  (obciążenie: ', '  (load: '),
  @('Pomijam (usuń przez Oczyszczanie dysku): ', 'Skipping (remove with Disk Cleanup): '),
  @('Pomijam (wymaga administratora): ', 'Skipping (requires administrator): '),
  @('Pomijam chroniony element systemowy: ', 'Skipping protected system item: '),
  @('Trwale usunąć zawartość poniższych kategorii (ok. ', 'Permanently delete the contents of the following categories (approx. '),
  @('Uruchomić kolejno polecenia z kategorii "', 'Run in turn the commands from the category "'),
  @('Przenieść do kosza zaznaczone pozycje: ', 'Move the selected items to the Recycle Bin: '),
  @('Wykonać operację na usłudze zdalnej "', 'Perform the operation on the remote service "'),
  @('WYLOGOWAĆ użytkownika na', 'LOG OFF the user on'),
  @('Zakończyć zdalny proces ', 'End remote process '),
  @('Zakończono zdalny proces: ', 'Ended remote process: '),
  @('Uruchomiono usługę zdalną: ', 'Started remote service: '),
  @('Zatrzymano usługę zdalną: ', 'Stopped remote service: '),
  @('Informacje o komputerze: ', 'Computer information: '),
  @('Największe pliki: ', 'Largest files: '),
  @('Wysłano polecenie (', 'Command sent ('),
  @('Odzyskano łącznie: ', 'Total recovered: '),
  @('Zaimportowano poleceń: ', 'Imported commands: '),
  @(', pominięto duplikaty: ', ', skipped duplicates: '),
  @('Przeniesiono do kosza: ', 'Moved to Recycle Bin: '),
  @('Kontrola bezpieczeństwa: problemy ', 'Security check: issues '),
  @(', ostrzeżenia ', ', warnings '),
  @('Porównywanie plików: ', 'Comparing files: '),
  @('Plików przeskanowano: ', 'Files scanned: '),
  @(', łącznie ', ', total '),
  @('Grup duplikatów: ', 'Duplicate groups: '),
  @(', do odzyskania: ', ', recoverable: '),
  @('Do odzyskania: ', 'Recoverable: '),
  @('Procesów zdalnych: ', 'Remote processes: '),
  @('Usług zdalnych: ', 'Remote services: '),
  @('Pobrano informacje: ', 'Information retrieved: '),
  @('Pozycji sprzętu: ', 'Hardware items: '),
  @('Sterowników: ', 'Drivers: '),
  @('Łączenie z ', 'Connecting to '),
  @('BŁĄD połączenia z ', 'ERROR connecting to '),
  @('Skanowanie: ', 'Scanning: '),
  @('Czyszczenie: ', 'Cleaning: '),
  @('Wyczyszczono: ', 'Cleaned: '),
  @(' (odzyskano ', ' (recovered '),
  @('Razem: ', 'Total: '),
  @(' podfolderach', ' subfolders'),
  @('Zestaw: ', 'Set: '),
  @('Konto: ', 'Account: '),
  @('Profil: ', 'Profile: '),
  @('Liczba: ', 'Count: '),
  @('Wiek: ', 'Age: '),
  @(' dni', ' days'),
  @('Dni temu: ', 'Days ago: '),
  @(', dni temu: ', ', days ago: '),
  @('Wersja ', 'Version '),
  @('Ruch przychodzący: ', 'Inbound traffic: '),
  @('Zaszyfrowano: ', 'Encrypted: '),
  @(', metoda: ', ', method: '),
  @('Typ uruchomienia: ', 'Startup type: '),
  @('Naładowanie ', 'Charge '),
  @('Wolne ', 'Free '),
  @(' wolne z ', ' free of '),
  @('Sterownik ', 'Driver '),
  @('Data sterownika: ', 'Driver date: '),
  @('Numer seryjny: ', 'Serial number: '),
  @(' rdzeni / ', ' cores / '),
  @(' wątków', ' threads'),
  @('Maks. taktowanie: ', 'Max. clock: '),
  @(', obciążenie: ', ', load: '),
  @(', temperatura: ', ', temperature: '),
  @(', zużycie: ', ', wear: '),
  @(', godziny pracy: ', ', power-on hours: '),
  @(', błędy odczytu: ', ', read errors: '),
  @('Kondycja: ', 'Health: '),
  @('% pojemności fabrycznej (', '% of design capacity ('),
  @('  (kod błędu: ', '  (error code: '),
  @(' komputer zdalny ', ' the remote computer '),
  @('ZRESTARTOWAĆ', 'RESTART'),
  @('WYŁĄCZYĆ', 'SHUT DOWN'),
  @('? Niezapisane dane użytkownika mogą zostać utracone.', '? Unsaved user data may be lost.'),
  @('Urządzenia z błędami', 'Devices with errors'),
  @('Zalogowany: ', 'Logged on: '),
  @('Ostatni start: ', 'Last boot: '),
  @('Model: ', 'Model: '),
  @('Nazwa: ', 'Name: '),
  @('Domena: ', 'Domain: '),
  @('Dysk ', 'Disk '),
  @('  (działa: ', '  (uptime: ')
)
$global:TrFrag = @(@($global:TrFrag) + @($global:TrNewFrag) | Sort-Object { $_[0].Length } -Descending)

function Get-Tr($s) {
  if ($global:Lang -ne 'en') { return $s }
  if ([string]::IsNullOrEmpty($s)) { return $s }
  if ($global:TrExact.ContainsKey($s)) { return $global:TrExact[$s] }
  $r = $s
  foreach ($p in $global:TrFrag) { if ($r.Contains($p[0])) { $r = $r.Replace($p[0], $p[1]) } }
  return $r
}
function L($s) { return (Get-Tr $s) }

$global:Orig = @{}
$global:OrigCols = @{}
$global:OrigItems = @{}
$global:OrigTip = @{}

function Set-Tip($c, $t) {
  $global:OrigTip[$c] = $t
  $global:Tip.SetToolTip($c, (Get-Tr $t))
}
# ---------- /i18n ----------

# ---------- pomocnicze ----------
function Say($m) { [void][Windows.Forms.MessageBox]::Show((L $m), 'Admin Toolbox') }
function Ask($m) { return ([Windows.Forms.MessageBox]::Show((L $m), (L 'Potwierdź'), 'YesNo', 'Question') -eq 'Yes') }

function Set-Status($t) {
  if (-not $global:StatusLbl) { return }
  $global:StatusLbl.Text = (L $t)
  if ($global:StatusLbl.IsHandleCreated) { $global:StatusLbl.Refresh() }
}

# ---------- obsługa błędów ----------
$global:ErrLog = Join-Path $env:APPDATA 'AdminToolbox\error.log'
$global:LastErr = $null
$global:ErrSeen = @{}
$global:ErrCount = 0

function Log-Error($ctx, $err) {
  try {
    $msg = ''
    $pos = ''
    $stk = ''
    if ($err -is [Management.Automation.ErrorRecord]) {
      $msg = [string]$err.Exception.Message
      if ($err.InvocationInfo) { $pos = [string]$err.InvocationInfo.PositionMessage }
      $stk = [string]$err.ScriptStackTrace
    } elseif ($err -is [Exception]) {
      $msg = [string]$err.Message
      $stk = [string]$err.StackTrace
    } else { $msg = [string]$err }
    $key = $ctx + '|' + $msg
    if ($global:ErrSeen.ContainsKey($key)) { return }
    $global:ErrSeen[$key] = 1
    $global:ErrCount++
    if ($global:ErrCount -gt 300) { return }
    $dir = Split-Path $global:ErrLog
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if ((Test-Path $global:ErrLog) -and ((Get-Item $global:ErrLog).Length -gt 1MB)) { Move-Item $global:ErrLog ($global:ErrLog + '.old') -Force }
    $text = (Get-Date -Format 's') + ' [' + $ctx + '] ' + $msg + "`r`n" + $pos + "`r`n" + $stk + "`r`n----`r`n"
    [IO.File]::AppendAllText($global:ErrLog, $text, (New-Object Text.UTF8Encoding($false)))
  } catch {}
}

function Report-Error($err, $ctx = 'ui') {
  $m = ''
  if ($err -is [Management.Automation.ErrorRecord]) { $m = [string]$err.Exception.Message }
  elseif ($err -is [Exception]) { $m = [string]$err.Message }
  else { $m = [string]$err }
  Log-Error $ctx $err
  try { Write-Log ('BŁĄD: ' + $m) } catch {}
}

function Guard($sb, $ctx = 'event') {
  try { & $sb } catch { Report-Error $_ $ctx }
}

function Flush-Errors {
  try {
    $new = @()
    foreach ($e in $global:Error) {
      if ([object]::ReferenceEquals($e, $global:LastErr)) { break }
      $new += $e
    }
    if ($new.Count -gt 0) {
      $global:LastErr = $global:Error[0]
      for ($i = $new.Count - 1; $i -ge 0; $i--) { Log-Error 'runtime' $new[$i] }
    }
  } catch {}
}

function Write-Log($t) {
  $t = L $t
  $rb = $global:LogBox
  $col = $global:LogFg
  if ($t -match '^\s*>>>') { $col = $global:LogCyan }
  elseif ($t -match '^\s*<<<') { $col = $global:LogYellow }
  elseif ($t -match 'BŁĄD|ERROR|^!!!') { $col = $global:LogRed }
  if ($rb.TextLength -gt 600000) { $rb.Select(0, 300000); $rb.SelectedText = '' }
  $rb.SelectionStart = $rb.TextLength
  $rb.SelectionLength = 0
  $rb.SelectionColor = $col
  $rb.AppendText($t + "`r`n")
  $rb.SelectionColor = $global:LogFg
  $rb.ScrollToCaret()
}

function Pump-Log {
  if (-not $global:LogFile -or -not (Test-Path -LiteralPath $global:LogFile)) { return }
  try {
    $fs = [IO.File]::Open($global:LogFile, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
      $n = $fs.Length - $global:LogPos
      if ($n -gt 0) {
        [void]$fs.Seek($global:LogPos, [IO.SeekOrigin]::Begin)
        $buf = New-Object byte[] $n
        $r = $fs.Read($buf, 0, $n)
        $global:LogPos += $r
        $txt = $global:Enc.GetString($buf, 0, $r) -replace "`r?`n", "`r`n"
        $rb = $global:LogBox
        $rb.SelectionStart = $rb.TextLength
        $rb.SelectionLength = 0
        $rb.SelectionColor = $global:LogFg
        $rb.AppendText($txt)
        $rb.ScrollToCaret()
      }
    } finally { $fs.Close() }
  } catch {}
}

function Start-Task($title, $cmd) {
  if ($global:Proc -and -not $global:Proc.HasExited) { Say 'Poprzednie zadanie jeszcze trwa. Poczekaj lub kliknij "Przerwij".'; return }
  Write-Log ("`r`n>>> " + $title + "  [" + (Get-Date -Format 'HH:mm:ss') + "]")
  $id = [guid]::NewGuid().ToString('N')
  $bat = Join-Path $global:RunDir ($id + '.cmd')
  $global:LogFile = Join-Path $global:RunDir ($id + '.log')
  $global:LogPos = 0
  $global:TaskBat = $bat
  $content = "@echo off`r`n(`r`n" + $cmd + "`r`n) > `"" + $global:LogFile + "`" 2>&1`r`n"
  [IO.File]::WriteAllText($bat, $content, $global:Enc)
  $psi = New-Object Diagnostics.ProcessStartInfo
  $psi.FileName = $bat
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $global:Proc = [Diagnostics.Process]::Start($psi)
  Set-Status ('Trwa: ' + $title)
  $global:BtnStop.Enabled = $true
  $global:Timer.Start()
}

function Get-HostInput {
  $h = $global:TxtHost.Text.Trim()
  if ($h -notmatch '^[A-Za-z0-9\.\-:_]+$') { Say 'Podaj poprawny host lub adres IP.'; return $null }
  return $h
}

# ---------- budowanie UI ----------
function Add-Btn($panel, $text, $action, $w = 160, $kind = 'normal', $tip = '') {
  $b = New-Object Windows.Forms.Button
  $b.Text = $text
  $b.Size = New-Object Drawing.Size($w, 32)
  $b.FlatStyle = 'Flat'
  $b.Margin = New-Object Windows.Forms.Padding(3)
  $b.Cursor = [Windows.Forms.Cursors]::Hand
  $b.Tag = $kind
  Style-Btn $b
  $b.Add_EnabledChanged({ Style-Btn $this })
  if ($tip) { Set-Tip $b $tip }
  $sb = $action
  $b.Add_Click({ try { & $sb } catch { Report-Error $_ 'click' } }.GetNewClosure())
  $panel.Controls.Add($b)
  return $b
}

function New-Bar($h = 46) {
  $p = New-Object Windows.Forms.FlowLayoutPanel
  $p.Dock = 'Top'
  $p.Height = $h
  $p.WrapContents = $true
  $p.Padding = New-Object Windows.Forms.Padding(4, 6, 4, 2)
  return $p
}

function New-Label($panel, $text) {
  $l = New-Object Windows.Forms.Label
  $l.Text = $text
  $l.AutoSize = $true
  $l.Margin = New-Object Windows.Forms.Padding(6, 9, 3, 0)
  $panel.Controls.Add($l)
  return $l
}

function New-Text($panel, $w, $text = '') {
  $t = New-Object Windows.Forms.TextBox
  $t.Width = $w
  $t.Text = $text
  $t.Margin = New-Object Windows.Forms.Padding(3, 6, 3, 0)
  $panel.Controls.Add($t)
  return $t
}

function New-Check($panel, $text, $w = 140) {
  $c = New-Object Windows.Forms.CheckBox
  $c.Text = $text
  $c.Width = $w
  $c.Margin = New-Object Windows.Forms.Padding(8, 8, 3, 0)
  $panel.Controls.Add($c)
  return $c
}

function New-Page($tab) {
  $p = New-Object Windows.Forms.FlowLayoutPanel
  $p.Dock = 'Fill'
  $p.FlowDirection = 'TopDown'
  $p.WrapContents = $false
  $p.AutoScroll = $true
  $p.Padding = New-Object Windows.Forms.Padding(8)
  $p.Add_HandleCreated({ Apply-NativeTheme $this })
  $tab.Controls.Add($p)
  return $p
}

function New-Group($page, $title) {
  $g = New-Object Windows.Forms.GroupBox
  $g.Text = $title
  $g.Font = New-Object Drawing.Font('Segoe UI Semibold', 9)
  $g.AutoSize = $true
  $g.AutoSizeMode = 'GrowAndShrink'
  $g.MinimumSize = New-Object Drawing.Size(950, 0)
  $g.Padding = New-Object Windows.Forms.Padding(6, 4, 6, 6)
  $g.Margin = New-Object Windows.Forms.Padding(0, 0, 0, 10)
  $f = New-Object Windows.Forms.FlowLayoutPanel
  $f.AutoSize = $true
  $f.AutoSizeMode = 'GrowAndShrink'
  $f.WrapContents = $true
  $f.FlowDirection = 'LeftToRight'
  $f.MaximumSize = New-Object Drawing.Size(930, 0)
  $f.Location = New-Object Drawing.Point(8, 22)
  $f.Font = New-Object Drawing.Font('Segoe UI', 9)
  $g.Controls.Add($f)
  $page.Controls.Add($g)
  return $f
}

function New-Tab($title, $key) {
  $t = New-Object Windows.Forms.TabPage
  $t.Text = $title
  $t.Name = $key
  [void]$global:Tabs.TabPages.Add($t)
  return $t
}

function New-List($cols) {
  $lv = New-Object Windows.Forms.ListView
  $lv.View = 'Details'
  $lv.FullRowSelect = $true
  $lv.GridLines = $true
  $lv.HideSelection = $false
  $lv.Dock = 'Fill'
  foreach ($c in $cols) { [void]$lv.Columns.Add($c[0], $c[1]) }
  $lv.Add_ColumnClick({ param($s, $e) Sort-List $s $e.Column $false })
  $lv.Add_DrawColumnHeader({ param($s, $e) try { Draw-Header $s $e } catch { Log-Error 'draw-header' $_ } })
  $lv.Add_DrawItem({ param($s, $e) })
  $lv.Add_DrawSubItem({ param($s, $e) try { Draw-SubItem $s $e } catch { Log-Error 'draw-item' $_ } })
  $lv.Add_Resize({ try { Fit-Last $this } catch { Log-Error 'resize' $_ } })
  $lv.Add_HandleCreated({ Apply-NativeTheme $this })
  return $lv
}

function Sort-List($lv, $col, $keep = $false) {
  $asc = $true
  if ($lv.Tag) {
    if ($keep) { $asc = $lv.Tag.Asc }
    elseif ($lv.Tag.Col -eq $col) { $asc = -not $lv.Tag.Asc }
  }
  $lv.Tag = @{ Col = $col; Asc = $asc }
  $items = @($lv.Items | ForEach-Object { $_ })
  if ($items.Count -lt 2) { return }
  $inv = [Globalization.CultureInfo]::InvariantCulture
  $num = $true
  foreach ($i in $items) {
    $d = [double]0
    if (-not [double]::TryParse($i.SubItems[$col].Text, [Globalization.NumberStyles]::Float, $inv, [ref]$d)) { $num = $false; break }
  }
  if ($num) {
    $sorted = $items | Sort-Object { [double]::Parse($_.SubItems[$col].Text, $inv) } -Descending:(-not $asc)
  } else {
    $sorted = $items | Sort-Object { $_.SubItems[$col].Text } -Descending:(-not $asc)
  }
  $lv.BeginUpdate()
  $lv.Items.Clear()
  foreach ($i in $sorted) { [void]$lv.Items.Add($i) }
  $lv.EndUpdate()
}

function Add-Row($lv, $cells) {
  $it = New-Object Windows.Forms.ListViewItem([string]$cells[0])
  for ($k = 1; $k -lt $cells.Count; $k++) { [void]$it.SubItems.Add([string]$cells[$k]) }
  [void]$lv.Items.Add($it)
  return $it
}

function Export-List($lv) {
  $d = New-Object Windows.Forms.SaveFileDialog
  $d.Filter = 'CSV (*.csv)|*.csv'
  $d.FileName = 'eksport.csv'
  $d.InitialDirectory = [Environment]::GetFolderPath('Desktop')
  if ($d.ShowDialog() -ne 'OK') { return }
  $sb = New-Object Text.StringBuilder
  $hdr = @()
  foreach ($c in $lv.Columns) { $hdr += ('"' + $c.Text.Replace('"', '""') + '"') }
  [void]$sb.AppendLine(($hdr -join ';'))
  foreach ($it in $lv.Items) {
    $r = @()
    foreach ($s in $it.SubItems) { $r += ('"' + $s.Text.Replace('"', '""') + '"') }
    [void]$sb.AppendLine(($r -join ';'))
  }
  [IO.File]::WriteAllText($d.FileName, $sb.ToString(), (New-Object Text.UTF8Encoding($true)))
  Write-Log ('Zapisano: ' + $d.FileName)
}

# ---------- logika: pulpit ----------
function SysRow($label, $value) { return ('  ' + (L $label).PadRight(20) + ': ' + $value) }

function Get-SysInfo {
  $os = Get-CimInstance Win32_OperatingSystem
  $cs = Get-CimInstance Win32_ComputerSystem
  $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
  $bios = Get-CimInstance Win32_BIOS
  $up = (Get-Date) - $os.LastBootUpTime
  $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
  $freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
  $sb = New-Object Text.StringBuilder
  [void]$sb.AppendLine((L 'KOMPUTER'))
  [void]$sb.AppendLine((SysRow 'Nazwa' $env:COMPUTERNAME))
  [void]$sb.AppendLine((SysRow 'Użytkownik' ($env:USERDOMAIN + '\' + $env:USERNAME)))
  [void]$sb.AppendLine((SysRow 'System' ($os.Caption + ' (build ' + $os.BuildNumber + ', ' + $os.OSArchitecture + ')')))
  [void]$sb.AppendLine((SysRow 'Producent/model' ($cs.Manufacturer + ' ' + $cs.Model)))
  [void]$sb.AppendLine((SysRow 'BIOS' $bios.SMBIOSBIOSVersion))
  [void]$sb.AppendLine((SysRow 'Procesor' ($cpu.Name.Trim() + ' (' + $cpu.NumberOfCores + (L ' rdzeni / ') + $cpu.NumberOfLogicalProcessors + (L ' wątków)'))))
  [void]$sb.AppendLine((SysRow 'RAM' ($freeGB + (L ' GB wolne z ') + $totalGB + ' GB')))
  [void]$sb.AppendLine((SysRow 'Uptime' ($up.Days + ' d ' + $up.Hours + ' h ' + $up.Minutes + ' min')))
  [void]$sb.AppendLine((SysRow 'Ostatni start' $os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm')))
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine(((L 'Dyski').ToUpper()))
  foreach ($d in (Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3')) {
    $sz = [math]::Round($d.Size / 1GB, 1)
    $fr = [math]::Round($d.FreeSpace / 1GB, 1)
    $pct = 0
    if ($d.Size -gt 0) { $pct = [int][math]::Round(100 * ($d.Size - $d.FreeSpace) / $d.Size) }
    $bar = ('#' * [int]($pct / 5)).PadRight(20, '.')
    [void]$sb.AppendLine('  ' + $d.DeviceID + '  [' + $bar + '] ' + $pct + '%   ' + $fr + (L ' GB wolne z ') + $sz + ' GB')
  }
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine((L 'SIEĆ (aktywne karty)'))
  try {
    $cfgs = Get-NetIPConfiguration -ErrorAction Stop | Where-Object { $_.NetAdapter.Status -eq 'Up' -and $_.IPv4Address }
    foreach ($c in $cfgs) {
      $ip = ($c.IPv4Address | ForEach-Object { $_.IPAddress + '/' + $_.PrefixLength }) -join ', '
      $gw = ''
      if ($c.IPv4DefaultGateway) { $gw = $c.IPv4DefaultGateway.NextHop }
      $dns = ($c.DnsServer | Where-Object { $_.AddressFamily -eq 2 } | ForEach-Object { $_.ServerAddresses }) -join ', '
      [void]$sb.AppendLine('  ' + $c.InterfaceAlias + '  (MAC ' + $c.NetAdapter.MacAddress + ')')
      [void]$sb.AppendLine('      IP: ' + $ip + (L '    Brama: ') + $gw)
      [void]$sb.AppendLine('      DNS: ' + $dns)
    }
  } catch { [void]$sb.AppendLine((L '  (nie udało się odczytać: ') + $_.Exception.Message + ')') }
  return $sb.ToString()
}

function Refresh-Sys { $global:TxtSys.Text = (Get-SysInfo) -replace "`r?`n", "`r`n" }

function Update-Meters {
  try {
    if ($global:PerfCpu) {
      $cpu = [int][math]::Min(100, [math]::Round($global:PerfCpu.NextValue()))
    } else {
      $cpu = [int](Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
    }
    $os = Get-CimInstance Win32_OperatingSystem -Property FreePhysicalMemory, TotalVisibleMemorySize
    $ram = [int][math]::Round(100 * ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize)
    $global:PbCpu.Value = [math]::Max(0, [math]::Min(100, $cpu))
    $global:PbRam.Value = [math]::Max(0, [math]::Min(100, $ram))
    $global:LblCpu.Text = 'CPU  ' + $cpu + '%'
    $global:LblRam.Text = 'RAM  ' + $ram + '%'
    Update-Hist $cpu $ram
  } catch {}
}

# ---------- logika: procesy ----------
function Refresh-Procs {
  $lv = $global:LvProc
  $f = $global:TxtProcFilter.Text.Trim()
  $sel = @{}
  foreach ($i in $lv.SelectedItems) { $sel[$i.SubItems[1].Text] = 1 }
  $lv.BeginUpdate()
  $lv.Items.Clear()
  foreach ($p in (Get-Process | Sort-Object WorkingSet64 -Descending)) {
    if ($f -and $p.ProcessName -notlike ('*' + $f + '*')) { continue }
    $cpu = '0'
    try { if ($p.CPU) { $cpu = [string][math]::Round($p.CPU, 1) } } catch {}
    $it = Add-Row $lv @($p.ProcessName, $p.Id, $cpu, [math]::Round($p.WorkingSet64 / 1MB, 1))
    if ($sel.ContainsKey([string]$p.Id)) { $it.Selected = $true }
  }
  $lv.EndUpdate()
  if ($lv.Tag) { Sort-List $lv $lv.Tag.Col $true }
  Set-Status ('Procesów: ' + $lv.Items.Count)
}

function Kill-Proc($tree) {
  $lv = $global:LvProc
  if ($lv.SelectedItems.Count -eq 0) { Say 'Zaznacz proces.'; return }
  $names = ($lv.SelectedItems | ForEach-Object { $_.Text + ' (' + $_.SubItems[1].Text + ')' }) -join ', '
  if (-not (Ask ('Zakończyć: ' + $names + '?'))) { return }
  foreach ($it in @($lv.SelectedItems)) {
    $pid2 = [int]$it.SubItems[1].Text
    try {
      if ($tree) { & taskkill /T /F /PID $pid2 | Out-Null } else { Stop-Process -Id $pid2 -Force -ErrorAction Stop }
      Write-Log ('Zakończono: ' + $it.Text + ' (' + $pid2 + ')')
    } catch { Write-Log ('BŁĄD (' + $it.Text + '): ' + $_.Exception.Message) }
  }
  Refresh-Procs
}

# ---------- logika: usługi ----------
function Refresh-Svc {
  $lv = $global:LvSvc
  $f = $global:TxtSvcFilter.Text.Trim()
  $onlyRun = $global:ChkSvcRun.Checked
  $lv.BeginUpdate()
  $lv.Items.Clear()
  foreach ($s in (Get-CimInstance Win32_Service | Sort-Object DisplayName)) {
    if ($onlyRun -and $s.State -ne 'Running') { continue }
    if ($f -and ($s.Name -notlike ('*' + $f + '*')) -and ($s.DisplayName -notlike ('*' + $f + '*'))) { continue }
    [void](Add-Row $lv @($s.Name, $s.DisplayName, $s.State, $s.StartMode))
  }
  $lv.EndUpdate()
  if ($lv.Tag) { Sort-List $lv $lv.Tag.Col $true }
  Set-Status ('Usług: ' + $lv.Items.Count)
}

function Svc-Act($a) {
  $lv = $global:LvSvc
  if ($lv.SelectedItems.Count -eq 0) { Say 'Zaznacz usługę.'; return }
  $n = $lv.SelectedItems[0].Text
  try {
    switch ($a) {
      'start'   { Start-Service -Name $n -ErrorAction Stop }
      'stop'    { Stop-Service -Name $n -Force -ErrorAction Stop }
      'restart' { Restart-Service -Name $n -Force -ErrorAction Stop }
      default   { Set-Service -Name $n -StartupType $a -ErrorAction Stop }
    }
    Write-Log ('Usługa ' + $n + ': ' + $a + ' - OK')
  } catch { Write-Log ('BŁĄD (' + $n + '): ' + $_.Exception.Message) }
  Refresh-Svc
}

# ---------- logika: porty ----------
function Refresh-Ports {
  $lv = $global:LvPort
  $f = $global:TxtPortFilter.Text.Trim()
  $onlyL = $global:ChkListen.Checked
  $names = @{}
  foreach ($p in (Get-Process)) { $names[[int]$p.Id] = $p.ProcessName }
  $lv.BeginUpdate()
  $lv.Items.Clear()
  foreach ($c in (Get-NetTCPConnection -ErrorAction SilentlyContinue)) {
    if ($onlyL -and $c.State -ne 'Listen') { continue }
    $pn = $names[[int]$c.OwningProcess]
    if (-not $pn) { $pn = '?' }
    $row = @('TCP', $c.LocalAddress, $c.LocalPort, ([string]$c.RemoteAddress + ':' + $c.RemotePort), $c.State, $c.OwningProcess, $pn)
    if ($f -and (($row -join ' ') -notlike ('*' + $f + '*'))) { continue }
    [void](Add-Row $lv $row)
  }
  foreach ($u in (Get-NetUDPEndpoint -ErrorAction SilentlyContinue)) {
    $pn = $names[[int]$u.OwningProcess]
    if (-not $pn) { $pn = '?' }
    $row = @('UDP', $u.LocalAddress, $u.LocalPort, '', '', $u.OwningProcess, $pn)
    if ($f -and (($row -join ' ') -notlike ('*' + $f + '*'))) { continue }
    [void](Add-Row $lv $row)
  }
  $lv.EndUpdate()
  if ($lv.Tag) { Sort-List $lv $lv.Tag.Col $true }
  Set-Status ('Wpisów: ' + $lv.Items.Count)
}

function Kill-PortProc {
  $lv = $global:LvPort
  if ($lv.SelectedItems.Count -eq 0) { Say 'Zaznacz wiersz.'; return }
  $it = $lv.SelectedItems[0]
  $pid2 = [int]$it.SubItems[5].Text
  if ($pid2 -le 4) { Say 'Tego procesu systemowego nie można zakończyć.'; return }
  if (-not (Ask ('Zakończyć proces ' + $it.SubItems[6].Text + ' (PID ' + $pid2 + ')?'))) { return }
  try { Stop-Process -Id $pid2 -Force -ErrorAction Stop; Write-Log ('Zakończono PID ' + $pid2) } catch { Write-Log ('BŁĄD: ' + $_.Exception.Message) }
  Refresh-Ports
}

# ---------- logika: użytkownicy ----------
function Refresh-Users {
  $lv = $global:LvUsr
  $lv.Items.Clear()
  foreach ($u in (Get-LocalUser)) {
    $ll = ''
    if ($u.LastLogon) { $ll = $u.LastLogon.ToString('yyyy-MM-dd HH:mm') }
    [void](Add-Row $lv @($u.Name, $u.Enabled, $ll, $u.Description))
  }
  if ($lv.Tag) { Sort-List $lv $lv.Tag.Col $true }
}

function User-Act($enable) {
  $lv = $global:LvUsr
  if ($lv.SelectedItems.Count -eq 0) { Say 'Zaznacz konto.'; return }
  $n = $lv.SelectedItems[0].Text
  $verb = 'wyłączyć'
  if ($enable) { $verb = 'włączyć' }
  if (-not (Ask ('Czy na pewno ' + $verb + ' konto "' + $n + '"?'))) { return }
  try {
    if ($enable) { Enable-LocalUser -Name $n -ErrorAction Stop } else { Disable-LocalUser -Name $n -ErrorAction Stop }
    Write-Log ('Konto ' + $n + ': OK')
  } catch { Write-Log ('BŁĄD (' + $n + '): ' + $_.Exception.Message) }
  Refresh-Users
}

# ---------- logika: programy i autostart ----------
function Refresh-Apps {
  $lv = $global:LvApp
  $f = $global:TxtAppFilter.Text.Trim()
  $keys = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
  $apps = Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -and -not $_.SystemComponent } | Sort-Object DisplayName
  $lv.BeginUpdate()
  $lv.Items.Clear()
  foreach ($a in $apps) {
    if ($f -and ($a.DisplayName -notlike ('*' + $f + '*')) -and ($a.Publisher -notlike ('*' + $f + '*'))) { continue }
    $dt = [string]$a.InstallDate
    if ($dt -match '^(\d{4})(\d{2})(\d{2})$') { $dt = $Matches[1] + '-' + $Matches[2] + '-' + $Matches[3] }
    $it = Add-Row $lv @($a.DisplayName, $a.DisplayVersion, $a.Publisher, $dt)
    $it.Tag = [string]$a.UninstallString
  }
  $lv.EndUpdate()
  Set-Status ('Programów: ' + $lv.Items.Count)
}

function Uninstall-App {
  $lv = $global:LvApp
  if ($lv.SelectedItems.Count -eq 0) { Say 'Zaznacz program.'; return }
  $it = $lv.SelectedItems[0]
  $us = [string]$it.Tag
  if (-not $us) { Say 'Ten wpis nie ma polecenia odinstalowania.'; return }
  if (-not (Ask ('Odinstalować "' + $it.Text + '"?'))) { return }
  Start-Process -FilePath 'cmd.exe' -ArgumentList ('/c "' + $us + '"')
  Write-Log ('Uruchomiono deinstalator: ' + $it.Text)
}

$global:StartupRunKeys = @(
  @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Appr = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Src = 'HKCU Run (bieżący użytkownik)' },
  @{ Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'; Appr = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Src = 'HKLM Run (wszyscy użytkownicy)' },
  @{ Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Appr = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32'; Src = 'HKLM Run 32-bit' }
)
$global:StartupFolders = @(
  @{ Special = 'Startup'; Appr = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'; Src = 'Folder Autostart (bieżący użytkownik)' },
  @{ Special = 'CommonStartup'; Appr = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'; Src = 'Folder Autostart (wszyscy użytkownicy)' }
)

function Get-ApprovedEnabled($key, $name) {
  try {
    if (Test-Path $key) {
      $v = (Get-Item -Path $key).GetValue($name)
      if (($v -is [byte[]]) -and ($v.Length -gt 0) -and (($v[0] -band 1) -eq 1)) { return $false }
    }
  } catch {}
  return $true
}

function Set-ApprovedEnabled($key, $name, $enable) {
  if (-not (Test-Path $key)) { [void](New-Item -Path $key -Force) }
  if ($enable) {
    $bytes = [byte[]](2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
  } else {
    $bytes = [byte[]](@(3, 0, 0, 0) + [BitConverter]::GetBytes([DateTime]::UtcNow.ToFileTimeUtc()))
  }
  [void](New-ItemProperty -Path $key -Name $name -Value $bytes -PropertyType Binary -Force)
}

function Get-LnkTarget($path) {
  try {
    $sh = New-Object -ComObject WScript.Shell
    $l = $sh.CreateShortcut($path)
    $t = [string]$l.TargetPath
    if ($l.Arguments) { $t = $t + ' ' + $l.Arguments }
    if ($t) { return $t }
  } catch {}
  return $path
}

function Get-CmdPath($cmd) {
  $c = [string]$cmd
  if ($c -match '^\s*"([^"]+)"') { return $Matches[1] }
  if ($c -match '^\s*(.+?\.(?:exe|bat|cmd|com|lnk|msc|cpl))(?:\s|$)') { return $Matches[1] }
  return $c.Trim()
}

function Get-StartupEntries {
  $list = New-Object Collections.ArrayList
  foreach ($k in $global:StartupRunKeys) {
    try {
      if (-not (Test-Path $k.Path)) { continue }
      $rk = Get-Item -Path $k.Path -ErrorAction Stop
      foreach ($n in $rk.GetValueNames()) {
        if (-not $n) { continue }
        [void]$list.Add([pscustomobject]@{ Name = $n; Cmd = [string]$rk.GetValue($n); Src = $k.Src; Kind = 'run'; Key = $k.Path; Appr = $k.Appr; ValueName = $n; Enabled = (Get-ApprovedEnabled $k.Appr $n) })
      }
    } catch {}
  }
  foreach ($f in $global:StartupFolders) {
    try {
      $dir = [Environment]::GetFolderPath($f.Special)
      if (-not $dir -or -not (Test-Path -LiteralPath $dir)) { continue }
      foreach ($file in (Get-ChildItem -LiteralPath $dir -File -Force -ErrorAction Stop)) {
        if ($file.Name -ieq 'desktop.ini') { continue }
        $cmd = $file.FullName
        if ($file.Extension -ieq '.lnk') { $cmd = Get-LnkTarget $file.FullName }
        [void]$list.Add([pscustomobject]@{ Name = [IO.Path]::GetFileNameWithoutExtension($file.Name); Cmd = $cmd; Src = $f.Src; Kind = 'folder'; Key = $file.FullName; Appr = $f.Appr; ValueName = $file.Name; Enabled = (Get-ApprovedEnabled $f.Appr $file.Name) })
      }
    } catch {}
  }
  return $list
}

function Refresh-Startup {
  $lv = $global:LvStart
  $lv.BeginUpdate()
  $lv.Items.Clear()
  foreach ($e in @(Get-StartupEntries | Sort-Object Name)) {
    if ($e.Enabled) { $st = (L 'Włączony') } else { $st = (L 'Wyłączony') }
    $it = Add-Row $lv @($e.Name, $st, (L $e.Src), $e.Cmd)
    $it.Tag = $e
  }
  $lv.EndUpdate()
  if ($lv.Tag) { Sort-List $lv $lv.Tag.Col $true }
  Set-Status ('Pozycji autostartu: ' + $lv.Items.Count)
}

function Startup-Act($a) {
  $lv = $global:LvStart
  if ($lv.SelectedItems.Count -eq 0) { Say 'Zaznacz pozycję.'; return }
  $e = $lv.SelectedItems[0].Tag
  if ($a -ne 'open' -and -not $global:IsAdmin -and ([string]$e.Appr -like 'HKLM*' -or [string]$e.Key -like 'HKLM*')) { Say 'Ta pozycja wymaga uprawnień administratora.'; return }
  try {
    switch ($a) {
      'on'  { Set-ApprovedEnabled $e.Appr $e.ValueName $true;  Write-Log ('Autostart: włączono "' + $e.Name + '"') }
      'off' { Set-ApprovedEnabled $e.Appr $e.ValueName $false; Write-Log ('Autostart: wyłączono "' + $e.Name + '"') }
      'del' {
        if (-not (Ask ('Usunąć pozycję autostartu "' + $e.Name + '"?'))) { return }
        if ($e.Kind -eq 'run') { Remove-ItemProperty -Path $e.Key -Name $e.ValueName -ErrorAction Stop }
        else { Remove-Item -LiteralPath $e.Key -Force -ErrorAction Stop }
        try { Remove-ItemProperty -Path $e.Appr -Name $e.ValueName -ErrorAction Stop } catch {}
        Write-Log ('Autostart: usunięto "' + $e.Name + '"')
      }
      'open' {
        $path = $e.Key
        if ($e.Kind -eq 'run') { $path = [Environment]::ExpandEnvironmentVariables((Get-CmdPath $e.Cmd)) }
        if ($path -and (Test-Path -LiteralPath $path)) { Start-Process explorer.exe -ArgumentList ('/select,"' + $path + '"') }
        else { Say 'Nie udało się ustalić pliku programu.' }
      }
    }
  } catch { Report-Error $_ 'startup' }
  if ($a -ne 'open') { Refresh-Startup }
}

# ---------- logika: historia wydajności (wykresy) ----------
$global:HistLen = 100
$global:Hist = @{}
foreach ($k in 'cpu', 'ram', 'disk', 'net') { $global:Hist[$k] = New-Object 'Collections.Generic.List[double]' }
$global:LastNet = $null
$global:GraphPanels = @()
try {
  $global:PerfDisk = New-Object Diagnostics.PerformanceCounter('PhysicalDisk', '% Disk Time', '_Total')
  [void]$global:PerfDisk.NextValue()
} catch { $global:PerfDisk = $null }

function Add-Hist($k, $v) {
  $l = $global:Hist[$k]
  $l.Add([double]$v)
  while ($l.Count -gt $global:HistLen) { $l.RemoveAt(0) }
}

function Get-NetBytes {
  $t = [int64]0
  foreach ($n in [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
    if ($n.OperationalStatus -eq 'Up' -and $n.NetworkInterfaceType -ne 'Loopback') {
      $s = $n.GetIPv4Statistics()
      $t += [int64]$s.BytesReceived + [int64]$s.BytesSent
    }
  }
  return $t
}

function Update-Hist($cpu, $ram) {
  Add-Hist 'cpu' $cpu
  Add-Hist 'ram' $ram
  if ($global:PerfDisk) { try { Add-Hist 'disk' ([math]::Min(100, $global:PerfDisk.NextValue())) } catch {} }
  try {
    $now = Get-NetBytes
    if ($global:LastNet -ne $null) {
      $kb = ($now - $global:LastNet) / 1KB / ($global:MeterTimer.Interval / 1000)
      if ($kb -lt 0) { $kb = 0 }
      Add-Hist 'net' $kb
    }
    $global:LastNet = $now
  } catch {}
  if ($global:Tabs.SelectedTab.Name -eq 'perf') { foreach ($gp in $global:GraphPanels) { $gp.Invalidate() } }
}

function Paint-Graph($p, $g) {
  $t = $p.Tag
  $data = $global:Hist[$t.Key]
  $w = $p.ClientSize.Width
  $h = $p.ClientSize.Height
  if ($w -lt 60 -or $h -lt 60) { return }
  $g.SmoothingMode = 'AntiAlias'
  $g.Clear($global:T.GraphBg)
  $top = 30; $pad = 8
  $gw = $w - 2 * $pad
  $gh = $h - $top - $pad
  $mx = [double]100
  if ($t.Max -le 0) {
    $m = [double]0
    foreach ($v in $data) { if ($v -gt $m) { $m = $v } }
    $mx = [math]::Max(100.0, $m * 1.25)
  }
  $gridPen = New-Object Drawing.Pen($global:T.Grid, 1)
  for ($i = 0; $i -le 4; $i++) {
    $y = [single]($top + $gh * $i / 4)
    $g.DrawLine($gridPen, [single]$pad, $y, [single]($pad + $gw), $y)
  }
  $gridPen.Dispose()
  $n = $data.Count
  $cur = 0
  if ($n -gt 0) {
    $cur = $data[$n - 1]
    if ($n -gt 1) {
      $pts = New-Object 'System.Collections.Generic.List[Drawing.PointF]'
      for ($i = 0; $i -lt $n; $i++) {
        $x = $pad + $gw * (($global:HistLen - $n + $i) / ($global:HistLen - 1))
        $y = $top + $gh * (1 - ($data[$i] / $mx))
        $pts.Add((New-Object Drawing.PointF([single]$x, [single]$y)))
      }
      $arr = $pts.ToArray()
      $poly = New-Object 'System.Collections.Generic.List[Drawing.PointF]'
      $poly.AddRange($arr)
      $poly.Add((New-Object Drawing.PointF($arr[$n - 1].X, [single]($top + $gh))))
      $poly.Add((New-Object Drawing.PointF($arr[0].X, [single]($top + $gh))))
      $fill = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(50, $t.Color))
      $g.FillPolygon($fill, $poly.ToArray())
      $fill.Dispose()
      $pen = New-Object Drawing.Pen($t.Color, 2)
      $g.DrawLines($pen, $arr)
      $pen.Dispose()
    }
  }
  $f1 = New-Object Drawing.Font('Segoe UI Semibold', 10)
  $f2 = New-Object Drawing.Font('Segoe UI', 8)
  $b1 = New-Object Drawing.SolidBrush($global:T.Text)
  $b2 = New-Object Drawing.SolidBrush($global:T.Muted)
  $g.DrawString(($t.Title + '   ' + [math]::Round($cur, 1) + ' ' + $t.Unit), $f1, $b1, [single]8, [single]5)
  $g.DrawString(('skala: 0 - ' + [math]::Round($mx, 0)), $f2, $b2, [single]8, [single]($top - 2 + $gh + 0))
  $f1.Dispose(); $f2.Dispose(); $b1.Dispose(); $b2.Dispose()
}

function New-Graph($key, $title, $unit, $color, $fixed) {
  $p = New-Object Windows.Forms.Panel
  $p.Dock = 'Fill'
  $p.BackColor = [Drawing.Color]::White
  $p.Margin = New-Object Windows.Forms.Padding(4)
  [void]([Windows.Forms.Panel].GetProperty('DoubleBuffered', [Reflection.BindingFlags]'Instance,NonPublic').SetValue($p, $true, $null))
  $p.Tag = @{ Key = $key; Title = $title; Unit = $unit; Color = $color; Max = $fixed }
  $p.Add_Paint({ param($s, $e) try { Paint-Graph $s $e.Graphics } catch { Log-Error 'paint' $_ } })
  $p.Add_Resize({ $this.Invalidate() })
  $global:GraphPanels += $p
  return $p
}

function New-Combo($panel, $items, $w, $sel = 0) {
  $c = New-Object Windows.Forms.ComboBox
  $c.DropDownStyle = 'DropDownList'
  $c.Width = $w
  $c.Margin = New-Object Windows.Forms.Padding(3, 6, 3, 0)
  foreach ($i in $items) { [void]$c.Items.Add($i) }
  $c.SelectedIndex = $sel
  $panel.Controls.Add($c)
  return $c
}

# ---------- logika: dziennik zdarzeń ----------
function Refresh-Events {
  $lv = $global:LvEvt
  $log = [string]$global:CmbLog.SelectedItem
  $hours = @(1, 24, 168, 720)[$global:CmbRange.SelectedIndex]
  $flt = @{ LogName = $log; StartTime = (Get-Date).AddHours(-$hours) }
  switch ($global:CmbLevel.SelectedIndex) {
    0 { $flt['Level'] = @(1, 2) }
    1 { $flt['Level'] = @(1, 2, 3) }
  }
  $txt = $global:TxtEvtFilter.Text.Trim()
  $global:Form.Cursor = [Windows.Forms.Cursors]::WaitCursor
  $lv.BeginUpdate()
  $lv.Items.Clear()
  try {
    $ev = Get-WinEvent -FilterHashtable $flt -MaxEvents 500 -ErrorAction Stop
    foreach ($e in $ev) {
      $m = [string]$e.Message
      $first = ($m -split "`r?`n")[0]
      if ($txt -and (($first + ' ' + $e.ProviderName) -notlike ('*' + $txt + '*'))) { continue }
      $it = Add-Row $lv @($e.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'), [string]$e.LevelDisplayName, $e.ProviderName, $e.Id, $first)
      $it.Tag = $m
    }
  } catch {
    if ($_.FullyQualifiedErrorId -notmatch 'NoMatchingEventsFound') { Write-Log ('BŁĄD (dziennik ' + $log + '): ' + $_.Exception.Message) }
  }
  $lv.EndUpdate()
  $global:Form.Cursor = [Windows.Forms.Cursors]::Default
  Set-Status ('Zdarzeń: ' + $lv.Items.Count)
}

function Show-EventDetail {
  $lv = $global:LvEvt
  if ($lv.SelectedItems.Count -eq 0) { Say 'Zaznacz zdarzenie.'; return }
  $it = $lv.SelectedItems[0]
  Write-Log ("`r`n>>> Zdarzenie " + $it.SubItems[3].Text + ' (' + $it.SubItems[2].Text + ') ' + $it.SubItems[0].Text)
  Write-Log ([string]$it.Tag)
}

# ---------- logika: zaplanowane zadania ----------
function Refresh-Tasks {
  $lv = $global:LvTask
  $hide = $global:ChkMs.Checked
  $f = $global:TxtTaskFilter.Text.Trim()
  $global:Form.Cursor = [Windows.Forms.Cursors]::WaitCursor
  $lv.BeginUpdate()
  $lv.Items.Clear()
  foreach ($t in (Get-ScheduledTask -ErrorAction SilentlyContinue | Sort-Object TaskPath, TaskName)) {
    if ($hide -and $t.TaskPath -like '\Microsoft\*') { continue }
    if ($f -and (($t.TaskName + ' ' + $t.TaskPath) -notlike ('*' + $f + '*'))) { continue }
    [void](Add-Row $lv @($t.TaskName, $t.TaskPath, $t.State, $t.Author))
  }
  $lv.EndUpdate()
  $global:Form.Cursor = [Windows.Forms.Cursors]::Default
  Set-Status ('Zadań: ' + $lv.Items.Count)
}

function Task-Act($a) {
  $lv = $global:LvTask
  if ($lv.SelectedItems.Count -eq 0) { Say 'Zaznacz zadanie.'; return }
  $n = $lv.SelectedItems[0].Text
  $pth = $lv.SelectedItems[0].SubItems[1].Text
  try {
    switch ($a) {
      'run' { Start-ScheduledTask -TaskName $n -TaskPath $pth -ErrorAction Stop }
      'on'  { [void](Enable-ScheduledTask -TaskName $n -TaskPath $pth -ErrorAction Stop) }
      'off' { [void](Disable-ScheduledTask -TaskName $n -TaskPath $pth -ErrorAction Stop) }
    }
    Write-Log ('Zadanie ' + $n + ': ' + $a + ' - OK')
  } catch { Write-Log ('BŁĄD (' + $n + '): ' + $_.Exception.Message) }
  Refresh-Tasks
}

# ---------- logika: raport HTML ----------
function Rpt-Table($rows) {
  $r = @($rows)
  if ($r.Count -eq 0) { return (L '<p><i>Brak danych.</i></p>') }
  return (($r | ConvertTo-Html -Fragment) | Out-String)
}

function Rpt-Sec($title, $html) { return ('<h2>' + [Net.WebUtility]::HtmlEncode((L $title)) + '</h2>' + $html) }

function New-Report {
  $d = New-Object Windows.Forms.SaveFileDialog
  $d.Filter = (L 'Raport HTML (*.html)|*.html')
  $d.FileName = (L 'raport-') + $env:COMPUTERNAME + '-' + (Get-Date -Format 'yyyyMMdd-HHmm') + '.html'
  $d.InitialDirectory = [Environment]::GetFolderPath('Desktop')
  if ($d.ShowDialog() -ne 'OK') { return }
  $global:Form.Cursor = [Windows.Forms.Cursors]::WaitCursor
  Write-Log "`r`n>>> Generowanie raportu systemowego..."
  try {
    $sb = New-Object Text.StringBuilder
    [void]$sb.Append((Rpt-Sec 'Informacje o systemie' ('<pre>' + [Net.WebUtility]::HtmlEncode((Get-SysInfo)) + '</pre>')))

    $rows = Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Select-Object @{ n = (L 'Dysk'); e = { $_.DeviceID } }, @{ n = (L 'Rozmiar (GB)'); e = { [math]::Round($_.Size / 1GB, 1) } }, @{ n = (L 'Wolne (GB)'); e = { [math]::Round($_.FreeSpace / 1GB, 1) } }
    [void]$sb.Append((Rpt-Sec 'Dyski' (Rpt-Table $rows)))

    $rows = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 15 @{ n = (L 'Proces'); e = { $_.ProcessName } }, Id, @{ n = (L 'Pamięć (MB)'); e = { [math]::Round($_.WorkingSet64 / 1MB, 1) } }
    [void]$sb.Append((Rpt-Sec 'Najbardziej pamięciożerne procesy (15)' (Rpt-Table $rows)))

    $rows = Get-CimInstance Win32_Service | Where-Object { $_.StartMode -eq 'Auto' -and $_.State -ne 'Running' } | Select-Object Name, DisplayName, State
    [void]$sb.Append((Rpt-Sec 'Usługi automatyczne, które nie działają' (Rpt-Table $rows)))

    $rows = @()
    try {
      $rows = Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 1, 2; StartTime = (Get-Date).AddDays(-1) } -MaxEvents 30 -ErrorAction Stop | Select-Object TimeCreated, ProviderName, Id, @{ n = (L 'Komunikat'); e = { (([string]$_.Message) -split "`r?`n")[0] } }
    } catch {}
    [void]$sb.Append((Rpt-Sec 'Błędy systemowe z ostatnich 24 godzin' (Rpt-Table $rows)))

    $rows = @()
    try { $rows = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 15 HotFixID, Description, InstalledOn } catch {}
    [void]$sb.Append((Rpt-Sec 'Ostatnie poprawki Windows' (Rpt-Table $rows)))

    $rows = Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location
    [void]$sb.Append((Rpt-Sec 'Autostart' (Rpt-Table $rows)))

    $css = 'body{font-family:Segoe UI,Arial,sans-serif;margin:30px;color:#1f2937}h1{color:#0f172a}h2{margin-top:28px;border-bottom:2px solid #0067b8;padding-bottom:4px}table{border-collapse:collapse;width:100%;font-size:13px}th{background:#1e293b;color:#fff;text-align:left;padding:6px 8px}td{padding:5px 8px;border-bottom:1px solid #e5e7eb}tr:nth-child(even){background:#f8fafc}pre{background:#f1f5f9;padding:12px;border-radius:6px;font-size:13px}'
    $html = (L '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Raport ') + [Net.WebUtility]::HtmlEncode($env:COMPUTERNAME) + '</title><style>' + $css + (L '</style></head><body><h1>Raport stanu systemu: ') + [Net.WebUtility]::HtmlEncode($env:COMPUTERNAME) + (L '</h1><p>Wygenerowano: ') + (Get-Date -Format 'yyyy-MM-dd HH:mm') + '</p>' + $sb.ToString() + '</body></html>'
    [IO.File]::WriteAllText($d.FileName, $html, (New-Object Text.UTF8Encoding($true)))
    Write-Log ('<<< raport zapisany: ' + $d.FileName)
    Start-Process $d.FileName
  } catch { Write-Log ('BŁĄD (raport): ' + $_.Exception.Message) }
  $global:Form.Cursor = [Windows.Forms.Cursors]::Default
}

# ---------- wspólne: nowe moduły (bezpieczeństwo, sprzęt, sprzątanie, dysk, zdalnie) ----------
$global:Busy = $false
$global:ScanCancel = $false

function Drop-Errs { try { $global:Error.Clear() } catch {} }

function MB($b) { return ([math]::Round(([double]$b) / 1MB, 1)).ToString([Globalization.CultureInfo]::InvariantCulture) }

function Set-State($it, $col, $state) {
  $it.UseItemStyleForSubItems = $false
  $sub = $it.SubItems[$col]
  $sub.Name = $state
  switch ($state) {
    'ok'   { $sub.ForeColor = (RGB 0 140 70) }
    'warn' { $sub.ForeColor = (RGB 190 120 0) }
    'bad'  { $sub.ForeColor = (RGB 200 60 45) }
  }
}

function Start-PS($title, $script) {
  $f = Join-Path $global:RunDir ([guid]::NewGuid().ToString('N') + '.ps1')
  $head = '$ProgressPreference = ''SilentlyContinue''' + "`r`n"
  [IO.File]::WriteAllText($f, ($head + $script), (New-Object Text.UTF8Encoding($true)))
  Start-Task $title ('powershell -NoProfile -ExecutionPolicy Bypass -File "' + $f + '"')
}

function Enter-Busy {
  if ($global:Busy) { Say 'Poprzednia operacja jeszcze trwa. Poczekaj lub kliknij "Przerwij".'; return $false }
  $global:Busy = $true
  $global:ScanCancel = $false
  if ($global:FastScan) { [DiskScan]::Cancel = $false }
  $global:Form.Cursor = [Windows.Forms.Cursors]::WaitCursor
  return $true
}

function Leave-Busy {
  $global:Busy = $false
  $global:Form.Cursor = [Windows.Forms.Cursors]::Default
}

function Cancel-Busy {
  $global:ScanCancel = $true
  if ($global:FastScan) { [DiskScan]::Cancel = $true }
}

# Skanuje katalog: zwraca Size, Files, Top (największe pliki)
function Scan-Dir($path, $top = 0, $collectMin = -1) {
  $r = [pscustomobject]@{ Size = [long]0; Files = [long]0; Top = @(); Found = @() }
  if (-not $path) { return $r }
  if (Test-Path -LiteralPath $path -PathType Leaf) {
    try { $r.Size = (Get-Item -LiteralPath $path -Force).Length; $r.Files = 1 } catch {}
    return $r
  }
  if (-not (Test-Path -LiteralPath $path -PathType Container)) { return $r }
  if ($global:FastScan) {
    $ds = New-Object DiskScan($top)
    $ds.CollectMin = $collectMin
    $ds.Walk($path)
    $ds.Finish()
    $r.Size = $ds.Size
    $r.Files = $ds.Files
    $r.Top = @($ds.Top | ForEach-Object { [pscustomobject]@{ Size = $_.Key; Path = $_.Value } })
    $r.Found = @($ds.Found | ForEach-Object { [pscustomobject]@{ Size = $_.Key; Path = $_.Value } })
    return $r
  }
  $all = @(Get-ChildItem -LiteralPath $path -Recurse -Force -File -ErrorAction SilentlyContinue)
  foreach ($f in $all) { $r.Size += $f.Length; $r.Files++ }
  if ($top -gt 0) { $r.Top = @($all | Sort-Object Length -Descending | Select-Object -First $top | ForEach-Object { [pscustomobject]@{ Size = $_.Length; Path = $_.FullName } }) }
  if ($collectMin -ge 0) { $r.Found = @($all | Where-Object { $_.Length -ge $collectMin } | ForEach-Object { [pscustomobject]@{ Size = $_.Length; Path = $_.FullName } }) }
  Drop-Errs
  return $r
}

function Scan-Filter($dir, $filter) {
  $r = [pscustomobject]@{ Size = [long]0; Files = [long]0 }
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return $r }
  if ($global:FastScan) {
    $ds = New-Object DiskScan(0)
    $ds.WalkFilter($dir, $filter)
    $r.Size = $ds.Size
    $r.Files = $ds.Files
  } else {
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter $filter -Force -File -ErrorAction SilentlyContinue)) { $r.Size += $f.Length; $r.Files++ }
    Drop-Errs
  }
  return $r
}

function Purge-Dir($dir, $filter) {
  $freed = [long]0
  if ($global:FastScan) {
    $ds = New-Object DiskScan(0)
    $ds.Purge($dir, $filter, $global:RunDir)
    return $ds.Freed
  }
  $items = @()
  if ($filter) { $items = @(Get-ChildItem -LiteralPath $dir -Filter $filter -Force -File -ErrorAction SilentlyContinue) }
  else { $items = @(Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue) }
  foreach ($k in $items) {
    if ($k.FullName.TrimEnd('\', '/') -eq $global:RunDir.TrimEnd('\', '/')) { continue }
    $sz = (Scan-Dir $k.FullName).Size
    try { Remove-Item -LiteralPath $k.FullName -Recurse -Force -ErrorAction Stop; $freed += $sz } catch {}
  }
  Drop-Errs
  return $freed
}

function Get-Age($d) {
  if (-not $d) { return $null }
  return [int][math]::Floor(((Get-Date) - [datetime]$d).TotalDays)
}

# ---------- logika: bezpieczeństwo ----------
function Add-SecRow($cat, $name, $value, $state, $detail) {
  $it = Add-Row $global:LvSec @((L $cat), (L $name), (L $value), (L $detail))
  if ($state) { Set-State $it 2 $state }
  switch ($state) { 'bad' { $global:SecBad++ } 'warn' { $global:SecWarn++ } }
}

function Reg-Val($path, $name) {
  try { return (Get-ItemProperty -Path $path -Name $name -ErrorAction Stop).$name } catch { return $null }
}

function Refresh-Security {
  $lv = $global:LvSec
  $lv.BeginUpdate()
  $lv.Items.Clear()
  $global:SecBad = 0
  $global:SecWarn = 0
  $on = 'Włączona'
  $off = 'Wyłączona'

  # --- antywirus ---
  try {
    $mp = Get-MpComputerStatus -ErrorAction Stop
    if ($mp.AntivirusEnabled) { Add-SecRow 'Antywirus' 'Microsoft Defender' 'Włączony' 'ok' '' }
    else { Add-SecRow 'Antywirus' 'Microsoft Defender' 'Wyłączony' 'bad' 'Brak aktywnej ochrony antywirusowej' }
    if ($mp.RealTimeProtectionEnabled) { Add-SecRow 'Antywirus' 'Ochrona w czasie rzeczywistym' $on 'ok' '' }
    else { Add-SecRow 'Antywirus' 'Ochrona w czasie rzeczywistym' $off 'bad' '' }
    $age = [int]$mp.AntivirusSignatureAge
    $st = 'ok'
    if ($age -gt 7) { $st = 'bad' } elseif ($age -gt 3) { $st = 'warn' }
    Add-SecRow 'Antywirus' 'Sygnatury wirusów' ('Wiek: ' + $age + ' dni') $st ('Wersja ' + $mp.AntivirusSignatureVersion)
    $qs = $mp.QuickScanEndTime
    if ($qs) {
      $qa = Get-Age $qs
      $st = 'ok'
      if ($qa -gt 30) { $st = 'bad' } elseif ($qa -gt 7) { $st = 'warn' }
      Add-SecRow 'Antywirus' 'Ostatni szybki skan' ($qs.ToString('yyyy-MM-dd HH:mm')) $st ('Dni temu: ' + $qa)
    } else { Add-SecRow 'Antywirus' 'Ostatni szybki skan' 'Brak danych' 'warn' '' }
    if ($mp.PSObject.Properties['IsTamperProtected']) {
      if ($mp.IsTamperProtected) { Add-SecRow 'Antywirus' 'Ochrona przed manipulacją' $on 'ok' '' }
      else { Add-SecRow 'Antywirus' 'Ochrona przed manipulacją' $off 'warn' '' }
    }
  } catch {
    Add-SecRow 'Antywirus' 'Microsoft Defender' 'Niedostępny' 'warn' 'Inny program antywirusowy lub brak dostępu do danych'
  }
  try {
    $av = @(Get-CimInstance -Namespace 'root\SecurityCenter2' -ClassName AntiVirusProduct -ErrorAction Stop | ForEach-Object { $_.displayName })
    if ($av.Count -gt 0) { Add-SecRow 'Antywirus' 'Zarejestrowane programy AV' ('Liczba: ' + $av.Count) '' ($av -join ', ') }
  } catch {}

  # --- zapora ---
  try {
    foreach ($p in @(Get-NetFirewallProfile -ErrorAction Stop)) {
      if ([string]$p.Enabled -eq 'True') { Add-SecRow 'Zapora' ('Profil: ' + $p.Name) $on 'ok' ('Ruch przychodzący: ' + $p.DefaultInboundAction) }
      else { Add-SecRow 'Zapora' ('Profil: ' + $p.Name) $off 'bad' '' }
    }
  } catch { Add-SecRow 'Zapora' 'Zapora Windows' 'Niedostępna' 'warn' 'Nie udało się odczytać profili zapory' }

  # --- szyfrowanie / sprzęt ---
  if ($global:IsAdmin) {
    try {
      foreach ($v in @(Get-BitLockerVolume -ErrorAction Stop)) {
        if ([string]$v.ProtectionStatus -eq 'On') { Add-SecRow 'Szyfrowanie' ('BitLocker ' + $v.MountPoint) 'Włączony' 'ok' ('Zaszyfrowano: ' + $v.EncryptionPercentage + '%, metoda: ' + $v.EncryptionMethod) }
        else { Add-SecRow 'Szyfrowanie' ('BitLocker ' + $v.MountPoint) 'Wyłączony' 'warn' ('Zaszyfrowano: ' + $v.EncryptionPercentage + '%') }
      }
    } catch { Add-SecRow 'Szyfrowanie' 'BitLocker' 'Niedostępny' 'warn' 'Funkcja nie jest obsługiwana w tej edycji systemu' }
    try {
      $sb = Confirm-SecureBootUEFI -ErrorAction Stop
      if ($sb) { Add-SecRow 'Sprzęt' 'Secure Boot' 'Włączony' 'ok' '' } else { Add-SecRow 'Sprzęt' 'Secure Boot' 'Wyłączony' 'warn' '' }
    } catch { Add-SecRow 'Sprzęt' 'Secure Boot' 'Niedostępny' 'warn' 'System w trybie Legacy BIOS lub brak obsługi' }
    try {
      $tpm = Get-Tpm -ErrorAction Stop
      if ($tpm.TpmPresent -and $tpm.TpmReady) { Add-SecRow 'Sprzęt' 'TPM' 'Gotowy' 'ok' '' }
      elseif ($tpm.TpmPresent) { Add-SecRow 'Sprzęt' 'TPM' 'Obecny, niegotowy' 'warn' '' }
      else { Add-SecRow 'Sprzęt' 'TPM' 'Brak' 'warn' '' }
    } catch { Add-SecRow 'Sprzęt' 'TPM' 'Niedostępny' 'warn' '' }
  } else {
    Add-SecRow 'Szyfrowanie' 'BitLocker, Secure Boot, TPM' 'Wymaga administratora' 'warn' 'Uruchom narzędzie jako administrator, aby sprawdzić'
  }

  # --- aktualizacje ---
  try {
    $hf = @(Get-HotFix -ErrorAction Stop | Where-Object { $_.InstalledOn } | Sort-Object InstalledOn -Descending | Select-Object -First 1)
    if ($hf.Count -gt 0) {
      $a = Get-Age $hf[0].InstalledOn
      $st = 'ok'
      if ($a -gt 90) { $st = 'bad' } elseif ($a -gt 45) { $st = 'warn' }
      Add-SecRow 'Aktualizacje' 'Ostatnia poprawka' (([datetime]$hf[0].InstalledOn).ToString('yyyy-MM-dd')) $st ($hf[0].HotFixID + ', dni temu: ' + $a)
    }
  } catch {}
  $pend = $false
  foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending', 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
    if (Test-Path $k) { $pend = $true }
  }
  if ($pend) { Add-SecRow 'Aktualizacje' 'Oczekuje restart' 'Tak' 'warn' 'Zainstalowane zmiany wymagają ponownego uruchomienia' }
  else { Add-SecRow 'Aktualizacje' 'Oczekuje restart' 'Nie' 'ok' '' }
  try {
    $wu = Get-Service wuauserv -ErrorAction Stop
    if ([string]$wu.StartType -eq 'Disabled') { Add-SecRow 'Aktualizacje' 'Usługa Windows Update' 'Wyłączona' 'bad' 'Aktualizacje nie będą pobierane' }
    else { Add-SecRow 'Aktualizacje' 'Usługa Windows Update' 'Dostępna' 'ok' ('Typ uruchomienia: ' + $wu.StartType) }
  } catch {}

  # --- konta i dostęp ---
  $lua = Reg-Val 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'EnableLUA'
  if ($lua -eq 0) { Add-SecRow 'Konta i dostęp' 'Kontrola konta (UAC)' $off 'bad' 'Zalecane włączenie' }
  else { Add-SecRow 'Konta i dostęp' 'Kontrola konta (UAC)' $on 'ok' '' }
  $auto = Reg-Val 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' 'AutoAdminLogon'
  if ([string]$auto -eq '1') { Add-SecRow 'Konta i dostęp' 'Automatyczne logowanie' 'Włączone' 'warn' 'Hasło może być zapisane w rejestrze' }
  else { Add-SecRow 'Konta i dostęp' 'Automatyczne logowanie' 'Wyłączone' 'ok' '' }
  $rdp = Reg-Val 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections'
  if ($rdp -eq 0) {
    $nla = Reg-Val 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' 'UserAuthentication'
    if ($nla -eq 1) { Add-SecRow 'Konta i dostęp' 'Pulpit zdalny (RDP)' 'Włączony' 'warn' 'Z uwierzytelnianiem NLA' }
    else { Add-SecRow 'Konta i dostęp' 'Pulpit zdalny (RDP)' 'Włączony' 'bad' 'Bez uwierzytelniania NLA' }
  } else { Add-SecRow 'Konta i dostęp' 'Pulpit zdalny (RDP)' 'Wyłączony' 'ok' '' }
  try {
    $lu = @(Get-LocalUser -ErrorAction Stop)
    $g = @($lu | Where-Object { $_.SID.Value -like '*-501' })
    if ($g.Count -gt 0) {
      if ($g[0].Enabled) { Add-SecRow 'Konta i dostęp' 'Konto Gość' 'Włączone' 'bad' $g[0].Name }
      else { Add-SecRow 'Konta i dostęp' 'Konto Gość' 'Wyłączone' 'ok' '' }
    }
    $ad = @($lu | Where-Object { $_.SID.Value -like '*-500' })
    if ($ad.Count -gt 0) {
      if ($ad[0].Enabled) { Add-SecRow 'Konta i dostęp' 'Wbudowany administrator' 'Włączony' 'warn' $ad[0].Name }
      else { Add-SecRow 'Konta i dostęp' 'Wbudowany administrator' 'Wyłączony' 'ok' '' }
    }
    $nopw = @($lu | Where-Object { $_.Enabled -and -not $_.PasswordRequired })
    if ($nopw.Count -gt 0) { Add-SecRow 'Konta i dostęp' 'Konta bez wymaganego hasła' ('Liczba: ' + $nopw.Count) 'bad' (($nopw | ForEach-Object { $_.Name }) -join ', ') }
  } catch {}
  try {
    $adm = @(Get-LocalGroupMember -SID 'S-1-5-32-544' -ErrorAction Stop)
    $st = 'ok'
    if ($adm.Count -gt 2) { $st = 'warn' }
    Add-SecRow 'Konta i dostęp' 'Administratorzy lokalni' ('Liczba: ' + $adm.Count) $st (($adm | ForEach-Object { $_.Name }) -join ', ')
  } catch {}

  # --- sieć ---
  try {
    $sh = @(Get-CimInstance Win32_Share -Filter 'Type=0' -ErrorAction Stop)
    if ($sh.Count -gt 0) { Add-SecRow 'Sieć' 'Udziały sieciowe' ('Liczba: ' + $sh.Count) 'warn' (($sh | ForEach-Object { $_.Name }) -join ', ') }
    else { Add-SecRow 'Sieć' 'Udziały sieciowe' 'Brak własnych udziałów' 'ok' '' }
  } catch {}
  if ($global:IsAdmin) {
    try {
      $smb1 = (Get-SmbServerConfiguration -ErrorAction Stop).EnableSMB1Protocol
      if ($smb1) { Add-SecRow 'Sieć' 'Protokół SMBv1' $on 'bad' 'Przestarzały i podatny na ataki, zalecane wyłączenie' }
      else { Add-SecRow 'Sieć' 'Protokół SMBv1' $off 'ok' '' }
    } catch {}
  }
  try {
    $rr = Get-Service RemoteRegistry -ErrorAction Stop
    if ([string]$rr.Status -eq 'Running') { Add-SecRow 'Sieć' 'Rejestr zdalny' 'Uruchomiony' 'warn' 'Umożliwia zdalny odczyt rejestru' }
    else { Add-SecRow 'Sieć' 'Rejestr zdalny' 'Zatrzymany' 'ok' '' }
  } catch {}

  $lv.EndUpdate()
  if ($lv.Tag) { Sort-List $lv $lv.Tag.Col $true }
  Drop-Errs
  Set-Status ('Kontrola bezpieczeństwa: problemy ' + $global:SecBad + ', ostrzeżenia ' + $global:SecWarn)
}

# ---------- logika: sprzęt i sterowniki ----------
$global:DrvCache = $null

function Add-HwRow($cat, $name, $value, $state, $detail) {
  $it = Add-Row $global:LvHw @((L $cat), (L $name), (L $value), (L $detail))
  if ($state) { Set-State $it 2 $state }
}

function Get-MemType($t, $smb) {
  $n = [int]$smb
  if ($n -eq 0) { $n = [int]$t }
  switch ($n) { 20 { return 'DDR' } 21 { return 'DDR2' } 24 { return 'DDR3' } 26 { return 'DDR4' } 34 { return 'DDR5' } 30 { return 'LPDDR4' } 35 { return 'LPDDR5' } default { return '' } }
}

function Fmt-GB($b) {
  $g = ([double]$b) / 1GB
  if ($g -ge 100) { return ([math]::Round($g, 0)).ToString([Globalization.CultureInfo]::InvariantCulture) + ' GB' }
  return ([math]::Round($g, 1)).ToString([Globalization.CultureInfo]::InvariantCulture) + ' GB'
}

function Refresh-Hardware {
  $lv = $global:LvHw
  $lv.BeginUpdate()
  $lv.Items.Clear()

  try {
    foreach ($c in @(Get-CimInstance Win32_Processor -ErrorAction Stop)) {
      Add-HwRow 'Procesor' ([string]$c.Name).Trim() ($c.NumberOfCores.ToString() + ' rdzeni / ' + $c.NumberOfLogicalProcessors + ' wątków') '' ('Maks. taktowanie: ' + $c.MaxClockSpeed + ' MHz, obciążenie: ' + $c.LoadPercentage + '%')
    }
  } catch {}
  try {
    $bb = Get-CimInstance Win32_BaseBoard -ErrorAction Stop
    Add-HwRow 'Płyta główna' ([string]$bb.Manufacturer + ' ' + $bb.Product) '' '' ('Numer seryjny: ' + $bb.SerialNumber)
    $bi = Get-CimInstance Win32_BIOS -ErrorAction Stop
    $bd = ''
    if ($bi.ReleaseDate) { $bd = ([datetime]$bi.ReleaseDate).ToString('yyyy-MM-dd') }
    Add-HwRow 'Płyta główna' ('BIOS ' + $bi.SMBIOSBIOSVersion) $bd '' ([string]$bi.Manufacturer)
  } catch {}
  try {
    $tot = [long]0
    foreach ($m in @(Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop)) {
      $tot += [long]$m.Capacity
      $ty = Get-MemType $m.MemoryType $m.SMBIOSMemoryType
      $spd = [string]$m.ConfiguredClockSpeed
      if (-not $m.ConfiguredClockSpeed) { $spd = [string]$m.Speed }
      Add-HwRow 'Pamięć RAM' ([string]$m.DeviceLocator) (Fmt-GB $m.Capacity) '' (($ty + ' ' + $spd + ' MHz, ' + ([string]$m.Manufacturer).Trim() + ' ' + ([string]$m.PartNumber).Trim()).Trim())
    }
    if ($tot -gt 0) { Add-HwRow 'Pamięć RAM' 'Razem' (Fmt-GB $tot) '' '' }
  } catch {}
  try {
    foreach ($g in @(Get-CimInstance Win32_VideoController -ErrorAction Stop)) {
      $dd = ''
      if ($g.DriverDate) { $dd = ([datetime]$g.DriverDate).ToString('yyyy-MM-dd') }
      Add-HwRow 'Karta graficzna' ([string]$g.Name) ('Sterownik ' + $g.DriverVersion) '' ('Data sterownika: ' + $dd)
    }
  } catch {}

  # dyski fizyczne + liczniki niezawodności
  try {
    foreach ($d in @(Get-PhysicalDisk -ErrorAction Stop)) {
      $hs = [string]$d.HealthStatus
      $st = 'ok'
      if ($hs -eq 'Warning') { $st = 'warn' } elseif ($hs -ne 'Healthy') { $st = 'bad' }
      $det = ([string]$d.MediaType + ', ' + [string]$d.BusType + ', ' + (Fmt-GB $d.Size))
      try {
        $rc = $d | Get-StorageReliabilityCounter -ErrorAction Stop
        if ($rc) {
          if ($null -ne $rc.Temperature) { $det += ', temperatura: ' + $rc.Temperature + ' °C' }
          if ($null -ne $rc.Wear) { $det += ', zużycie: ' + $rc.Wear + '%' }
          if ($null -ne $rc.PowerOnHours) { $det += ', godziny pracy: ' + $rc.PowerOnHours }
          if ($rc.ReadErrorsTotal -gt 0) { $det += ', błędy odczytu: ' + $rc.ReadErrorsTotal; $st = 'warn' }
        }
      } catch {}
      Add-HwRow 'Dysk fizyczny' ([string]$d.FriendlyName) $hs $st $det
    }
  } catch {
    Add-HwRow 'Dysk fizyczny' 'Dyski' 'Niedostępne' 'warn' 'Nie udało się odczytać stanu dysków'
  }
  try {
    foreach ($v in @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop)) {
      if (-not $v.Size) { continue }
      $pct = [math]::Round(100 * $v.FreeSpace / $v.Size)
      $st = 'ok'
      if ($pct -lt 5) { $st = 'bad' } elseif ($pct -lt 15) { $st = 'warn' }
      Add-HwRow 'Wolumin' ([string]$v.DeviceID + ' ' + $v.VolumeName) ('Wolne ' + $pct + '%') $st ((Fmt-GB $v.FreeSpace) + ' wolne z ' + (Fmt-GB $v.Size) + ', ' + $v.FileSystem)
    }
  } catch {}

  # bateria
  try {
    $bat = @(Get-CimInstance Win32_Battery -ErrorAction Stop)
    foreach ($b in $bat) {
      $det = 'Status: ' + $b.BatteryStatus
      $st = 'ok'
      try {
        $full = (Get-CimInstance -Namespace 'root\wmi' -ClassName BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1).FullChargedCapacity
        $des = (Get-CimInstance -Namespace 'root\wmi' -ClassName BatteryStaticData -ErrorAction Stop | Select-Object -First 1).DesignedCapacity
        if ($full -and $des) {
          $health = [math]::Round(100 * $full / $des)
          $det = 'Kondycja: ' + $health + '% pojemności fabrycznej (' + $full + ' / ' + $des + ' mWh)'
          if ($health -lt 60) { $st = 'bad' } elseif ($health -lt 80) { $st = 'warn' }
        }
      } catch {}
      Add-HwRow 'Bateria' ([string]$b.Name) ('Naładowanie ' + $b.EstimatedChargeRemaining + '%') $st $det
    }
  } catch {}

  # temperatury (ACPI)
  $tz = @()
  try { $tz = @(Get-CimInstance -Namespace 'root\wmi' -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop) } catch {}
  if ($tz.Count -gt 0) {
    foreach ($z in $tz) {
      $t = [math]::Round(($z.CurrentTemperature / 10) - 273.15, 1)
      $st = 'ok'
      if ($t -ge 90) { $st = 'bad' } elseif ($t -ge 75) { $st = 'warn' }
      Add-HwRow 'Temperatura' ([string]$z.InstanceName) (($t.ToString([Globalization.CultureInfo]::InvariantCulture)) + ' °C') $st 'Strefa termiczna ACPI'
    }
  } else {
    Add-HwRow 'Temperatura' 'Czujniki ACPI' 'Niedostępne' '' 'System nie udostępnia temperatur przez WMI (użyj narzędzia producenta)'
  }

  $lv.EndUpdate()
  if ($lv.Tag) { Sort-List $lv $lv.Tag.Col $true }
  Drop-Errs
  Set-Status ('Pozycji sprzętu: ' + $lv.Items.Count)
}

function Load-Drivers($force) {
  if ($force -or -not $global:DrvCache) {
    $global:DrvCache = @(Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue | Where-Object { $_.DeviceName })
    Drop-Errs
  }
  Refresh-Drivers
}

function Refresh-Drivers {
  $lv = $global:LvDrv
  if (-not $global:DrvCache) { return }
  $q = (Fold $global:TxtDrvFilter.Text.Trim())
  $old = $global:ChkDrvOld.Checked
  $uns = $global:ChkDrvUns.Checked
  $limit = (Get-Date).AddYears(-3)
  $lv.BeginUpdate()
  $lv.Items.Clear()
  foreach ($d in $global:DrvCache) {
    $mf = [string]$d.Manufacturer
    $isOld = ($d.DriverDate -and ([datetime]$d.DriverDate) -lt $limit -and $mf -notlike '*Microsoft*')
    if ($old -and -not $isOld) { continue }
    if ($uns -and $d.IsSigned) { continue }
    if ($q) {
      $hay = Fold ([string]$d.DeviceName + ' ' + $d.DeviceClass + ' ' + $mf + ' ' + $d.DriverVersion)
      $okq = $true
      foreach ($w in $q.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)) { if (-not $hay.Contains($w)) { $okq = $false; break } }
      if (-not $okq) { continue }
    }
    $dt = ''
    if ($d.DriverDate) { $dt = ([datetime]$d.DriverDate).ToString('yyyy-MM-dd') }
    if ($d.IsSigned) { $sg = (L 'Tak') } else { $sg = (L 'Nie') }
    $it = Add-Row $lv @([string]$d.DeviceName, [string]$d.DeviceClass, $mf, [string]$d.DriverVersion, $dt, $sg)
    if ($isOld) { Set-State $it 4 'warn' }
    if (-not $d.IsSigned) { Set-State $it 5 'bad' }
  }
  $lv.EndUpdate()
  if ($lv.Tag) { Sort-List $lv $lv.Tag.Col $true }
  Set-Status ('Sterowników: ' + $lv.Items.Count)
}

function Switch-HwView {
  $drv = ($global:CmbHw.SelectedIndex -eq 1)
  $global:LvHw.Visible = (-not $drv)
  $global:LvDrv.Visible = $drv
  $global:TxtDrvFilter.Enabled = $drv
  $global:ChkDrvOld.Enabled = $drv
  $global:ChkDrvUns.Enabled = $drv
  if ($drv -and -not $global:DrvCache) {
    Set-Status 'Ładowanie...'
    $global:Form.Cursor = [Windows.Forms.Cursors]::WaitCursor
    try { Load-Drivers $false } finally { $global:Form.Cursor = [Windows.Forms.Cursors]::Default }
  }
  Fit-Visible
}

function Hw-Refresh {
  if ($global:CmbHw.SelectedIndex -eq 1) {
    Set-Status 'Ładowanie...'
    $global:Form.Cursor = [Windows.Forms.Cursors]::WaitCursor
    try { Load-Drivers $true } finally { $global:Form.Cursor = [Windows.Forms.Cursors]::Default }
  } else { Refresh-Hardware }
}

function Hw-Export {
  if ($global:CmbHw.SelectedIndex -eq 1) { Export-List $global:LvDrv } else { Export-List $global:LvHw }
}

function Show-DeviceErrors {
  Write-Log "`r`n>>> Urządzenia z błędami"
  $n = 0
  try {
    foreach ($d in @(Get-CimInstance Win32_PnPEntity -Filter 'ConfigManagerErrorCode <> 0' -ErrorAction Stop)) {
      $n++
      Write-Log ('  ' + $d.Name + '  (kod błędu: ' + $d.ConfigManagerErrorCode + ')  ' + $d.PNPDeviceID)
    }
  } catch { Write-Log ('BŁĄD: ' + $_.Exception.Message) }
  if ($n -eq 0) { Write-Log 'Brak urządzeń zgłaszających błędy.' }
  Drop-Errs
}

function Export-Drivers {
  $d = New-Object Windows.Forms.FolderBrowserDialog
  $d.Description = (L 'Wybierz folder docelowy dla kopii sterowników')
  if ($d.ShowDialog() -ne 'OK') { return }
  $dest = Join-Path $d.SelectedPath ('sterowniki-' + $env:COMPUTERNAME + '-' + (Get-Date -Format 'yyyyMMdd'))
  Start-PS 'Eksport sterowników' ('New-Item -ItemType Directory -Path "' + $dest + '" -Force | Out-Null' + "`r`n" + 'Export-WindowsDriver -Online -Destination "' + $dest + '" | Format-Table Driver,OriginalFileName,ClassName,Version -AutoSize | Out-String -Width 200' + "`r`n" + 'Write-Output ("' + (L 'Zapisano: ') + $dest + '")')
}

# ---------- logika: sprzątanie dysku ----------
function Expand-CatPaths($c) {
  $out = @()
  foreach ($p in $c.Paths) {
    $e = [Environment]::ExpandEnvironmentVariables($p)
    if ($e -match '[\*\?]') {
      try { foreach ($m in @(Resolve-Path -Path $e -ErrorAction Stop)) { $out += $m.ProviderPath } } catch {}
    } else { $out += $e }
  }
  Drop-Errs
  return $out
}

function Get-CleanCats {
  $c = New-Object Collections.ArrayList
  function New-CatDef($id, $name, $paths, $admin, $note, $filter = '', $special = '', $nodelete = $false) {
    return [pscustomobject]@{ Id = $id; Name = $name; Paths = $paths; Admin = $admin; Note = $note; Filter = $filter; Special = $special; NoDelete = $nodelete }
  }
  $la = '%LOCALAPPDATA%'
  [void]$c.Add((New-CatDef 'utemp' 'Pliki tymczasowe użytkownika' @('%TEMP%') $false ''))
  [void]$c.Add((New-CatDef 'stemp' 'Pliki tymczasowe systemu' @('%WINDIR%\Temp') $true ''))
  [void]$c.Add((New-CatDef 'thumb' 'Cache miniatur Eksploratora' @($la + '\Microsoft\Windows\Explorer') $false '' 'thumbcache_*.db'))
  [void]$c.Add((New-CatDef 'chrome' 'Cache Google Chrome' @($la + '\Google\Chrome\User Data\*\Cache', $la + '\Google\Chrome\User Data\*\Code Cache', $la + '\Google\Chrome\User Data\*\GPUCache') $false 'Zamknij przeglądarkę'))
  [void]$c.Add((New-CatDef 'edge' 'Cache Microsoft Edge' @($la + '\Microsoft\Edge\User Data\*\Cache', $la + '\Microsoft\Edge\User Data\*\Code Cache', $la + '\Microsoft\Edge\User Data\*\GPUCache') $false 'Zamknij przeglądarkę'))
  [void]$c.Add((New-CatDef 'brave' 'Cache Brave' @($la + '\BraveSoftware\Brave-Browser\User Data\*\Cache', $la + '\BraveSoftware\Brave-Browser\User Data\*\Code Cache') $false 'Zamknij przeglądarkę'))
  [void]$c.Add((New-CatDef 'firefox' 'Cache Mozilla Firefox' @($la + '\Mozilla\Firefox\Profiles\*\cache2') $false 'Zamknij przeglądarkę'))
  [void]$c.Add((New-CatDef 'wupd' 'Pobrane aktualizacje Windows' @('%WINDIR%\SoftwareDistribution\Download') $true ''))
  [void]$c.Add((New-CatDef 'wer' 'Raporty błędów Windows (WER)' @('%PROGRAMDATA%\Microsoft\Windows\WER\ReportArchive', '%PROGRAMDATA%\Microsoft\Windows\WER\ReportQueue', $la + '\Microsoft\Windows\WER') $true ''))
  [void]$c.Add((New-CatDef 'dumps' 'Zrzuty pamięci i awarii' @('%WINDIR%\Minidump', '%WINDIR%\MEMORY.DMP', $la + '\CrashDumps') $true ''))
  [void]$c.Add((New-CatDef 'bin' 'Kosz' @() $false '' '' 'bin'))
  [void]$c.Add((New-CatDef 'winold' 'Poprzednia instalacja Windows (Windows.old)' @('%SystemDrive%\Windows.old') $true 'Tylko informacja: usuń przez Oczyszczanie dysku' '' '' $true))
  return @($c)
}

function Get-BinSize {
  $r = [pscustomobject]@{ Size = [long]0; Files = [long]0 }
  try {
    $sh = New-Object -ComObject Shell.Application
    $bin = $sh.NameSpace(0xA)
    foreach ($i in @($bin.Items())) {
      $r.Files++
      try { $r.Size += [long]$i.ExtendedProperty('Size') } catch {}
    }
  } catch {}
  return $r
}

function Scan-Cat($c) {
  $size = [long]0
  $files = [long]0
  if ($c.Special -eq 'bin') {
    $b = Get-BinSize
    return [pscustomobject]@{ Size = $b.Size; Files = $b.Files }
  }
  foreach ($p in (Expand-CatPaths $c)) {
    if ($c.Filter) { $s = Scan-Filter $p $c.Filter } else { $s = Scan-Dir $p }
    $size += $s.Size
    $files += $s.Files
  }
  return [pscustomobject]@{ Size = $size; Files = $files }
}

function Refresh-Clean {
  if (-not (Enter-Busy)) { return }
  $lv = $global:LvClean
  try {
    $lv.BeginUpdate()
    $lv.Items.Clear()
    $total = [long]0
    foreach ($c in (Get-CleanCats)) {
      if ($global:ScanCancel) { break }
      Set-Status ('Skanowanie: ' + (L $c.Name))
      $s = Scan-Cat $c
      $note = $c.Note
      if ($c.Admin -and -not $global:IsAdmin) {
        if ($note) { $note += '; ' }
        $note += 'Wymaga administratora'
      }
      $paths = ($c.Paths -join '; ')
      if ($c.Special -eq 'bin') { $paths = '(Kosz)' }
      $it = Add-Row $lv @((L $c.Name), (MB $s.Size), $s.Files, (L $note), $paths)
      $it.Tag = $c
      if ($c.NoDelete) { Set-State $it 3 'warn' }
      elseif ($c.Admin -and -not $global:IsAdmin) { Set-State $it 3 'warn' }
      if (-not $c.NoDelete) { $total += $s.Size }
      [Windows.Forms.Application]::DoEvents()
    }
    $lv.EndUpdate()
    Set-Status ('Do odzyskania: ' + (MB $total) + ' MB')
  } finally { Leave-Busy }
  Drop-Errs
}

function Clean-SelectSafe {
  foreach ($it in $global:LvClean.Items) {
    $c = $it.Tag
    $it.Selected = ($c -and -not $c.NoDelete -and ($global:IsAdmin -or -not $c.Admin))
  }
}

function Clean-Preview {
  $lv = $global:LvClean
  if ($lv.SelectedItems.Count -eq 0) { Say 'Zaznacz kategorię.'; return }
  $c = $lv.SelectedItems[0].Tag
  if ($c.Special -eq 'bin') { Say 'Podgląd plików nie jest dostępny dla kosza.'; return }
  if (-not (Enter-Busy)) { return }
  try {
    Write-Log ("`r`n>>> Największe pliki: " + (L $c.Name))
    $all = @()
    foreach ($p in (Expand-CatPaths $c)) {
      if ($c.Filter) {
        $all += @(Get-ChildItem -LiteralPath $p -Filter $c.Filter -Force -File -ErrorAction SilentlyContinue | ForEach-Object { [pscustomobject]@{ Size = $_.Length; Path = $_.FullName } })
      } else { $all += @((Scan-Dir $p 25).Top) }
    }
    $n = 0
    foreach ($f in @($all | Sort-Object Size -Descending | Select-Object -First 25)) { $n++; Write-Log ('  ' + (MB $f.Size).PadLeft(10) + ' MB   ' + $f.Path) }
    if ($n -eq 0) { Write-Log 'Brak plików do wyświetlenia.' }
  } finally { Leave-Busy }
  Drop-Errs
}

function Clean-Run {
  $lv = $global:LvClean
  if ($lv.SelectedItems.Count -eq 0) { Say 'Zaznacz kategorie do wyczyszczenia.'; return }
  $todo = @()
  $sum = [long]0
  $lines = @()
  foreach ($it in $lv.SelectedItems) {
    $c = $it.Tag
    if ($c.NoDelete) { Write-Log ('Pomijam (usuń przez Oczyszczanie dysku): ' + (L $c.Name)); continue }
    if ($c.Admin -and -not $global:IsAdmin) { Write-Log ('Pomijam (wymaga administratora): ' + (L $c.Name)); continue }
    $todo += $c
    $lines += ('  - ' + (L $c.Name) + '  (' + $it.SubItems[1].Text + ' MB)')
    $sum += [long]([double]::Parse($it.SubItems[1].Text, [Globalization.CultureInfo]::InvariantCulture) * 1MB)
  }
  if ($todo.Count -eq 0) { Say 'Nie ma nic do wyczyszczenia w zaznaczonych kategoriach.'; return }
  if (-not (Ask ("Trwale usunąć zawartość poniższych kategorii (ok. " + (MB $sum) + " MB)?`r`n`r`n" + ($lines -join "`r`n") + "`r`n`r`nPliki w użyciu zostaną pominięte. Operacji nie można cofnąć."))) { return }
  if (-not (Enter-Busy)) { return }
  try {
    $freedAll = [long]0
    foreach ($c in $todo) {
      if ($global:ScanCancel) { break }
      Set-Status ('Czyszczenie: ' + (L $c.Name))
      $freed = [long]0
      if ($c.Special -eq 'bin') {
        $before = (Get-BinSize).Size
        try { Clear-RecycleBin -Force -ErrorAction Stop } catch {}
        $freed = [math]::Max(0, $before - (Get-BinSize).Size)
      } else {
        foreach ($p in (Expand-CatPaths $c)) {
          if (Test-Path -LiteralPath $p -PathType Leaf) {
            try { $l = (Get-Item -LiteralPath $p -Force).Length; Remove-Item -LiteralPath $p -Force -ErrorAction Stop; $freed += $l } catch {}
          } elseif (Test-Path -LiteralPath $p -PathType Container) {
            $freed += (Purge-Dir $p $c.Filter)
          }
        }
      }
      $freedAll += $freed
      Write-Log ('Wyczyszczono: ' + (L $c.Name) + ' (odzyskano ' + (MB $freed) + ' MB)')
      [Windows.Forms.Application]::DoEvents()
    }
    Write-Log ('<<< Odzyskano łącznie: ' + (MB $freedAll) + ' MB')
  } finally { Leave-Busy }
  Drop-Errs
  Refresh-Clean
}

# ---------- logika: analiza dysku ----------
function Disk-Path {
  $p = $global:TxtDiskPath.Text.Trim().Trim('"')
  if (-not $p -or -not (Test-Path -LiteralPath $p -PathType Container)) { Say 'Podaj istniejący folder lub dysk do analizy.'; return $null }
  return $p
}

function Disk-Browse {
  $d = New-Object Windows.Forms.FolderBrowserDialog
  $d.Description = (L 'Wybierz folder do analizy')
  if ($d.ShowDialog() -eq 'OK') { $global:TxtDiskPath.Text = $d.SelectedPath }
}

function Get-QuickHash($path, $full) {
  $fs = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
  try {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
      if ($full) { $h = $sha.ComputeHash($fs) }
      else {
        $buf = New-Object byte[] 65536
        $n = $fs.Read($buf, 0, $buf.Length)
        $h = $sha.ComputeHash($buf, 0, $n)
      }
    } finally { $sha.Dispose() }
  } finally { $fs.Close() }
  return [BitConverter]::ToString($h)
}

function Disk-Analyze {
  $p = Disk-Path
  if (-not $p) { return }
  if (-not (Enter-Busy)) { return }
  $lv = $global:LvDisk
  $mode = $global:CmbDisk.SelectedIndex
  try {
    $lv.BeginUpdate()
    $lv.Items.Clear()
    $lv.Columns[2].Text = (L 'Szczegóły')
    if ($mode -eq 0) {
      # największe foldery (poziom bezpośrednich podfolderów)
      $lv.Columns[2].Text = (L 'Udział')
      $rows = @()
      $root = Scan-Dir $p
      $own = [long]0
      try { foreach ($f in [IO.Directory]::EnumerateFiles($p)) { try { $own += (New-Object IO.FileInfo($f)).Length } catch {} } } catch {}
      $dirs = @()
      try { $dirs = @([IO.Directory]::EnumerateDirectories($p)) } catch {}
      $i = 0
      foreach ($d in $dirs) {
        if ($global:ScanCancel) { break }
        $i++
        Set-Status ('Skanowanie: ' + (Split-Path $d -Leaf) + '  (' + $i + '/' + $dirs.Count + ')')
        $s = Scan-Dir $d
        $rows += [pscustomobject]@{ Name = (Split-Path $d -Leaf); Size = $s.Size; Path = $d; Dir = $true }
        [Windows.Forms.Application]::DoEvents()
      }
      if ($own -gt 0) { $rows += [pscustomobject]@{ Name = (L '(pliki w tym folderze)'); Size = $own; Path = $p; Dir = $false } }
      $tot = [long]0
      foreach ($r in $rows) { $tot += $r.Size }
      foreach ($r in @($rows | Sort-Object Size -Descending)) {
        $pct = 0
        if ($tot -gt 0) { $pct = [math]::Round(100 * $r.Size / $tot, 1) }
        $it = Add-Row $lv @($r.Name, (MB $r.Size), ($pct.ToString([Globalization.CultureInfo]::InvariantCulture) + ' %'), $r.Path)
        $it.Tag = $r
      }
      Set-Status ('Razem: ' + (MB $tot) + ' MB w ' + $dirs.Count + ' podfolderach')
    }
    elseif ($mode -eq 1) {
      # największe pliki
      Set-Status 'Skanowanie...'
      $s = Scan-Dir $p 200
      foreach ($f in $s.Top) {
        $mod = ''
        try { $mod = (Get-Item -LiteralPath $f.Path -Force).LastWriteTime.ToString('yyyy-MM-dd') } catch {}
        $it = Add-Row $lv @((Split-Path $f.Path -Leaf), (MB $f.Size), $mod, $f.Path)
        $it.Tag = [pscustomobject]@{ Name = (Split-Path $f.Path -Leaf); Size = $f.Size; Path = $f.Path; Dir = $false }
      }
      Set-Status ('Plików przeskanowano: ' + $s.Files + ', łącznie ' + (MB $s.Size) + ' MB')
    }
    else {
      # duplikaty
      $mins = @(1, 10, 50, 100)
      $minB = [long]($mins[$global:CmbDiskMin.SelectedIndex]) * 1MB
      Set-Status 'Skanowanie...'
      $s = Scan-Dir $p 0 $minB
      $groups = @($s.Found | Group-Object Size | Where-Object { $_.Count -gt 1 } | Sort-Object { [long]$_.Name } -Descending)
      $total = 0
      foreach ($g in $groups) { $total += $g.Count }
      $done = 0
      $gid = 0
      $wasted = [long]0
      foreach ($g in $groups) {
        if ($global:ScanCancel) { break }
        $byQuick = @{}
        foreach ($f in $g.Group) {
          if ($global:ScanCancel) { break }
          $done++
          if (($done % 5) -eq 0) { Set-Status ('Porównywanie plików: ' + $done + '/' + $total) }
          try { $h = Get-QuickHash $f.Path $false } catch { continue }
          if (-not $byQuick.ContainsKey($h)) { $byQuick[$h] = New-Object Collections.ArrayList }
          [void]$byQuick[$h].Add($f)
          [Windows.Forms.Application]::DoEvents()
        }
        foreach ($qk in @($byQuick.Keys)) {
          $cand = $byQuick[$qk]
          if ($cand.Count -lt 2) { continue }
          $byFull = @{}
          foreach ($f in $cand) {
            if ($global:ScanCancel) { break }
            try { $h2 = Get-QuickHash $f.Path $true } catch { continue }
            if (-not $byFull.ContainsKey($h2)) { $byFull[$h2] = New-Object Collections.ArrayList }
            [void]$byFull[$h2].Add($f)
            [Windows.Forms.Application]::DoEvents()
          }
          foreach ($fk in @($byFull.Keys)) {
            $same = @($byFull[$fk] | Sort-Object { (Get-Item -LiteralPath $_.Path -Force).LastWriteTime })
            if ($same.Count -lt 2) { continue }
            $gid++
            $wasted += ([long]$same[0].Size * ($same.Count - 1))
            $k = 0
            foreach ($f in $same) {
              $k++
              $mod = ''
              try { $mod = (Get-Item -LiteralPath $f.Path -Force).LastWriteTime.ToString('yyyy-MM-dd') } catch {}
              $it = Add-Row $lv @((Split-Path $f.Path -Leaf), (MB $f.Size), ('#' + $gid + '  ' + $mod), $f.Path)
              $it.Tag = [pscustomobject]@{ Name = (Split-Path $f.Path -Leaf); Size = $f.Size; Path = $f.Path; Dir = $false; Group = $gid; Oldest = ($k -eq 1) }
            }
          }
        }
      }
      $lv.Columns[2].Text = (L 'Grupa i data')
      Set-Status ('Grup duplikatów: ' + $gid + ', do odzyskania: ' + (MB $wasted) + ' MB')
    }
    if ($global:ScanCancel) { Set-Status 'Przerwano.' }
  } finally {
    $lv.EndUpdate()
    Leave-Busy
  }
  Drop-Errs
}

function Disk-SelectDupes {
  $any = $false
  foreach ($it in $global:LvDisk.Items) {
    $t = $it.Tag
    if ($t -and $t.PSObject.Properties['Oldest']) { $it.Selected = (-not $t.Oldest); $any = $true }
  }
  if (-not $any) { Say 'Najpierw uruchom analizę w trybie "Duplikaty".' }
}

function Disk-Open {
  $lv = $global:LvDisk
  if ($lv.SelectedItems.Count -eq 0) { Say 'Zaznacz pozycję.'; return }
  $t = $lv.SelectedItems[0].Tag
  if (-not $t -or -not (Test-Path -LiteralPath $t.Path)) { Say 'Nie znaleziono pliku lub folderu.'; return }
  if ($t.Dir) { Start-Process explorer.exe -ArgumentList ('"' + $t.Path + '"') }
  else { Start-Process explorer.exe -ArgumentList ('/select,"' + $t.Path + '"') }
}

function Test-Protected($p) {
  $x = $p.TrimEnd('\', '/')
  if ($x -match '^[A-Za-z]:$' -or $x -eq '') { return $true }
  foreach ($r in $env:WINDIR, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData, (Join-Path $env:SystemDrive 'Users'), $env:USERPROFILE) {
    if ($r -and $x.TrimEnd('\') -eq $r.TrimEnd('\')) { return $true }
  }
  foreach ($r in $env:WINDIR, $env:ProgramFiles, ${env:ProgramFiles(x86)}) {
    if ($r -and $x.StartsWith($r.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { return $true }
  }
  return $false
}

function Disk-Trash {
  $lv = $global:LvDisk
  if ($lv.SelectedItems.Count -eq 0) { Say 'Zaznacz pozycje do przeniesienia do kosza.'; return }
  $sel = @()
  $sum = [long]0
  foreach ($it in $lv.SelectedItems) {
    $t = $it.Tag
    if (-not $t) { continue }
    if (-not $t.Dir -and $t.Name -eq (L '(pliki w tym folderze)')) { continue }
    if (Test-Protected $t.Path) { Write-Log ('Pomijam chroniony element systemowy: ' + $t.Path); continue }
    $sel += $it
    $sum += [long]$t.Size
  }
  if ($sel.Count -eq 0) { Say 'Nie ma nic do usunięcia w zaznaczeniu.'; return }
  if (-not (Ask ('Przenieść do kosza zaznaczone pozycje: ' + $sel.Count + ' (ok. ' + (MB $sum) + ' MB)?'))) { return }
  try { Add-Type -AssemblyName Microsoft.VisualBasic } catch { Say 'Nie udało się załadować obsługi kosza.'; return }
  $ok = 0
  foreach ($it in $sel) {
    $t = $it.Tag
    try {
      if ($t.Dir) { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($t.Path, 'OnlyErrorDialogs', 'SendToRecycleBin') }
      else { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($t.Path, 'OnlyErrorDialogs', 'SendToRecycleBin') }
      $ok++
      $lv.Items.Remove($it)
    } catch { Write-Log ('BŁĄD: ' + $t.Path + ' - ' + $_.Exception.Message) }
  }
  Write-Log ('Przeniesiono do kosza: ' + $ok + ' / ' + $sel.Count)
}

# ---------- logika: zarządzanie zdalne (CIM / WinRM, awaryjnie DCOM) ----------
$global:RCred = $null

function Test-LocalHost($h) {
  $x = $h.ToLowerInvariant()
  return ($x -eq 'localhost' -or $x -eq '127.0.0.1' -or $x -eq '::1' -or $x -eq $env:COMPUTERNAME.ToLowerInvariant() -or $x -eq '.')
}

function Remember-Host($h) {
  try {
    $list = New-Object Collections.ArrayList
    [void]$list.Add($h)
    foreach ($x in @($global:Settings['RemoteHosts'])) { if ($x -and ([string]$x).ToLowerInvariant() -ne $h.ToLowerInvariant()) { [void]$list.Add([string]$x) } }
    while ($list.Count -gt 15) { $list.RemoveAt($list.Count - 1) }
    $global:Settings['RemoteHosts'] = @($list.ToArray())
    Save-Settings
    $ac = $global:TxtRHost.AutoCompleteCustomSource
    $ac.Clear()
    foreach ($x in $list) { [void]$ac.Add([string]$x) }
  } catch {}
}

function Get-RHost {
  $h = $global:TxtRHost.Text.Trim()
  if ($h -notmatch '^[A-Za-z0-9\.\-_]+$') { Say 'Podaj poprawną nazwę komputera lub adres IP.'; return $null }
  return $h
}

function New-RSession($h) {
  $p = @{ ComputerName = $h; OperationTimeoutSec = 20; ErrorAction = 'Stop' }
  if ($global:RCred) { $p.Credential = $global:RCred }
  $first = $null
  try {
    $s = New-CimSession @p
    [void](Get-CimInstance -CimSession $s -ClassName Win32_OperatingSystem -OperationTimeoutSec 20 -ErrorAction Stop)
    return $s
  } catch {
    $first = $_
    try { if ($s) { Remove-CimSession $s -ErrorAction SilentlyContinue } } catch {}
  }
  try {
    $p.SessionOption = (New-CimSessionOption -Protocol Dcom)
    $s = New-CimSession @p
    [void](Get-CimInstance -CimSession $s -ClassName Win32_OperatingSystem -OperationTimeoutSec 20 -ErrorAction Stop)
    return $s
  } catch {
    try { if ($s) { Remove-CimSession $s -ErrorAction SilentlyContinue } } catch {}
    Write-Log ('BŁĄD połączenia z ' + $h + ': ' + $first.Exception.Message)
    Write-Log 'Sprawdź: czy komputer jest włączony, czy usługa WinRM jest uruchomiona (winrm quickconfig), zapora oraz uprawnienia konta.'
    return $null
  }
}

# wykonuje blok z sesją CIM; zawsze zamyka sesję
function With-RSession($needRemote, $sb) {
  $h = Get-RHost
  if (-not $h) { return }
  if ($needRemote -and (Test-LocalHost $h)) { Say 'Ta operacja jest zablokowana dla komputera lokalnego (użyj zakładki Naprawa).'; return }
  if (-not (Enter-Busy)) { return }
  $s = $null
  try {
    Set-Status ('Łączenie z ' + $h + '...')
    $s = New-RSession $h
    if ($s) { Remember-Host $h; & $sb $s $h }
  } catch { Report-Error $_ 'remote' }
  finally {
    if ($s) { try { Remove-CimSession $s -ErrorAction SilentlyContinue } catch {} }
    Leave-Busy
    Drop-Errs
  }
}

function Show-CredDialog {
  $d = New-Object Windows.Forms.Form
  $d.Text = (L 'Poświadczenia zdalne')
  $d.Size = New-Object Drawing.Size(440, 230)
  $d.StartPosition = 'CenterParent'
  $d.FormBorderStyle = 'FixedDialog'
  $d.MaximizeBox = $false
  $d.MinimizeBox = $false
  $d.Font = $global:Form.Font
  $l1 = New-Object Windows.Forms.Label; $l1.Text = 'Użytkownik (DOMENA\login):'; $l1.AutoSize = $true; $l1.Location = New-Object Drawing.Point(14, 16)
  $tu = New-Object Windows.Forms.TextBox; $tu.Location = New-Object Drawing.Point(14, 38); $tu.Width = 396
  $l2 = New-Object Windows.Forms.Label; $l2.Text = 'Hasło:'; $l2.AutoSize = $true; $l2.Location = New-Object Drawing.Point(14, 72)
  $tp = New-Object Windows.Forms.TextBox; $tp.Location = New-Object Drawing.Point(14, 94); $tp.Width = 396; $tp.UseSystemPasswordChar = $true
  $l3 = New-Object Windows.Forms.Label; $l3.Text = 'Hasło jest przechowywane tylko w pamięci do zamknięcia programu.'; $l3.AutoSize = $true; $l3.Location = New-Object Drawing.Point(14, 126); $l3.Tag = 'muted'
  $ok = New-Object Windows.Forms.Button; $ok.Text = 'Zapisz'; $ok.DialogResult = 'OK'; $ok.Location = New-Object Drawing.Point(220, 154); $ok.Size = New-Object Drawing.Size(90, 30)
  $cn = New-Object Windows.Forms.Button; $cn.Text = 'Anuluj'; $cn.DialogResult = 'Cancel'; $cn.Location = New-Object Drawing.Point(320, 154); $cn.Size = New-Object Drawing.Size(90, 30)
  $d.AcceptButton = $ok
  $d.CancelButton = $cn
  $d.Controls.AddRange(@($l1, $tu, $l2, $tp, $l3, $ok, $cn))
  $d.BackColor = $global:T.Page
  $d.ForeColor = $global:T.Text
  foreach ($dc in $d.Controls) { Theme-Control $dc; Tr-Control $dc }
  $d.Add_Shown({ Set-TitleBar $this })
  $res = $d.ShowDialog($global:Form)
  $user = $tu.Text.Trim()
  $pw = $tp.Text
  $d.Dispose()
  if ($res -ne 'OK') { return }
  if (-not $user) { $global:RCred = $null }
  else {
    $sec = ConvertTo-SecureString $pw -AsPlainText -Force
    $global:RCred = New-Object Management.Automation.PSCredential($user, $sec)
  }
  Update-RCredLabel
}

function Remote-Info {
  With-RSession $false {
    param($s, $h)
    Write-Log ("`r`n>>> Informacje o komputerze: " + $h)
    $os = Get-CimInstance -CimSession $s -ClassName Win32_OperatingSystem -ErrorAction Stop
    $cs = Get-CimInstance -CimSession $s -ClassName Win32_ComputerSystem -ErrorAction Stop
    $up = (Get-Date) - $os.LastBootUpTime
    Write-Log ('  System: ' + $os.Caption + ' ' + $os.Version)
    Write-Log ('  Nazwa: ' + $cs.Name + '   Domena: ' + $cs.Domain)
    Write-Log ('  Model: ' + $cs.Manufacturer + ' ' + $cs.Model)
    Write-Log ('  Zalogowany: ' + $cs.UserName)
    Write-Log ('  Ostatni start: ' + $os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm') + '  (działa: ' + [int]$up.TotalDays + ' d ' + $up.Hours + ' h)')
    Write-Log ('  RAM: ' + [math]::Round($os.FreePhysicalMemory / 1MB, 1) + ' GB wolne z ' + [math]::Round($os.TotalVisibleMemorySize / 1MB, 1) + ' GB')
    try {
      foreach ($c in @(Get-CimInstance -CimSession $s -ClassName Win32_Processor -ErrorAction Stop)) { Write-Log ('  CPU: ' + ([string]$c.Name).Trim() + '  (obciążenie: ' + $c.LoadPercentage + '%)') }
      foreach ($v in @(Get-CimInstance -CimSession $s -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop)) {
        Write-Log ('  Dysk ' + $v.DeviceID + ' ' + [math]::Round($v.FreeSpace / 1GB, 1) + ' GB wolne z ' + [math]::Round($v.Size / 1GB, 1) + ' GB')
      }
      foreach ($n in @(Get-CimInstance -CimSession $s -ClassName Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True' -ErrorAction Stop)) {
        Write-Log ('  IP: ' + (@($n.IPAddress) -join ', ') + '   MAC: ' + $n.MACAddress)
      }
    } catch {}
    Set-Status ('Pobrano informacje: ' + $h)
  }
}

function Update-RCredLabel {
  if (-not $global:LblRCred) { return }
  if ($global:RCred) { $global:LblRCred.Text = (L 'Konto: ') + $global:RCred.UserName }
  else { $global:LblRCred.Text = (L 'Konto: bieżący użytkownik') }
}

function Remote-Load($what) {
  if ($what -eq 'svc') { $global:CmbR.SelectedIndex = 1 } else { $global:CmbR.SelectedIndex = 0 }
  With-RSession $false {
    param($s, $h)
    if ($what -eq 'procs') {
      $lv = $global:LvRProc
      $rows = @(Get-CimInstance -CimSession $s -ClassName Win32_Process -OperationTimeoutSec 30 -ErrorAction Stop)
      $lv.BeginUpdate(); $lv.Items.Clear()
      foreach ($p in $rows) {
        $it = Add-Row $lv @([string]$p.Name, [string]$p.ProcessId, (MB $p.WorkingSetSize), [string]$p.CommandLine)
        $it.Tag = [int]$p.ProcessId
      }
      $lv.EndUpdate()
      Set-Status ('Procesów zdalnych: ' + $lv.Items.Count)
    } else {
      $lv = $global:LvRSvc
      $rows = @(Get-CimInstance -CimSession $s -ClassName Win32_Service -OperationTimeoutSec 30 -ErrorAction Stop)
      $lv.BeginUpdate(); $lv.Items.Clear()
      foreach ($v in $rows) {
        $it = Add-Row $lv @([string]$v.DisplayName, [string]$v.Name, [string]$v.State, [string]$v.StartMode, [string]$v.StartName)
        $it.Tag = [string]$v.Name
        if ($v.State -eq 'Running') { Set-State $it 2 'ok' }
      }
      $lv.EndUpdate()
      Set-Status ('Usług zdalnych: ' + $lv.Items.Count)
    }
    $global:CurrentRView = $what
  }
  Switch-RView
}

function Switch-RView {
  $svc = ($global:CmbR.SelectedIndex -eq 1)
  $global:LvRProc.Visible = (-not $svc)
  $global:LvRSvc.Visible = $svc
  Fit-Visible
}

function Remote-Kill {
  if ($global:LvRProc.SelectedItems.Count -eq 0 -or -not $global:LvRProc.Visible) { Say 'Zaznacz proces na liście procesów zdalnych.'; return }
  $it = $global:LvRProc.SelectedItems[0]
  $pid2 = [int]$it.Tag
  if (-not (Ask ('Zakończyć zdalny proces ' + $it.Text + ' (PID ' + $pid2 + ')?'))) { return }
  With-RSession $false {
    param($s, $h)
    $p = Get-CimInstance -CimSession $s -ClassName Win32_Process -Filter ('ProcessId=' + $pid2) -ErrorAction Stop
    if (-not $p) { Write-Log 'Proces już nie istnieje.'; return }
    $r = Invoke-CimMethod -InputObject $p -MethodName Terminate -ErrorAction Stop
    if ($r.ReturnValue -eq 0) { Write-Log ('Zakończono zdalny proces: ' + $p.Name + ' (PID ' + $pid2 + ')') }
    else { Write-Log ('BŁĄD: nie udało się zakończyć procesu (kod ' + $r.ReturnValue + ')') }
  }
  Remote-Load 'procs'
}

function Remote-Svc($act) {
  if ($global:LvRSvc.SelectedItems.Count -eq 0 -or -not $global:LvRSvc.Visible) { Say 'Zaznacz usługę na liście usług zdalnych.'; return }
  $name = [string]$global:LvRSvc.SelectedItems[0].Tag
  if ($act -ne 'start') { if (-not (Ask ('Wykonać operację na usłudze zdalnej "' + $name + '"?'))) { return } }
  With-RSession $false {
    param($s, $h)
    $flt = "Name='" + $name.Replace("'", "''") + "'"
    $svc = Get-CimInstance -CimSession $s -ClassName Win32_Service -Filter $flt -ErrorAction Stop
    if (-not $svc) { Write-Log 'Nie znaleziono usługi.'; return }
    if ($act -eq 'stop' -or $act -eq 'restart') {
      $r = Invoke-CimMethod -InputObject $svc -MethodName StopService -ErrorAction Stop
      if ($r.ReturnValue -ne 0 -and $r.ReturnValue -ne 5) { Write-Log ('BŁĄD: zatrzymanie usługi nie powiodło się (kod ' + $r.ReturnValue + ')'); return }
      for ($i = 0; $i -lt 20; $i++) {
        $svc = Get-CimInstance -CimSession $s -ClassName Win32_Service -Filter $flt -ErrorAction Stop
        if ($svc.State -eq 'Stopped') { break }
        Start-Sleep -Milliseconds 700
      }
      Write-Log ('Zatrzymano usługę zdalną: ' + $name)
    }
    if ($act -eq 'start' -or $act -eq 'restart') {
      $r = Invoke-CimMethod -InputObject $svc -MethodName StartService -ErrorAction Stop
      if ($r.ReturnValue -eq 0 -or $r.ReturnValue -eq 10) { Write-Log ('Uruchomiono usługę zdalną: ' + $name) }
      else { Write-Log ('BŁĄD: uruchomienie usługi nie powiodło się (kod ' + $r.ReturnValue + ')') }
    }
  }
  Remote-Load 'svc'
}

function Remote-Power($act) {
  $h = Get-RHost
  if (-not $h) { return }
  $txt = @{ restart = 'ZRESTARTOWAĆ'; shutdown = 'WYŁĄCZYĆ'; logoff = 'WYLOGOWAĆ użytkownika na' }[$act]
  if (-not (Ask ('Czy na pewno ' + $txt + ' komputer zdalny ' + $h + '? Niezapisane dane użytkownika mogą zostać utracone.'))) { return }
  $flags = @{ restart = 6; shutdown = 5; logoff = 4 }[$act]
  With-RSession $true {
    param($s, $hh)
    $os = Get-CimInstance -CimSession $s -ClassName Win32_OperatingSystem -ErrorAction Stop
    $r = Invoke-CimMethod -InputObject $os -MethodName Win32Shutdown -Arguments @{ Flags = [int]$flags } -ErrorAction Stop
    if ($r.ReturnValue -eq 0) { Write-Log ('Wysłano polecenie (' + $act + ') -> ' + $hh) }
    else { Write-Log ('BŁĄD: polecenie nie powiodło się (kod ' + $r.ReturnValue + ')') }
  }
}

function Remote-Share {
  $h = Get-RHost
  if (-not $h) { return }
  Start-Process explorer.exe -ArgumentList ('"\\' + $h + '\c$"')
}

function Remote-Rdp {
  $h = Get-RHost
  if (-not $h) { return }
  Start-Process mstsc.exe -ArgumentList ('/v:' + $h)
}

# ---------- logika: własne polecenia i profile ----------
$global:CustomFile = Join-Path $env:APPDATA 'AdminToolbox\custom.json'
$global:Custom = New-Object Collections.ArrayList

function New-CustomObj($n, $t, $c, $cat) {
  if ($t -ne 'PowerShell') { $t = 'CMD' }
  return [pscustomobject]@{ Name = [string]$n; Type = [string]$t; Cmd = [string]$c; Cat = [string]$cat }
}

function Refresh-Custom {
  $lv = $global:LvCust
  $q = ''
  if ($global:TxtCustFilter) { $q = (Fold $global:TxtCustFilter.Text.Trim()) }
  $lv.BeginUpdate()
  $lv.Items.Clear()
  for ($i = 0; $i -lt $global:Custom.Count; $i++) {
    $c = $global:Custom[$i]
    if ($q) {
      $hay = Fold ($c.Name + ' ' + $c.Cat + ' ' + $c.Cmd)
      $okq = $true
      foreach ($w in $q.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)) { if (-not $hay.Contains($w)) { $okq = $false; break } }
      if (-not $okq) { continue }
    }
    $it = Add-Row $lv @($c.Name, $c.Cat, $c.Type, (($c.Cmd -split "`r?`n")[0]))
    $it.Tag = $i
  }
  $lv.EndUpdate()
  if ($lv.Tag) { Sort-List $lv $lv.Tag.Col $true }
}

function Read-CustomList($x) {
  $res = @()
  foreach ($i in @($x)) {
    if ($null -eq $i -or -not $i.Name -or -not $i.Cmd) { continue }
    $cat = ''
    if ($i.PSObject.Properties['Cat']) { $cat = [string]$i.Cat }
    $res += (New-CustomObj $i.Name $i.Type $i.Cmd $cat)
  }
  return $res
}

function Load-Custom {
  $global:Custom.Clear()
  try {
    if (Test-Path $global:CustomFile) {
      $x = Get-Content -Raw -Encoding UTF8 $global:CustomFile | ConvertFrom-Json
      foreach ($o in (Read-CustomList $x)) { [void]$global:Custom.Add($o) }
    }
  } catch { Write-Log ('BŁĄD (własne polecenia): ' + $_.Exception.Message) }
  Refresh-Custom
}

function Save-Custom {
  $dir = Split-Path $global:CustomFile
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $json = ConvertTo-Json -InputObject @($global:Custom.ToArray()) -Depth 3
  [IO.File]::WriteAllText($global:CustomFile, $json, (New-Object Text.UTF8Encoding($true)))
}

function Show-CustomDialog($ex = $null) {
  $d = New-Object Windows.Forms.Form
  if ($ex) { $d.Text = (L 'Edytuj polecenie') } else { $d.Text = (L 'Nowe polecenie') }
  $d.Size = New-Object Drawing.Size(560, 340)
  $d.StartPosition = 'CenterParent'
  $d.FormBorderStyle = 'FixedDialog'
  $d.MaximizeBox = $false
  $d.MinimizeBox = $false
  $d.Font = $global:Form.Font

  $l1 = New-Object Windows.Forms.Label; $l1.Text = 'Nazwa:'; $l1.AutoSize = $true; $l1.Location = New-Object Drawing.Point(14, 16)
  $tn = New-Object Windows.Forms.TextBox; $tn.Location = New-Object Drawing.Point(90, 12); $tn.Width = 440
  $l2 = New-Object Windows.Forms.Label; $l2.Text = 'Typ:'; $l2.AutoSize = $true; $l2.Location = New-Object Drawing.Point(14, 50)
  $cb = New-Object Windows.Forms.ComboBox; $cb.DropDownStyle = 'DropDownList'; $cb.Location = New-Object Drawing.Point(90, 46); $cb.Width = 140
  [void]$cb.Items.Add('CMD'); [void]$cb.Items.Add('PowerShell'); $cb.SelectedIndex = 0
  $l4 = New-Object Windows.Forms.Label; $l4.Text = 'Kategoria:'; $l4.AutoSize = $true; $l4.Location = New-Object Drawing.Point(250, 50)
  $tg = New-Object Windows.Forms.TextBox; $tg.Location = New-Object Drawing.Point(330, 46); $tg.Width = 200
  $ac = New-Object Windows.Forms.AutoCompleteStringCollection
  foreach ($cat in @($global:Custom | ForEach-Object { $_.Cat } | Where-Object { $_ } | Sort-Object -Unique)) { [void]$ac.Add($cat) }
  $tg.AutoCompleteMode = 'SuggestAppend'; $tg.AutoCompleteSource = 'CustomSource'; $tg.AutoCompleteCustomSource = $ac
  $l3 = New-Object Windows.Forms.Label; $l3.Text = 'Polecenie (może być kilka linii):'; $l3.AutoSize = $true; $l3.Location = New-Object Drawing.Point(14, 84)
  $tc = New-Object Windows.Forms.TextBox; $tc.Multiline = $true; $tc.ScrollBars = 'Vertical'; $tc.AcceptsReturn = $true
  $tc.Font = New-Object Drawing.Font('Consolas', 9.5); $tc.Location = New-Object Drawing.Point(14, 106); $tc.Size = New-Object Drawing.Size(516, 120)
  $ok = New-Object Windows.Forms.Button; $ok.Text = 'Zapisz'; $ok.DialogResult = 'OK'; $ok.Location = New-Object Drawing.Point(340, 250); $ok.Size = New-Object Drawing.Size(90, 30)
  $cn = New-Object Windows.Forms.Button; $cn.Text = 'Anuluj'; $cn.DialogResult = 'Cancel'; $cn.Location = New-Object Drawing.Point(440, 250); $cn.Size = New-Object Drawing.Size(90, 30)
  $d.CancelButton = $cn
  $d.Controls.AddRange(@($l1, $tn, $l2, $cb, $l4, $tg, $l3, $tc, $ok, $cn))
  if ($ex) {
    $tn.Text = $ex.Name
    $tg.Text = $ex.Cat
    $tc.Text = ([string]$ex.Cmd) -replace "`r?`n", "`r`n"
    if ($ex.Type -eq 'PowerShell') { $cb.SelectedIndex = 1 }
  }
  $d.BackColor = $global:T.Page
  $d.ForeColor = $global:T.Text
  foreach ($dc in $d.Controls) { Theme-Control $dc; Tr-Control $dc }
  $d.Add_Shown({ Set-TitleBar $this })
  $res = $d.ShowDialog($global:Form)
  $name = $tn.Text.Trim(); $type = [string]$cb.SelectedItem; $cat2 = $tg.Text.Trim(); $cmd = $tc.Text
  $d.Dispose()
  if ($res -ne 'OK') { return $null }
  if (-not $name -or -not $cmd.Trim()) { Say 'Nazwa i polecenie nie mogą być puste.'; return $null }
  return (New-CustomObj $name $type $cmd $cat2)
}

function Add-Custom {
  $o = Show-CustomDialog
  if ($o) { [void]$global:Custom.Add($o); Save-Custom; Refresh-Custom }
}

function Edit-Custom {
  $lv = $global:LvCust
  if ($lv.SelectedItems.Count -eq 0) { Say 'Zaznacz polecenie.'; return }
  $idx = [int]$lv.SelectedItems[0].Tag
  $o = Show-CustomDialog $global:Custom[$idx]
  if ($o) { $global:Custom[$idx] = $o; Save-Custom; Refresh-Custom }
}

function Copy-Custom {
  $lv = $global:LvCust
  if ($lv.SelectedItems.Count -eq 0) { Say 'Zaznacz polecenie.'; return }
  $c = $global:Custom[[int]$lv.SelectedItems[0].Tag]
  [void]$global:Custom.Add((New-CustomObj ($c.Name + ' (kopia)') $c.Type $c.Cmd $c.Cat))
  Save-Custom
  Refresh-Custom
}

function Del-Custom {
  $lv = $global:LvCust
  if ($lv.SelectedItems.Count -eq 0) { Say 'Zaznacz polecenie.'; return }
  $idx = [int]$lv.SelectedItems[0].Tag
  if (-not (Ask ('Usunąć polecenie "' + $global:Custom[$idx].Name + '"?'))) { return }
  $global:Custom.RemoveAt($idx)
  Save-Custom
  Refresh-Custom
}

function Run-Custom {
  $lv = $global:LvCust
  if ($lv.SelectedItems.Count -eq 0) { Say 'Zaznacz polecenie.'; return }
  $c = $global:Custom[[int]$lv.SelectedItems[0].Tag]
  if ($c.Type -eq 'PowerShell') {
    $f = Join-Path $global:RunDir ([guid]::NewGuid().ToString('N') + '.ps1')
    [IO.File]::WriteAllText($f, $c.Cmd, (New-Object Text.UTF8Encoding($true)))
    Start-Task $c.Name ('powershell -NoProfile -ExecutionPolicy Bypass -File "' + $f + '"')
  } else {
    Start-Task $c.Name $c.Cmd
  }
}

function Run-CustomCat {
  $lv = $global:LvCust
  if ($lv.SelectedItems.Count -eq 0) { Say 'Zaznacz polecenie.'; return }
  $cat = $global:Custom[[int]$lv.SelectedItems[0].Tag].Cat
  if (-not $cat) { Say 'Zaznaczone polecenie nie ma kategorii.'; return }
  $set = @($global:Custom | Where-Object { $_.Cat -eq $cat })
  if (-not (Ask ('Uruchomić kolejno polecenia z kategorii "' + $cat + '" (' + $set.Count + ')?'))) { return }
  $lines = @()
  foreach ($c in $set) {
    $title = ($c.Name -replace '[&|<>^%"()!]', '_')
    $lines += 'echo.'
    $lines += ('echo === ' + $title + ' ===')
    $id = [guid]::NewGuid().ToString('N')
    if ($c.Type -eq 'PowerShell') {
      $f = Join-Path $global:RunDir ($id + '.ps1')
      [IO.File]::WriteAllText($f, $c.Cmd, (New-Object Text.UTF8Encoding($true)))
      $lines += ('powershell -NoProfile -ExecutionPolicy Bypass -File "' + $f + '"')
    } else {
      $f = Join-Path $global:RunDir ($id + '-set.cmd')
      [IO.File]::WriteAllText($f, ("@echo off`r`n" + $c.Cmd + "`r`n"), $global:Enc)
      $lines += ('call "' + $f + '"')
    }
  }
  Start-Task ('Zestaw: ' + $cat) ($lines -join "`r`n")
}

function Export-Profile {
  $d = New-Object Windows.Forms.SaveFileDialog
  $d.Filter = (L 'Profil Admin Toolbox (*.json)|*.json')
  $d.FileName = 'admin-toolbox-profil.json'
  $d.InitialDirectory = [Environment]::GetFolderPath('Desktop')
  if ($d.ShowDialog() -ne 'OK') { return }
  $obj = [ordered]@{
    Format = 'AdminToolboxProfile'
    Version = 1
    Exported = (Get-Date -Format 's')
    Commands = @($global:Custom.ToArray())
    RemoteHosts = @($global:Settings['RemoteHosts'] | Where-Object { $_ })
  }
  [IO.File]::WriteAllText($d.FileName, (ConvertTo-Json -InputObject $obj -Depth 5), (New-Object Text.UTF8Encoding($true)))
  Write-Log ('Zapisano: ' + $d.FileName)
}

function Import-Profile {
  $d = New-Object Windows.Forms.OpenFileDialog
  $d.Filter = (L 'Profil Admin Toolbox (*.json)|*.json|Wszystkie pliki (*.*)|*.*')
  $d.InitialDirectory = [Environment]::GetFolderPath('Desktop')
  if ($d.ShowDialog() -ne 'OK') { return }
  if (-not (Ask 'Importować polecenia z pliku? Zaimportowane polecenia nie są uruchamiane automatycznie. Uruchamiaj tylko polecenia z zaufanych źródeł.')) { return }
  try {
    $x = Get-Content -Raw -Encoding UTF8 -LiteralPath $d.FileName | ConvertFrom-Json
  } catch { Say 'Nie udało się odczytać pliku profilu (nieprawidłowy format).'; return }
  $cmds = $x
  if ($x -and $x.PSObject.Properties['Commands']) { $cmds = $x.Commands }
  $added = 0
  $skipped = 0
  foreach ($o in (Read-CustomList $cmds)) {
    $dup = $false
    foreach ($e in $global:Custom) { if ($e.Name -eq $o.Name -and $e.Cmd -eq $o.Cmd -and $e.Type -eq $o.Type) { $dup = $true; break } }
    if ($dup) { $skipped++ } else { [void]$global:Custom.Add($o); $added++ }
  }
  if ($x -and $x.PSObject.Properties['RemoteHosts']) {
    foreach ($h in @($x.RemoteHosts)) { if ($h -and ([string]$h) -match '^[A-Za-z0-9\.\-_]+$') { Remember-Host ([string]$h) } }
  }
  Save-Custom
  Refresh-Custom
  Write-Log ('Zaimportowano poleceń: ' + $added + ', pominięto duplikaty: ' + $skipped)
}

# ---------- język: tłumaczenie interfejsu ----------
function Tr-Control($c) {
  if ([object]::ReferenceEquals($c, $global:Header)) { return }
  if ([object]::ReferenceEquals($c, $global:LogBox)) { return }
  if ([object]::ReferenceEquals($c, $global:StatusLbl)) { return }
  if ($c -is [Windows.Forms.ListView]) {
    if (-not $global:OrigCols.ContainsKey($c)) {
      $a = @()
      foreach ($col in $c.Columns) { $a += [string]$col.Text }
      $global:OrigCols[$c] = $a
    }
    for ($i = 0; $i -lt $c.Columns.Count; $i++) { $c.Columns[$i].Text = (Get-Tr $global:OrigCols[$c][$i]) }
  }
  elseif ($c -is [Windows.Forms.ComboBox]) {
    if (-not $global:OrigItems.ContainsKey($c)) {
      $a = @()
      foreach ($i in $c.Items) { $a += [string]$i }
      $global:OrigItems[$c] = $a
    }
    $sel = $c.SelectedIndex
    $c.Items.Clear()
    foreach ($o in $global:OrigItems[$c]) { [void]$c.Items.Add((Get-Tr $o)) }
    $c.SelectedIndex = $sel
  }
  elseif (($c -is [Windows.Forms.Button]) -or ($c -is [Windows.Forms.Label]) -or ($c -is [Windows.Forms.CheckBox]) -or ($c -is [Windows.Forms.GroupBox]) -or ($c -is [Windows.Forms.TabPage])) {
    if (-not $global:Orig.ContainsKey($c)) { $global:Orig[$c] = [string]$c.Text }
    $c.Text = (Get-Tr $global:Orig[$c])
    if ($global:OrigTip.ContainsKey($c)) { $global:Tip.SetToolTip($c, (Get-Tr $global:OrigTip[$c])) }
  }
  foreach ($ch in $c.Controls) { Tr-Control $ch }
}

function Update-Sub {
  if (-not $global:LblSub) { return }
  $s = $env:USERNAME + ' @ ' + $env:COMPUTERNAME + '  |  tryb: ' + $global:ModeText
  if ($global:OsCaption) { $s = $s + '  |  ' + $global:OsCaption }
  $global:LblSub.Text = (L $s)
}

function Set-Cue($tb, $text) {
  if (-not $global:ThemeNative) { return }
  try { [void][Win32Theme]::SendMessage($tb.Handle, 0x1501, [IntPtr]1, $text) } catch {}
}

function Update-HeaderLang {
  $f = $global:Form
  if (-not $f) { return }
  $f.Text = (L ('Admin Toolbox - ' + $env:COMPUTERNAME + ' [' + $global:ModeText + ']'))
  Update-Sub
  if ($global:BtnTheme) {
    if ($global:IsDark) { $global:BtnTheme.Text = (L 'Tryb jasny') } else { $global:BtnTheme.Text = (L 'Tryb ciemny') }
    Set-Tip $global:BtnTheme 'Przełącz motyw jasny / ciemny'
  }
  if ($global:BtnLang) {
    if ($global:Lang -eq 'en') { $global:BtnLang.Text = 'PL' } else { $global:BtnLang.Text = 'EN' }
  }
  if ($global:BtnElev) {
    $global:BtnElev.Text = (L 'Uruchom jako administrator')
    Set-Tip $global:BtnElev 'Uruchamia to narzędzie ponownie z uprawnieniami administratora'
  }
  if ($global:TxtSearch) { Set-Cue $global:TxtSearch (L 'Szukaj funkcji... (Ctrl+F)') }
}

function Apply-Language {
  $f = $global:Form
  $f.SuspendLayout()
  foreach ($c in $f.Controls) { Tr-Control $c }
  Update-HeaderLang
  $f.ResumeLayout($true)
  if ($global:Tabs) { $global:Tabs.Invalidate() }
  foreach ($gp in $global:GraphPanels) { $gp.Invalidate() }
  Set-Status 'Gotowe  |  F5 = odśwież bieżącą zakładkę'
}

function Switch-Lang {
  if ($global:Lang -eq 'en') { $global:Lang = 'pl' } else { $global:Lang = 'en' }
  $global:Settings['Lang'] = $global:Lang
  Save-Settings
  Apply-Language
  $global:Loaded = @{}
  Load-Tab $true
}

# ---------- wyszukiwarka funkcji ----------
$global:SearchIndex = $null
$global:SearchResults = @()
$global:FlashBtn = $null

function Fold($s) {
  if ([string]::IsNullOrEmpty($s)) { return '' }
  $t = $s.ToLowerInvariant()
  $from = 'ąćęłńóśźż'
  $to = 'acelnoszz'
  for ($i = 0; $i -lt $from.Length; $i++) { $t = $t.Replace($from[$i], $to[$i]) }
  return $t
}

function Add-ButtonsToIndex($ctl, $tab, $idx) {
  foreach ($c in $ctl.Controls) {
    if ($c -is [Windows.Forms.Button]) { [void]$idx.Add(@{ Kind = 'btn'; Tab = $tab; Btn = $c }) }
    elseif ($c.Controls.Count -gt 0) { Add-ButtonsToIndex $c $tab $idx }
  }
}

function Build-SearchIndex {
  $idx = New-Object Collections.ArrayList
  foreach ($tp in $global:Tabs.TabPages) {
    [void]$idx.Add(@{ Kind = 'tab'; Tab = $tp; Btn = $null })
    Add-ButtonsToIndex $tp $tp $idx
  }
  $global:SearchIndex = $idx
}

function Search-Items($q) {
  $res = New-Object Collections.ArrayList
  $words = @((Fold $q).Split(' ', [StringSplitOptions]::RemoveEmptyEntries))
  if ($words.Count -eq 0) { return $res }
  foreach ($it in $global:SearchIndex) {
    if ($it.Kind -eq 'btn') { $key = $it.Btn } else { $key = $it.Tab }
    $hay = Fold ([string]$key.Text + ' ' + [string]$global:Orig[$key] + ' ' + [string]$it.Tab.Text + ' ' + [string]$global:Orig[$it.Tab])
    $ok = $true
    foreach ($w in $words) { if (-not $hay.Contains($w)) { $ok = $false; break } }
    if ($ok) { [void]$res.Add($it) }
    if ($res.Count -ge 14) { break }
  }
  return $res
}

function Search-Label($it) {
  if ($it.Kind -eq 'btn') { return ([string]$it.Btn.Text + '   —   ' + [string]$it.Tab.Text) }
  return ((L 'Zakładka: ') + [string]$it.Tab.Text)
}

function Hide-Search { if ($global:LbSearch) { $global:LbSearch.Visible = $false } }

function Search-Update {
  $q = $global:TxtSearch.Text.Trim()
  if (-not $q) { Hide-Search; return }
  if (-not $global:SearchIndex) { Build-SearchIndex }
  $global:SearchResults = @(Search-Items $q)
  $lb = $global:LbSearch
  $lb.BeginUpdate()
  $lb.Items.Clear()
  foreach ($it in $global:SearchResults) { [void]$lb.Items.Add((Search-Label $it)) }
  if ($lb.Items.Count -eq 0) { [void]$lb.Items.Add((L 'Brak wyników')) }
  $lb.EndUpdate()
  $lb.Height = ([math]::Min(14, $lb.Items.Count) * $lb.ItemHeight) + 6
  $lb.Visible = $true
  $lb.BringToFront()
}

function Flash-Btn($b) {
  $global:FlashBtn = $b
  $b.FlatAppearance.BorderColor = (RGB 255 193 7)
  $b.FlatAppearance.BorderSize = 3
  $global:FlashTimer.Stop()
  $global:FlashTimer.Start()
}

function Go-Search($it) {
  if (-not $it) { return }
  Hide-Search
  $global:Tabs.SelectedTab = $it.Tab
  if ($it.Btn) {
    $b = $it.Btn
    $p = $b.Parent
    while ($p -and -not (($p -is [Windows.Forms.ScrollableControl]) -and $p.AutoScroll)) { $p = $p.Parent }
    if ($p) { try { $p.ScrollControlIntoView($b) } catch {} }
    try { [void]$b.Focus() } catch {}
    Flash-Btn $b
  }
}

function Search-Pick {
  $i = $global:LbSearch.SelectedIndex
  if ($i -ge 0 -and $i -lt $global:SearchResults.Count) { Go-Search $global:SearchResults[$i] }
}

function Search-Key($e) {
  $lb = $global:LbSearch
  if ($e.KeyCode -eq 'Down' -and $lb.Visible -and $global:SearchResults.Count -gt 0) {
    [void]$lb.Focus()
    $lb.SelectedIndex = 0
    $e.Handled = $true
    $e.SuppressKeyPress = $true
  }
  elseif ($e.KeyCode -eq 'Enter') {
    if ($lb.Visible -and $global:SearchResults.Count -gt 0) { Go-Search $global:SearchResults[0] }
    $e.Handled = $true
    $e.SuppressKeyPress = $true
  }
  elseif ($e.KeyCode -eq 'Escape') {
    $global:TxtSearch.Clear()
    Hide-Search
    $e.Handled = $true
    $e.SuppressKeyPress = $true
  }
}

# ---------- ładowanie zakładek ----------
function Load-Tab($force) {
  $n = $global:Tabs.SelectedTab.Name
  if (-not $force -and $global:Loaded[$n]) { return }
  $global:Loaded[$n] = $true
  Set-Status 'Ładowanie...'
  $global:Form.Cursor = [Windows.Forms.Cursors]::WaitCursor
  try {
    switch ($n) {
      'home'  { Refresh-Sys }
      'procs' { Refresh-Procs }
      'svc'   { Refresh-Svc }
      'ports' { Refresh-Ports }
      'users' { Refresh-Users }
      'apps'  { Refresh-Apps }
      'start' { Refresh-Startup }
      'tasks' { Refresh-Tasks }
      'events' { Refresh-Events }
      'custom' { Load-Custom }
      'sec'   { Refresh-Security }
      'hw'    { Refresh-Hardware }
      'remote' { Update-RCredLabel }
    }
  } catch { Report-Error $_ 'tab' }
  if ($global:StatusLbl.Text -eq (L 'Ładowanie...')) { Set-Status 'Gotowe  |  F5 = odśwież bieżącą zakładkę' }
  $global:Form.Cursor = [Windows.Forms.Cursors]::Default
}

# =====================================================================
#  OKNO GŁÓWNE
# =====================================================================
$global:Form = New-Object Windows.Forms.Form
$form = $global:Form
$form.Text = 'Admin Toolbox - ' + $env:COMPUTERNAME + ' [' + $global:ModeText + ']'
$form.Size = New-Object Drawing.Size(1200, 800)
$form.MinimumSize = New-Object Drawing.Size(900, 600)
$form.StartPosition = 'CenterScreen'
$form.Font = $uiFont
$form.KeyPreview = $true

$split = New-Object Windows.Forms.SplitContainer
$split.Dock = 'Fill'
$split.Orientation = 'Horizontal'
$split.SplitterDistance = 470
$form.Controls.Add($split)

$statusPanel = New-Object Windows.Forms.Panel
$statusPanel.Dock = 'Bottom'
$statusPanel.Height = 24
$global:StatusLbl = New-Object Windows.Forms.Label
$global:StatusLbl.Dock = 'Fill'
$global:StatusLbl.TextAlign = 'MiddleLeft'
$global:StatusLbl.Padding = New-Object Windows.Forms.Padding(8, 0, 0, 0)
Set-Status ('Gotowe  |  F5 = odśwież bieżącą zakładkę')
$statusPanel.Controls.Add($global:StatusLbl)
$form.Controls.Add($statusPanel)

# --- nagłówek z miernikami ---
$header = New-Object Windows.Forms.Panel
$header.Dock = 'Top'
$header.Height = 58
$header.BackColor = [Drawing.Color]::FromArgb(30, 41, 59)
$form.Controls.Add($header)
$global:Header = $header

$lblTitle = New-Object Windows.Forms.Label
$lblTitle.Text = 'Admin Toolbox'
$lblTitle.ForeColor = [Drawing.Color]::White
$lblTitle.Font = New-Object Drawing.Font('Segoe UI Semibold', 15)
$lblTitle.AutoSize = $true
$lblTitle.Location = New-Object Drawing.Point(14, 5)
$header.Controls.Add($lblTitle)

$global:LblSub = New-Object Windows.Forms.Label
$global:LblSub.Text = $env:USERNAME + ' @ ' + $env:COMPUTERNAME + '  |  tryb: ' + $global:ModeText
$global:LblSub.ForeColor = [Drawing.Color]::FromArgb(170, 184, 204)
$global:LblSub.AutoSize = $true
$global:LblSub.Location = New-Object Drawing.Point(16, 36)
$header.Controls.Add($global:LblSub)

function New-Meter($x, $caption) {
  $l = New-Object Windows.Forms.Label
  $l.Text = $caption
  $l.ForeColor = [Drawing.Color]::White
  $l.AutoSize = $false
  $l.Size = New-Object Drawing.Size(170, 18)
  $l.Location = New-Object Drawing.Point($x, 10)
  $l.Anchor = 'Top,Right'
  $header.Controls.Add($l)
  $pb = New-Object Windows.Forms.ProgressBar
  $pb.Size = New-Object Drawing.Size(170, 12)
  $pb.Location = New-Object Drawing.Point($x, 32)
  $pb.Style = 'Continuous'
  $pb.Anchor = 'Top,Right'
  $header.Controls.Add($pb)
  return @($l, $pb)
}
$m1 = New-Meter 660 'CPU'
$m2 = New-Meter 840 'RAM'
$global:LblCpu = $m1[0]; $global:PbCpu = $m1[1]
$global:LblRam = $m2[0]; $global:PbRam = $m2[1]

$global:BtnTheme = Add-Btn $header 'Tryb ciemny' { Switch-Theme } 96 'ghost' 'Przełącz motyw jasny / ciemny'
$global:BtnTheme.Location = New-Object Drawing.Point(1070, 13)
$global:BtnTheme.Anchor = 'Top,Right'

$global:BtnLang = Add-Btn $header 'EN' { Switch-Lang } 44 'ghost' 'Język / Language'
$global:BtnLang.Location = New-Object Drawing.Point(1018, 13)
$global:BtnLang.Anchor = 'Top,Right'

$global:TxtSearch = New-Object Windows.Forms.TextBox
$global:TxtSearch.Size = New-Object Drawing.Size(200, 24)
$global:TxtSearch.Location = New-Object Drawing.Point(250, 9)
$global:TxtSearch.BorderStyle = 'FixedSingle'
$global:TxtSearch.BackColor = [Drawing.Color]::FromArgb(45, 58, 80)
$global:TxtSearch.ForeColor = [Drawing.Color]::White
$header.Controls.Add($global:TxtSearch)

$global:LbSearch = New-Object Windows.Forms.ListBox
$global:LbSearch.Location = New-Object Drawing.Point(250, 33)
$global:LbSearch.Size = New-Object Drawing.Size(420, 120)
$global:LbSearch.BorderStyle = 'FixedSingle'
$global:LbSearch.Visible = $false
$global:LbSearch.IntegralHeight = $false
$form.Controls.Add($global:LbSearch)

$global:SearchHide = New-Object Windows.Forms.Timer
$global:SearchHide.Interval = 250
$global:SearchHide.Add_Tick({
  $global:SearchHide.Stop()
  if (-not $global:TxtSearch.Focused -and -not $global:LbSearch.Focused) { Hide-Search }
})
$global:FlashTimer = New-Object Windows.Forms.Timer
$global:FlashTimer.Interval = 1600
$global:FlashTimer.Add_Tick({
  $global:FlashTimer.Stop()
  if ($global:FlashBtn) { Style-Btn $global:FlashBtn; $global:FlashBtn = $null }
})

$global:TxtSearch.Add_HandleCreated({ try { Set-Cue $this (L 'Szukaj funkcji... (Ctrl+F)') } catch {} })
$global:TxtSearch.Add_TextChanged({ Guard { Search-Update } 'search' })
$global:TxtSearch.Add_KeyDown({ param($s, $e) try { Search-Key $e } catch { Report-Error $_ 'search' } })
$global:TxtSearch.Add_Leave({ $global:SearchHide.Stop(); $global:SearchHide.Start() })
$global:LbSearch.Add_Click({ Guard { Search-Pick } 'search' })
$global:LbSearch.Add_Leave({ $global:SearchHide.Stop(); $global:SearchHide.Start() })
$global:LbSearch.Add_KeyDown({
  param($s, $e)
  if ($e.KeyCode -eq 'Enter') { Guard { Search-Pick } 'search'; $e.Handled = $true }
  elseif ($e.KeyCode -eq 'Escape') { Hide-Search; $global:TxtSearch.Focus(); $e.Handled = $true }
})

# --- zakładki ---
if ($global:CanThemeTabs) { $global:Tabs = New-Object ThemedTabControl } else { $global:Tabs = New-Object Windows.Forms.TabControl }
$global:Tabs.Dock = 'Fill'
$global:Tabs.Multiline = $true
$split.Panel1.Controls.Add($global:Tabs)

# --- panel logu ---
$global:LogBox = New-Object Windows.Forms.RichTextBox
$global:LogBox.ReadOnly = $true
$global:LogBox.WordWrap = $false
$global:LogBox.HideSelection = $false
$global:LogBox.DetectUrls = $false
$global:LogBox.Dock = 'Fill'
$global:LogBox.Font = $monoFont
$global:LogBox.BackColor = [Drawing.Color]::FromArgb(22, 25, 31)
$global:LogBox.ForeColor = $global:LogFg
$global:LogBox.BorderStyle = 'None'
$global:LogBox.Add_HandleCreated({ if ($global:ThemeNative) { try { [void][Win32Theme]::SetWindowTheme($this.Handle, 'DarkMode_Explorer', [NullString]::Value) } catch {} } })
$split.Panel2.Controls.Add($global:LogBox)

$logBar = New-Bar 42
$logBar.Dock = 'Bottom'
$split.Panel2.Controls.Add($logBar)
[void](Add-Btn $logBar 'Wyczyść log' { $global:LogBox.Clear() } 110)
[void](Add-Btn $logBar 'Kopiuj log' { if ($global:LogBox.TextLength -gt 0) { [Windows.Forms.Clipboard]::SetText($global:LogBox.Text) } } 100)
[void](Add-Btn $logBar 'Zapisz log...' {
  $d = New-Object Windows.Forms.SaveFileDialog
  $d.Filter = (L 'Plik tekstowy (*.txt)|*.txt')
  $d.FileName = 'admin-toolbox-log.txt'
  $d.InitialDirectory = [Environment]::GetFolderPath('Desktop')
  if ($d.ShowDialog() -eq 'OK') { [IO.File]::WriteAllText($d.FileName, $global:LogBox.Text, [Text.Encoding]::UTF8) }
} 110)
$global:BtnStop = Add-Btn $logBar 'Przerwij zadanie' {
  if ($global:Proc -and -not $global:Proc.HasExited) { & taskkill /T /F /PID $global:Proc.Id | Out-Null; Write-Log '!!! Zadanie przerwane przez użytkownika.' }
} 130 'danger'
$global:BtnStop.Enabled = $false
$chkWrap = New-Check $logBar 'Zawijaj wiersze' 130
$chkWrap.Add_CheckedChanged({ $global:LogBox.WordWrap = $this.Checked })

# --- timer zadań ---
$global:Timer = New-Object Windows.Forms.Timer
$global:Timer.Interval = 400
function Tick-Task {
  Pump-Log
  if ($global:Proc -and $global:Proc.HasExited) {
    Pump-Log
    Write-Log ('<<< zakończono (kod wyjścia: ' + $global:Proc.ExitCode + ')')
    $global:Timer.Stop()
    $global:Proc = $null
    $global:BtnStop.Enabled = $false
    Set-Status ('Gotowe')
    Remove-Item -LiteralPath $global:TaskBat -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $global:LogFile -Force -ErrorAction SilentlyContinue
  }
}
$global:Timer.Add_Tick({ try { Tick-Task } catch { Report-Error $_ 'timer' } })

# --- timer mierników i auto-odświeżania ---
try {
  $global:PerfCpu = New-Object Diagnostics.PerformanceCounter('Processor', '% Processor Time', '_Total')
  [void]$global:PerfCpu.NextValue()
} catch { $global:PerfCpu = $null }
$global:MeterTimer = New-Object Windows.Forms.Timer
$global:MeterTimer.Interval = 3000
function Tick-Meter {
  Update-Meters
  if ($global:ChkAuto.Checked -and $global:Tabs.SelectedTab.Name -eq 'procs') { Refresh-Procs }
  Fit-Visible
  Flush-Errors
}
$global:MeterTimer.Add_Tick({ try { Tick-Meter } catch { Report-Error $_ 'meter' } })

# =====================================================================
#  ZAKŁADKA: PULPIT
# =====================================================================
$tHome = New-Tab 'Pulpit' 'home'
$global:TxtSys = New-Object Windows.Forms.TextBox
$global:TxtSys.Multiline = $true
$global:TxtSys.ReadOnly = $true
$global:TxtSys.Dock = 'Fill'
$global:TxtSys.Font = $monoFont
$global:TxtSys.ScrollBars = 'Vertical'
$global:TxtSys.BackColor = [Drawing.Color]::White
$global:TxtSys.Add_HandleCreated({ Apply-NativeTheme $this })
$tHome.Controls.Add($global:TxtSys)
$barHome = New-Bar 46
$tHome.Controls.Add($barHome)
[void](Add-Btn $barHome 'Odśwież' { Refresh-Sys } 100 'primary')
[void](Add-Btn $barHome 'Kopiuj' { [Windows.Forms.Clipboard]::SetText($global:TxtSys.Text) } 90)
[void](Add-Btn $barHome 'Publiczny IP' {
  try { Write-Log ('Publiczny IP: ' + (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 6)) } catch { Write-Log 'Nie udało się pobrać publicznego IP (brak internetu?).' }
} 110)
[void](Add-Btn $barHome 'systeminfo' { Start-Task 'systeminfo' 'systeminfo' } 100)
[void](Add-Btn $barHome 'Stan dysków (SMART)' { Start-Task 'Stan dysków' 'powershell -NoProfile -Command "Get-PhysicalDisk | Format-Table FriendlyName,MediaType,HealthStatus,OperationalStatus -AutoSize | Out-String -Width 200"' } 150)
[void](Add-Btn $barHome 'Ostatnie poprawki' { Start-Task 'Poprawki Windows' 'powershell -NoProfile -Command "Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 30 | Format-Table HotFixID,Description,InstalledOn -AutoSize | Out-String -Width 200"' } 140)
[void](Add-Btn $barHome 'Raport HTML' { New-Report } 110 'primary' 'Zapisuje raport stanu systemu jako plik HTML')

# =====================================================================
#  ZAKŁADKA: WYDAJNOŚĆ
# =====================================================================
$tPerf = New-Tab 'Wydajność' 'perf'
$tl = New-Object Windows.Forms.TableLayoutPanel
$tl.Dock = 'Fill'
$tl.ColumnCount = 2
$tl.RowCount = 2
[void]$tl.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent', 50)))
[void]$tl.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent', 50)))
[void]$tl.RowStyles.Add((New-Object Windows.Forms.RowStyle('Percent', 50)))
[void]$tl.RowStyles.Add((New-Object Windows.Forms.RowStyle('Percent', 50)))
$tl.Controls.Add((New-Graph 'cpu' 'Procesor' '%' ([Drawing.Color]::FromArgb(0, 120, 212)) 100), 0, 0)
$tl.Controls.Add((New-Graph 'ram' 'Pamięć RAM' '%' ([Drawing.Color]::FromArgb(142, 68, 173)) 100), 1, 0)
$tl.Controls.Add((New-Graph 'disk' 'Aktywność dysku' '%' ([Drawing.Color]::FromArgb(230, 126, 34)) 100), 0, 1)
$tl.Controls.Add((New-Graph 'net' 'Sieć (wysłane + odebrane)' 'KB/s' ([Drawing.Color]::FromArgb(39, 174, 96)) 0), 1, 1)
$tPerf.Controls.Add($tl)

# =====================================================================
#  ZAKŁADKA: PROCESY
# =====================================================================
$tProc = New-Tab 'Procesy' 'procs'
$global:LvProc = New-List @(@('Nazwa', 280), @('PID', 80), @('CPU (s)', 90), @('Pamięć (MB)', 110))
$tProc.Controls.Add($global:LvProc)
$barProc = New-Bar 46
$tProc.Controls.Add($barProc)
[void](New-Label $barProc 'Filtr:')
$global:TxtProcFilter = New-Text $barProc 140
$global:TxtProcFilter.Add_TextChanged({ Guard { Refresh-Procs } })
$global:ChkAuto = New-Check $barProc 'Auto (3 s)' 90
[void](Add-Btn $barProc 'Odśwież' { Refresh-Procs } 90 'primary')
[void](Add-Btn $barProc 'Zakończ proces' { Kill-Proc $false } 120 'danger')
[void](Add-Btn $barProc 'Zakończ drzewo' { Kill-Proc $true } 120 'danger')
[void](Add-Btn $barProc 'Lokalizacja pliku' {
  $lv = $global:LvProc
  if ($lv.SelectedItems.Count -eq 0) { Say 'Zaznacz proces.'; return }
  $p = Get-Process -Id ([int]$lv.SelectedItems[0].SubItems[1].Text) -ErrorAction Stop
  Write-Log ($p.ProcessName + ' -> ' + $p.Path)
} 130)
[void](Add-Btn $barProc 'Eksport CSV' { Export-List $global:LvProc } 100)

# =====================================================================
#  ZAKŁADKA: USŁUGI
# =====================================================================
$tSvc = New-Tab 'Usługi' 'svc'
$global:LvSvc = New-List @(@('Nazwa', 200), @('Nazwa wyświetlana', 340), @('Stan', 90), @('Typ uruchomienia', 130))
$tSvc.Controls.Add($global:LvSvc)
$barSvc = New-Bar 82
$tSvc.Controls.Add($barSvc)
[void](New-Label $barSvc 'Filtr:')
$global:TxtSvcFilter = New-Text $barSvc 140
$global:TxtSvcFilter.Add_TextChanged({ Guard { Refresh-Svc } })
$global:ChkSvcRun = New-Check $barSvc 'Tylko uruchomione' 140
$global:ChkSvcRun.Add_CheckedChanged({ Guard { Refresh-Svc } })
[void](Add-Btn $barSvc 'Odśwież' { Refresh-Svc } 90 'primary')
[void](Add-Btn $barSvc 'Eksport CSV' { Export-List $global:LvSvc } 100)
[void](Add-Btn $barSvc 'Start' { Svc-Act 'start' } 80)
[void](Add-Btn $barSvc 'Stop' { Svc-Act 'stop' } 80 'danger')
[void](Add-Btn $barSvc 'Restart' { Svc-Act 'restart' } 80)
[void](Add-Btn $barSvc 'Auto' { Svc-Act 'Automatic' } 80)
[void](Add-Btn $barSvc 'Ręczny' { Svc-Act 'Manual' } 80)
[void](Add-Btn $barSvc 'Wyłączony' { Svc-Act 'Disabled' } 90 'danger')

# =====================================================================
#  ZAKŁADKA: PORTY
# =====================================================================
$tPort = New-Tab 'Porty' 'ports'
$global:LvPort = New-List @(@('Proto', 55), @('Adres lokalny', 140), @('Port', 65), @('Adres zdalny', 170), @('Stan', 100), @('PID', 65), @('Proces', 200))
$tPort.Controls.Add($global:LvPort)
$barPort = New-Bar 46
$tPort.Controls.Add($barPort)
[void](New-Label $barPort 'Filtr:')
$global:TxtPortFilter = New-Text $barPort 140
$global:TxtPortFilter.Add_TextChanged({ Guard { Refresh-Ports } })
$global:ChkListen = New-Check $barPort 'Tylko nasłuchujące' 140
$global:ChkListen.Checked = $true
$global:ChkListen.Add_CheckedChanged({ Guard { Refresh-Ports } })
[void](Add-Btn $barPort 'Odśwież' { Refresh-Ports } 90 'primary')
[void](Add-Btn $barPort 'Zakończ proces' { Kill-PortProc } 120 'danger')
[void](Add-Btn $barPort 'Eksport CSV' { Export-List $global:LvPort } 100)

# =====================================================================
#  ZAKŁADKA: SIEĆ
# =====================================================================
$tNet = New-Tab 'Sieć' 'net'
$pgNet = New-Page $tNet

$gTest = New-Group $pgNet 'Test połączenia'
[void](New-Label $gTest 'Host / IP:')
$global:TxtHost = New-Text $gTest 200 '8.8.8.8'
[void](New-Label $gTest 'Port:')
$global:TxtPort = New-Text $gTest 60 '443'
[void](Add-Btn $gTest 'Ping' { $h = Get-HostInput; if ($h) { Start-Task ('ping ' + $h) ('ping -n 4 ' + $h) } } 80 'primary')
[void](Add-Btn $gTest 'Tracert' { $h = Get-HostInput; if ($h) { Start-Task ('tracert ' + $h) ('tracert -d ' + $h) } } 80)
[void](Add-Btn $gTest 'Nslookup' { $h = Get-HostInput; if ($h) { Start-Task ('nslookup ' + $h) ('nslookup ' + $h) } } 80)
[void](Add-Btn $gTest 'Pathping' { $h = Get-HostInput; if ($h) { Start-Task ('pathping ' + $h) ('pathping -n -q 10 ' + $h) } } 80)
[void](Add-Btn $gTest 'Test portu' {
  $h = Get-HostInput
  if (-not $h) { return }
  $pt = 0
  if (-not [int]::TryParse($global:TxtPort.Text.Trim(), [ref]$pt) -or $pt -lt 1 -or $pt -gt 65535) { Say 'Podaj port 1-65535.'; return }
  Start-Task ('Test portu ' + $h + ':' + $pt) ('powershell -NoProfile -Command "Test-NetConnection ' + $h + ' -Port ' + $pt + ' | Out-String"')
} 100)

$gInfo = New-Group $pgNet 'Informacje'
[void](Add-Btn $gInfo 'ipconfig /all' { Start-Task 'ipconfig /all' 'ipconfig /all' })
[void](Add-Btn $gInfo 'Karty sieciowe' { Start-Task 'Karty sieciowe' 'powershell -NoProfile -Command "Get-NetAdapter | Format-Table Name,InterfaceDescription,Status,LinkSpeed,MacAddress -AutoSize | Out-String -Width 200"' })
[void](Add-Btn $gInfo 'Połączenia (netstat)' { Start-Task 'netstat -ano' 'netstat -ano' })
[void](Add-Btn $gInfo 'Tablica ARP' { Start-Task 'arp -a' 'arp -a' })
[void](Add-Btn $gInfo 'Tablica tras' { Start-Task 'route print' 'route print' })
[void](Add-Btn $gInfo 'Cache DNS' { Start-Task 'Cache DNS' 'ipconfig /displaydns' })
[void](Add-Btn $gInfo 'Profile Wi-Fi (nazwy)' { Start-Task 'Profile Wi-Fi' 'netsh wlan show profiles' })
[void](Add-Btn $gInfo 'Zapora - status' { Start-Task 'Zapora' 'netsh advfirewall show allprofiles state' })
[void](Add-Btn $gInfo 'Udziały sieciowe' { Start-Task 'net share' 'net share' })

$gNetFix = New-Group $pgNet 'Naprawa sieci'
[void](Add-Btn $gNetFix 'Wyczyść cache DNS' { Start-Task 'Flush DNS' 'ipconfig /flushdns' } 160 'primary')
[void](Add-Btn $gNetFix 'Odnów adres IP' { if (Ask 'Zwolnić i odnowić adres IP? Połączenie zniknie na chwilę.') { Start-Task 'Odnowienie IP' 'ipconfig /release & ipconfig /renew' } } 160 'danger')
[void](Add-Btn $gNetFix 'Reset Winsock' { if (Ask 'Zresetować Winsock? Wymaga restartu komputera.') { Start-Task 'Winsock reset' 'netsh winsock reset' } } 160 'danger')
[void](Add-Btn $gNetFix 'Reset TCP/IP' { if (Ask 'Zresetować stos TCP/IP? Wymaga restartu komputera.') { Start-Task 'TCP/IP reset' 'netsh int ip reset' } } 160 'danger')

# =====================================================================
#  ZAKŁADKA: NAPRAWA
# =====================================================================
$tFix = New-Tab 'Naprawa' 'fix'
$pgFix = New-Page $tFix

$gScan = New-Group $pgFix 'Skanowanie i naprawa systemu'
[void](Add-Btn $gScan 'SFC /scannow' { if (Ask 'Uruchomić SFC /scannow? To może potrwać kilkanaście minut.') { Start-Task 'sfc /scannow' 'sfc /scannow' } } 160 'primary')
[void](Add-Btn $gScan 'DISM CheckHealth' { Start-Task 'DISM CheckHealth' 'DISM /Online /Cleanup-Image /CheckHealth' })
[void](Add-Btn $gScan 'DISM ScanHealth' { Start-Task 'DISM ScanHealth' 'DISM /Online /Cleanup-Image /ScanHealth' })
[void](Add-Btn $gScan 'DISM RestoreHealth' { if (Ask 'Uruchomić DISM RestoreHealth? Wymaga internetu i może potrwać długo.') { Start-Task 'DISM RestoreHealth' 'DISM /Online /Cleanup-Image /RestoreHealth' } })
[void](Add-Btn $gScan 'CHKDSK C: (odczyt)' { Start-Task 'chkdsk C:' 'chkdsk C:' })
[void](Add-Btn $gScan 'CHKDSK C: /f /r' { if (Ask 'Zaplanować CHKDSK /f /r dla C: przy następnym starcie?') { Start-Task 'chkdsk /f /r' 'echo Y| chkdsk C: /f /r' } } 160 'danger')

$gClean = New-Group $pgFix 'Czyszczenie'
[void](Add-Btn $gClean 'Wyczyść pliki TEMP' {
  if (Ask 'Usunąć zawartość %TEMP% i C:\Windows\Temp?') {
    Start-Task 'Czyszczenie TEMP' 'powershell -NoProfile -Command "foreach($p in $env:TEMP,($env:WINDIR+''\Temp'')){ Get-ChildItem $p -Force -Exclude AdminToolbox_run -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }; Write-Output Gotowe."'
  }
} 160 'primary')
[void](Add-Btn $gClean 'Opróżnij kosz' { if (Ask 'Opróżnić kosz na wszystkich dyskach?') { Start-Task 'Kosz' 'powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue; Write-Output Gotowe."' } })
[void](Add-Btn $gClean 'Oczyszczanie dysku' { Start-Process cleanmgr.exe })
[void](Add-Btn $gClean 'Reset Windows Update' {
  if (Ask 'Zatrzymać usługi Windows Update i zmienić nazwy folderów cache?') {
    Start-Task 'Reset Windows Update' 'net stop wuauserv & net stop bits & rd /s /q %WINDIR%\SoftwareDistribution.old & rd /s /q %WINDIR%\System32\catroot2.old & ren %WINDIR%\SoftwareDistribution SoftwareDistribution.old & ren %WINDIR%\System32\catroot2 catroot2.old & net start bits & net start wuauserv'
  }
} 160 'danger')

$gMaint = New-Group $pgFix 'Konserwacja'
[void](Add-Btn $gMaint 'Punkt przywracania' { Start-Task 'Punkt przywracania' 'powershell -NoProfile -Command "Checkpoint-Computer -Description AdminToolbox -RestorePointType MODIFY_SETTINGS; Write-Output Gotowe."' } 160 'primary')
[void](Add-Btn $gMaint 'Odśwież zasady grupy' { Start-Task 'gpupdate' 'gpupdate /force' })
[void](Add-Btn $gMaint 'Restart Eksploratora' { Start-Task 'Restart Eksploratora' 'taskkill /f /im explorer.exe & start explorer.exe' })
[void](Add-Btn $gMaint 'Raport baterii' { Start-Task 'Raport baterii' ('powercfg /batteryreport /output "' + [Environment]::GetFolderPath('Desktop') + '\battery-report.html"') })
[void](Add-Btn $gMaint 'Raport energii (60 s)' { Start-Task 'Raport energii' ('powercfg /energy /duration 60 /output "' + [Environment]::GetFolderPath('Desktop') + '\energy-report.html"') })

$gPower = New-Group $pgFix 'Zasilanie'
[void](Add-Btn $gPower 'Restart (10 s)' { if (Ask 'Zrestartować komputer za 10 sekund?') { Start-Task 'Restart' 'shutdown /r /t 10' } } 160 'danger')
[void](Add-Btn $gPower 'Wyłącz (10 s)' { if (Ask 'Wyłączyć komputer za 10 sekund?') { Start-Task 'Wyłączenie' 'shutdown /s /t 10' } } 160 'danger')
[void](Add-Btn $gPower 'Anuluj restart/wyłączenie' { Start-Task 'Anuluj' 'shutdown /a' } 190 'primary')

# =====================================================================
#  ZAKŁADKA: UŻYTKOWNICY
# =====================================================================
$tUsr = New-Tab 'Użytkownicy' 'users'
$global:LvUsr = New-List @(@('Konto', 200), @('Włączone', 90), @('Ostatnie logowanie', 160), @('Opis', 420))
$tUsr.Controls.Add($global:LvUsr)
$barUsr = New-Bar 82
$tUsr.Controls.Add($barUsr)
[void](Add-Btn $barUsr 'Odśwież' { Refresh-Users } 90 'primary')
[void](Add-Btn $barUsr 'Włącz konto' { User-Act $true } 110)
[void](Add-Btn $barUsr 'Wyłącz konto' { User-Act $false } 110 'danger')
[void](Add-Btn $barUsr 'Szczegóły konta' {
  $lv = $global:LvUsr
  if ($lv.SelectedItems.Count -eq 0) { Say 'Zaznacz konto.'; return }
  $n = $lv.SelectedItems[0].Text
  if ($n -notmatch '^[A-Za-z0-9\.\-_ ]+$') { Say 'Nietypowa nazwa konta - użyj narzędzia lusrmgr.msc.'; return }
  Start-Task ('net user ' + $n) ('net user "' + $n + '"')
} 130)
[void](Add-Btn $barUsr 'Administratorzy' { Start-Task 'Grupa Administratorzy' 'powershell -NoProfile -Command "Get-LocalGroupMember -SID S-1-5-32-544 | Format-Table Name,ObjectClass,PrincipalSource -AutoSize | Out-String -Width 200"' } 130)
[void](Add-Btn $barUsr 'Zalogowani' { Start-Task 'query user' 'query user' } 100)
[void](Add-Btn $barUsr 'Eksport CSV' { Export-List $global:LvUsr } 100)

# =====================================================================
#  ZAKŁADKA: PROGRAMY
# =====================================================================
$tApp = New-Tab 'Programy' 'apps'
$global:LvApp = New-List @(@('Nazwa', 360), @('Wersja', 120), @('Wydawca', 220), @('Data instalacji', 110))
$tApp.Controls.Add($global:LvApp)
$barApp = New-Bar 46
$tApp.Controls.Add($barApp)
[void](New-Label $barApp 'Filtr:')
$global:TxtAppFilter = New-Text $barApp 160
$global:TxtAppFilter.Add_TextChanged({ Guard { Refresh-Apps } })
[void](Add-Btn $barApp 'Odśwież' { Refresh-Apps } 90 'primary')
[void](Add-Btn $barApp 'Odinstaluj' { Uninstall-App } 110 'danger')
[void](Add-Btn $barApp 'Eksport CSV' { Export-List $global:LvApp } 100)

# =====================================================================
#  ZAKŁADKA: AUTOSTART
# =====================================================================
$tStart = New-Tab 'Autostart' 'start'
$global:LvStart = New-List @(@('Nazwa', 220), @('Stan', 90), @('Źródło', 220), @('Polecenie', 520))
$tStart.Controls.Add($global:LvStart)
$barStart = New-Bar 82
$tStart.Controls.Add($barStart)
[void](Add-Btn $barStart 'Odśwież' { Refresh-Startup } 90 'primary')
[void](Add-Btn $barStart 'Włącz wpis' { Startup-Act 'on' } 120)
[void](Add-Btn $barStart 'Wyłącz wpis' { Startup-Act 'off' } 120 'danger')
[void](Add-Btn $barStart 'Usuń wpis' { Startup-Act 'del' } 110 'danger')
[void](Add-Btn $barStart 'Otwórz lokalizację' { Startup-Act 'open' } 150)
[void](Add-Btn $barStart 'Eksport CSV' { Export-List $global:LvStart } 100)
[void](Add-Btn $barStart 'Zarządzaj (Menedżer zadań)' { Start-Process taskmgr.exe '/0 /startup' } 190)

# =====================================================================
#  ZAKŁADKA: ZADANIA
# =====================================================================
$tTask = New-Tab 'Zadania' 'tasks'
$global:LvTask = New-List @(@('Nazwa', 260), @('Ścieżka', 280), @('Stan', 90), @('Autor', 240))
$tTask.Controls.Add($global:LvTask)
$barTask = New-Bar 82
$tTask.Controls.Add($barTask)
[void](New-Label $barTask 'Filtr:')
$global:TxtTaskFilter = New-Text $barTask 140
$global:TxtTaskFilter.Add_TextChanged({ Guard { Refresh-Tasks } })
$global:ChkMs = New-Check $barTask 'Ukryj zadania Microsoft' 170
$global:ChkMs.Checked = $true
$global:ChkMs.Add_CheckedChanged({ Guard { Refresh-Tasks } })
[void](Add-Btn $barTask 'Odśwież' { Refresh-Tasks } 90 'primary')
[void](Add-Btn $barTask 'Uruchom teraz' { Task-Act 'run' } 120)
[void](Add-Btn $barTask 'Włącz zadanie' { Task-Act 'on' } 120)
[void](Add-Btn $barTask 'Wyłącz zadanie' { Task-Act 'off' } 120 'danger')
[void](Add-Btn $barTask 'Eksport CSV' { Export-List $global:LvTask } 100)
[void](Add-Btn $barTask 'Harmonogram (okno)' { Start-Process taskschd.msc } 150)

# =====================================================================
#  ZAKŁADKA: ZDARZENIA
# =====================================================================
$tEvt = New-Tab 'Zdarzenia' 'events'
$global:LvEvt = New-List @(@('Czas', 140), @('Poziom', 80), @('Źródło', 200), @('ID', 60), @('Komunikat', 520))
$global:LvEvt.Add_DoubleClick({ Guard { Show-EventDetail } })
$tEvt.Controls.Add($global:LvEvt)
$barEvt = New-Bar 82
$tEvt.Controls.Add($barEvt)
[void](New-Label $barEvt 'Dziennik:')
$global:CmbLog = New-Combo $barEvt @('System', 'Application', 'Security', 'Setup') 110 0
[void](New-Label $barEvt 'Poziom:')
$global:CmbLevel = New-Combo $barEvt @('Błędy i krytyczne', 'Z ostrzeżeniami', 'Wszystkie') 140 0
[void](New-Label $barEvt 'Zakres:')
$global:CmbRange = New-Combo $barEvt @('Ostatnia godzina', 'Ostatnie 24 godziny', 'Ostatnie 7 dni', 'Ostatnie 30 dni') 150 1
[void](New-Label $barEvt 'Szukaj:')
$global:TxtEvtFilter = New-Text $barEvt 130
[void](Add-Btn $barEvt 'Odśwież' { Refresh-Events } 90 'primary')
[void](Add-Btn $barEvt 'Pełny komunikat' { Show-EventDetail } 130 'normal' 'Wyświetla pełny tekst zaznaczonego zdarzenia w logu (działa też dwuklik)')
[void](Add-Btn $barEvt 'Eksport CSV' { Export-List $global:LvEvt } 100)

# =====================================================================
#  ZAKŁADKA: BEZPIECZEŃSTWO
# =====================================================================
$tSec = New-Tab 'Bezpieczeństwo' 'sec'
$global:LvSec = New-List @(@('Kategoria', 130), @('Element', 280), @('Stan', 190), @('Szczegóły', 480))
$tSec.Controls.Add($global:LvSec)
$barSec = New-Bar 82
$tSec.Controls.Add($barSec)
[void](Add-Btn $barSec 'Odśwież' { Refresh-Security } 90 'primary' 'Ponownie sprawdza ustawienia bezpieczeństwa systemu')
[void](Add-Btn $barSec 'Szybki skan Defendera' {
  if (Ask 'Uruchomić szybki skan Microsoft Defender?') { Start-PS 'Szybki skan Defendera' ('Start-MpScan -ScanType QuickScan' + "`r`n" + 'Get-MpThreatDetection | Select-Object -First 20 | Format-Table InitialDetectionTime,ThreatID,ProcessName -AutoSize | Out-String -Width 200' + "`r`n" + 'Write-Output ''' + ((L 'Gotowe.') -replace "'", "''") + '''') }
} 170 'primary')
[void](Add-Btn $barSec 'Aktualizuj sygnatury' { Start-PS 'Aktualizacja sygnatur' ('Update-MpSignature' + "`r`n" + 'Write-Output ''' + ((L 'Gotowe.') -replace "'", "''") + '''') } 160)
[void](Add-Btn $barSec 'Administratorzy lokalni' { Start-PS 'Administratorzy lokalni' 'Get-LocalGroupMember -SID S-1-5-32-544 | Format-Table Name,ObjectClass,PrincipalSource -AutoSize | Out-String -Width 200' } 170)
[void](Add-Btn $barSec 'Udziały sieciowe' { Start-PS 'Udziały sieciowe' 'Get-CimInstance Win32_Share | Format-Table Name,Path,Description -AutoSize | Out-String -Width 200' } 140)
[void](Add-Btn $barSec 'Nieudane logowania (24 h)' {
  $none = ((L 'Brak zdarzeń lub brak dostępu.') -replace "'", "''")
  Start-PS 'Nieudane logowania' ('try {' + "`r`n" + '  $ev = Get-WinEvent -FilterHashtable @{ LogName = ''Security''; Id = 4625; StartTime = (Get-Date).AddDays(-1) } -MaxEvents 50 -ErrorAction Stop' + "`r`n" + '  $ev | ForEach-Object { [pscustomobject]@{ Time = $_.TimeCreated; Account = $_.Properties[5].Value; Source = $_.Properties[19].Value; LogonType = $_.Properties[10].Value } } | Format-Table -AutoSize | Out-String -Width 200' + "`r`n" + '} catch { Write-Output ''' + $none + ''' }')
} 190 'normal' 'Zdarzenia 4625 z dziennika Security (wymaga administratora)')
[void](Add-Btn $barSec 'Centrum zabezpieczeń' { Start-Process 'windowsdefender:' } 160)
[void](Add-Btn $barSec 'Windows Update' { Start-Process 'ms-settings:windowsupdate' } 130)
[void](Add-Btn $barSec 'Eksport CSV' { Export-List $global:LvSec } 100)

# =====================================================================
#  ZAKŁADKA: SPRZĘT I STEROWNIKI
# =====================================================================
$tHw = New-Tab 'Sprzęt' 'hw'
$global:LvHw = New-List @(@('Kategoria', 130), @('Element', 300), @('Wartość', 230), @('Szczegóły', 480))
$global:LvDrv = New-List @(@('Urządzenie', 320), @('Klasa', 120), @('Producent', 200), @('Wersja', 130), @('Data', 90), @('Podpisany', 90))
$global:LvDrv.Visible = $false
$tHw.Controls.Add($global:LvHw)
$tHw.Controls.Add($global:LvDrv)
$barHw = New-Bar 118
$tHw.Controls.Add($barHw)
[void](New-Label $barHw 'Widok:')
$global:CmbHw = New-Combo $barHw @('Podzespoły', 'Sterowniki') 130 0
$global:CmbHw.Add_SelectedIndexChanged({ Guard { Switch-HwView } })
[void](New-Label $barHw 'Szukaj:')
$global:TxtDrvFilter = New-Text $barHw 140
$global:TxtDrvFilter.Enabled = $false
$global:TxtDrvFilter.Add_TextChanged({ Guard { Refresh-Drivers } })
$global:ChkDrvOld = New-Check $barHw 'Starsze niż 3 lata' 150
$global:ChkDrvOld.Enabled = $false
$global:ChkDrvOld.Add_CheckedChanged({ Guard { Refresh-Drivers } })
$global:ChkDrvUns = New-Check $barHw 'Niepodpisane' 120
$global:ChkDrvUns.Enabled = $false
$global:ChkDrvUns.Add_CheckedChanged({ Guard { Refresh-Drivers } })
[void](Add-Btn $barHw 'Odśwież' { Hw-Refresh } 90 'primary')
[void](Add-Btn $barHw 'Urządzenia z błędami' { Show-DeviceErrors } 160 'normal' 'Wypisuje w logu urządzenia, które zgłaszają błąd w Menedżerze urządzeń')
[void](Add-Btn $barHw 'Skanuj zmiany sprzętu' { Start-Task 'Skanowanie sprzętu' 'pnputil /scan-devices' } 170)
[void](Add-Btn $barHw 'Eksportuj sterowniki' { Export-Drivers } 150 'normal' 'Zapisuje kopię zainstalowanych sterowników (Export-WindowsDriver)')
[void](Add-Btn $barHw 'Menedżer urządzeń' { Start-Process devmgmt.msc } 150)
[void](Add-Btn $barHw 'Eksport CSV' { Hw-Export } 100)

# =====================================================================
#  ZAKŁADKA: SPRZĄTANIE DYSKU
# =====================================================================
$tClean = New-Tab 'Sprzątanie' 'clean'
$global:LvClean = New-List @(@('Kategoria', 300), @('Rozmiar (MB)', 110), @('Pliki', 80), @('Uwagi', 240), @('Ścieżka', 400))
$tClean.Controls.Add($global:LvClean)
$barClean = New-Bar 82
$tClean.Controls.Add($barClean)
[void](Add-Btn $barClean 'Skanuj' { Refresh-Clean } 90 'primary' 'Oblicza ile miejsca zajmują pliki tymczasowe i cache')
[void](Add-Btn $barClean 'Zaznacz bezpieczne' { Clean-SelectSafe } 150)
[void](Add-Btn $barClean 'Podgląd plików' { Clean-Preview } 130 'normal' 'Wypisuje w logu największe pliki zaznaczonej kategorii')
[void](Add-Btn $barClean 'Wyczyść zaznaczone' { Clean-Run } 160 'danger')
[void](Add-Btn $barClean 'Przerwij' { Cancel-Busy } 90)
[void](Add-Btn $barClean 'Oczyszczanie dysku' { Start-Process cleanmgr.exe } 150)
$lblClean = New-Label $barClean 'Najpierw kliknij "Skanuj", zaznacz kategorie (Ctrl+klik) i wybierz "Wyczyść zaznaczone".'
$lblClean.Tag = 'muted'

# =====================================================================
#  ZAKŁADKA: ANALIZA DYSKU
# =====================================================================
$tDisk = New-Tab 'Dysk' 'disk'
$global:LvDisk = New-List @(@('Nazwa', 280), @('Rozmiar (MB)', 110), @('Szczegóły', 150), @('Ścieżka', 520))
$tDisk.Controls.Add($global:LvDisk)
$barDisk = New-Bar 118
$tDisk.Controls.Add($barDisk)
[void](New-Label $barDisk 'Folder:')
$global:TxtDiskPath = New-Text $barDisk 280 ($env:SystemDrive + '\')
[void](Add-Btn $barDisk 'Wybierz...' { Disk-Browse } 100)
[void](New-Label $barDisk 'Tryb:')
$global:CmbDisk = New-Combo $barDisk @('Największe foldery', 'Największe pliki', 'Duplikaty') 160 0
[void](New-Label $barDisk 'Min. rozmiar duplikatów:')
$global:CmbDiskMin = New-Combo $barDisk @('1 MB', '10 MB', '50 MB', '100 MB') 80 1
[void](Add-Btn $barDisk 'Analizuj' { Disk-Analyze } 100 'primary')
[void](Add-Btn $barDisk 'Przerwij' { Cancel-Busy } 90)
[void](Add-Btn $barDisk 'Zaznacz duplikaty' { Disk-SelectDupes } 150 'normal' 'Zaznacza wszystkie kopie oprócz najstarszej w każdej grupie')
[void](Add-Btn $barDisk 'Otwórz lokalizację' { Disk-Open } 150)
[void](Add-Btn $barDisk 'Do kosza' { Disk-Trash } 100 'danger' 'Przenosi zaznaczone pliki lub foldery do Kosza (można przywrócić)')
[void](Add-Btn $barDisk 'Eksport CSV' { Export-List $global:LvDisk } 100)

# =====================================================================
#  ZAKŁADKA: ZDALNIE
# =====================================================================
$tRem = New-Tab 'Zdalnie' 'remote'
$global:LvRProc = New-List @(@('Nazwa', 240), @('PID', 70), @('Pamięć (MB)', 100), @('Linia poleceń', 560))
$global:LvRSvc = New-List @(@('Nazwa', 300), @('Usługa', 200), @('Stan', 100), @('Start', 100), @('Konto', 250))
$global:LvRSvc.Visible = $false
$tRem.Controls.Add($global:LvRProc)
$tRem.Controls.Add($global:LvRSvc)
$barRem = New-Bar 154
$tRem.Controls.Add($barRem)
[void](New-Label $barRem 'Komputer:')
$global:TxtRHost = New-Text $barRem 170
$global:TxtRHost.AutoCompleteMode = 'SuggestAppend'
$global:TxtRHost.AutoCompleteSource = 'CustomSource'
$acR = New-Object Windows.Forms.AutoCompleteStringCollection
foreach ($hx in @($global:Settings['RemoteHosts'])) { if ($hx) { [void]$acR.Add([string]$hx) } }
$global:TxtRHost.AutoCompleteCustomSource = $acR
[void](Add-Btn $barRem 'Poświadczenia...' { Show-CredDialog } 140 'normal' 'Konto używane do połączenia (puste = bieżący użytkownik)')
$global:LblRCred = New-Label $barRem 'Konto: bieżący użytkownik'
$global:LblRCred.Tag = 'muted'
[void](New-Label $barRem 'Widok:')
$global:CmbR = New-Combo $barRem @('Procesy', 'Usługi') 110 0
$global:CmbR.Add_SelectedIndexChanged({ Guard { Switch-RView } })
[void](Add-Btn $barRem 'Wczytaj' { if ($global:CmbR.SelectedIndex -eq 1) { Remote-Load 'svc' } else { Remote-Load 'procs' } } 90 'primary' 'Pobiera listę procesów lub usług z komputera zdalnego')
[void](Add-Btn $barRem 'Informacje' { Remote-Info } 100 'normal' 'System, sprzęt, dyski i adresy IP komputera zdalnego (także test połączenia)')
[void](Add-Btn $barRem 'Zakończ proces' { Remote-Kill } 130 'danger')
[void](Add-Btn $barRem 'Start usługi' { Remote-Svc 'start' } 110)
[void](Add-Btn $barRem 'Stop usługi' { Remote-Svc 'stop' } 110 'danger')
[void](Add-Btn $barRem 'Restart usługi' { Remote-Svc 'restart' } 120)
[void](Add-Btn $barRem 'Restart zdalny' { Remote-Power 'restart' } 130 'danger')
[void](Add-Btn $barRem 'Wyłącz zdalnie' { Remote-Power 'shutdown' } 130 'danger')
[void](Add-Btn $barRem 'Wyloguj zdalnie' { Remote-Power 'logoff' } 130 'danger')
[void](Add-Btn $barRem 'Udział C$' { Remote-Share } 100)
[void](Add-Btn $barRem 'Pulpit zdalny' { Remote-Rdp } 120)

# =====================================================================
#  ZAKŁADKA: WŁASNE POLECENIA I PROFILE
# =====================================================================
$tCust = New-Tab 'Własne' 'custom'
$global:LvCust = New-List @(@('Nazwa', 240), @('Kategoria', 140), @('Typ', 90), @('Polecenie', 560))
$global:LvCust.Add_DoubleClick({ Guard { Run-Custom } })
$tCust.Controls.Add($global:LvCust)
$barCust = New-Bar 118
$tCust.Controls.Add($barCust)
[void](New-Label $barCust 'Filtr:')
$global:TxtCustFilter = New-Text $barCust 140
$global:TxtCustFilter.Add_TextChanged({ Guard { Refresh-Custom } })
[void](Add-Btn $barCust 'Dodaj...' { Add-Custom } 100 'primary')
[void](Add-Btn $barCust 'Edytuj...' { Edit-Custom } 100)
[void](Add-Btn $barCust 'Duplikuj' { Copy-Custom } 100)
[void](Add-Btn $barCust 'Uruchom' { Run-Custom } 100)
[void](Add-Btn $barCust 'Uruchom kategorię' { Run-CustomCat } 150 'normal' 'Uruchamia kolejno wszystkie polecenia z kategorii zaznaczonego wiersza')
[void](Add-Btn $barCust 'Usuń' { Del-Custom } 90 'danger')
[void](Add-Btn $barCust 'Eksport profilu...' { Export-Profile } 140 'normal' 'Zapisuje polecenia i listę komputerów zdalnych do pliku JSON')
[void](Add-Btn $barCust 'Import profilu...' { Import-Profile } 140 'normal' 'Dołącza polecenia z pliku JSON (duplikaty są pomijane)')
$lblHint = New-Label $barCust 'Dwuklik uruchamia. Zapis: %APPDATA%\AdminToolbox\custom.json'
$lblHint.ForeColor = [Drawing.Color]::FromArgb(110, 120, 135)
$lblHint.Tag = 'muted'

# =====================================================================
#  ZAKŁADKA: NARZĘDZIA
# =====================================================================
$tTool = New-Tab 'Narzędzia' 'tools'
$pgTool = New-Page $tTool

function Add-Launchers($flow, $items) {
  foreach ($t in $items) {
    $exe = $t[1]
    [void](Add-Btn $flow $t[0] ({ Start-Process $exe }.GetNewClosure()) 180)
  }
}

$gMmc = New-Group $pgTool 'Zarządzanie systemem'
Add-Launchers $gMmc @(
  @('Menedżer zadań', 'taskmgr.exe'), @('Menedżer urządzeń', 'devmgmt.msc'), @('Zarządzanie dyskami', 'diskmgmt.msc'),
  @('Podgląd zdarzeń', 'eventvwr.msc'), @('Usługi (services.msc)', 'services.msc'), @('Harmonogram zadań', 'taskschd.msc'),
  @('Zarządzanie komputerem', 'compmgmt.msc'), @('Użytkownicy lokalni', 'lusrmgr.msc'), @('Zasady grup lokalnych', 'gpedit.msc'),
  @('Edytor rejestru', 'regedit.exe')
)
$gSys = New-Group $pgTool 'Informacje i wydajność'
Add-Launchers $gSys @(
  @('Informacje o systemie', 'msinfo32.exe'), @('Monitor zasobów', 'resmon.exe'), @('Monitor wydajności', 'perfmon.exe'),
  @('Diagnostyka DirectX', 'dxdiag.exe')
)
$gNetTools = New-Group $pgTool 'Sieć i programy'
Add-Launchers $gNetTools @(
  @('Zapora zaawansowana', 'wf.msc'), @('Połączenia sieciowe', 'ncpa.cpl'), @('Programy i funkcje', 'appwiz.cpl'),
  @('Ustawienia systemu', 'ms-settings:'), @('Właściwości systemu', 'SystemPropertiesAdvanced.exe')
)
$gShell = New-Group $pgTool 'Konsole'
Add-Launchers $gShell @(@('Wiersz polecenia', 'cmd.exe'), @('PowerShell', 'powershell.exe'), @('Eksplorator plików', 'explorer.exe'))
[void](Add-Btn $gShell 'Otwórz log błędów' {
  if (Test-Path $global:ErrLog) { Start-Process notepad.exe -ArgumentList ('"' + $global:ErrLog + '"') } else { Say 'Brak pliku logu błędów (nie wystąpiły błędy).' }
} 180)
[void](Add-Btn $gShell 'Błędy systemowe (24 h)' {
  Write-Log "`r`n>>> Błędy systemowe z ostatnich 24 h"
  try {
    $ev = Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 1, 2; StartTime = (Get-Date).AddDays(-1) } -MaxEvents 40 -ErrorAction Stop
    Write-Log (($ev | Format-Table TimeCreated, ProviderName, Id -AutoSize | Out-String -Width 220))
  } catch { Write-Log 'Brak błędów w ostatnich 24 godzinach (lub brak dostępu).' }
} 180 'primary')

# =====================================================================
#  TRYB UŻYTKOWNIKA: blokada funkcji wymagających admina
# =====================================================================
function Disable-AdminBtns($ctl) {
  foreach ($c in $ctl.Controls) {
    if (($c -is [Windows.Forms.Button]) -and ($global:AdminOnly -contains $c.Text)) {
      $c.Enabled = $false
      Set-Tip $c 'Wymaga uprawnień administratora'
    }
    if ($c.Controls.Count -gt 0) { Disable-AdminBtns $c }
  }
}
if (-not $global:IsAdmin) {
  Disable-AdminBtns $form
  $global:BtnElev = Add-Btn $header 'Uruchom jako administrator' {
    Start-Process -FilePath $env:SELF -ArgumentList '/admin' -Verb RunAs
    $global:Form.Close()
  } 190 'primary' 'Uruchamia to narzędzie ponownie z uprawnieniami administratora'
  $global:BtnElev.Size = New-Object Drawing.Size(190, 26)
  $global:BtnElev.Location = New-Object Drawing.Point(460, 6)
  $global:BtnElev.Anchor = 'Top,Right'
  Write-Log '!!! Tryb ograniczony: funkcje wymagające administratora są wyłączone (szare przyciski).'
}

# =====================================================================
#  MOTYW: zastosuj zapisany / systemowy
# =====================================================================
Apply-Theme
Apply-Language

# =====================================================================
#  ZDARZENIA FORMULARZA
# =====================================================================
$global:Tabs.Add_SelectedIndexChanged({ try { Load-Tab $false; Fit-Visible; Hide-Search } catch { Report-Error $_ 'tab' } })
$form.Add_KeyDown({
  try {
    if ($_.KeyCode -eq 'F5') { Load-Tab $true }
    elseif ($_.Control -and $_.KeyCode -eq 'F') { $global:TxtSearch.Focus(); $global:TxtSearch.SelectAll(); $_.SuppressKeyPress = $true }
  } catch { Report-Error $_ 'key' }
})

$form.Add_Shown({ try {
  Set-TitleBar $form
  try { $global:OsCaption = (Get-CimInstance Win32_OperatingSystem).Caption } catch {}
  Update-Sub
  Load-Tab $false
  Fit-Visible
  Update-Meters
  $global:MeterTimer.Start()
  Write-Log 'Admin Toolbox gotowy. Wyniki poleceń pojawiają się tutaj. F5 odświeża bieżącą zakładkę.'
} catch { Report-Error $_ 'shown' } })

$form.Add_FormClosing({
  if ($global:Proc -and -not $global:Proc.HasExited) {
    if (-not (Ask 'Zadanie nadal trwa. Zamknąć i przerwać je?')) { $_.Cancel = $true; return }
    & taskkill /T /F /PID $global:Proc.Id | Out-Null
  }
  $global:MeterTimer.Stop()
})

try {
  [System.Windows.Forms.Application]::add_ThreadException({ param($s, $e) Report-Error $e.Exception 'thread' })
  [AppDomain]::CurrentDomain.add_UnhandledException({ param($s, $e) Log-Error 'unhandled' $e.ExceptionObject })
} catch {}
Flush-Errors
if ($global:ErrSeen.Count -gt 0) { Write-Log 'Plik error.log zawiera komunikaty diagnostyczne (mogą to być niegroźne, obsłużone błędy). Narzędzia > Otwórz log błędów.' }
[void]$form.ShowDialog()
