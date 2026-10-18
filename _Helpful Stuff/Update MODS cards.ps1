# Генерация карточек модов (_Helpful Stuff\mods\*.md) и сводной таблицы _Helpful Stuff\MODS.md; в конце — Update site.ps1 (Z@RYA.html)
# Пути считаются от папки скрипта: корень инстанса = родитель папки скрипта.
param([string]$InstallLog = 'U:\Minecraft\_Z@RYA DDF 1.21.1\install-log.json', [switch]$NoNet,
  [string]$ModsDir, [string]$CardsDir, [string]$ModsMd, [switch]$NoReadme)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$enc = New-Object Text.UTF8Encoding($false)
$root = Split-Path -Parent $PSScriptRoot
$modsDir = if ($ModsDir) { $ModsDir } else { Join-Path $root 'minecraft\mods' }
$cardsDir = if ($CardsDir) { $CardsDir } else { Join-Path $PSScriptRoot 'mods' }
$modsMdPath = if ($ModsMd) { $ModsMd } else { Join-Path $PSScriptRoot 'MODS.md' }
# Шаблон карточки: всегда из _Helpful Stuff\mods\_TEMPLATE.md
$templatePath = Join-Path $PSScriptRoot 'mods\_TEMPLATE.md'
if (-not (Test-Path -LiteralPath $templatePath)) { Write-Error "Нет шаблона: $templatePath"; exit 1 }
$template = [IO.File]::ReadAllText($templatePath, (New-Object Text.UTF8Encoding($false)))
# Карточки — все *.md, кроме служебных (README.md и файлы на '_')
function Get-Cards { Get-ChildItem -LiteralPath $cardsDir -Filter *.md | Where-Object { $_.Name -ne 'README.md' -and -not $_.Name.StartsWith('_') } }
if (-not (Test-Path -LiteralPath $cardsDir)) { New-Item -ItemType Directory -Path $cardsDir | Out-Null }
$fields = 'name','modid','file','version','modrinth','curseforge','git','category'
# Категории, Parse-Card, Get-RepoUrl, Get-PackInfo — в _common.ps1
. (Join-Path $PSScriptRoot '_common.ps1')
$dropFields = 'status','replaces'

function Q([string]$s) { if ($null -eq $s) { $s = '' }; "'" + ($s -replace "'", "''") + "'" }
function Read-Card($path) { Parse-Card ([IO.File]::ReadAllText($path, $enc)) }
function Write-Card($path, $fm, $body) {
  $sb = New-Object Text.StringBuilder
  [void]$sb.Append("---`n")
  foreach ($f in $fields) { [void]$sb.Append("${f}: $(Q $fm[$f])`n") }
  foreach ($k in ($fm.Keys | Sort-Object)) { if ($fields -notcontains $k -and $dropFields -notcontains $k) { [void]$sb.Append("${k}: $(Q $fm[$k])`n") } }
  [void]$sb.Append("---`n")
  [void]$sb.Append($body)
  [IO.File]::WriteAllText($path, $sb.ToString(), $enc)
}
function New-Stub($vals) {
  # Подстановка {{поле}} из шаблона; неизвестные — пустая строка
  $t = [regex]::Replace($template, '\{\{(\w+)\}\}', { param($mm) $v = $vals[$mm.Groups[1].Value]; if ($null -eq $v) { '' } else { [string]$v } })
  $d = Parse-Card $t
  $d.body = $d.body -replace '(?m)^[ \t]+$', ''
  $d
}
# Чистая версия: только номер версии мода, без версии Minecraft, лоадера и названия.
# Источники по приоритету: neoforge.mods.toml (если не ${...}), версия из install-log (Modrinth), имя файла.
function Clean-Version([string]$s) {
  if (-not $s -or $s -like '*${*') { return '' }
  $s = $s -replace '(?i)\.jar$', ''
  $s = $s -replace '\[[^\]]*\]|\([^)]*\)', ' '
  $s = $s -replace '(?i)neo(forge)?[-_ ]21\.1(?![\d.])', ' '
  $s = $s -replace '(?i)(?<![\d.])(mc[ ._-]?)?1\.2[01](\.\d+)?([-+]1\.2[01](\.\d+)?)?(?![\d.])', ' '
  $s = $s -replace '(?i)(?<![a-z])(neoforge|forge|fabric|neo|quilt|release|mc)(?![a-z])', ' '
  $m = [regex]::Match($s, '(?i)(?<![a-z0-9])v?(\d+(?:\.\d+)*(?:[a-z]+\d*)?(?:[-+.](?:\d[a-z0-9]*|(?:alpha|beta|rc|pre|build|hotfix|snapshot)\.?\d*))*)(?![a-z0-9])')
  if ($m.Success) { $m.Groups[1].Value } else { '' }
}
function Get-Version($tomlVer, $logVer, $fileName) {
  foreach ($c in @($tomlVer, $logVer, $fileName)) { $v = Clean-Version $c; if ($v) { return $v } }
  ''
}
function Jar-Meta($jarPath) {
  $r = @{ modid = ''; name = ''; version = '' }
  $z = [IO.Compression.ZipFile]::OpenRead($jarPath)
  try {
    $e = $z.GetEntry('META-INF/neoforge.mods.toml'); if (-not $e) { $e = $z.GetEntry('META-INF/mods.toml') }
    if ($e) {
      $sr = New-Object IO.StreamReader($e.Open(), $enc); $t = $sr.ReadToEnd(); $sr.Close()
      $i = $t.IndexOf('[[mods]]'); if ($i -ge 0) { $t = $t.Substring($i) }
      if ($t -match '(?m)^\s*modId\s*=\s*"([^"]+)"') { $r.modid = $Matches[1] }
      if ($t -match '(?m)^\s*displayName\s*=\s*"([^"]+)"') { $r.name = $Matches[1] }
      if ($t -match '(?m)^\s*version\s*=\s*"([^"]+)"') { $r.version = $Matches[1] }
    } else {
      $e = $z.GetEntry('fabric.mod.json')
      if ($e) {
        $sr = New-Object IO.StreamReader($e.Open(), $enc); $j = $sr.ReadToEnd() | ConvertFrom-Json; $sr.Close()
        $r.modid = $j.id; $r.name = $j.name; $r.version = $j.version
      }
    }
    if ($r.version -like '*${*' -or -not $r.version) {
      $mf = $z.GetEntry('META-INF/MANIFEST.MF'); $r.version = ''
      if ($mf) { $sr = New-Object IO.StreamReader($mf.Open()); $t = $sr.ReadToEnd(); $sr.Close()
        if ($t -match '(?m)^Implementation-Version:\s*(\S+)') { $r.version = $Matches[1] } }
    }
  } finally { $z.Dispose() }
  $r
}

# install-log (необязателен)
$log = @{}
if ($InstallLog -and (Test-Path -LiteralPath $InstallLog)) {
  $jl = [IO.File]::ReadAllText($InstallLog, $enc) | ConvertFrom-Json
  foreach ($m in $jl.mods) { if ($m.sha1) { $log[$m.sha1] = $m }; if ($m.file) { $log['f:' + $m.file] = $m } }
}

$jars = Get-ChildItem -LiteralPath $modsDir -File -Filter *.jar | Sort-Object Name
$cardsByFile = @{}; $cardsByModid = @{}
foreach ($c in (Get-Cards)) {
  $d = Read-Card $c.FullName
  if ($d.fm.file) { $cardsByFile[$d.fm.file] = $c.FullName }
  if ($d.fm.modid) { $cardsByModid[$d.fm.modid] = $c.FullName }
}

$items = @(); $used = @{}; $new = 0
foreach ($j in $jars) {
  $sha = (Get-FileHash -LiteralPath $j.FullName -Algorithm SHA1).Hash.ToLower()
  $meta = Jar-Meta $j.FullName
  $path = $cardsByFile[$j.Name]
  if (-not $path -and $meta.modid -and $cardsByModid[$meta.modid]) { $path = $cardsByModid[$meta.modid] }
  if (-not $path) {
    $slug = if ($meta.modid) { $meta.modid } else { ($j.BaseName -replace '[-_]?(neoforge|forge|fabric|mc)?[-_]?1\.21(\.\d+)?.*$', '') }
    $slug = ($slug.ToLower() -replace '[^a-z0-9_.-]+', '-').Trim('-'); if (-not $slug) { $slug = 'mod' }
    $s = $slug; $n = 2
    while ($used[$s] -or ((Test-Path -LiteralPath (Join-Path $cardsDir "$s.md")) -and -not $cardsByFile.ContainsValue((Join-Path $cardsDir "$s.md")))) { $s = "$slug-$n"; $n++ }
    $path = Join-Path $cardsDir "$s.md"
  }
  $used[[IO.Path]::GetFileNameWithoutExtension($path)] = 1
  $L = $log[$sha]; if (-not $L) { $L = $log['f:' + $j.Name] }
  if (Test-Path -LiteralPath $path) { $d = Read-Card $path } else {
    $notes = if ($L -and $L.vtype -and $L.vtype -ne 'release') { "- Версия: $($L.vtype)" } else { '' }
    $d = New-Stub @{ notes = $notes }; $d.fm = @{}; $new++
  }
  $fm = $d.fm
  foreach ($f in $fields) { if ($null -eq $fm[$f]) { $fm[$f] = '' } }
  $fm.file = $j.Name
  if (-not $fm.category) { $fm.category = $noCategory }
  $ver = Get-Version $meta.version $(if ($L) { $L.ver } else { '' }) $j.Name; if ($ver) { $fm.version = $ver }
  if (-not $fm.modid) { $fm.modid = $meta.modid }
  if (-not $fm.name) { $fm.name = if ($meta.name -and $meta.name -notlike '*${*') { $meta.name } elseif ($L -and $L.name) { $L.name } else { $j.BaseName } }
  if ($L) {
    if (-not $fm.git -and $L.git) { $fm.git = $L.git }
    if (-not $fm.curseforge -and $L.cf) { $fm.curseforge = "https://www.curseforge.com/projects/$($L.cf)" }
    if (-not $fm._pid -and $L.pid) { $fm._pid = $L.pid }
  }
  $items += [pscustomobject]@{ path = $path; fm = $fm; body = $d.body; sha = $sha }
}

# Modrinth: дозаполнить ссылки
if (-not $NoNet) {
  try {
    $need = $items | Where-Object { -not $_.fm.modrinth -or -not $_.fm.git }
    if ($need) {
      $body = @{ hashes = @($need | ForEach-Object { $_.sha }); algorithm = 'sha1' } | ConvertTo-Json
      $vf = Invoke-RestMethod -Method Post -Uri 'https://api.modrinth.com/v2/version_files' -ContentType 'application/json' -Body $body -UserAgent 'ZaryaDDF-cards/1.0'
      foreach ($it in $need) { $v = $vf.($it.sha); if ($v -and -not $it.fm._pid) { $it.fm._pid = $v.project_id } }
    }
    $pids = @($items | Where-Object { $_.fm._pid -and (-not $_.fm.modrinth -or -not $_.fm.git) } | ForEach-Object { $_.fm._pid } | Select-Object -Unique)
    $proj = @{}
    for ($k = 0; $k -lt $pids.Count; $k += 100) {
      $chunk = $pids[$k..([Math]::Min($k + 99, $pids.Count - 1))]
      $ids = [uri]::EscapeDataString((ConvertTo-Json @($chunk) -Compress))
      foreach ($p in (Invoke-RestMethod -Uri "https://api.modrinth.com/v2/projects?ids=$ids" -UserAgent 'ZaryaDDF-cards/1.0')) { $proj[$p.id] = $p }
    }
    foreach ($it in $items) { $p = $null; if ($it.fm._pid) { $p = $proj[$it.fm._pid] }; if ($p) {
      if (-not $it.fm.modrinth) { $it.fm.modrinth = "https://modrinth.com/$($p.project_type)/$($p.slug)" }
      if (-not $it.fm.git -and $p.source_url) { $it.fm.git = $p.source_url }
    } }
  } catch { Write-Warning "Modrinth недоступен: $_" }
}

foreach ($it in $items) { $it.fm.Remove('_pid'); Write-Card $it.path $it.fm $it.body }

function Esc([string]$s) { ($s -replace '\|', '\|') }
# --- MODS.md: только GitHub-безопасный Markdown/HTML (без CSS/JS) ---
function Md-Section([string]$body, [string]$title) {
  $mm = [regex]::Match($body, '(?s)##\s*' + [regex]::Escape($title) + '[ \t]*\r?\n(.*?)(?=\r?\n##\s|\z)')
  if ($mm.Success) { (($mm.Groups[1].Value -replace '(?s)<!--.*?-->', '') -replace '\r', '').Trim() } else { '' }
}
function HtmlE([string]$s) { [Net.WebUtility]::HtmlEncode($s) }
function Badge([string]$label, [string]$color, [string]$logo, [string]$url) {
  $u = "https://img.shields.io/badge/$label-$color" + $(if ($logo) { "?logo=$logo&logoColor=white" } else { '' })
  "[![$label]($u)]($url)"
}
$catList = @(Get-CategoryOrder @($items | ForEach-Object { [string]$_.fm.category }))
$catOrder = @($catList | ForEach-Object { $_.name })
$catInfo = @{}; foreach ($c in $catList) { $catInfo[$c.name] = @($c.icon, $c.id) }
$repoUrl = Get-RepoUrl $root; $repoLabel = Get-RepoLabel $repoUrl
$packInfo = Get-PackInfo $root; $mcVer = $packInfo.mc; $neoVer = $packInfo.neo
$sb = New-Object Text.StringBuilder
[void]$sb.Append("# Z@RYA Deep Dark Fantasies — моды`n`n")
[void]$sb.Append("**Модов: $($items.Count)** · Minecraft $mcVer · NeoForge $(if ($neoVer) { $neoVer } else { '—' })$(if ($repoUrl) { " · [$repoLabel]($repoUrl)" } else { '' })`n`n")
[void]$sb.Append("> Поиск, фильтр по категориям и сортировка — на странице сборки [Z@RYA.html](../Z%40RYA.html#mods) (скачайте и откройте в браузере, работает без интернета).`n`n")
[void]$sb.Append("## Категории`n`n| | Категория | Модов |`n|:-:|---|--:|`n")
$groups = @{}
foreach ($cat in $catOrder) {
  $groups[$cat] = @($items | Where-Object { [string]$_.fm.category -ceq $cat } | Sort-Object { $_.fm.name })
  [void]$sb.Append("| $($catInfo[$cat][0]) | [$(Esc $cat)](#$($catInfo[$cat][1])) | $($groups[$cat].Count) |`n")
}
[void]$sb.Append("`n## Список модов`n`n")
foreach ($cat in $catOrder) {
  $icon = $catInfo[$cat][0]; $aid = $catInfo[$cat][1]; $group = $groups[$cat]
  [void]$sb.Append("<a id=`"$aid`"></a>`n<details>`n<summary><b>$icon $(HtmlE $cat)</b> ($($group.Count))</summary>`n`n<blockquote>`n`n")
  foreach ($it in $group) {
    $f = $it.fm; $rel = 'mods/' + [uri]::EscapeDataString([IO.Path]::GetFileName($it.path))
    $ver = if ($f.version) { " · <code>$(HtmlE $f.version)</code>" } else { '' }
    $ds = Md-Section $it.body 'Описание'; if (-not $ds) { $ds = '_Описание не заполнено._' }
    $bd = @()
    if ($f.modrinth) { $bd += Badge 'Modrinth' '1bd96a' 'modrinth' $f.modrinth }
    if ($f.curseforge) { $bd += Badge 'CurseForge' 'f16436' 'curseforge' $f.curseforge }
    if ($f.git) { if ($f.git -match 'github\.com') { $bd += Badge 'GitHub' '24292e' 'github' $f.git } else { $bd += Badge 'Git' '555555' 'git' $f.git } }
    $bd += "[📄 карточка]($rel)"
    [void]$sb.Append("<details>`n<summary><b>$(HtmlE $f.name)</b>$ver</summary>`n`n$ds`n`n$($bd -join ' ')`n`n</details>`n")
  }
  [void]$sb.Append("`n</blockquote>`n`n</details>`n`n")
}
[void]$sb.Append("---`n`n<sub>Сгенерировано скриптом <code>Update MODS cards.ps1</code> · $(Get-Date -Format 'yyyy-MM-dd'). Правьте карточки в <code>mods/</code>, а не этот файл. Поиск и фильтр — на странице сборки <a href=`"../Z%40RYA.html#mods`">Z@RYA.html</a>.</sub>`n")
[IO.File]::WriteAllText($modsMdPath, $sb.ToString(), $enc)

$stale = (Get-Cards | Where-Object { $used[$_.BaseName] -ne 1 }).Name
Write-Host "Карточек: $($items.Count), новых: $new, jar: $($jars.Count)"
if ($stale) { Write-Host "Карточки без jar: $($stale -join ', ')" }

# --- README.md: NFO-шапка (версии, число модов/ресурспаков/треков) — Update README header.ps1 ---
if (-not $NoReadme) { & (Join-Path $PSScriptRoot 'Update README header.ps1') -NoSite }

# --- Страница сборки Z@RYA.html (вкладка «Моды» и остальное) ---
& (Join-Path $PSScriptRoot 'Update site.ps1')
