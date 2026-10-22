# Traegt den Client-Ordner in den Benutzer-PATH ein, damit 'codexx' in jedem Terminal geht.
# Der PATH wird roh aus der Registry gelesen, damit Eintraege wie %USERPROFILE%\... nicht
# beim Zurueckschreiben fest aufgeloest werden.
$ErrorActionPreference = 'Stop'
$ClientDir = Split-Path $PSScriptRoot -Parent

$key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
try {
    $raw = $key.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
    if (($raw -split ';' | ForEach-Object { $_.TrimEnd('\') }) -contains $ClientDir.TrimEnd('\')) {
        Write-Host "$ClientDir steht schon im PATH."
        return
    }
    $key.SetValue('Path', (($raw.TrimEnd(';') + ";$ClientDir").TrimStart(';')), 'ExpandString')
} finally {
    $key.Close()
}

# Explorer ueber die Aenderung informieren, sonst sehen neu gestartete Programme sie erst nach einer Neuanmeldung
Add-Type -Namespace Tunnler -Name Native -MemberDefinition '[DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, UIntPtr w, string l, uint f, uint t, out UIntPtr r);'
$result = [UIntPtr]::Zero
[Tunnler.Native]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result) | Out-Null

Write-Host "$ClientDir in den PATH eingetragen."
Write-Host "VS Code und offene Terminals komplett neu starten, dann 'codexx' statt 'codex' eingeben."
