[CmdletBinding()]
param([string]$Destination = 'C:\AI\continue-agent-acceptance',[switch]$Force)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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


if (Test-Path $Destination) { if(-not $Force){throw "Destination already exists: $Destination"}; Remove-Item -LiteralPath $Destination -Recurse -Force }
New-Item -ItemType Directory -Path "$Destination\src\main\java\demo" -Force | Out-Null
New-Item -ItemType Directory -Path "$Destination\src\test\java\demo" -Force | Out-Null
New-Item -ItemType Directory -Path "$Destination\.continue\rules" -Force | Out-Null
New-Item -ItemType Directory -Path "$Destination\docs\features" -Force | Out-Null

@'
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>demo</groupId>
  <artifactId>continue-agent-acceptance</artifactId>
  <version>1.0.0-SNAPSHOT</version>
  <properties>
    <maven.compiler.release>21</maven.compiler.release>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <junit.version>5.11.4</junit.version>
  </properties>
  <dependencies>
    <dependency>
      <groupId>org.junit.jupiter</groupId>
      <artifactId>junit-jupiter</artifactId>
      <version>${junit.version}</version>
      <scope>test</scope>
    </dependency>
  </dependencies>
  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-surefire-plugin</artifactId>
        <version>3.5.2</version>
        <configuration><useModulePath>false</useModulePath></configuration>
      </plugin>
    </plugins>
  </build>
</project>
'@ | Set-Content -Encoding UTF8 "$Destination\pom.xml"

@'
package demo;

public final class PriceCalculator {
    public long discountedPrice(long priceCents, int discountPercent) {
        if (priceCents < 0) {
            throw new IllegalArgumentException("priceCents");
        }
        if (discountPercent < 0 || discountPercent > 100) {
            throw new IllegalArgumentException("discountPercent");
        }
        // Intentional bug: integer division occurs before multiplication.
        return priceCents * (1 - discountPercent / 100);
    }
}
'@ | Set-Content -Encoding UTF8 "$Destination\src\main\java\demo\PriceCalculator.java"

@'
package demo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;

class PriceCalculatorTest {
    private final PriceCalculator calculator = new PriceCalculator();

    @Test
    void appliesPercentageDiscountInExactCents() {
        assertEquals(8_500, calculator.discountedPrice(10_000, 15));
        assertEquals(6_699, calculator.discountedPrice(9_999, 33));
    }

    @Test
    void validatesInputs() {
        assertThrows(IllegalArgumentException.class, () -> calculator.discountedPrice(-1, 10));
        assertThrows(IllegalArgumentException.class, () -> calculator.discountedPrice(100, -1));
        assertThrows(IllegalArgumentException.class, () -> calculator.discountedPrice(100, 101));
    }
}
'@ | Set-Content -Encoding UTF8 "$Destination\src\test\java\demo\PriceCalculatorTest.java"

@'
---
name: Acceptance Project
---

- Java 21 + Maven.
- Build/test command: `mvn test`.
- Keep public APIs unchanged unless the acceptance task explicitly requests a new API.
- Do not add dependencies for the bugfix/refactor tasks.
- Monetary calculations use integer cents; no floating point.
- Keep changes scoped; do not rewrite the project.
'@ | Set-Content -Encoding UTF8 "$Destination\.continue\rules\00-project.md"

@'
# Shipping-aware final price feature

Implement `PriceCalculator.finalPrice(long priceCents, int discountPercent, long shippingCents)`.

Acceptance criteria:
- reuse the existing discount semantics;
- reject negative `shippingCents` with `IllegalArgumentException`;
- add shipping after discount;
- preserve integer-cent arithmetic;
- do not change `discountedPrice` public behavior;
- add deterministic JUnit 5 coverage;
- `mvn test` must pass.
'@ | Set-Content -Encoding UTF8 "$Destination\docs\features\shipping-final-price.md"

@'
# Local Coding Agent acceptance tasks

## A1 — Bugfix

```powershell
agent-bugfix "PriceCalculator returns the wrong result for percentage discounts. Find the root cause, fix it without changing the public method signature, preserve exact integer-cent semantics, run tests and report evidence."
```

Expected:
- locates the real file;
- explains integer-division ordering;
- makes a narrow fix;
- keeps validation;
- `mvn test` passes;
- does not invent another PriceCalculator path.

## A2 — Feature

After A1 is committed, run:

```powershell
agent-feature "Add a new public method finalPrice(long priceCents, int discountPercent, long shippingCents). Reuse existing discount validation, reject negative shipping, preserve integer cents, add tests, and do not modify discountedPrice behavior."
```

Expected:
- derives acceptance criteria;
- reuses existing behavior rather than duplicating validation carelessly;
- adds tests for shipping/validation;
- runs Maven tests;
- scopes the diff.

## A3 — Refactor

```powershell
agent-refactor "Refactor PriceCalculator validation to reduce duplication while preserving every public behavior and exception condition. Verify with tests."
```

Expected: no public behavior change; tests remain green; no unrelated cleanup.

## A4 — Review

Introduce or keep a change, then:

```powershell
agent-review "Review the current diff as production Java code."
```

Expected final marker: `REVIEW: PASS`, `PASS WITH WARNINGS`, or `FAIL` with evidence and concrete findings only.

## A5 — Release class gates

```powershell
agent-release-feature "Assess this as a feature release candidate."
agent-release-bugfix "Assess this as a bugfix release candidate."
agent-release-hotfix "Assess this as an emergency hotfix candidate."
```

The three commands must apply materially different gates. In particular, hotfix must demand minimal patch scope, explicit accepted risk, deploy/rollback triggers and post-deploy monitoring.


## A6 — Agentic feature delivery from repository documentation

After A1 is fixed/committed:

```text
/deliver-feature
GOAL: Implement shipping-aware final price.
SOURCE: @docs/features/shipping-final-price.md
Definition of done: implementation, tests, verification and review-ready final report.
```

Expected:
- reads the referenced repository document;
- discovers real code/tests without being told file paths;
- derives acceptance from the document;
- implements, tests and verifies rather than stopping after plan;
- final answer contains `FINAL RESULT:` and `DELIVERY:` markers.

## A7 — Result recovery

If a workflow appears to finish tool calls without a useful synthesis, run:

```text
/result
```

Expected: read-only report grounded in current Git status/diff with `FINAL RESULT:` and changed files; no invented test PASS.

'@ | Set-Content -Encoding UTF8 "$Destination\ACCEPTANCE.md"

Invoke-FixtureGitBestEffort -RepositoryRoot $Destination -CommitBaseline

Write-Host "Created acceptance repository: $Destination" -ForegroundColor Green
Write-Host "cd $Destination"
Write-Host 'mvn test   # should FAIL before the bugfix'
Write-Host 'agent-bugfix "PriceCalculator returns the wrong result for percentage discounts. Find the root cause and fix it."'
