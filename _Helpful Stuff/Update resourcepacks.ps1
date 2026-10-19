# Ресурспаки: MD5 (minecraft\resourcepacks\RESOURCEPACKLIST.md), карточки _Helpful Stuff\resourcepacks\*.md, сводка _Helpful Stuff\RESOURCEPACKS.md, в конце — Update README and site.ps1 (NFO-шапка README.md и Z@RYA.html)
# Работает из любой текущей папки: пути считаются от расположения скрипта (корень инстанса = папка выше).
param([switch]$NoNet, [switch]$NoSite, [switch]$NoReadme)
$root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $root 'minecraft\resourcepacks'
if (-not (Test-Path -LiteralPath $dir)) { Write-Error "Папка не найдена: $dir"; exit 1 }
$output = "## Список ресурспаков и ХЭШ-суммы`n"
$output += "`n"
foreach($f in (Get-ChildItem -LiteralPath $dir -File | Sort-Object Name)){
	if($f.Extension -eq ".zip"){
		$output += "    Имя файла: " + $f.Name + "`n"
		$output += "    MD5: " + (Get-FileHash -LiteralPath $f.FullName -Algorithm MD5).Hash + "`n"
		$output +=  "---`n"
}}
Out-File -FilePath (Join-Path $dir 'RESOURCEPACKLIST.md') -InputObject $output -Encoding utf8
Write-Host "Обновлён: $(Join-Path $dir 'RESOURCEPACKLIST.md')"

# --- Карточки ресурспаков: _Helpful Stuff\resourcepacks\*.md (по одной на zip/папку) ---
# Заполненные поля и текст карточек не трогаются; карточки без пака только перечисляются.
. (Join-Path $PSScriptRoot '_common.ps1')
Add-Type -AssemblyName System.IO.Compression.FileSystem
$enc = New-Object Text.UTF8Encoding($false)
$cardsDir = Join-Path $PSScriptRoot 'resourcepacks'
if (-not (Test-Path -LiteralPath $cardsDir)) { New-Item -ItemType Directory -Path $cardsDir | Out-Null }
$templatePath = Join-Path $cardsDir '_TEMPLATE.md'
$template = if (Test-Path -LiteralPath $templatePath) { [IO.File]::ReadAllText($templatePath, $enc) } else {
  Write-Warning "Нет шаблона: $templatePath"; "---`n---`n`n## Описание`n`n{{description}}`n`n## Заметки`n`n{{notes}}`n" }
$rpFields = 'name','file','version','modrinth','curseforge','git','other'
function Q([string]$s) { if ($null -eq $s) { $s = '' }; "'" + ($s -replace "'", "''") + "'" }
function Format-PackCard($fm, $body) {
  $sb = New-Object Text.StringBuilder
  [void]$sb.Append("---`n")
  foreach ($f in $rpFields) { [void]$sb.Append("${f}: $(Q $fm[$f])`n") }
  foreach ($k in ($fm.Keys | Sort-Object)) { if ($rpFields -notcontains $k) { [void]$sb.Append("${k}: $(Q $fm[$k])`n") } }
  [void]$sb.Append("---`n")
  [void]$sb.Append($body)
  $sb.ToString()
}
function New-PackStub {
  $t = [regex]::Replace($template, '\{\{(\w+)\}\}', '')
  $d = Parse-Card $t
  $d.body = $d.body -replace '(?m)^[ \t]+$', ''
  $d
}
# Имя без расширения и номеров версий: по нему карточка находится после обновления пака
function Pack-Stem([string]$n) {
  $n = $n -replace '(?i)\.zip$', ''
  (($n -replace '(?i)(?<![a-z])v?\d+(?:[._]\d+)*', '') -replace '[^\p{L}]+', '').ToLower()
}
# Версия из имени файла (без версии Minecraft)
function Pack-Version([string]$n) {
  $n = $n -replace '(?i)\.zip$', ''
  $n = $n -replace '(?i)(?<![\d.])(mc[ ._-]?)?1\.(1\d|2\d)(\.\d+)?(?![\d.])', ' '
  $m = [regex]::Match($n, '(?i)(?<![a-z0-9])v?(\d+(?:[._]\d+)*)(?![\d])')
  if ($m.Success) { $m.Groups[1].Value } else { '' }
}

$rpItems = @(Get-ChildItem -LiteralPath $dir | Where-Object { $_.PSIsContainer -or $_.Extension -eq '.zip' } | Sort-Object Name)
$cards = @{}; $byFile = @{}
foreach ($c in (Get-ChildItem -LiteralPath $cardsDir -Filter *.md | Where-Object { $_.Name -ne 'README.md' -and -not $_.Name.StartsWith('_') })) {
  $raw = [IO.File]::ReadAllText($c.FullName, $enc); $d = Parse-Card $raw
  $cards[$c.FullName] = @{ d = $d; raw = $raw }
  if ($d.fm.file) { $byFile[[string]$d.fm.file] = $c.FullName }
}
$present = @{}; foreach ($it in $rpItems) { $present[$it.Name] = 1 }
$used = @{}; $work = @(); $newCards = 0
foreach ($it in $rpItems) {
  $path = $byFile[$it.Name]
  if (-not $path) {
    # пак обновился: ищем карточку без пака с тем же именем без версии
    $st = Pack-Stem $it.Name
    $cand = @($cards.Keys | Where-Object { -not $used[$_] -and -not $present[[string]$cards[$_].d.fm.file] -and (Pack-Stem ([string]$cards[$_].d.fm.file)) -eq $st })
    if ($st -and $cand.Count -eq 1) { $path = $cand[0] }
  }
  if (-not $path) {
    $base = if ($it.PSIsContainer) { $it.Name } else { $it.BaseName }
    $slug = (($base -replace '(?i)(?<![a-z])v?\d+(?:[._]\d+)*', ' ').ToLower() -replace '[^a-z0-9]+', '-').Trim('-'); if (-not $slug) { $slug = 'pack' }
    $s = $slug; $n = 2
    while ($used[(Join-Path $cardsDir "$s.md")] -or (Test-Path -LiteralPath (Join-Path $cardsDir "$s.md"))) { $s = "$slug-$n"; $n++ }
    $path = Join-Path $cardsDir "$s.md"
    $d = New-PackStub; $d.fm = @{ name = $base }; $raw = ''; $newCards++
  } else { $d = $cards[$path].d; $raw = $cards[$path].raw }
  $used[$path] = 1
  $fm = $d.fm; foreach ($f in $rpFields) { if ($null -eq $fm[$f]) { $fm[$f] = '' } }
  if (-not $fm.name) { $fm.name = if ($it.PSIsContainer) { $it.Name } else { $it.BaseName } }
  $changedFile = $fm.file -ne $it.Name
  $fm.file = $it.Name
  if (-not $fm.version -or $changedFile) { $v = Pack-Version $it.Name; if ($v) { $fm.version = $v } elseif ($changedFile) { $fm.version = '' } }
  $sha = if ($it.PSIsContainer) { '' } else { (Get-FileHash -LiteralPath $it.FullName -Algorithm SHA1).Hash.ToLower() }
  $work += [pscustomobject]@{ path = $path; fm = $fm; body = $d.body; raw = $raw; sha = $sha }
}
# Modrinth: пустые ссылки modrinth дозаполняются только при точном совпадении файла (sha1)
if (-not $NoNet) {
  try {
    $need = @($work | Where-Object { $_.sha -and -not $_.fm.modrinth })
    if ($need.Count) {
      $body = @{ hashes = @($need | ForEach-Object { $_.sha }); algorithm = 'sha1' } | ConvertTo-Json
      $vf = Invoke-RestMethod -Method Post -Uri 'https://api.modrinth.com/v2/version_files' -ContentType 'application/json' -Body $body -UserAgent 'ZaryaDDF-cards/1.0'
      $hit = @($need | Where-Object { $vf.($_.sha) })
      if ($hit.Count) {
        $ids = [uri]::EscapeDataString((ConvertTo-Json @($hit | ForEach-Object { $vf.($_.sha).project_id } | Select-Object -Unique) -Compress))
        $proj = @{}; foreach ($p in @(Invoke-RestMethod -Uri "https://api.modrinth.com/v2/projects?ids=$ids" -UserAgent 'ZaryaDDF-cards/1.0')) { $proj[$p.id] = $p }
        foreach ($w in $hit) {
          $v = $vf.($w.sha); $p = $proj[$v.project_id]
          if ($p) { $w.fm.modrinth = "https://modrinth.com/$($p.project_type)/$($p.slug)"; if (-not $w.fm.version) { $w.fm.version = ($v.version_number -replace '^v(?=\d)', '') } }
        }
      }
    }
  } catch { Write-Warning "Modrinth недоступен: $($_.Exception.Message)" }
}
$written = 0
foreach ($w in $work) {
  $t = Format-PackCard $w.fm $w.body
  if ($t -ne $w.raw) { [IO.File]::WriteAllText($w.path, $t, $enc); $written++ }
}
$orphans = @($cards.Keys | Where-Object { -not $used[$_] } | ForEach-Object { [IO.Path]::GetFileName($_) } | Sort-Object)
Write-Host "Карточки ресурспаков: $($work.Count), новых: $newCards, обновлено: $written"
if ($orphans.Count) { Write-Host "Карточки без ресурспака (не удалены): $($orphans -join ', ')" }

# --- RESOURCEPACKS.md: те же данные и порядок, что на вкладке «Ресурспаки» Z@RYA.html (Get-ResourcePacks в _common.ps1) ---
# Порядок как в игре (options.txt): сначала включённые («Вкл N» — место в списке «Выбранные» сверху вниз), затем выключенные; без options.txt — по алфавиту.
$rpData = Get-ResourcePacks $root $cardsDir
$rpList = @($rpData.packs); $gameOrder = $rpData.order -eq 'game'
function Rp-Aid($p) { 'rp-' + (([string]$p.key).ToLower() -replace '[^a-z0-9_]+', '-').Trim('-') }
function Rp-Status($p) {
  if (-not $gameOrder) { return '' }
  $s = if ($p.on) { "Вкл $($p.pos)" } else { 'Выкл' }
  if ($p.incompat) { $s += ' · ⚠️ несовместим' }
  $s
}
$repoUrl = Get-RepoUrl $root; $repoLabel = Get-RepoLabel $repoUrl
$pi = Get-PackInfo $root
$onCount = @($rpList | Where-Object { $_.on }).Count
$sb = New-Object Text.StringBuilder
[void]$sb.Append("# Z@RYA Deep Dark Fantasies — ресурспаки`n`n")
[void]$sb.Append("**Ресурспаков: $($rpList.Count)**$(if ($gameOrder) { " (включено: $onCount)" } else { '' }) · Minecraft $($pi.mc)$(if ($repoUrl) { " · [$repoLabel]($repoUrl)" } else { '' })`n`n")
[void]$sb.Append("> Поиск, порядок и карточки — на $(Site-Links 'packs').`n")
if ($gameOrder) { [void]$sb.Append("> Порядок как в игре (``options.txt``): сначала включённые — «Вкл 1» вверху списка «Выбранные» (высший приоритет), затем выключенные по алфавиту.`n`n") }
else { [void]$sb.Append("> По алфавиту — ``options.txt`` ещё нет (порядок из игры появится после первого запуска).`n`n") }
[void]$sb.Append("## Список`n`n| № | Ресурспак | Версия |$(if ($gameOrder) { ' Статус |' } else { '' })`n|--:|---|---|$(if ($gameOrder) { '---|' } else { '' })`n")
$n = 0
foreach ($p in $rpList) {
  $n++
  [void]$sb.Append("| $n | [$(([string]$p.name) -replace '\|', '\|')](#$(Rp-Aid $p)) | $(if ($p.version) { ('`' + $p.version + '`') } else { '—' }) |$(if ($gameOrder) { " $(Rp-Status $p) |" } else { '' })`n")
}
$groupsRp = if ($gameOrder) { @(@{ id = 'enabled'; title = '✅ Включены'; items = @($rpList | Where-Object { $_.on }) }, @{ id = 'disabled'; title = '⏸️ Выключены'; items = @($rpList | Where-Object { -not $_.on }) }) }
  else { @(@{ id = 'all'; title = '🎨 Все ресурспаки'; items = $rpList }) }
[void]$sb.Append("`n## Ресурспаки`n`n")
foreach ($g in $groupsRp) {
  if (-not $g.items.Count) { continue }
  [void]$sb.Append("<a id=`"$($g.id)`"></a>`n<details>`n<summary><b>$($g.title)</b> ($($g.items.Count))</summary>`n`n<blockquote>`n`n")
  foreach ($p in $g.items) {
    $ver = if ($p.version) { " · <code>$(HtmlE $p.version)</code>" } else { '' }
    $st = Rp-Status $p; $st = if ($st) { " · $(HtmlE $st)" } else { '' }
    $ds = if ($p.desc) { $p.desc } elseif ($p.mcdesc) { $p.mcdesc } else { '_Описание не заполнено._' }
    $bd = @()
    if ($p.modrinth) { $bd += Md-Badge 'Modrinth' '1bd96a' 'modrinth' $p.modrinth }
    if ($p.curseforge) { $bd += Md-Badge 'CurseForge' 'f16436' 'curseforge' $p.curseforge }
    if ($p.git) { if ($p.git -match 'github\.com') { $bd += Md-Badge 'GitHub' '24292e' 'github' $p.git } else { $bd += Md-Badge 'Git' '555555' 'git' $p.git } }
    if ($p.other) { $bd += Md-Badge 'Ссылка' '555555' '' $p.other }
    if ($p.card) { $bd += "[📄 карточка](resourcepacks/$([uri]::EscapeDataString("$($p.key).md")))" }
    [void]$sb.Append("<a id=`"$(Rp-Aid $p)`"></a>`n<details>`n<summary><b>$(HtmlE $p.name)</b>$ver$st</summary>`n`n$ds`n`n")
    if ($p.notes) { [void]$sb.Append("**Заметки**`n`n$($p.notes)`n`n") }
    [void]$sb.Append("Файл: <code>$(HtmlE $p.file)</code>$(if ($p.kind -eq 'folder') { ' (папка)' } else { '' })`n`n")
    if ($bd.Count) { [void]$sb.Append("$($bd -join ' ')`n`n") }
    [void]$sb.Append("</details>`n")
  }
  [void]$sb.Append("`n</blockquote>`n`n</details>`n`n")
}
[void]$sb.Append("---`n`n<sub>Сгенерировано скриптом <code>Update resourcepacks.ps1</code> · $(Get-Date -Format 'yyyy-MM-dd'). Правьте карточки в <code>resourcepacks/</code>, а не этот файл. Поиск — на странице сборки <a href=`"Z%40RYA.html#packs`">Z@RYA.html</a>.</sub>`n")
$rpMd = Join-Path $PSScriptRoot 'RESOURCEPACKS.md'
[IO.File]::WriteAllText($rpMd, $sb.ToString(), $enc)
Write-Host "Обновлён: $rpMd"

# --- README.md (NFO-шапка) и страница сборки Z@RYA.html — Update README and site.ps1 ---
if (-not ($NoReadme -and $NoSite)) { & (Join-Path $PSScriptRoot 'Update README and site.ps1') -NoReadme:$NoReadme -NoSite:$NoSite }
