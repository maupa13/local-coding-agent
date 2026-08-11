[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$temp=Join-Path ([System.IO.Path]::GetTempPath()) ('LocalCodingAgent-fixtures-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{
  $generic=Join-Path $temp 'generic'
  & (Join-Path $root 'tests\NEW-ACCEPTANCE-REPO.ps1') -Destination $generic
  if(-not(Test-Path -LiteralPath (Join-Path $generic 'pom.xml') -PathType Leaf)){throw 'Generic fixture pom.xml missing.'}

  $rust=Join-Path $temp 'rust'
  & (Join-Path $root 'tests\NEW-RUST-GUARD-REPO.ps1') -OutDir $rust
  if(-not(Test-Path -LiteralPath (Join-Path $rust 'src-tauri\Cargo.toml') -PathType Leaf)){throw 'Rust fixture Cargo.toml missing.'}

  $docProject=Join-Path $temp 'doc-project'
  $docSource=Join-Path $temp 'doc-source'
  & (Join-Path $root 'tests\NEW-DOC-SOURCE-REPO.ps1') -Project $docProject -Docs $docSource -Force
  if(-not(Test-Path -LiteralPath (Join-Path $docSource 'feature.md') -PathType Leaf)){throw 'External docs fixture feature.md missing.'}

  $compliance=Join-Path $temp 'compliance'
  & (Join-Path $root 'tests\NEW-COMPLIANCE-REPO.ps1') -Path $compliance
  if(-not(Test-Path -LiteralPath (Join-Path $compliance 'docs\requirements.md') -PathType Leaf)){throw 'Compliance fixture requirements missing.'}
  Write-Host '[PASS] fixture generators are repeatable and isolated' -ForegroundColor Green
}finally{
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
