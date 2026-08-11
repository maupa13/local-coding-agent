[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

$files=Get-ChildItem -LiteralPath $root -Recurse -File -Include *.ps1,*.psm1
$errors=New-Object 'System.Collections.Generic.List[string]'
foreach($file in $files){
  $tokens=$null
  $parseErrors=$null
  [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$parseErrors)
  foreach($err in @($parseErrors)){
    [void]$errors.Add(('{0}:{1}:{2}: {3}' -f $file.FullName,$err.Extent.StartLineNumber,$err.Extent.StartColumnNumber,$err.Message))
  }
}
if($errors.Count){throw ("PowerShell parser errors: "+($errors -join ' | '))}
Write-Host '[PASS] all PowerShell scripts parse without variable-colon or other parser errors' -ForegroundColor Green
Write-Host 'PowerShell parser hygiene PASS' -ForegroundColor Cyan
