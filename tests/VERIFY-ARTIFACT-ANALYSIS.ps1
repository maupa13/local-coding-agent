[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'powershell\ArtifactAnalysis.ps1')
$tmp=Join-Path ([IO.Path]::GetTempPath()) ('lca-artifacts-'+[guid]::NewGuid().ToString('N'))
try{
  New-Item -ItemType Directory -Force -Path $tmp|Out-Null
  @'
<?xml version="1.0"?><definitions xmlns="http://www.omg.org/spec/BPMN/20100524/MODEL"><process id="p"><startEvent id="start"/><userTask id="work"/><endEvent id="end"/><serviceTask id="orphan"/><sequenceFlow id="f1" sourceRef="start" targetRef="work"/><sequenceFlow id="f2" sourceRef="work" targetRef="end"/></process></definitions>
'@|Set-Content -Encoding UTF8 (Join-Path $tmp 'flow.bpmn')
  @'
<?xml version="1.0"?><xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:test"><xs:include schemaLocation="missing.xsd"/><xs:element name="Order" type="xs:string"/><xs:complexType name="Item"/></xs:schema>
'@|Set-Content -Encoding UTF8 (Join-Path $tmp 'model.xsd')
  '{"$schema":"https://json-schema.org/draft/2020-12/schema","properties":{"child":{"$ref":"missing.json#/defs/child"}}}'|Set-Content -Encoding UTF8 (Join-Path $tmp 'schema.json')
  "# Spec`n`nREQ-01: Parse structured artifacts.`nREQ-02 - Preserve line evidence."|Set-Content -Encoding UTF8 (Join-Path $tmp 'spec.md')

  $bpmn=Invoke-AgentArtifactAnalysis (Join-Path $tmp 'flow.bpmn')
  if($bpmn.kind -ne 'bpmn' -or $bpmn.nodes.Count -ne 4 -or $bpmn.unreachable -notcontains 'orphan'){throw 'BPMN topology analysis failed'}
  $xsd=Invoke-AgentArtifactAnalysis (Join-Path $tmp 'model.xsd')
  if($xsd.valid -or $xsd.elements -notcontains 'Order' -or $xsd.complexTypes -notcontains 'Item'){throw 'XSD structure/reference analysis failed'}
  $json=Invoke-AgentArtifactAnalysis (Join-Path $tmp 'schema.json')
  if($json.valid -or $json.kind -ne 'json-schema' -or $json.references.Count -ne 1){throw 'JSON Schema reference analysis failed'}
  $spec=Invoke-AgentArtifactAnalysis (Join-Path $tmp 'spec.md')
  if($spec.requirements.Count -ne 2 -or $spec.requirements[0].line -ne 3){throw 'specification requirement extraction failed'}
}finally{Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue}
Write-Host '[PASS] BPMN, XSD, JSON Schema, and specification structural analysis' -ForegroundColor Green
