# Общие данные и функции для скриптов _Helpful Stuff (подключается через точку: . "$PSScriptRoot\_common.ps1")
# Категории модов: порядок групп в MODS.md и фильтров в Z@RYA.html. Поле category в карточке — одно значение из списка.
# Новые карточки получают 'Без категории'. Неизвестные категории выводятся в конце (с предупреждением).
$categories = @(
  'Create и аддоны',
  'Техника, хранение и логистика',
  'RPG, магия и прогрессия',
  'Бой и оружие',
  'Мобы и боссы',
  'Мир и генерация',
  'Структуры и подземелья',
  'Еда и фермерство',
  'Жители и животные',
  'Выживание и механики',
  'Транспорт и перемещение',
  'Декор и строительство',
  'Интерфейс и QoL',
  'Графика и анимации',
  'Звук и музыка',
  'Оптимизация и исправления',
  'Сервер, скрипты и утилиты',
  'Библиотеки и API',
  'Прочее',
  'Без категории'
)
$noCategory = 'Без категории'
# Опубликованная страница сборки (GitHub Pages) и строка-ссылка для шапок MODS.md / MUSIC.md / RESOURCEPACKS.md:
# онлайн-версия + локальная Z@RYA.html (лежит рядом с MD-файлами в _Helpful Stuff) на ту же вкладку.
$siteUrl = 'https://draction.github.io/ZARYA-DDF-1.21.1/'
function Site-Links([string]$tab) { "[странице сборки]($siteUrl#$tab) [(версия без интернета)](Z%40RYA.html#$tab)" }
# Иконка и ASCII-якорь категории для MODS.md и Z@RYA.html (неизвестные категории: 🏷️ и cat-N)
$categoryMeta = @{
  'Create и аддоны' = @('⚙️', 'create')
  'Техника, хранение и логистика' = @('🏭', 'tech')
  'RPG, магия и прогрессия' = @('🔮', 'rpg')
  'Бой и оружие' = @('⚔️', 'combat')
  'Мобы и боссы' = @('💀', 'mobs')
  'Мир и генерация' = @('🌍', 'world')
  'Структуры и подземелья' = @('🏰', 'structures')
  'Еда и фермерство' = @('🌾', 'food')
  'Жители и животные' = @('🐄', 'villagers')
  'Выживание и механики' = @('🏕️', 'survival')
  'Транспорт и перемещение' = @('🚂', 'transport')
  'Декор и строительство' = @('🧱', 'decor')
  'Интерфейс и QoL' = @('🖱️', 'ui')
  'Графика и анимации' = @('✨', 'graphics')
  'Звук и музыка' = @('🎵', 'sound')
  'Оптимизация и исправления' = @('🚀', 'performance')
  'Сервер, скрипты и утилиты' = @('🛠️', 'server')
  'Библиотеки и API' = @('📚', 'libraries')
  'Прочее' = @('📦', 'misc')
  'Без категории' = @('❓', 'uncategorized')
}

# Разбор карточки: YAML-блок (---) + тело
function Parse-Card([string]$t) {
  $fm = @{}; $body = $t
  $m = [regex]::Match($t, '^---\r?\n(.*?)\r?\n---\r?\n?(.*)$', 'Singleline')
  if ($m.Success) {
    foreach ($l in ($m.Groups[1].Value -split '\r?\n')) {
      if ($l -match '^([A-Za-z_]+):\s*(.*?)\s*(#.*)?$') {
        $key = $Matches[1]; $v = $Matches[2]
        if ($v -match "^'(.*)'$") { $v = $Matches[1] -replace "''", "'" } elseif ($v -match '^"(.*)"$') { $v = $Matches[1] }
        $fm[$key] = $v
      }
    }
    $body = $m.Groups[2].Value
  }
  @{ fm = $fm; body = $body }
}

# Порядок категорий: сначала из $categories (только присутствующие), затем неизвестные по алфавиту.
# Возвращает список @{ name; icon; id }.
function Get-CategoryOrder([string[]]$present) {
  $present = @($present | Select-Object -Unique)
  $unknown = @($present | Where-Object { $categories -notcontains $_ } | Sort-Object)
  if ($unknown.Count) { Write-Warning "Категории не из списка: $($unknown -join ', ')" }
  $k = 0
  foreach ($cat in (@($categories | Where-Object { $present -contains $_ }) + $unknown)) {
    $k++; $m = $categoryMeta[$cat]
    if ($m) { [pscustomobject]@{ name = $cat; icon = $m[0]; id = $m[1] } } else { [pscustomobject]@{ name = $cat; icon = '🏷️'; id = "cat-$k" } }
  }
}

# Ссылка на репозиторий: git remote инстанса (origin, иначе первый). Нет remote/git — пустая строка.
function Get-RepoUrl([string]$dir) {
  $url = ''
  try {
    $remotes = @(& git -C $dir remote 2>$null)
    if ($remotes.Count) {
      $rn = if ($remotes -contains 'origin') { 'origin' } else { $remotes[0] }
      $ru = ([string](& git -C $dir remote get-url $rn 2>$null)).Trim()
      if ($ru -match '^[\w.-]+@([^:/]+):(.+)$') { $ru = "https://$($Matches[1])/$($Matches[2])" }        # git@host:user/repo
      elseif ($ru -match '^(?:ssh|git)://(?:[^@/]+@)?([^:/]+)(?::\d+)?/(.+)$') { $ru = "https://$($Matches[1])/$($Matches[2])" }
      $ru = $ru -replace '^(https?://)[^@/]+@', '$1'     # убрать логин/токен из URL
      $ru = ($ru -replace '/+$', '') -replace '\.git$', ''
      if ($ru -match '^https?://') { $url = $ru }
    }
  } catch { $url = '' }
  $url
}
function Get-RepoLabel([string]$url) { if ($url -match '^https?://(www\.)?github\.com/') { 'GitHub' } else { 'Git' } }

# Версии: Minecraft и NeoForge из mmc-pack.json, версия сборки (rX.Y.Z) и иконка из instance.cfg
function Get-PackInfo([string]$dir) {
  $r = [ordered]@{ mc = ''; neo = ''; version = ''; name = ''; iconKey = '' }
  $pj = Join-Path $dir 'mmc-pack.json'
  if (Test-Path -LiteralPath $pj) {
    $comps = (Get-Content -LiteralPath $pj -Raw -Encoding UTF8 | ConvertFrom-Json).components
    $r.mc = [string]($comps | Where-Object { $_.uid -eq 'net.minecraft' }).version
    $r.neo = [string]($comps | Where-Object { $_.uid -eq 'net.neoforged' }).version
  }
  $ic = Join-Path $dir 'instance.cfg'
  if (Test-Path -LiteralPath $ic) {
    foreach ($l in (Get-Content -LiteralPath $ic -Encoding UTF8)) {
      if ($l -match '^name=(.*)$') { $r.name = $Matches[1].Trim(); if ($r.name -match '\b(r\d+\.\d+\.\d+)\b') { $r.version = $Matches[1] } }
      elseif ($l -match '^iconKey=(.*)$') { $r.iconKey = $Matches[1].Trim() }
    }
  }
  if (-not $r.mc) { $r.mc = '1.21.1' }
  $r
}

# --- Разбор карточек и форматы ---
function Get-Section([string]$body, [string]$title) {
  $mm = [regex]::Match($body, '(?s)##\s*' + [regex]::Escape($title) + '[ \t]*\r?\n(.*?)(?=\r?\n##\s|\z)')
  if ($mm.Success) { (($mm.Groups[1].Value -replace '(?s)<!--.*?-->', '') -replace '\r', '').Trim() } else { '' }
}
# Текст Minecraft (строка / объект {text,extra} / массив) → обычная строка без §-кодов
function Mc-Text($v) {
  if ($null -eq $v) { return '' }
  if ($v -is [string]) { return ($v -replace '§.', '') }
  if ($v -is [array]) { return (($v | ForEach-Object { Mc-Text $_ }) -join '') }
  $t = ''
  if ($v.PSObject.Properties['text']) { $t += Mc-Text $v.text }
  if ($v.PSObject.Properties['translate'] -and -not $t) { $t += [string]$v.translate }
  if ($v.PSObject.Properties['extra']) { $t += Mc-Text $v.extra }
  $t
}
function Parse-TomlValue([string]$s) {
  $s = $s.Trim()
  if ($s -match '^\[(.*)\]$') { return ,@([regex]::Matches($Matches[1], '"((?:[^"\\]|\\.)*)"') | ForEach-Object { $_.Groups[1].Value }) }
  if ($s -match '^"(.*)"$') { return $Matches[1] }
  if ($s -match "^'(.*)'$") { return $Matches[1] }
  $s
}
function HtmlE([string]$s) { [Net.WebUtility]::HtmlEncode($s) }
# Значок shields.io: текст экранируется по правилам shields (- → --, _ → __)
function Shield-Text([string]$s) { $t = ($s -replace '-', '--') -replace '_', '__'; [uri]::EscapeDataString($t) }
function Md-Badge([string]$label, [string]$color, [string]$logo, [string]$url, [string]$message) {
  $u = "https://img.shields.io/badge/$(Shield-Text $label)" + $(if ($message) { "-$(Shield-Text $message)" } else { '' }) + "-$color" + $(if ($logo) { "?logo=$logo&logoColor=white" } else { '' })
  if ($url) { "[![$label]($u)]($url)" } else { "![$label]($u)" }
}
function Format-Mss($sec) { if ($null -eq $sec -or "$sec" -eq '') { return '—' }; $s = [int][Math]::Round([double]$sec); '{0}:{1:00}' -f [Math]::Floor($s / 60), ($s % 60) }
function Format-Hms($sec) { $s = [int][Math]::Round([double]$sec); $h = [Math]::Floor($s / 3600); $m = [Math]::Floor(($s % 3600) / 60); if (-not $h -and -not $m) { return "$s с" }; $(if ($h) { "$h ч " } else { '' }) + "$m мин" }
function Format-Size([int64]$n) { if ($n -ge 1MB) { '{0:0.0} МБ' -f ($n / 1MB) -replace '\.', ',' } elseif ($n -ge 1KB) { "$([Math]::Round($n / 1KB)) КБ" } else { "$n Б" } }

# --- Ресурспаки: zip и папки; название, ссылки, описание и заметки из карточек _Helpful Stuff\resourcepacks, запасное описание из pack.mcmeta.
# Возвращает @{ order = 'game'|'alpha'; packs = @(...) } — общие данные для Z@RYA.html и RESOURCEPACKS.md.
function Get-ResourcePacks([string]$root, [string]$cardsDir) {
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $enc = New-Object Text.UTF8Encoding($false)
  $rpDir = Join-Path $root 'minecraft\resourcepacks'
  $packs = @(); $rpCards = @{}
  if (Test-Path -LiteralPath $cardsDir) {
    foreach ($c in (Get-ChildItem -LiteralPath $cardsDir -Filter *.md | Where-Object { $_.Name -ne 'README.md' -and -not $_.Name.StartsWith('_') })) {
      $d = Parse-Card ([IO.File]::ReadAllText($c.FullName, $enc)); if ($d.fm.file) { $rpCards[[string]$d.fm.file] = @{ key = $c.BaseName; d = $d } }
    }
  }
  if (Test-Path -LiteralPath $rpDir) {
    foreach ($it in (Get-ChildItem -LiteralPath $rpDir | Where-Object { $_.PSIsContainer -or $_.Extension -eq '.zip' } | Sort-Object Name)) {
      $mcmeta = ''; $sz = 0
      try {
        if ($it.PSIsContainer) {
          $mp = Join-Path $it.FullName 'pack.mcmeta'; if (Test-Path -LiteralPath $mp) { $mcmeta = [IO.File]::ReadAllText($mp, $enc) }
          $sz = (Get-ChildItem -LiteralPath $it.FullName -Recurse -File | Measure-Object Length -Sum).Sum
        } else {
          $sz = $it.Length
          $z = [IO.Compression.ZipFile]::OpenRead($it.FullName)
          try {
            $e = $z.GetEntry('pack.mcmeta'); if ($e) { $sr = New-Object IO.StreamReader($e.Open(), $enc); $mcmeta = $sr.ReadToEnd(); $sr.Close() }
          } finally { $z.Dispose() }
        }
      } catch { Write-Warning "Ресурспак $($it.Name): $_" }
      $desc = ''
      if ($mcmeta) { try { $j = ($mcmeta.TrimStart([char]0xFEFF)) | ConvertFrom-Json; $desc = (Mc-Text $j.pack.description).Trim() } catch { } }
      $rc = $rpCards[$it.Name]; $f = @{}; $cd = ''; $cn = ''; $key = $it.Name
      if ($rc) { $f = $rc.d.fm; $key = $rc.key; $cd = Get-Section $rc.d.body 'Описание'; $cn = Get-Section $rc.d.body 'Заметки' }
      $short = if ($cd) { (($cd -replace '\s+', ' ').Trim() -split '(?<=[.!?])\s')[0] } else { $desc }
      $packs += [ordered]@{ key = $key; name = $(if ($f.name) { [string]$f.name } else { $it.Name }); file = $it.Name; kind = $(if ($it.PSIsContainer) { 'folder' } else { 'zip' }); size = [int64]$sz
        version = [string]$f.version; modrinth = [string]$f.modrinth; curseforge = [string]$f.curseforge; git = [string]$f.git; other = [string]$f.other
        short = $short; desc = $cd; notes = $cn; mcdesc = $desc; card = [bool]$rc }
    }
  }
  # Порядок ресурспаков. В options.txt resourcePacks идёт снизу вверх (первый грузится первым, последний — высший приоритет);
  # в игре список «Выбранные» показан наоборот: сверху последний из options.txt. Показываем как в игре, затем выключенные по алфавиту.
  # Нефайловые записи (vanilla, mod_resources и т. п.) не показываются.
  $packsOrder = 'alpha'
  $optionsPath = Join-Path $root 'minecraft\options.txt'
  if (Test-Path -LiteralPath $optionsPath) {
    $sel = @(); $inc = @(); $ok = $true
    foreach ($l in [IO.File]::ReadAllLines($optionsPath, $enc)) {
      if ($l -match '^(resourcePacks|incompatibleResourcePacks):(.*)$') {
        $k = $Matches[1]; $v = $Matches[2].Trim()
        try { $pj = if ($v) { ConvertFrom-Json $v } else { $null }; $arr = @($pj | Where-Object { $_ -is [string] }) } catch { $arr = @(); if ($k -eq 'resourcePacks') { $ok = $false }; Write-Warning "options.txt: не разобрано $k" }
        if ($k -eq 'resourcePacks') { $sel = $arr } else { $inc = $arr }
      }
    }
    if ($ok) {
      $packsOrder = 'game'
      $fileIds = @($sel | Where-Object { $_.StartsWith('file/') } | ForEach-Object { $_.Substring(5) } | Select-Object -Unique)
      [array]::Reverse($fileIds)
      $posMap = @{}; $n = 0; foreach ($id in $fileIds) { if (-not $posMap.ContainsKey($id)) { $n++; $posMap[$id] = $n } }
      $incMap = @{}; foreach ($id in $inc) { if ($id.StartsWith('file/')) { $incMap[$id.Substring(5)] = 1 } }
      $p2 = 0
      foreach ($pk in $packs) {
        if ($posMap.ContainsKey($pk.file)) { $pk.on = $true; $pk.pos = ++$p2; $pk._o = $posMap[$pk.file] } else { $pk.on = $false; $pk.pos = 0; $pk._o = 100000 }
        $pk.incompat = [bool]$incMap[$pk.file]
      }
      $packs = @($packs | Sort-Object { $_._o }, { $_.name.ToLowerInvariant() })
      $i = 0; foreach ($pk in $packs) { $pk.Remove('_o'); if ($pk.on) { $i++; $pk.pos = $i } }
    }
  }
  if ($packsOrder -eq 'alpha') { $packs = @($packs | Sort-Object { $_.name.ToLowerInvariant() }) }
  @{ order = $packsOrder; packs = @($packs) }
}

function Get-AudioDuration([string]$path) {
  # Длительность в секундах (double) или $null. OGG (Vorbis/Opus) и MP3 — без внешних зависимостей.
  $fs = $null
  try {
    $fs = [IO.File]::Open($path, 'Open', 'Read', 'ReadWrite')
    $len = $fs.Length; if ($len -lt 64) { return $null }
    $hn = [int][Math]::Min($len, 65536); $head = New-Object byte[] $hn; [void]$fs.Read($head, 0, $hn)
    if ($head[0] -eq 0x4F -and $head[1] -eq 0x67 -and $head[2] -eq 0x67 -and $head[3] -eq 0x53) {
      # OGG: частота из identification header первой страницы, длина — granule position последней страницы
      $segs = $head[26]; $p = 27 + $segs; $rate = 0; $pre = 0
      if ($head[$p] -eq 1 -and [Text.Encoding]::ASCII.GetString($head, $p + 1, 6) -eq 'vorbis') { $rate = [BitConverter]::ToUInt32($head, $p + 12) }
      elseif ([Text.Encoding]::ASCII.GetString($head, $p, 8) -eq 'OpusHead') { $rate = 48000; $pre = [BitConverter]::ToUInt16($head, $p + 10) }
      if ($rate -le 0) { return $null }
      $tn = [int][Math]::Min($len, 131072); $tail = New-Object byte[] $tn
      [void]$fs.Seek($len - $tn, 'Begin'); $got = 0; while ($got -lt $tn) { $r = $fs.Read($tail, $got, $tn - $got); if ($r -le 0) { break }; $got += $r }
      for ($i = $tn - 27; $i -ge 0; $i--) {
        if ($tail[$i] -eq 0x4F -and $tail[$i + 1] -eq 0x67 -and $tail[$i + 2] -eq 0x67 -and $tail[$i + 3] -eq 0x53 -and $tail[$i + 4] -eq 0) {
          $g = [BitConverter]::ToInt64($tail, $i + 6); if ($g -gt 0) { return [double]($g - $pre) / $rate }
        }
      }
      return $null
    }
    # MP3: пропустить ID3v2, найти первый кадр; Xing/Info/VBRI → число кадров, иначе CBR по битрейту
    $off = 0
    if ($head[0] -eq 0x49 -and $head[1] -eq 0x44 -and $head[2] -eq 0x33) {
      $off = 10 + (([int]$head[6] -band 0x7F) -shl 21) + (([int]$head[7] -band 0x7F) -shl 14) + (([int]$head[8] -band 0x7F) -shl 7) + ($head[9] -band 0x7F)
      if ($head[5] -band 0x10) { $off += 10 }
    }
    if ($off -ge $len) { return $null }
    $bn = [int][Math]::Min($len - $off, 131072); $b = New-Object byte[] $bn
    [void]$fs.Seek($off, 'Begin'); $got = 0; while ($got -lt $bn) { $r = $fs.Read($b, $got, $bn - $got); if ($r -le 0) { break }; $got += $r }
    $BR = @{ '3-3' = @(0,32,64,96,128,160,192,224,256,288,320,352,384,416,448); '3-2' = @(0,32,48,56,64,80,96,112,128,160,192,224,256,320,384); '3-1' = @(0,32,40,48,56,64,80,96,112,128,160,192,224,256,320); '2-3' = @(0,32,48,56,64,80,96,112,128,144,160,176,192,224,256); '2-2' = @(0,8,16,24,32,40,48,56,64,80,96,112,128,144,160) }
    $SR = @{ 3 = @(44100,48000,32000); 2 = @(22050,24000,16000); 0 = @(11025,12000,8000) }
    $hdr = {
      param($j)
      if ($j + 4 -gt $bn) { return $null }
      if ($b[$j] -ne 0xFF -or ($b[$j + 1] -band 0xE0) -ne 0xE0) { return $null }
      $ver = ($b[$j + 1] -shr 3) -band 3; $lay = ($b[$j + 1] -shr 1) -band 3; $bi = $b[$j + 2] -shr 4; $si = ($b[$j + 2] -shr 2) -band 3
      if ($ver -eq 1 -or $lay -eq 0 -or $bi -eq 0 -or $bi -eq 15 -or $si -eq 3) { return $null }
      $vk = if ($ver -eq 3) { 3 } else { 2 }; $lk = if ($vk -eq 2 -and $lay -eq 1) { 2 } else { $lay }
      $kbps = $BR["$vk-$lk"][$bi]; $sr = $SR[$ver][$si]; $pad = ($b[$j + 2] -shr 1) -band 1
      $spf = if ($lay -eq 3) { 384 } elseif ($lay -eq 2 -or $ver -eq 3) { 1152 } else { 576 }
      $flen = if ($lay -eq 3) { [int][Math]::Floor(12 * $kbps * 1000 / $sr + $pad) * 4 } else { [int][Math]::Floor(($spf / 8) * $kbps * 1000 / $sr) + $pad }
      @{ ver = $ver; lay = $lay; kbps = $kbps; sr = $sr; spf = $spf; flen = $flen; mono = ((($b[$j + 3] -shr 6) -band 3) -eq 3) }
    }
    for ($j = 0; $j -lt $bn - 4; $j++) {
      $h = & $hdr $j; if (-not $h -or $h.flen -le 4) { continue }
      $n = & $hdr ($j + $h.flen); if (-not $n -and $j + $h.flen + 4 -le $bn) { continue }
      $xo = $j + 4 + $(if ($h.ver -eq 3) { if ($h.mono) { 17 } else { 32 } } else { if ($h.mono) { 9 } else { 17 } })
      if ($xo + 12 -le $bn) {
        $tag = [Text.Encoding]::ASCII.GetString($b, $xo, 4)
        if (($tag -eq 'Xing' -or $tag -eq 'Info') -and ($b[$xo + 7] -band 1)) {
          $fr = ([int64]$b[$xo + 8] -shl 24) + ([int]$b[$xo + 9] -shl 16) + ([int]$b[$xo + 10] -shl 8) + $b[$xo + 11]
          if ($fr -gt 0) { return [double]$fr * $h.spf / $h.sr }
        }
      }
      $vo = $j + 36
      if ($vo + 18 -le $bn -and [Text.Encoding]::ASCII.GetString($b, $vo, 4) -eq 'VBRI') {
        $fr = ([int64]$b[$vo + 14] -shl 24) + ([int]$b[$vo + 15] -shl 16) + ([int]$b[$vo + 16] -shl 8) + $b[$vo + 17]
        if ($fr -gt 0) { return [double]$fr * $h.spf / $h.sr }
      }
      $audio = $len - $off - $j
      [void]$fs.Seek($len - 128, 'Begin'); $t3 = New-Object byte[] 3; [void]$fs.Read($t3, 0, 3)
      if ([Text.Encoding]::ASCII.GetString($t3) -eq 'TAG') { $audio -= 128 }
      return [double]$audio * 8 / ($h.kbps * 1000)
    }
    return $null
  } catch { return $null } finally { if ($fs) { $fs.Dispose() } }
}

# --- Music Triggers: подписи событий и пояснения параметров (по документации и исходникам Music Triggers 7.0.4:
# docs/musictriggers/triggers/*.mdx, lang/en_us.json, MTConfigV6.java). Общие для Z@RYA.html и MUSIC.md.
# $mtParams: имя = @(название, пояснение (можно <code>), единицы и значение по умолчанию).
$mtTypeNames = [ordered]@{
  height = 'Высота'
  biome = 'Биом'
  time = 'Время суток'
  bloodmoon = 'Кровавая луна'
  mob = 'Мобы'
  dimension = 'Измерение'
  dead = 'Смерть'
  riding = 'Езда верхом'
  menu = 'Главное меню'
  universal = 'Общие настройки'
  structure = 'Структура'
  raid = 'Рейд'
  underwater = 'Под водой'
  elytra = 'Элитры'
  fishing = 'Рыбалка'
  pvp = 'PvP'
  lowhp = 'Мало здоровья'
}
$mtTypeDesc = [ordered]@{
  height = 'Игрок находится на высоте, заданной level'
  biome = 'Биом под игроком подходит под условия'
  time = 'Время суток / номер дня / фаза луны подходят под условия'
  bloodmoon = 'Идёт кровавая луна (нужен мод с кровавой луной)'
  mob = 'Рядом достаточно подходящих мобов'
  dimension = 'Игрок в подходящем измерении'
  dead = 'Игрок мёртв'
  riding = 'Игрок едет верхом на подходящем существе'
  menu = 'Открыт главный экран до входа в мир'
}
$mtParams = [ordered]@{
  identifier = @('Идентификатор', 'Уникальное имя этого экземпляра события (нужно, когда событий одного типа несколько: biome, mob, dimension, riding, time, height…). На условия срабатывания не влияет — только группирует параметры и даёт ссылку вида <code>biome-ocean</code>, по которой к событию привязываются треки.', 'строка; обязателен для таких событий')
  priority = @('Приоритет', 'Приоритет относительно других событий, которые подходят одновременно: по умолчанию играет событие с наибольшим приоритетом. Если событий несколько (комбинация), общие параметры вроде fade_out берутся у события с наибольшим приоритетом.', 'число; по умолчанию своё для каждого типа события')
  fade_in = @('Нарастание', 'Сколько тиков звук плавно нарастает после того, как событие стало активным.', 'тики (20 тиков = 1 с); по умолчанию 0')
  fade_out = @('Затухание', 'Сколько тиков звук плавно затухает, когда событие перестало быть активным.', 'тики (20 тиков = 1 с); по умолчанию 0')
  level = @('Уровень (height)', 'Для события height: Y-координата игрока должна быть больше этого значения (при check_above_level = true — меньше). При check_for_sky = true (по умолчанию) над игроком ещё и не должно быть видно неба — так получается «под землёй».', 'блоки (Y); по умолчанию 0')
  biome_category = @('Категория биома', 'Устаревшее имя параметра из Music Triggers 6.x; в 7.x автоматически переименовывается в <code>biome_tag</code>. Категория/тег биома под игроком должен совпасть с одним из значений списка по правилу biome_tag_matcher.', 'список строк; по умолчанию [any]')
  biome_tag = @('Тег биома', 'Категория/тег биома под игроком должен совпасть с одним из значений списка по правилу biome_tag_matcher.', 'список строк; по умолчанию [any]')
  biome_tag_matcher = @('Сравнение тега биома', 'Как сравнивать biome_tag (biome_category): exact — точное совпадение, partial — частичное (подстрока), regex — регулярное выражение.', 'exact / partial / regex; по умолчанию exact')
  song_delay = @('Пауза между треками', 'Устаревшее имя из 6.x; в 7.x — <code>ticks_between_audio</code>: сколько тиков ждать после окончания трека, прежде чем заиграет следующий из пула.', 'тики (20 тиков = 1 с); по умолчанию 0')
  ticks_between_audio = @('Пауза между треками', 'Сколько тиков ждать после окончания трека, прежде чем заиграет следующий из пула.', 'тики (20 тиков = 1 с); по умолчанию 0')
  trigger_delay = @('Задержка звука', 'Устаревшее имя из 6.x; в 7.x — <code>ticks_before_audio</code>: сколько тиков после активации события пройдёт, прежде чем начнётся звук.', 'тики (20 тиков = 1 с); по умолчанию 0')
  ticks_before_audio = @('Задержка звука', 'Сколько тиков после активации события пройдёт, прежде чем начнётся звук.', 'тики (20 тиков = 1 с); по умолчанию 0')
  start_delay = @('Задержка активации', 'Устаревшее имя из 6.x; в 7.x — <code>ticks_before_active</code>: сколько тиков условия должны выполняться, прежде чем событие станет активным.', 'тики (20 тиков = 1 с); по умолчанию 0')
  ticks_before_active = @('Задержка активации', 'Сколько тиков после выполнения условий пройдёт, прежде чем событие станет активным (или доступным, если оно не самое приоритетное).', 'тики (20 тиков = 1 с); по умолчанию 0')
  stop_delay = @('Перезарядка', 'Устаревшее имя из 6.x; в 7.x — <code>active_cooldown</code>: сколько тиков событие не может снова активироваться после того, как отключилось.', 'тики (20 тиков = 1 с); по умолчанию 0')
  active_cooldown = @('Перезарядка', 'Сколько тиков событие не может снова активироваться после того, как отключилось.', 'тики (20 тиков = 1 с); по умолчанию 0')
  persistence = @('Удержание', 'Сколько тиков событие остаётся доступным после того, как его условия перестали выполняться.', 'тики (20 тиков = 1 с); по умолчанию 0')
  time_bundle = @('Период суток', 'Готовый диапазон времени: night, day, sunrise или sunset (параметры start_hour/end_hour тогда игнорируются). Любое другое значение, например any, отключает его.', 'night / day / sunrise / sunset; по умолчанию any')
  detection_range = @('Радиус обнаружения', 'Радиус вокруг игрока, в котором ищутся подходящие мобы. По вертикали проверяется доля этого радиуса (detection_y_ratio, по умолчанию 0.5).', 'блоки; по умолчанию 16')
  mob_targeting = @('Моб нацелен на игрока', 'Нужно ли, чтобы моб целился в игрока, чтобы событие сработало. В творческом режиме и режиме наблюдателя мобы игрока не выбирают целью.', 'true / false; по умолчанию true')
  resource_name = @('ID ресурса', 'ID (resource name) моба / измерения / транспорта должен совпасть с одним из значений списка по правилу resource_matcher. Особое значение <code>MOB</code> (по исходникам) — любой враждебный моб.', 'список строк; по умолчанию [any]')
  resource_matcher = @('Сравнение ID', 'Как сравнивать resource_name: exact — точно, partial — частично (подстрока), regex — регулярное выражение.', 'exact / partial / regex; по умолчанию partial')
  play_once = @('Однократный трек', 'Что происходит после проигрывания трека: 0 — ничего; 1 — не повторяется, пока не сыграют все треки пула или событие не отключится; 2 — пока событие не отключится; 3 — до выхода из мира; 4 — только один раз за мир (даже после перезапусков); 5 — до перезапуска игры.', '0–5; по умолчанию 0')
  triggers = @('События трека', 'События, к которым привязан трек. Если указано несколько — должны выполняться все сразу (И); для «ИЛИ» добавляют ещё одну запись трека.', 'список; по умолчанию []')
}
# Параметры во времени (тики, 20 тиков = 1 с)
$mtTickParams = @('fade_in', 'fade_out', 'song_delay', 'ticks_between_audio', 'trigger_delay', 'ticks_before_audio', 'start_delay', 'ticks_before_active', 'stop_delay', 'active_cooldown', 'persistence')

# --- Музыка: файлы из MusicTriggers\songs (папка данных Music Triggers) + события из general\main.toml.
# Возвращает [ordered]@{ parsed; triggers; tracks; missing; info } — общие данные для Z@RYA.html и MUSIC.md.
function Get-MusicData([string]$root) {
  $enc = New-Object Text.UTF8Encoding($false)
  $mtDir = Join-Path $root 'minecraft\config\MusicTriggers'
  $musicDir = Join-Path $mtDir 'songs'
  $tracks = @(); $trigs = New-Object System.Collections.ArrayList; $trackMap = @{}; $trackOnce = @{}; $parsed = $false; $missing = @()
  $mainToml = Join-Path $mtDir 'general\main.toml'; if (-not (Test-Path -LiteralPath $mainToml)) { $mainToml = Join-Path $mtDir 'main.toml' }
  if (Test-Path -LiteralPath $mainToml) {
    try {
      $cur = $null; $curTrack = $null
      foreach ($raw in [IO.File]::ReadAllLines($mainToml, $enc)) {
        $l = $raw.Trim(); if (-not $l -or $l.StartsWith('#')) { continue }
        if ($l -match '^\[\[?\s*([^\[\]]+?)\s*\]\]?$') {
          $sec = $Matches[1]; $cur = $null; $curTrack = $null
          if ($sec -match '^triggers\.([\w-]+)$') { $cur = [ordered]@{ key = ''; type = $Matches[1]; id = ''; priority = ''; params = [ordered]@{} }; [void]$trigs.Add($cur) }
          elseif ($sec -match '^songs\.(.+)$') { $curTrack = $Matches[1]; if (-not $trackMap.ContainsKey($curTrack)) { $trackMap[$curTrack] = New-Object System.Collections.ArrayList } }
          continue
        }
        if ($l -match '^([\w.-]+)\s*=\s*(.+)$') {
          $k = $Matches[1]; $v = Parse-TomlValue $Matches[2]
          if ($cur) { if ($k -eq 'identifier') { $cur.id = [string]$v } elseif ($k -eq 'priority') { $cur.priority = [string]$v } else { $cur.params[$k] = $v } }
          elseif ($curTrack) {
            if ($k -eq 'triggers') { foreach ($t in @($v)) { if (-not $trackMap[$curTrack].Contains($t)) { [void]$trackMap[$curTrack].Add($t) } } }
            elseif ($k -eq 'play_once') { $trackOnce[$curTrack] = [string]$v }
          }
        }
      }
      foreach ($t in $trigs) { $t.key = if ($t.id) { "$($t.type)-$($t.id)" } else { $t.type } }
      $parsed = $true
    } catch { Write-Warning "main.toml не разобран: $_"; $trigs.Clear(); $trackMap = @{}; $parsed = $false }
  }
  if (Test-Path -LiteralPath $musicDir) {
    $files = @(Get-ChildItem -LiteralPath $musicDir -File | Where-Object { $_.Extension -eq '.ogg' -or $_.Extension -eq '.mp3' } | Sort-Object Name)
    $stems = @{}; foreach ($f in $files) { $stems[$f.BaseName] = 1 }
    foreach ($f in $files) {
      $title = (($f.BaseName -split '_+') | Where-Object { $_ } | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) }) -join ' '
      $tr = @(if ($trackMap.ContainsKey($f.BaseName)) { $trackMap[$f.BaseName] })
      $dur = Get-AudioDuration $f.FullName; if ($dur -ne $null) { $dur = [Math]::Round([double]$dur, 1) }
      $tracks += [ordered]@{ file = $f.Name; title = $title; size = [int64]$f.Length; dur = $dur; triggers = [object[]]$tr; playOnce = [string]$trackOnce[$f.BaseName] }
    }
    # [songs.universal] — служебная запись Music Triggers (общие настройки), не трек
    $missing = @($trackMap.Keys | Where-Object { $_ -ne 'universal' -and -not $stems[$_] } | Sort-Object)
  }
  [ordered]@{ parsed = $parsed; triggers = @($trigs); tracks = $tracks; missing = $missing; info = [ordered]@{ tn = $mtTypeNames; td = $mtTypeDesc; pd = $mtParams; tick = $mtTickParams } }
}
