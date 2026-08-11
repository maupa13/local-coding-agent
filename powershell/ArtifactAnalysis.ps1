<#
.SYNOPSIS
Deterministic structural analysis for specifications and interchange formats.
.DESCRIPTION
Parsers establish facts (nodes, references, requirements, diagnostics). The
LLM may explain those facts, but it is never asked to guess XML/JSON structure.
#>
function Invoke-AgentArtifactAnalysis {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $resolved=(Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $extension=[IO.Path]::GetExtension($resolved).ToLowerInvariant()
    if($extension -in @('.bpmn','.xsd','.xml')){
        try{[xml]$xml=Get-Content -LiteralPath $resolved -Raw}catch{return [pscustomobject]@{path=$resolved;kind='xml';valid=$false;diagnostics=@($_.Exception.Message)}}
        $rootName=$xml.DocumentElement.LocalName
        if($extension -eq '.bpmn' -or $rootName -eq 'definitions'){
            $nodes=@($xml.SelectNodes("//*[local-name()='process']/*[local-name()='startEvent' or local-name()='endEvent' or local-name()='task' or local-name()='userTask' or local-name()='serviceTask' or local-name()='scriptTask' or local-name()='exclusiveGateway' or local-name()='parallelGateway' or local-name()='inclusiveGateway']")|ForEach-Object{[pscustomobject]@{id=$_.GetAttribute('id');type=$_.LocalName;name=$_.GetAttribute('name')}})
            $flows=@($xml.SelectNodes("//*[local-name()='sequenceFlow']")|ForEach-Object{[pscustomobject]@{id=$_.GetAttribute('id');source=$_.GetAttribute('sourceRef');target=$_.GetAttribute('targetRef')}})
            $ids=@($nodes.id);$diagnostics=New-Object Collections.Generic.List[string]
            foreach($flow in $flows){if($flow.source -notin $ids){$diagnostics.Add("sequenceFlow $($flow.id) has missing source $($flow.source)")};if($flow.target -notin $ids){$diagnostics.Add("sequenceFlow $($flow.id) has missing target $($flow.target)")}}
            $starts=@($nodes|Where-Object type -eq 'startEvent');$reachable=New-Object 'Collections.Generic.HashSet[string]';$queue=New-Object Collections.Queue
            foreach($start in $starts){if($start.id){[void]$reachable.Add($start.id);$queue.Enqueue($start.id)}}
            while($queue.Count){$current=[string]$queue.Dequeue();foreach($edge in @($flows|Where-Object source -eq $current)){if($edge.target -and $reachable.Add($edge.target)){$queue.Enqueue($edge.target)}}}
            $unreachable=@($nodes|Where-Object{$_.id -and -not $reachable.Contains($_.id)}|ForEach-Object id)
            return [pscustomobject]@{path=$resolved;kind='bpmn';valid=($diagnostics.Count -eq 0);processCount=@($xml.SelectNodes("//*[local-name()='process']")).Count;nodes=$nodes;flows=$flows;unreachable=$unreachable;diagnostics=@($diagnostics)}
        }
        if($extension -eq '.xsd' -or $rootName -eq 'schema'){
            $imports=@($xml.SelectNodes("//*[local-name()='import' or local-name()='include']")|ForEach-Object{[pscustomobject]@{kind=$_.LocalName;namespace=$_.GetAttribute('namespace');schemaLocation=$_.GetAttribute('schemaLocation')}})
            $missing=@($imports|Where-Object{$_.schemaLocation -and -not(Test-Path -LiteralPath (Join-Path (Split-Path -Parent $resolved) $_.schemaLocation))}|ForEach-Object schemaLocation)
            return [pscustomobject]@{path=$resolved;kind='xsd';valid=($missing.Count -eq 0);targetNamespace=$xml.DocumentElement.GetAttribute('targetNamespace');elements=@($xml.SelectNodes("//*[local-name()='schema']/*[local-name()='element']")|ForEach-Object{$_.GetAttribute('name')});complexTypes=@($xml.SelectNodes("//*[local-name()='complexType']")|ForEach-Object{$_.GetAttribute('name')}|Where-Object{$_});simpleTypes=@($xml.SelectNodes("//*[local-name()='simpleType']")|ForEach-Object{$_.GetAttribute('name')}|Where-Object{$_});imports=$imports;diagnostics=@($missing|ForEach-Object{"missing schemaLocation: $_"})}
        }
        return [pscustomobject]@{path=$resolved;kind='xml';valid=$true;root=$rootName;diagnostics=@()}
    }
    if($extension -eq '.json'){
        try{$document=Get-Content -LiteralPath $resolved -Raw|ConvertFrom-Json}catch{return [pscustomobject]@{path=$resolved;kind='json';valid=$false;diagnostics=@($_.Exception.Message)}}
        $refs=New-Object Collections.Generic.List[string]
        function Visit-JsonNode($node){if($null -eq $node -or $node -is [string] -or $node.GetType().IsPrimitive -or $node -is [decimal]){return};if($node -is [Collections.IEnumerable]){foreach($item in $node){Visit-JsonNode $item};return};foreach($property in @($node.PSObject.Properties)){if($property.Name -eq '$ref'){$refs.Add([string]$property.Value)};Visit-JsonNode $property.Value}}
        Visit-JsonNode $document
        $external=@($refs|Where-Object{$_ -notmatch '^#'});$missing=@($external|Where-Object{-not(Test-Path -LiteralPath (Join-Path (Split-Path -Parent $resolved) ($_ -split '#')[0]))})
        return [pscustomobject]@{path=$resolved;kind=if($document.PSObject.Properties['openapi']){'openapi'}elseif($document.PSObject.Properties['$schema']){'json-schema'}else{'json'};valid=($missing.Count -eq 0);references=@($refs);diagnostics=@($missing|ForEach-Object{"missing external reference: $_"})}
    }
    if($extension -in @('.md','.txt')){
        $lines=@(Get-Content -LiteralPath $resolved);$requirements=for($i=0;$i -lt $lines.Count;$i++){if($lines[$i] -match '(?i)^\s*(REQ[-_ ]?[A-Z0-9.-]+)\s*[:\-]\s*(.+)$'){[pscustomobject]@{id=$Matches[1];text=$Matches[2].Trim();line=$i+1}}}
        return [pscustomobject]@{path=$resolved;kind='specification';valid=$true;requirements=@($requirements);diagnostics=@()}
    }
    throw "Unsupported artifact type: $extension"
}
