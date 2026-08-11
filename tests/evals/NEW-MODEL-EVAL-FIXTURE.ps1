[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('node-bugfix','python-feature','java-refactor','powershell-analysis')][string]$Scenario,[Parameter(Mandatory)][string]$Path)
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
if(Test-Path -LiteralPath $Path){Remove-Item -LiteralPath $Path -Recurse -Force}
New-Item -ItemType Directory -Force -Path $Path|Out-Null
switch($Scenario){
  'node-bugfix' {
    & (Join-Path (Split-Path -Parent $PSScriptRoot) 'NEW-RELEASE-E2E-REPO.ps1') -Path $Path
    return
  }
  'python-feature' {
    New-Item -ItemType Directory -Force -Path (Join-Path $Path 'docs'),(Join-Path $Path 'src'),(Join-Path $Path 'tests')|Out-Null
    @'
# Rate limiter feature

- Implement `RateLimiter(limit, window_seconds, clock=time.monotonic)` in `src/rate_limiter.py`.
- `allow(key)` permits at most `limit` calls per key in a fixed window.
- The boundary at exactly `window_seconds` starts a new window.
- Keys are independent. Blank/non-string keys and non-positive constructor values are invalid.
- `reset(key)` clears only that key and returns whether state existed.
- Use only the Python standard library and add deterministic pytest coverage.
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'docs\feature.md')
    "# Implement the RateLimiter described in docs/feature.md.`n"|Set-Content -Encoding UTF8 (Join-Path $Path 'src\rate_limiter.py')
    @'
def test_placeholder():
    # Replace with behavioral tests while implementing the feature.
    assert True
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'tests\test_rate_limiter.py')
  }
  'java-refactor' {
    New-Item -ItemType Directory -Force -Path (Join-Path $Path 'src\main\java\eval'),(Join-Path $Path 'src\test\java\eval'),(Join-Path $Path 'docs')|Out-Null
    @'
# Refactoring task

Refactor `PriceCalculator` to remove duplicated discount/tax branching and make rules independently testable. Preserve the public constructor and `total(String,int,BigDecimal,String)` API and every existing observable result. Do not add dependencies. Add regression tests for boundary quantities, unknown tiers, scale/rounding, and invalid arguments.
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'docs\refactor.md')
    @'
package eval;
import java.math.BigDecimal;
import java.math.RoundingMode;

public class PriceCalculator {
  public BigDecimal total(String tier, int quantity, BigDecimal unitPrice, String region) {
    if (tier == null || unitPrice == null || region == null || quantity <= 0 || unitPrice.signum() < 0) throw new IllegalArgumentException();
    BigDecimal subtotal = unitPrice.multiply(BigDecimal.valueOf(quantity));
    if (tier.equals("GOLD")) subtotal = subtotal.multiply(quantity >= 10 ? new BigDecimal("0.80") : new BigDecimal("0.90"));
    else if (tier.equals("SILVER")) subtotal = subtotal.multiply(quantity >= 10 ? new BigDecimal("0.90") : new BigDecimal("0.95"));
    else if (!tier.equals("STANDARD")) throw new IllegalArgumentException();
    if (region.equals("EU")) subtotal = subtotal.multiply(new BigDecimal("1.20"));
    else if (region.equals("US")) subtotal = subtotal.multiply(new BigDecimal("1.07"));
    else if (!region.equals("NONE")) throw new IllegalArgumentException();
    return subtotal.setScale(2, RoundingMode.HALF_UP);
  }
}
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'src\main\java\eval\PriceCalculator.java')
    @'
package eval;
import static org.junit.jupiter.api.Assertions.*;
import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
class PriceCalculatorTest {
  @Test void goldEuSmoke(){assertEquals(new BigDecimal("96.00"),new PriceCalculator().total("GOLD",10,new BigDecimal("10"),"EU"));}
}
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'src\test\java\eval\PriceCalculatorTest.java')
    @'
<project xmlns="http://maven.apache.org/POM/4.0.0"><modelVersion>4.0.0</modelVersion><groupId>eval</groupId><artifactId>refactor-eval</artifactId><version>1</version><properties><maven.compiler.release>17</maven.compiler.release><project.build.sourceEncoding>UTF-8</project.build.sourceEncoding></properties><dependencies><dependency><groupId>org.junit.jupiter</groupId><artifactId>junit-jupiter</artifactId><version>5.11.4</version><scope>test</scope></dependency></dependencies><build><plugins><plugin><groupId>org.apache.maven.plugins</groupId><artifactId>maven-surefire-plugin</artifactId><version>3.5.2</version></plugin></plugins></build></project>
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'pom.xml')
  }
  'powershell-analysis' {
    New-Item -ItemType Directory -Force -Path (Join-Path $Path 'docs'),(Join-Path $Path 'src'),(Join-Path $Path 'tests')|Out-Null
    @'
# Safety requirements

REQ-PS-01: deletion targets must remain inside the supplied project root.
REQ-PS-02: destructive functions must support `-WhatIf` through ShouldProcess.
REQ-PS-03: reusable module functions must return structured data rather than user-interface text.

Create `AUDIT.md` with a compliance table, exact file/line evidence, risks, and minimal remediation. Do not edit implementation.
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'docs\requirements.md')
    @'
function Invoke-UnsafeDelete {
  param([string]$Root,[string]$RelativePath)
  $target=Join-Path $Root $RelativePath
  Remove-Item -LiteralPath $target -Recurse -Force
  Write-Host "Deleted $target"
}
Export-ModuleMember -Function Invoke-UnsafeDelete
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'src\Tools.psm1')
    @'
Describe 'Tools' {
  It 'exports delete command' {
    Import-Module "$PSScriptRoot\..\src\Tools.psm1" -Force
    Get-Command Invoke-UnsafeDelete | Should -Not -BeNullOrEmpty
  }
}
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'tests\Tools.Tests.ps1')
  }
}
$old=$ErrorActionPreference;$ErrorActionPreference='Continue'
try{
  & git -C $Path init -q;if($LASTEXITCODE -ne 0){throw 'git init failed'}
  & git -C $Path config user.email 'eval@example.invalid'; & git -C $Path config user.name 'Model Eval'
  & git -C $Path add .; & git -C $Path commit -q -m baseline;if($LASTEXITCODE -ne 0){throw 'git commit failed'}
}finally{$ErrorActionPreference=$old}
Write-Host "[PASS] $Scenario fixture: $Path"
