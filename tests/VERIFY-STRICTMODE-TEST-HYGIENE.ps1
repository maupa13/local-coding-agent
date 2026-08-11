[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$files=Get-ChildItem -LiteralPath (Join-Path $root 'tests') -Filter 'VERIFY-*.ps1' -File
$bad=@()
foreach($file in $files){
  $lines=Get-Content -LiteralPath $file.FullName
  for($i=0;$i -lt $lines.Count;$i++){
    $line=[string]$lines[$i]
    # Verifier regex/assertion patterns should be single-quoted when they contain
    # a literal PowerShell variable token. In a double-quoted string, `\$Name`
    # does NOT escape interpolation; the backtick is the PowerShell escape.
    if($line -match '^\s*(?:Need|Assert\w*)\s+"[^"\r\n]*\\\$[A-Za-z_][A-Za-z0-9_]*[^"\r\n]*"'){
      $bad += "$($file.Name):$($i+1): $line"
    }
  }
}
if($bad.Count){throw "unsafe double-quoted verifier pattern(s): $($bad -join ' | ')"}
Write-Host '[PASS] verifier patterns do not interpolate literal `$variables under StrictMode' -ForegroundColor Green
Write-Host 'StrictMode verifier hygiene PASS' -ForegroundColor Cyan
