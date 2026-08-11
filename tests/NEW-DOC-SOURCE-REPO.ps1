[CmdletBinding()]
param(
    [string]$Project = 'C:\AI\continue-agent-doc-source',
    [string]$Docs = 'C:\AI\continue-agent-doc-source-docs',
    [switch]$Force
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Invoke-FixtureGitBestEffort {
    param([Parameter(Mandatory=$true)][string]$RepositoryRoot,[switch]$CommitBaseline)
    if(-not(Get-Command git -ErrorAction SilentlyContinue)){ return }
    $oldEap=$ErrorActionPreference
    $ErrorActionPreference='Continue'
    try{
        & git -C $RepositoryRoot init 2>$null | Out-Null
        if($LASTEXITCODE -ne 0){ Write-Warning "Fixture Git init skipped: $RepositoryRoot"; return }
        & git -C $RepositoryRoot config user.email 'fixture@local.invalid' 2>$null | Out-Null
        & git -C $RepositoryRoot config user.name 'Local Agent Fixture' 2>$null | Out-Null
        & git -C $RepositoryRoot add . 2>$null | Out-Null
        if($LASTEXITCODE -ne 0){ Write-Warning "Fixture Git add skipped: $RepositoryRoot"; return }
        if($CommitBaseline){
            & git -C $RepositoryRoot commit -m 'fixture baseline' 2>$null | Out-Null
            if($LASTEXITCODE -ne 0){ Write-Warning "Fixture Git baseline commit skipped: $RepositoryRoot" }
        }
    }finally{$ErrorActionPreference=$oldEap}
}

foreach($p in @($Project,$Docs)){
    if(Test-Path $p){if(-not $Force){throw "Path already exists: $p. Use -Force to recreate."};Remove-Item -LiteralPath $p -Recurse -Force}
    New-Item -ItemType Directory -Force -Path $p | Out-Null
}
New-Item -ItemType Directory -Force -Path (Join-Path $Project 'src') | Out-Null
@'
[package]
name = "doc-source-fixture"
version = "0.1.0"
edition = "2021"

[lib]
path = "src/lib.rs"
'@ | Set-Content -Encoding UTF8 (Join-Path $Project 'Cargo.toml')
@'
pub fn normalize_username(input: &str) -> String {
    input.to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn trims_and_lowercases_username() {
        assert_eq!(normalize_username("  Alice  "), "alice");
    }
}
'@ | Set-Content -Encoding UTF8 (Join-Path $Project 'src\lib.rs')
@'
# Feature: username normalization

## Goal
Implement `normalize_username` in the Rust library.

## Requirements
- trim leading and trailing whitespace;
- convert the result to lowercase;
- keep the public function name and signature unchanged;
- do not add dependencies;
- do not change Cargo.toml as part of the implementation.

## Acceptance
- `normalize_username("  Alice  ")` returns `"alice"`;
- existing Rust tests pass;
- Cargo.toml remains unchanged.
'@ | Set-Content -Encoding UTF8 (Join-Path $Docs 'feature.md')
@'
# Documentation-source acceptance fixture

The feature source of truth intentionally lives OUTSIDE the Git repository.

Expected managed-shell request:

/deliver-feature Реализуй функцию нормализации на основе документации по пути C:\AI\continue-agent-doc-source-docs

Expected behavior:
1. wrapper creates requirements-source.md in evidence before the model starts;
2. agent derives acceptance from the external document;
3. only src/lib.rs needs to change;
4. Cargo.toml stays protected;
5. quality engine runs Rust tests when Cargo.lock is available;
6. final output includes FINAL RESULT and QUALITY GATE/SCORE.
'@ | Set-Content -Encoding UTF8 (Join-Path $Project 'ACCEPTANCE.md')

if(Get-Command cargo -ErrorAction SilentlyContinue){
    $old=$ErrorActionPreference;$ErrorActionPreference='Continue'
    try{& cargo generate-lockfile --manifest-path (Join-Path $Project 'Cargo.toml') | Out-Null}
    finally{$ErrorActionPreference=$old}
}
Invoke-FixtureGitBestEffort -RepositoryRoot $Project -CommitBaseline

Write-Host "[PASS] Project fixture: $Project" -ForegroundColor Green
Write-Host "[PASS] External docs:   $Docs" -ForegroundColor Green
Write-Host ''
Write-Host 'Run:' -ForegroundColor Cyan
Write-Host "  agent -Project `"$Project`""
Write-Host "  /deliver-feature Реализуй функцию нормализации на основе документации по пути $Docs"
