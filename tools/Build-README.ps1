#Requires -Version 5.1

<#
.SYNOPSIS
    Actualiza las secciones dinamicas del README de SCR1PT.

.DESCRIPTION
    Lee catalog.json y reemplaza exclusivamente los bloques delimitados por
    marcadores SCR1PT:DYNAMIC. El resto del README permanece manual y editable.

    Bloques gestionados:
      - BADGES
      - CATALOG
      - STRUCTURE
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$catalogPath = Join-Path $RepositoryRoot 'catalog.json'
$readmePath = Join-Path $RepositoryRoot 'README.md'

if (-not (Test-Path -LiteralPath $catalogPath)) {
    throw ('No existe catalog.json: {0}' -f $catalogPath)
}

if (-not (Test-Path -LiteralPath $readmePath)) {
    throw ('No existe README.md: {0}' -f $readmePath)
}

function Set-DynamicBlock {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Lines
    )

    $startMarker = '<!-- SCR1PT:DYNAMIC:{0}:START -->' -f $Name
    $endMarker = '<!-- SCR1PT:DYNAMIC:{0}:END -->' -f $Name

    $startIndex = $Text.IndexOf($startMarker, [StringComparison]::Ordinal)

    if ($startIndex -lt 0) {
        throw ('No se encuentra el marcador inicial {0}.' -f $startMarker)
    }

    $endIndex = $Text.IndexOf(
        $endMarker,
        $startIndex + $startMarker.Length,
        [StringComparison]::Ordinal
    )

    if ($endIndex -lt 0) {
        throw ('No se encuentra el marcador final {0}.' -f $endMarker)
    }

    $prefix = $Text.Substring(0, $startIndex)
    $suffix = $Text.Substring($endIndex + $endMarker.Length)
    $body = $Lines -join [Environment]::NewLine

    $replacement = $startMarker + [Environment]::NewLine

    if (-not [string]::IsNullOrWhiteSpace($body)) {
        $replacement += $body + [Environment]::NewLine
    }

    $replacement += $endMarker

    return $prefix + $replacement + $suffix
}

function Escape-MarkdownCell {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) {
        return ''
    }

    return (
        ([string]$Value) `
            -replace '\|', '\|' `
            -replace "`r?`n", ' '
    ).Trim()
}

function Convert-RawToGitHubUrl {
    param([Parameter(Mandatory)][string]$Url)

    try {
        $uri = [Uri]$Url

        if ($uri.Host -ine 'raw.githubusercontent.com') {
            return $Url
        }

        $segments = @(
            $uri.AbsolutePath.Trim('/') -split '/' |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )

        if ($segments.Count -lt 4) {
            return $Url
        }

        $owner = $segments[0]
        $repo = $segments[1]
        $branch = $segments[2]
        $path = ($segments[3..($segments.Count - 1)] -join '/')

        return 'https://github.com/{0}/{1}/blob/{2}/{3}' -f `
            $owner,
            $repo,
            $branch,
            $path
    }
    catch {
        return $Url
    }
}

$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
$readme = Get-Content -LiteralPath $readmePath -Raw

if ($null -eq $catalog -or [int]$catalog.schemaVersion -ne 1) {
    throw 'catalog.json no tiene un esquema compatible.'
}

$scripts = @($catalog.scripts)
$categories = @($catalog.categories)

if ($scripts.Count -eq 0) {
    throw 'catalog.json no contiene scripts.'
}

$launcherVersion = ''
$launcherPowerShell = '5.1'

if ($null -ne $catalog.PSObject.Properties['launcher']) {
    if ($null -ne $catalog.launcher.PSObject.Properties['version']) {
        $launcherVersion = [string]$catalog.launcher.version
    }

    if ($null -ne $catalog.launcher.PSObject.Properties['minPowerShell']) {
        $launcherPowerShell = [string]$catalog.launcher.minPowerShell
    }
}

if ([string]::IsNullOrWhiteSpace($launcherVersion)) {
    $launcherVersion = 'actual'
}

if ([string]::IsNullOrWhiteSpace($launcherPowerShell)) {
    $launcherPowerShell = '5.1'
}

$badgeVersion = [Uri]::EscapeDataString($launcherVersion)
$badgePowerShell = [Uri]::EscapeDataString($launcherPowerShell + '+')

$badgeLines = @(
    '![Version](https://img.shields.io/badge/version-{0}-00FF00?style=for-the-badge&labelColor=111111)' -f $badgeVersion,
    '![PowerShell](https://img.shields.io/badge/PowerShell-{0}-5391FE?style=for-the-badge&logo=powershell&logoColor=white)' -f $badgePowerShell,
    '![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=for-the-badge&logo=windows11&logoColor=white)',
    '![Scripts](https://img.shields.io/badge/catalogo-{0}-00FF00?style=for-the-badge&labelColor=111111)' -f $scripts.Count
)

$categoryMap = @{}

foreach ($category in $categories) {
    $categoryMap[[string]$category.id] = [string]$category.name
}

$tableLines = New-Object 'System.Collections.Generic.List[string]'
$tableLines.Add('| ID | Script | Version | Categoria | Administrador | PowerShell | Finalidad |')
$tableLines.Add('| --- | --- | ---: | --- | :---: | :---: | --- |')

foreach ($script in $scripts) {
    $id = Escape-MarkdownCell $script.id
    $name = Escape-MarkdownCell $script.name
    $version = '—'
    $category = [string]$script.category
    $categoryName = if ($categoryMap.ContainsKey($category)) {
        $categoryMap[$category]
    }
    else {
        $category
    }

    if ($null -ne $script.PSObject.Properties['version'] -and
        -not [string]::IsNullOrWhiteSpace([string]$script.version)) {
        $version = Escape-MarkdownCell $script.version
    }

    $requiresAdmin = $false

    if ($null -ne $script.PSObject.Properties['requiresAdmin']) {
        $requiresAdmin = [bool]$script.requiresAdmin
    }

    $minimumPowerShell = '5.1'

    if ($null -ne $script.PSObject.Properties['minPowerShell'] -and
        -not [string]::IsNullOrWhiteSpace([string]$script.minPowerShell)) {
        $minimumPowerShell = [string]$script.minPowerShell
    }

    $githubUrl = Convert-RawToGitHubUrl -Url ([string]$script.url)
    $linkedName = '[{0}]({1})' -f $name, $githubUrl
    $description = Escape-MarkdownCell $script.description

    $tableLines.Add(
        '| `{0}` | {1} | {2} | {3} | {4} | {5}+ | {6} |' -f
        $id,
        $linkedName,
        $version,
        (Escape-MarkdownCell $categoryName),
        $(if ($requiresAdmin) { 'Si' } else { 'No' }),
        (Escape-MarkdownCell $minimumPowerShell),
        $description
    )
}

$localScripts = @(
    $scripts |
        Where-Object { [string]$_.source -ieq 'SCR1PT' } |
        Sort-Object -Property fileName
)

$structureLines = New-Object 'System.Collections.Generic.List[string]'
$structureLines.Add('```text')
$structureLines.Add('SCR1PT/')
$structureLines.Add('|-- SCR1PT.ps1')
$structureLines.Add('|-- catalog.json')
$structureLines.Add('|-- SCR1PT/')

for ($i = 0; $i -lt $localScripts.Count; $i++) {
    $prefix = if ($i -eq ($localScripts.Count - 1)) { '    `-- ' } else { '    |-- ' }
    $structureLines.Add($prefix + [string]$localScripts[$i].fileName)
}

$structureLines.Add('|-- tools/')
$structureLines.Add('|   |-- Build-Catalog.ps1')
$structureLines.Add('|   `-- Build-README.ps1')
$structureLines.Add('|-- .github/workflows/build-catalog.yml')
$structureLines.Add('`-- README.md')
$structureLines.Add('```')

$readme = Set-DynamicBlock -Text $readme -Name 'BADGES' -Lines $badgeLines
$readme = Set-DynamicBlock -Text $readme -Name 'CATALOG' -Lines $tableLines.ToArray()
$readme = Set-DynamicBlock -Text $readme -Name 'STRUCTURE' -Lines $structureLines.ToArray()

$utf8NoBom = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($readmePath, ($readme.TrimEnd() + [Environment]::NewLine), $utf8NoBom)

Write-Host ('README actualizado: {0}' -f $readmePath) -ForegroundColor Green
Write-Host ('Scripts documentados: {0}' -f $scripts.Count)
