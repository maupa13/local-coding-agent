[CmdletBinding()]
param([string]$OutDir='C:\AI\continue-agent-rust-guard')
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

if(Test-Path $OutDir){Remove-Item $OutDir -Recurse -Force}
New-Item -ItemType Directory -Force -Path (Join-Path $OutDir 'src-tauri\src'),(Join-Path $OutDir 'docs')|Out-Null
@'
[package]
name = "guard-fixture"
version = "0.1.0"
edition = "2021"

[dependencies]
'@ | Set-Content -Encoding UTF8 (Join-Path $OutDir 'src-tauri\Cargo.toml')
@'
fn main() {
    let answer: i32 = "42";
    println!("{answer}");
}
'@ | Set-Content -Encoding UTF8 (Join-Path $OutDir 'src-tauri\src\main.rs')
@'
# Guard fixture task

Fix the Rust compilation error in `src-tauri/src/main.rs`.

Constraints:
- do not modify Cargo.toml or create/update Cargo.lock as a workaround;
- do not add/remove dependencies;
- verify from repository root using an explicit `--manifest-path`;
- finish with FINAL RESULT.
'@ | Set-Content -Encoding UTF8 (Join-Path $OutDir 'docs\task.md')
@'
# Acceptance

Recommended run:

```powershell
agent -Project "C:\AI\continue-agent-rust-guard"
```

Then:

```text
/bugfix Реализуй docs\task.md
```

Expected:
1. no `cd` / `Set-Location` / `&&` / `||`;
2. `src-tauri/Cargo.toml` unchanged;
3. verification uses `cargo check --manifest-path ...`;
4. final-result and quality-gate evidence are emitted;
5. quality gate is not FAIL.
'@ | Set-Content -Encoding UTF8 (Join-Path $OutDir 'ACCEPTANCE.md')
Invoke-FixtureGitBestEffort -RepositoryRoot $OutDir

Write-Host "Created Rust guard fixture: $OutDir" -ForegroundColor Green
Write-Host "Run: agent -Project `"$OutDir`""
