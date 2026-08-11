[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

$files=Get-ChildItem -LiteralPath $root -Recurse -File -Include *.ps1,*.psm1
$bad=New-Object 'System.Collections.Generic.List[string]'
foreach($file in $files){
  $lineNo=0
  foreach($line in @(Get-Content -LiteralPath $file.FullName)){
    $lineNo++
    $trimmed=$line.TrimStart()
    if($trimmed.StartsWith('#')){continue}
    # In a double-quoted PowerShell string, an unescaped "$name:" is parsed as
    # a scoped variable reference. Escaped "`$name:" and valid scopes are safe.
    $matches=[regex]::Matches($line,'"[^"]*(?<!`)\$([A-Za-z_][A-Za-z0-9_]*):[^"]*"')
    foreach($m in $matches){
      $name=$m.Groups[1].Value
      if($name -in @('env','script','global','local','private')){continue}
      [void]$bad.Add(('{0}:{1}: {2}' -f $file.FullName,$lineNo,$line.Trim()))
    }
  }
}
if($bad.Count){
  throw ("Unsafe `$variable: interpolation found: "+($bad -join ' | '))
}
Write-Host '[PASS] no unsafe $variable: interpolation in PowerShell strings' -ForegroundColor Green
Write-Host 'PowerShell variable-colon hygiene PASS' -ForegroundColor Cyan
