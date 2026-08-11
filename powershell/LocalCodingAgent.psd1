@{
    RootModule = 'LocalCodingAgent.psm1'
    ModuleVersion = '1.0.0'
    GUID = '0fbcdd4b-1c4d-4c58-9858-1137d5d1fca9'
    Author = 'Local Coding Agent contributors'
    CompanyName = 'Community'
    Copyright = '(c) Local Coding Agent contributors. All rights reserved.'
    Description = 'Local-first Windows coding agent runtime with managed tools, workflows, evidence, and quality gates.'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop','Core')
    FunctionsToExport = @(
        'Invoke-ContinueAgent','Invoke-AgentWorkflow','Invoke-AgentArtifactAnalysis','Test-LocalCodingAgentComplianceExtractor','Test-LocalCodingAgentComplianceResult',
        'Start-LocalCodingAgent','Install-AgentIdeaIntegration','Install-AgentIdeaIntegrations','Find-AgentIdeaProjects','Show-AgentIdeaIntegration','Remove-AgentIdeaIntegration',
        'agent-idea','agent-idea-all','agent','agent-fast','agent-tui','agent-ask','agent-team','agent-plan','agent-auto','agent-resume',
        'agent-analyze','agent-feature','agent-bugfix','agent-hotfix','agent-refactor','agent-test','agent-review','agent-result',
        'agent-release','agent-release-feature','agent-release-bugfix','agent-release-hotfix','agent-docs','agent-business','agent-architecture','agent-migration','agent-performance','agent-security',
        'agent-deliver-feature','agent-deliver-bugfix','agent-deliver-hotfix','agent-init','agent-help','agent-doctor','agent-workflows'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('AI','CodingAgent','Ollama','Windows')
            ProjectUri = 'https://github.com/'
            ReleaseNotes = 'See docs/CHANGELOG.md.'
        }
    }
}
