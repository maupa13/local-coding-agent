[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('node-bugfix','python-feature','java-refactor','kotlin-feature','rust-feature','frontend-feature','powershell-analysis')][string]$Scenario,[Parameter(Mandatory)][string]$Path)
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
<project xmlns="http://maven.apache.org/POM/4.0.0"><modelVersion>4.0.0</modelVersion><groupId>eval</groupId><artifactId>refactor-eval</artifactId><version>1</version><properties><maven.compiler.release>17</maven.compiler.release><project.build.sourceEncoding>UTF-8</project.build.sourceEncoding></properties><dependencies><dependency><groupId>org.junit.jupiter</groupId><artifactId>junit-jupiter</artifactId><version>5.11.4</version><scope>test</scope></dependency></dependencies><build><plugins><plugin><groupId>org.apache.maven.plugins</groupId><artifactId>maven-surefire-plugin</artifactId><version>3.5.2</version></plugin><plugin><groupId>org.apache.maven.plugins</groupId><artifactId>maven-checkstyle-plugin</artifactId><version>3.6.0</version><configuration><configLocation>checkstyle.xml</configLocation><failOnViolation>true</failOnViolation></configuration></plugin></plugins></build></project>
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'pom.xml')
    @'
<?xml version="1.0"?><!DOCTYPE module PUBLIC "-//Checkstyle//DTD Checkstyle Configuration 1.3//EN" "https://checkstyle.org/dtds/configuration_1_3.dtd"><module name="Checker"><module name="FileTabCharacter"/><module name="TreeWalker"><module name="AvoidStarImport"/><module name="UnusedImports"/></module></module>
'@|Set-Content -Encoding UTF8 (Join-Path $Path 'checkstyle.xml')
  }
  'kotlin-feature' {
    New-Item -ItemType Directory -Force -Path (Join-Path $Path 'src\main\kotlin\eval'),(Join-Path $Path 'src\test\kotlin\eval'),(Join-Path $Path 'docs')|Out-Null
    "# Slug feature`n`nImplement ``eval.Slugifier.slug(String?): String`` in Kotlin. Trim input, lowercase with locale-independent rules, convert every run of non-ASCII-alphanumeric characters to one ``-``, strip edge separators, and reject null/blank/results that contain no alphanumeric characters. Preserve Java-callable static API. Add tests."|Set-Content -Encoding UTF8 (Join-Path $Path 'docs\feature.md')
    "package eval`n`nobject Slugifier {`n    @JvmStatic`n    fun slug(value: String?): String = TODO(`"Implement docs/feature.md`")`n}"|Set-Content -Encoding UTF8 (Join-Path $Path 'src\main\kotlin\eval\Slugifier.kt')
    "package eval`n`nimport kotlin.test.Test`nimport kotlin.test.assertEquals`n`nclass SlugifierTest {`n    @Test fun placeholder() = assertEquals(`"todo`", `"todo`")`n}"|Set-Content -Encoding UTF8 (Join-Path $Path 'src\test\kotlin\eval\SlugifierTest.kt')
    "plugins { kotlin(`"jvm`") version `"2.2.0`"; id(`"io.gitlab.arturbosch.detekt`") version `"1.23.8`" }`nrepositories { mavenCentral() }`ndependencies { testImplementation(kotlin(`"test`")) }`njava { sourceCompatibility = JavaVersion.VERSION_21; targetCompatibility = JavaVersion.VERSION_21 }`nkotlin { compilerOptions { allWarningsAsErrors.set(true); jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21) } }`ndetekt { buildUponDefaultConfig = true; allRules = false }`ntasks.withType<io.gitlab.arturbosch.detekt.Detekt>().configureEach { jvmTarget = `"21`" }`ntasks.test { useJUnitPlatform() }"|Set-Content -Encoding UTF8 (Join-Path $Path 'build.gradle.kts')
    'rootProject.name = "kotlin-feature-eval"'|Set-Content -Encoding UTF8 (Join-Path $Path 'settings.gradle.kts')
  }
  'rust-feature' {
    New-Item -ItemType Directory -Force -Path (Join-Path $Path 'src'),(Join-Path $Path 'tests'),(Join-Path $Path 'docs')|Out-Null
    "# Port parser`n`nImplement ``parse_port(&str) -> Result<u16, PortError>``. Trim whitespace, accept decimal digits only and ports 1..=65535. Distinguish Empty, Invalid and OutOfRange. Do not panic."|Set-Content -Encoding UTF8 (Join-Path $Path 'docs\feature.md')
    "#[derive(Debug, PartialEq, Eq)]`npub enum PortError { Empty, Invalid, OutOfRange }`n`npub fn parse_port(_value: &str) -> Result<u16, PortError> {`n    todo!()`n}"|Set-Content -Encoding UTF8 (Join-Path $Path 'src\lib.rs')
    "use rust_feature::{parse_port, PortError};`n`n#[test]`nfn placeholder() { assert_eq!(parse_port(`"`"), Err(PortError::Empty)); }"|Set-Content -Encoding UTF8 (Join-Path $Path 'tests\port_test.rs')
    "[package]`nname = `"rust-feature`"`nversion = `"0.1.0`"`nedition = `"2024`"`n`n[dependencies]"|Set-Content -Encoding UTF8 (Join-Path $Path 'Cargo.toml')
  }
  'frontend-feature' {
    New-Item -ItemType Directory -Force -Path (Join-Path $Path 'src'),(Join-Path $Path 'tests'),(Join-Path $Path 'docs')|Out-Null
    "# Accessible disclosure`n`nImplement HTML/CSS/JS disclosure. Button id toggle controls panel id details. Export initDisclosure(document). Initial panel hidden and aria-expanded=false; click toggles both. Use semantic button, visible focus, responsive layout at 600px, no dependencies."|Set-Content -Encoding UTF8 (Join-Path $Path 'docs\feature.md')
    '<main><div id="toggle">Details</div><div id="details">Content</div></main>'|Set-Content -Encoding UTF8 (Join-Path $Path 'src\index.html')
    '/* implement accessible responsive disclosure */'|Set-Content -Encoding UTF8 (Join-Path $Path 'src\styles.css')
    'export function initDisclosure(document) { throw new Error("TODO"); }'|Set-Content -Encoding UTF8 (Join-Path $Path 'src\disclosure.mjs')
    "import test from 'node:test';`nimport assert from 'node:assert/strict';`ntest('placeholder',()=>assert.equal(true,true));"|Set-Content -Encoding UTF8 (Join-Path $Path 'tests\disclosure.test.mjs')
    '{"scripts":{"test":"node --test","lint":"node --check src/disclosure.mjs"},"type":"module"}'|Set-Content -Encoding UTF8 (Join-Path $Path 'package.json')
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
  & git -C $Path config core.autocrlf false
  & git -C $Path add .; & git -C $Path commit -q -m baseline;if($LASTEXITCODE -ne 0){throw 'git commit failed'}
}finally{$ErrorActionPreference=$old}
Write-Host "[PASS] $Scenario fixture: $Path"
