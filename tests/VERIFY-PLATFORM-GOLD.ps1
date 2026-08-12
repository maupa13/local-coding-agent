[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'powershell\ArtifactAnalysis.ps1')
$tmp=Join-Path ([IO.Path]::GetTempPath()) ('lca-platform-gold-'+[guid]::NewGuid().ToString('N'))
try{
  New-Item -ItemType Directory -Force $tmp|Out-Null
  'platform-gold'|Set-Content -Encoding ASCII (Join-Path $tmp 'payload.txt')
  "FROM scratch`nLABEL org.opencontainers.image.title=`"platform-gold`"`nCOPY payload.txt /payload.txt`n"|Set-Content -Encoding ASCII (Join-Path $tmp 'Dockerfile')
  @'
services:
  app:
    build: .
    restart: unless-stopped
    read_only: true
    security_opt:
      - no-new-privileges:true
'@|Set-Content -Encoding UTF8 (Join-Path $tmp 'compose.yaml')
  Push-Location $tmp
  try{
    & docker compose config -q;if($LASTEXITCODE -ne 0){throw '[FAIL] Compose semantic validation'}
    & docker build --quiet --tag lca-platform-gold:local .|Out-Null;if($LASTEXITCODE -ne 0){throw '[FAIL] Dockerfile build'}
  }finally{Pop-Location}

  @'
function ConvertTo-SafeName {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Value)
  $normalized=($Value.Trim() -replace '[^A-Za-z0-9]+','-').Trim('-').ToLowerInvariant()
  if(-not $normalized){throw 'Value has no alphanumeric characters'}
  return $normalized
}
'@|Set-Content -Encoding UTF8 (Join-Path $tmp 'Tools.ps1')
  $tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $tmp 'Tools.ps1'),[ref]$tokens,[ref]$errors)
  if($errors){throw '[FAIL] PowerShell parser'}
  . (Join-Path $tmp 'Tools.ps1')
  if((ConvertTo-SafeName ' Hello, WORLD ') -ne 'hello-world'){throw '[FAIL] PowerShell behavior'}
  try{ConvertTo-SafeName '---'|Out-Null;throw '[FAIL] PowerShell invalid-input contract'}catch{if($_.Exception.Message -eq '[FAIL] PowerShell invalid-input contract'){throw}}

  '{"$schema":"https://json-schema.org/draft/2020-12/schema","type":"object","required":["id"],"properties":{"id":{"type":"string"}}}'|Set-Content -Encoding UTF8 (Join-Path $tmp 'schema.json')
  '<?xml version="1.0"?><xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:gold"><xs:element name="Order" type="xs:string"/></xs:schema>'|Set-Content -Encoding UTF8 (Join-Path $tmp 'model.xsd')
  '<?xml version="1.0"?><definitions xmlns="http://www.omg.org/spec/BPMN/20100524/MODEL"><process id="p"><startEvent id="start"/><serviceTask id="work"/><endEvent id="end"/><sequenceFlow id="f1" sourceRef="start" targetRef="work"/><sequenceFlow id="f2" sourceRef="work" targetRef="end"/></process></definitions>'|Set-Content -Encoding UTF8 (Join-Path $tmp 'process.bpmn')
  $json=Invoke-AgentArtifactAnalysis (Join-Path $tmp 'schema.json');if(-not $json.valid -or $json.kind -ne 'json-schema'){throw '[FAIL] JSON Schema gold'}
  $xml=Invoke-AgentArtifactAnalysis (Join-Path $tmp 'model.xsd');if(-not $xml.valid -or $xml.elements -notcontains 'Order'){throw '[FAIL] XML/XSD gold'}
  $bpmn=Invoke-AgentArtifactAnalysis (Join-Path $tmp 'process.bpmn');if(-not $bpmn.valid -or $bpmn.unreachable.Count -or $bpmn.nodes.Count -ne 3){throw '[FAIL] BPMN topology gold'}

  @'
pipeline {
  agent any
  options { timeout(time: 20, unit: 'MINUTES'); disableConcurrentBuilds() }
  stages {
    stage('Test') { steps { bat 'powershell.exe -NoProfile -File tests\\RUN-ALL.ps1 -Profile Quick' } }
    stage('Package') { steps { bat 'powershell.exe -NoProfile -File powershell\\VERIFY-PACKAGE.ps1' } }
  }
  post { always { archiveArtifacts artifacts: 'test-results/**', allowEmptyArchive: true } }
}
'@|Set-Content -Encoding UTF8 (Join-Path $tmp 'Jenkinsfile')
  $jenkins=Get-Content (Join-Path $tmp 'Jenkinsfile') -Raw
  foreach($required in @('pipeline {','stage(''Test'')','stage(''Package'')','timeout(','disableConcurrentBuilds','post { always','archiveArtifacts')){if(-not $jenkins.Contains($required)){throw "[FAIL] Jenkins policy: $required"}}
  $opens=([regex]::Matches($jenkins,'\{')).Count;$closes=([regex]::Matches($jenkins,'\}')).Count;if($opens -ne $closes){throw '[FAIL] Jenkins brace structure'}

  "REQ-SYS-01: Docker image builds.`nREQ-SYS-02: Compose is hardened.`nREQ-SYS-03: CI tests before packaging."|Set-Content -Encoding UTF8 (Join-Path $tmp 'requirements.md')
  $spec=Invoke-AgentArtifactAnalysis (Join-Path $tmp 'requirements.md');if($spec.requirements.Count -ne 3){throw '[FAIL] system-analysis requirements extraction'}
  $matrix=@{'REQ-SYS-01'='Dockerfile';'REQ-SYS-02'='compose.yaml';'REQ-SYS-03'='Jenkinsfile'}
  foreach($req in $spec.requirements){if(-not $matrix.ContainsKey($req.id) -or -not(Test-Path (Join-Path $tmp $matrix[$req.id]))){throw "[FAIL] system-analysis traceability: $($req.id)"}}
}finally{
  & docker image rm lca-platform-gold:local --force 2>$null|Out-Null
  Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host '[PASS] Docker, Compose, PowerShell, JSON, XML, BPMN, Jenkins and system-analysis gold gates' -ForegroundColor Green
