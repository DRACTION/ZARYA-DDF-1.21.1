# Музыка Music Triggers: список файлов с MD5 (MusicTriggers\songs\MUSICLIST.md), сводка _Helpful Stuff\MUSIC.md, в конце — Update site.ps1 (Z@RYA.html)
# Пути считаются от папки скрипта: корень инстанса = родитель папки скрипта.
# Папка songs — папка данных Music Triggers (на неё ссылается config), её имя не меняется.
param([switch]$NoSite, [switch]$NoReadme)
. (Join-Path $PSScriptRoot '_common.ps1')
$enc = New-Object Text.UTF8Encoding($false)
$root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $root 'minecraft\config\MusicTriggers\songs'
if (-not (Test-Path -LiteralPath $dir)) { Write-Error "Папка не найдена: $dir"; exit 1 }
$output = "## Список музыки с расширениями ``.OGG`` и ``.MP3``, а также ХЭШ-суммы`n"
$output += "`n"
foreach($f in (Get-ChildItem -LiteralPath $dir -File | Sort-Object Name)){
	if(($f.Extension -eq ".ogg") -or ($f.Extension -eq ".mp3")){
		$output += "    Имя файла: " + $f.Name + "`n"
		$output += "    MD5: " + (Get-FileHash -LiteralPath $f.FullName -Algorithm MD5).Hash + "`n"
		$output += "---`n"
}}
[IO.File]::WriteAllText((Join-Path $dir 'MUSICLIST.md'), $output, $enc)
Write-Host "Обновлён: $(Join-Path $dir 'MUSICLIST.md')"

# --- MUSIC.md: те же данные, что на вкладке «Музыка» Z@RYA.html (Get-MusicData в _common.ps1); только GitHub-безопасный Markdown/HTML ---
$M = Get-MusicData $root
$tracks = @($M.tracks); $trigs = @($M.triggers)
$tmap = @{}; $tord = @{}; $k = 0; foreach ($t in $trigs) { $tmap[$t.key] = $t; $tord[$t.key] = $k++ }
$typeIcon = @{ height = '⛏️'; biome = '🌿'; time = '🌙'; bloodmoon = '🩸'; mob = '⚔️'; dimension = '🌍'; dead = '☠️'; riding = '🐎'; menu = '🏠'; structure = '🏰'; raid = '🚩'; underwater = '🌊'; elytra = '🪽'; fishing = '🎣'; pvp = '🤺'; lowhp = '💔' }
$typeColor = @{ height = '8d6e63'; biome = '43a047'; time = '3949ab'; bloodmoon = 'b71c1c'; mob = 'e65100'; dimension = '00838f'; dead = '424242'; riding = 'ad1457'; menu = '6d4c41' }
function T-Type([string]$key) { $t = $tmap[$key]; if ($t) { [string]$t.type } else { ($key -split '-', 2)[0] } }
function T-Id([string]$key) { $t = $tmap[$key]; if ($t) { [string]$t.id } else { $p = $key -split '-', 2; if ($p.Count -gt 1) { $p[1] } else { '' } } }
function T-Label([string]$key) { $ty = T-Type $key; $id = T-Id $key; $n = $mtTypeNames[$ty]; if (-not $n) { $n = $ty }; if ($id) { "${n}: $id" } else { $n } }
function T-Prio([string]$key) { $t = $tmap[$key]; $p = 0; if ($t -and [int]::TryParse([string]$t.priority, [ref]$p)) { $p } else { 0 } }
function Aid([string]$s) { (($s.ToLower() -replace '[^a-z0-9_]+', '-').Trim('-')) }
function P-Val([string]$name, $v) {
  $t = if ($v -is [array]) { '[' + ($v -join ', ') + ']' } else { [string]$v }
  $u = if ($mtTickParams -contains $name -and $t -match '^\d+$') { ' <sub>≈ ' + (([double]$t / 20).ToString([Globalization.CultureInfo]::InvariantCulture) -replace '\.', ',') + ' с</sub>' } else { '' }
  "<code>$(HtmlE "$name = $t")</code>$u"
}
function P-Legend([string[]]$keys) {
  ($keys | ForEach-Object {
    $d = $mtParams[$_]
    if ($d) { "- <code>$_</code> — <b>$(HtmlE $d[0])</b>. $($d[1]) <i>($(HtmlE $d[2]))</i>" } else { "- <code>$_</code> — <i>не уточнено</i>" }
  }) -join "`n"
}
# Группы: одинаковый набор событий (несколько событий у трека = должны выполняться все сразу).
# Порядок групп — по наибольшему приоритету события в наборе (как выбирает Music Triggers), затем по числу треков.
$groups = [ordered]@{}
foreach ($s in $tracks) {
  $ks = @($s.triggers | Sort-Object { -(T-Prio $_) }, { $tord[$_] })
  $gk = $ks -join ' + '
  if (-not $groups.Contains($gk)) { $groups[$gk] = [pscustomobject]@{ keys = $ks; items = New-Object System.Collections.ArrayList } }
  [void]$groups[$gk].items.Add($s)
}
$glist = @($groups.Values | Sort-Object { if ($_.keys.Count) { -(T-Prio $_.keys[0]) } else { 1 } }, { -$_.items.Count }, { ($_.keys | ForEach-Object { T-Label $_ }) -join ' + ' })
function G-Title($g) { if ($g.keys.Count) { ($g.keys | ForEach-Object { T-Label $_ }) -join ' + ' } else { 'Без события' } }
function G-Icon($g) { if ($g.keys.Count) { $i = $typeIcon[(T-Type $g.keys[0])]; if ($i) { $i } else { '🎵' } } else { '🎵' } }
function G-Id($g) { if ($g.keys.Count) { 'g-' + (Aid ($g.keys -join '--')) } else { 'g-none' } }
function Sum-Dur($list) { $t = 0.0; foreach ($x in $list) { if ($null -ne $x.dur -and "$($x.dur)" -ne '') { $t += [double]$x.dur } }; $t }
$repoUrl = Get-RepoUrl $root; $repoLabel = Get-RepoLabel $repoUrl
$pi = Get-PackInfo $root
$total = Sum-Dur $tracks
$sb = New-Object Text.StringBuilder
[void]$sb.Append("# Z@RYA Deep Dark Fantasies — музыка`n`n")
[void]$sb.Append("**Треков: $($tracks.Count)** · $(Format-Hms $total) · Minecraft $($pi.mc) · Music Triggers$(if ($repoUrl) { " · [$repoLabel]($repoUrl)" } else { '' })`n`n")
[void]$sb.Append("> Поиск и фильтр по событиям — на странице сборки [Z@RYA.html](../Z%40RYA.html#music) (скачайте и откройте в браузере, работает без интернета).`n")
[void]$sb.Append("> Треки — ``minecraft/config/MusicTriggers/songs``, события — ``config/MusicTriggers/general/main.toml``. Если у трека несколько событий, он играет, только когда выполняются все сразу.`n`n")
[void]$sb.Append("## События`n`n| | События | Треков | Длительность |`n|:-:|---|--:|--:|`n")
foreach ($g in $glist) { [void]$sb.Append("| $(G-Icon $g) | [$((G-Title $g) -replace '\|', '\|')](#$(G-Id $g)) | $($g.items.Count) | $(Format-Hms (Sum-Dur $g.items)) |`n") }
[void]$sb.Append("| | **Всего** | **$($tracks.Count)** | **$(Format-Hms $total)** |`n")
if ($M.parsed -and $trigs.Count) { [void]$sb.Append("`nКак настроено каждое событие и что означают параметры — в разделе [Как настроены события](#events).`n") }
[void]$sb.Append("`n## Список треков`n`n")
foreach ($g in $glist) {
  [void]$sb.Append("<a id=`"$(G-Id $g)`"></a>`n<details>`n<summary><b>$(G-Icon $g) $(HtmlE (G-Title $g))</b> ($($g.items.Count) · $(Format-Hms (Sum-Dur $g.items)))</summary>`n`n<blockquote>`n`n")
  foreach ($s in @($g.items | Sort-Object { $_.title })) {
    $bd = @($s.triggers | ForEach-Object {
      $ty = T-Type $_; $c = $typeColor[$ty]; if (-not $c) { $c = '555555' }
      $n = $mtTypeNames[$ty]; if (-not $n) { $n = $ty }
      Md-Badge $n $c '' "#ev-$(Aid $_)" (T-Id $_)
    })
    $ext = ([IO.Path]::GetExtension($s.file)).TrimStart('.').ToUpper()
    [void]$sb.Append("<details>`n<summary><b>$(HtmlE $s.title)</b> · <code>$(Format-Mss $s.dur)</code></summary>`n`n")
    [void]$sb.Append("Файл: <code>$(HtmlE $s.file)</code> · $ext · $(Format-Size $s.size)`n`n")
    if ($bd.Count) { [void]$sb.Append("$($bd -join ' ')`n`n") } else { [void]$sb.Append("_Не привязан ни к одному событию._`n`n") }
    if ($s.playOnce) { $d = $mtParams['play_once']; [void]$sb.Append("$(P-Val 'play_once' $s.playOnce) — $(HtmlE $d[0]): $($d[1])`n`n") }
    [void]$sb.Append("</details>`n")
  }
  [void]$sb.Append("`n</blockquote>`n`n</details>`n`n")
}
if ($M.missing.Count) { [void]$sb.Append("> В main.toml есть треки без файла: $(($M.missing | ForEach-Object { '`' + $_ + '`' }) -join ', ')`n`n") }
# --- Как настроены события (то же, что панель на сайте) ---
if ($M.parsed -and $trigs.Count) {
  $uni = $null; $used = [ordered]@{ identifier = 1; priority = 1 }
  [void]$sb.Append("## Как настроены события`n`n<a id=`"events`"></a>`n<details>`n<summary><b>⚙️ События из main.toml</b> ($(@($trigs | Where-Object { $_.type -ne 'universal' }).Count))</summary>`n`n<blockquote>`n`n")
  [void]$sb.Append("| Событие | Приоритет | Треков | Параметры |`n|---|--:|--:|---|`n")
  foreach ($t in $trigs) {
    if ($t.type -eq 'universal') { $uni = $t; continue }
    foreach ($pk in $t.params.Keys) { $used[$pk] = 1 }
    $n = @($tracks | Where-Object { @($_.triggers) -contains $t.key }).Count
    $ps = (@($t.params.Keys | ForEach-Object { P-Val $_ $t.params[$_] }) -join ' ')
    $td = $mtTypeDesc[$t.type]
    $cell = "<a id=`"ev-$(Aid $t.key)`"></a>$(HtmlE (T-Label $t.key))$(if ($td) { "<br><sub>$(HtmlE $td)</sub>" } else { '' })"
    [void]$sb.Append("| $cell | $(if ($t.priority) { $t.priority } else { '—' }) | $n | $(if ($ps) { $ps } else { '—' }) |`n")
  }
  [void]$sb.Append("`n")
  if ($uni -and $uni.params.Count) {
    [void]$sb.Append("Общие настройки <code>[triggers.universal]</code>: $(@($uni.params.Keys | ForEach-Object { P-Val $_ $uni.params[$_] }) -join ' ') — применяются ко всем событиям, у которых этот параметр не задан.`n`n")
    foreach ($pk in $uni.params.Keys) { $used[$pk] = 1 }
  }
  $ordK = @('identifier', 'priority') + @($used.Keys | Where-Object { $_ -ne 'identifier' -and $_ -ne 'priority' } | Sort-Object)
  $usedS = @('triggers') + @(if (@($tracks | Where-Object { $_.playOnce }).Count) { 'play_once' }) | Sort-Object
  [void]$sb.Append("<details>`n<summary><b>Что означают параметры</b></summary>`n`n")
  [void]$sb.Append("По документации и исходникам Music Triggers 7.0.4. Время указывается в тиках: 20 тиков = 1 секунда.`n`n")
  [void]$sb.Append("$(P-Legend $ordK)`n`n**Параметры треков** (<code>[songs.*]</code>):`n`n$(P-Legend $usedS)`n`n</details>`n`n</blockquote>`n`n</details>`n`n")
}
[void]$sb.Append("---`n`n<sub>Сгенерировано скриптом <code>Update MD5 music.ps1</code> · $(Get-Date -Format 'yyyy-MM-dd'). Длительность посчитана по самим файлам. Поиск и фильтр — на странице сборки <a href=`"../Z%40RYA.html#music`">Z@RYA.html</a>.</sub>`n")
$musicMd = Join-Path $PSScriptRoot 'MUSIC.md'
[IO.File]::WriteAllText($musicMd, $sb.ToString(), $enc)
Write-Host "Обновлён: $musicMd (треков: $($tracks.Count), групп: $($glist.Count), $(Format-Hms $total))"

# README.md: NFO-шапка (число ресурспаков/треков, длительность музыки)
if (-not $NoReadme) { & (Join-Path $PSScriptRoot 'Update README header.ps1') -NoSite }

# Страница сборки Z@RYA.html
if (-not $NoSite) { & (Join-Path $PSScriptRoot 'Update site.ps1') }
