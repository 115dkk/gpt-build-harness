<#
  gpt-build-harness 1.0.0: install into Claude Code (global ~/.claude).
  Needs ClaudeRipple installed and routing first: https://github.com/PBJ-2/clauderipple
  Run from the unzipped release package:
    powershell -ExecutionPolicy Bypass -File install\install-claude-code.ps1
  Existing files are moved aside before being replaced:
    skill folder -> ~/.claude/skill-backups/<stamp>/gpt-build-harness
    agent and rule files -> <name>.bak-<stamp> next to the original
#>
$ErrorActionPreference = 'Stop'
$root   = Split-Path -Parent $MyInvocation.MyCommand.Path   # .../gpt-build-harness/install
$pkg    = Split-Path -Parent $root                          # .../gpt-build-harness
$claude = Join-Path $env:USERPROFILE '.claude'
$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'

function Set-AsideFile([string]$path) {
  if (Test-Path -LiteralPath $path) {
    Move-Item -LiteralPath $path -Destination "$path.bak-$stamp" -Force
    Write-Host "  kept the old file as $(Split-Path -Leaf $path).bak-$stamp"
  }
}

# Skill docs (English only; *_ko.md and references/legacy stay in the repository)
$skillDst = Join-Path $claude 'skills\gpt-build-harness'
if (Test-Path -LiteralPath $skillDst) {
  $backup = Join-Path $claude "skill-backups\$stamp"
  New-Item -ItemType Directory -Force -Path $backup | Out-Null
  Move-Item -LiteralPath $skillDst -Destination $backup -Force
  Write-Host "  kept the old skill in skill-backups\$stamp\gpt-build-harness"
}
New-Item -ItemType Directory -Force -Path (Join-Path $skillDst 'references') | Out-Null
Copy-Item (Join-Path $pkg 'SKILL.md') $skillDst -Force
foreach ($f in 'routing.md', 'pitfalls.md') {
  Copy-Item (Join-Path $pkg "references\$f") (Join-Path $skillDst 'references') -Force
}

# Worker subagents
$agentsDst = Join-Path $claude 'agents'
New-Item -ItemType Directory -Force -Path $agentsDst | Out-Null
foreach ($f in 'gpt-worker.md', 'astra-worker.md') {
  Set-AsideFile (Join-Path $agentsDst $f)
  Copy-Item (Join-Path $pkg "agents\$f") $agentsDst -Force
}

# Delegation policy, loaded in every session
$rulesDst = Join-Path $claude 'rules'
New-Item -ItemType Directory -Force -Path $rulesDst | Out-Null
Set-AsideFile (Join-Path $rulesDst 'gpt-workers.md')
Copy-Item (Join-Path $pkg 'rules\gpt-workers.md') $rulesDst -Force

Write-Host "[gpt-build-harness] installed:"
Write-Host "  - skills\gpt-build-harness (SKILL.md, references\routing.md, references\pitfalls.md)"
Write-Host "  - agents\gpt-worker.md, agents\astra-worker.md"
Write-Host "  - rules\gpt-workers.md"
Write-Host ""
Write-Host "Merge this into ~/.claude/settings.json. List every @effort form you use:"
Write-Host "a form missing from availableModels is silently replaced by a Claude model."
Write-Host @'
  "availableModels": [
    "opus", "sonnet", "haiku",
    "gpt-daybreak-blue", "gpt-daybreak-blue@high", "gpt-daybreak-blue@max",
    "gpt-6-astra", "gpt-6-astra@high", "gpt-6-astra@xhigh", "gpt-6-astra@max"
  ],
  "modelPicker": {
    "options": [
      { "model": "gpt-daybreak-blue@high", "label": "Daybreak Blue - high", "behavesAs": "claude-opus-5" },
      { "model": "gpt-6-astra@high", "label": "ASTRA - high", "behavesAs": "claude-opus-5" }
    ]
  }
'@
Write-Host "Then start a NEW Claude Code session: agent definitions are read once per session."
