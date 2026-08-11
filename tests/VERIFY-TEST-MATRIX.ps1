[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$path=Join-Path $root 'tests\TEST-MATRIX.json'
$m=Get-Content $path -Raw | ConvertFrom-Json

if($m.version -ne (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()){throw 'test matrix version mismatch'}
if(-not $m.PSObject.Properties['contracts']){throw 'test matrix missing contracts array'}

$required=@('id','area','description','test','tier')
$allowedTiers=@('regression','acceptance','lifecycle','runtime')
$ids=@()

foreach($c in @($m.contracts)){
  foreach($field in $required){
    $prop=$c.PSObject.Properties[$field]
    if($null -eq $prop){throw "test matrix contract missing required field '$field': $($c | ConvertTo-Json -Compress)"}
    if([string]::IsNullOrWhiteSpace([string]$prop.Value)){throw "test matrix contract has empty '$field': $($c | ConvertTo-Json -Compress)"}
  }

  $id=[string]$c.PSObject.Properties['id'].Value
  $tier=[string]$c.PSObject.Properties['tier'].Value
  $test=[string]$c.PSObject.Properties['test'].Value

  if($tier -notin $allowedTiers){throw "$id has unsupported tier '$tier'"}
  $ids += $id

  $p=Join-Path $root $test
  if(-not(Test-Path -LiteralPath $p)){throw "$id missing test: $test"}
}

if($ids.Count -ne (@($ids|Select-Object -Unique)).Count){throw 'duplicate test contract id'}

$reg=@($m.contracts|Where-Object{[string]$_.id -like 'REG-*'}).Count
$acc=@($m.contracts|Where-Object{[string]$_.id -like 'ACC-*'}).Count
if($reg -lt 12){throw "historical regression coverage too small: $reg"}
if($acc -lt 4){throw "acceptance fixture coverage too small: $acc"}

Write-Host "[PASS] test matrix schema: $($required -join ', ')" -ForegroundColor Green
Write-Host "[PASS] test matrix contracts: $($ids.Count) (regression=$reg acceptance=$acc)" -ForegroundColor Green
Write-Host 'Test matrix verification PASS' -ForegroundColor Cyan
