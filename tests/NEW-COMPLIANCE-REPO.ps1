[CmdletBinding()]
param([string]$Path='C:\AI\continue-agent-compliance')
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

if(Test-Path -LiteralPath $Path){Remove-Item -LiteralPath $Path -Recurse -Force}
New-Item -ItemType Directory -Force -Path (Join-Path $Path 'docs'),(Join-Path $Path 'src'),(Join-Path $Path 'tests')|Out-Null
@'
# Session requirements

REQ-01: `SessionStore.save()` must persist the supplied token.
REQ-02: `SessionStore.load()` must return the persisted token.
REQ-03: `SessionStore.clear()` must remove the persisted token.
REQ-04: Save/load/clear behavior must have automated regression tests.
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'docs\requirements.md')
@'
class SessionStore:
    def __init__(self):
        self._token = None
    def save(self, token):
        self._token = token
    def load(self):
        return self._token
    def clear(self):
        # Intentionally incomplete fixture: requirement exists but implementation does not clear.
        return None
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'src\session_store.py')
@'
from src.session_store import SessionStore

def test_save_and_load():
    store = SessionStore()
    store.save("abc")
    assert store.load() == "abc"
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'tests\test_session_store.py')
@'
[tool.pytest.ini_options]
pythonpath = ["."]
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'pyproject.toml')
Invoke-FixtureGitBestEffort -RepositoryRoot $Path -CommitBaseline

Write-Host "[PASS] Compliance fixture: $Path" -ForegroundColor Green
Write-Host 'Run:' -ForegroundColor Cyan
Write-Host "  agent -Project `"$Path`""
Write-Host '  > проанализируй папку docs и проект на соответствие документации'
Write-Host 'Expected: REQ-01/02 PASS evidence, REQ-03 FAIL/PARTIAL, REQ-04 PARTIAL/FAIL with missing clear regression evidence.' -ForegroundColor DarkGray
