# Обновляет NFO-шапку README.md (ASCII-блок ```text между <!-- ZARYA-HEADER:BEGIN --> и <!-- ZARYA-HEADER:END -->):
# версия сборки, Minecraft, NeoForge, Java, число модов / ресурспаков / треков и длительность музыки, скрипты, дата.
# Источники: instance.cfg и mmc-pack.json (Get-PackInfo), мета лаунчера (Java), minecraft\mods, minecraft\resourcepacks, Music Triggers (Get-MusicData).
# Меняются только строки-поля внутри рамки; ширина рамки и выравнивание сохраняются. Повторный запуск без изменений данных ничего не меняет.
# Кодировка (BOM или без) и переводы строк (CRLF/LF) файла сохраняются. В конце — Update site.ps1 (если не -NoSite).
param([switch]$NoSite)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')
$root = Split-Path -Parent $PSScriptRoot
$readmePath = Join-Path $root 'README.md'
if (-not (Test-Path -LiteralPath $readmePath)) { Write-Error "Нет файла: $readmePath"; exit 1 }
$BEGIN = '<!-- ZARYA-HEADER:BEGIN -->'; $END = '<!-- ZARYA-HEADER:END -->'

# --- данные ---
$pi = Get-PackInfo $root
$packName = ($pi.name -replace '\s*\(\d+(\.\d+)+\)', '' -replace '\s*\br\d+\.\d+\.\d+\b', '').Trim(); if (-not $packName) { $packName = 'Z@RYA Deep Dark Fantasies' }
# Java: compatibleJavaMajors из меты Minecraft в лаунчере (<лаунчер>\meta\net.minecraft\<версия>.json); нет меты — по версии Minecraft
$java = ''
$metaMc = Join-Path (Split-Path -Parent (Split-Path -Parent $root)) "meta\net.minecraft\$($pi.mc).json"
if (Test-Path -LiteralPath $metaMc) { try { $j = @((Get-Content -LiteralPath $metaMc -Raw -Encoding UTF8 | ConvertFrom-Json).compatibleJavaMajors); if ($j.Count) { $java = [string]($j | Measure-Object -Maximum).Maximum } } catch { } }
if (-not $java) { $java = if ([version]$pi.mc -ge [version]'1.20.5') { '21' } elseif ([version]$pi.mc -ge [version]'1.18') { '17' } else { '8' } }
$modsDir = Join-Path $root 'minecraft\mods'
$jars = @(if (Test-Path -LiteralPath $modsDir) { Get-ChildItem -LiteralPath $modsDir -File -Filter *.jar })
$rpDir = Join-Path $root 'minecraft\resourcepacks'
$rpCount = @(if (Test-Path -LiteralPath $rpDir) { Get-ChildItem -LiteralPath $rpDir | Where-Object { $_.PSIsContainer -or $_.Extension -eq '.zip' } }).Count
$music = Get-MusicData $root
$tracks = @($music.tracks); $sec = 0.0; foreach ($t in $tracks) { if ($null -ne $t.dur -and "$($t.dur)" -ne '') { $sec += [double]$t.dur } }
$s = [int][Math]::Round($sec); $durTxt = '{0}h {1:00}m' -f [Math]::Floor($s / 3600), [Math]::Floor(($s % 3600) / 60)
$scripts = @(@('kubejs', 'KubeJS'), @('lootjs', 'LootJS'), @('morejs', 'MoreJS') | Where-Object { $p = $_[0]; @($jars | Where-Object { $_.Name -match "^(?i)$p[-_ ]" }).Count } | ForEach-Object { $_[1] }) -join ' + '
if (-not $scripts) { $scripts = '-' }
$fields = [ordered]@{
  'PACK'      = $packName
  'VERSION'   = $(if ($pi.version) { $pi.version } else { '-' })
  'MINECRAFT' = $pi.mc
  'LOADER'    = $(if ($pi.neo) { "NeoForge $($pi.neo)" } else { '-' })
  'JAVA'      = $java
  'MODS'      = "$($jars.Count)"
  'RESOURCES' = "$rpCount resource packs"
  'MUSIC'     = "$($tracks.Count) tracks, $durTxt"
  'SCRIPTS'   = $scripts
  'DATE'      = (Get-Date -Format 'yyyy-MM')
}

# --- README ---
$bytes = [IO.File]::ReadAllBytes($readmePath)
$bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
$enc = New-Object Text.UTF8Encoding($bom)
$orig = [IO.File]::ReadAllText($readmePath, $enc)
$nl = if ($orig.Contains("`r`n")) { "`r`n" } else { "`n" }
$txt = $orig -replace "`r`n", "`n"
if (-not $txt.Contains($BEGIN)) {
  $m = [regex]::Match($txt, '(?s)```text\n.*?\n```')
  if (-not $m.Success) { Write-Error 'В README.md нет блока ```text с шапкой'; exit 1 }
  $txt = $txt.Substring(0, $m.Index) + "$BEGIN`n" + $m.Value + "`n$END" + $txt.Substring($m.Index + $m.Length)
}
$bi = $txt.IndexOf($BEGIN); $ei = $txt.IndexOf($END, $bi)
if ($ei -lt 0) { Write-Error "Нет маркера $END"; exit 1 }
$block = $txt.Substring($bi, $ei - $bi)
$lines = [Collections.Generic.List[string]]($block -split "`n")
# Строки-поля рамки: <отступ>+<ключ справа> : <значение>+ ; строки-разделители: <отступ>+--- - - ... +
$rowRe = '^(\s*\+)(\s*)([A-Z][A-Z .]*?) : (.*?)\+$'
$idx = @(for ($k = 0; $k -lt $lines.Count; $k++) { if ($lines[$k] -match $rowRe) { $k } })
if (-not $idx.Count) { Write-Error 'В шапке нет строк вида «KEY : value»'; exit 1 }
$first = $lines[$idx[0]]; [void]($first -match $rowRe)
$lead = $Matches[1]; $keyW = $Matches[2].Length + $Matches[3].Length; $valW = $Matches[4].Length
$sep = $null; for ($k = $idx[0] + 1; $k -lt $idx[-1]; $k++) { if ($lines[$k] -notmatch $rowRe -and $lines[$k].StartsWith($lead)) { $sep = $lines[$k]; break } }
if (-not $sep) { $sep = $lead + '-' * ($keyW + 3 + $valW) + '+' }
$rows = New-Object System.Collections.Generic.List[string]
foreach ($key in $fields.Keys) {
  $v = ([string]$fields[$key] -replace '[^\x20-\x7E]', '?').Trim()
  if ($v.Length -gt $valW - 1) { Write-Warning "README-шапка: значение $key обрезано до $($valW - 1) символов"; $v = $v.Substring(0, $valW - 1) }
  if ($key.Length -gt $keyW) { Write-Warning "README-шапка: ключ $key длиннее $keyW"; continue }
  if ($rows.Count) { $rows.Add($sep) }
  $rows.Add($lead + $key.PadLeft($keyW) + ' : ' + $v.PadRight($valW) + '+')
}
$lines.RemoveRange($idx[0], $idx[-1] - $idx[0] + 1)
$lines.InsertRange($idx[0], $rows)
$txt = $txt.Substring(0, $bi) + ($lines -join "`n") + $txt.Substring($ei)
$new = $txt -replace "`n", $nl
if ($new -cne $orig) { [IO.File]::WriteAllText($readmePath, $new, $enc); Write-Host 'README.md: шапка обновлена' } else { Write-Host 'README.md: шапка без изменений' }

# Страница сборки Z@RYA.html (шапка показывается на главной)
if (-not $NoSite) { & (Join-Path $PSScriptRoot 'Update site.ps1') }
