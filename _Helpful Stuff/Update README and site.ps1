# README.md (NFO-шапка) и страница сборки Z@RYA.html + index.html — одним скриптом.
# 1) Шапка README.md: ASCII-блок ```text между <!-- ZARYA-HEADER:BEGIN --> и <!-- ZARYA-HEADER:END -->:
#    название и версия сборки, Minecraft, NeoForge, число модов, скрипты (KubeJS/LootJS/MoreJS), дата.
#    Источники: instance.cfg и mmc-pack.json (Get-PackInfo), minecraft\mods.
#    Меняются только строки-поля внутри рамки; ширина и выравнивание сохраняются; файл пишется, только если что-то изменилось.
#    Кодировка (BOM или без) и переводы строк (CRLF/LF) сохраняются.
# 2) _Helpful Stuff\Z@RYA.html: один офлайн-файл (без внешних CSS/JS/шрифтов) + index.html в корне инстанса с переадресацией на неё
#    (GitHub Pages; в корне нужен пустой .nojekyll — иначе Jekyll не публикует папки, начинающиеся с «_»; скрипт создаёт его сам).
#    Вкладки: Главная / Установка / Помощь (тексты из README.md), Моды (карточки mods/*.md), Ресурспаки, Музыка.
# Вызывается из Update mods.ps1, Update resourcepacks.ps1, Update music.ps1; можно запускать отдельно.
# -NoReadme — не трогать README.md; -NoSite — не собирать Z@RYA.html/index.html; -OutFile — собрать страницу в другой файл (без index.html).
# Пути считаются от папки скрипта: корень инстанса = родитель папки скрипта.
param([switch]$NoReadme, [switch]$NoSite, [string]$OutFile)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')
$root = Split-Path -Parent $PSScriptRoot

# ================= 1. NFO-шапка README.md =================
function Update-ReadmeHeader([string]$root) {
  $readmePath = Join-Path $root 'README.md'
  if (-not (Test-Path -LiteralPath $readmePath)) { Write-Warning ("README.md: " + "Нет файла: $readmePath"); return }
  $BEGIN = '<!-- ZARYA-HEADER:BEGIN -->'; $END = '<!-- ZARYA-HEADER:END -->'

  # --- данные ---
  $pi = Get-PackInfo $root
  $packName = ($pi.name -replace '\s*\(\d+(\.\d+)+\)', '' -replace '\s*\br\d+\.\d+\.\d+\b', '').Trim(); if (-not $packName) { $packName = 'Z@RYA Deep Dark Fantasies' }
  $modsDir = Join-Path $root 'minecraft\mods'
  $jars = @(if (Test-Path -LiteralPath $modsDir) { Get-ChildItem -LiteralPath $modsDir -File -Filter *.jar })
  $scripts = @(@('kubejs', 'KubeJS'), @('lootjs', 'LootJS'), @('morejs', 'MoreJS') | Where-Object { $p = $_[0]; @($jars | Where-Object { $_.Name -match "^(?i)$p[-_ ]" }).Count } | ForEach-Object { $_[1] }) -join ' + '
  if (-not $scripts) { $scripts = '-' }
  $fields = [ordered]@{
    'PACK'      = $packName
    'VERSION'   = $(if ($pi.version) { $pi.version } else { '-' })
    'MINECRAFT' = $pi.mc
    'LOADER'    = $(if ($pi.neo) { "NeoForge $($pi.neo)" } else { '-' })
    'MODS'      = "$($jars.Count)"
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
    if (-not $m.Success) { Write-Warning ("README.md: " + 'В README.md нет блока ```text с шапкой'); return }
    $txt = $txt.Substring(0, $m.Index) + "$BEGIN`n" + $m.Value + "`n$END" + $txt.Substring($m.Index + $m.Length)
  }
  $bi = $txt.IndexOf($BEGIN); $ei = $txt.IndexOf($END, $bi)
  if ($ei -lt 0) { Write-Warning ("README.md: " + "Нет маркера $END"); return }
  $block = $txt.Substring($bi, $ei - $bi)
  $lines = [Collections.Generic.List[string]]($block -split "`n")
  # Строки-поля рамки: <отступ>+<ключ справа> : <значение>+ ; строки-разделители: <отступ>+--- - - ... +
  $rowRe = '^(\s*\+)(\s*)([A-Z][A-Z .]*?) : (.*?)\+$'
  $idx = @(for ($k = 0; $k -lt $lines.Count; $k++) { if ($lines[$k] -match $rowRe) { $k } })
  if (-not $idx.Count) { Write-Warning ("README.md: " + 'В шапке нет строк вида «KEY : value»'); return }
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
}
if (-not $NoReadme) { Update-ReadmeHeader $root }
if ($NoSite) { return }

# ================= 2. Страница сборки Z@RYA.html =================
Add-Type -AssemblyName System.IO.Compression.FileSystem
$enc = New-Object Text.UTF8Encoding($false)
$outPath = if ($OutFile) { $OutFile } else { Join-Path $root '_Helpful Stuff\Z@RYA.html' }
$cardsDir = Join-Path $PSScriptRoot 'mods'
$modsDir = Join-Path $root 'minecraft\mods'
$rpCardsDir = Join-Path $PSScriptRoot 'resourcepacks'

function Url-Path([string]$rel) { (($rel -split '[\\/]') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/' }
function Data-Uri([byte[]]$b) {
  if (-not $b -or $b.Length -lt 8) { return '' }
  $mime = if ($b[0] -eq 0x89 -and $b[1] -eq 0x50 -and $b[2] -eq 0x4E -and $b[3] -eq 0x47) { 'image/png' }
    elseif ($b[0] -eq 0xFF -and $b[1] -eq 0xD8) { 'image/jpeg' }
    elseif ($b[0] -eq 0x47 -and $b[1] -eq 0x49 -and $b[2] -eq 0x46) { 'image/gif' } else { '' }
  if ($mime) { "data:$mime;base64," + [Convert]::ToBase64String($b) } else { '' }
}
# Масштабирование иконки (HighQualityBicubic) до $size по большей стороне — для чёткой картинки на HiDPI; при ошибке — исходные байты
function Resize-Image([byte[]]$b, [int]$size) {
  try {
    Add-Type -AssemblyName System.Drawing
    $ms = New-Object IO.MemoryStream(, $b); $src = [Drawing.Image]::FromStream($ms)
    try {
      $k = $size / [Math]::Max($src.Width, $src.Height)
      $w = [Math]::Max(1, [int][Math]::Round($src.Width * $k)); $h = [Math]::Max(1, [int][Math]::Round($src.Height * $k))
      if ($w -eq $src.Width -and $h -eq $src.Height) { return ,$b }
      $bmp = New-Object Drawing.Bitmap($w, $h, [Drawing.Imaging.PixelFormat]::Format32bppPArgb)
      $g = [Drawing.Graphics]::FromImage($bmp)
      $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $g.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
      $g.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
      $g.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
      $ia = New-Object Drawing.Imaging.ImageAttributes; $ia.SetWrapMode([Drawing.Drawing2D.WrapMode]::TileFlipXY)
      $g.DrawImage($src, (New-Object Drawing.Rectangle(0, 0, $w, $h)), 0, 0, $src.Width, $src.Height, [Drawing.GraphicsUnit]::Pixel, $ia)
      $g.Dispose(); $ia.Dispose()
      $out = New-Object IO.MemoryStream; $bmp.Save($out, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
      return ,$out.ToArray()
    } finally { $src.Dispose(); $ms.Dispose() }
  } catch { Write-Warning "Иконка: не удалось масштабировать ($($_.Exception.Message)), используется исходная"; return ,$b }
}

# --- Сведения о сборке ---
$pi = Get-PackInfo $root
$repoUrl = Get-RepoUrl $root
$pack = [ordered]@{ name = 'Z@RYA Deep Dark Fantasies'; version = $pi.version; mc = $pi.mc; neo = $pi.neo; repo = $repoUrl; repoLabel = (Get-RepoLabel $repoUrl); date = (Get-Date -Format 'yyyy-MM-dd HH:mm') }
# Путь от страницы к корню инстанса (для относительных ссылок README): _Helpful Stuff\Z@RYA.html -> '../'
$siteDir = Split-Path -Parent ([IO.Path]::GetFullPath($outPath)); $rootDir = [IO.Path]::GetFullPath($root).TrimEnd('\')
$pack['base'] = if ($siteDir.TrimEnd('\') -ieq $rootDir) { '' } else { (New-Object Uri(($siteDir.TrimEnd('\') + '\'))).MakeRelativeUri((New-Object Uri($rootDir + '\'))).ToString() }

# --- README: ASCII-шапка отдельно, комментарии (<!-- TODO … -->) вырезаются ---
$readme = ''; $header = ''
$readmePath = Join-Path $root 'README.md'
if (Test-Path -LiteralPath $readmePath) {
  $readme = [IO.File]::ReadAllText($readmePath, $enc) -replace '\r', ''
  $hm = [regex]::Match($readme, '(?s)```text\n(.*?)\n```')
  if ($hm.Success) { $header = [Net.WebUtility]::HtmlEncode($hm.Groups[1].Value); $readme = $readme.Remove($hm.Index, $hm.Length) }
  $readme = $readme -replace '(?s)<!--.*?-->', ''
  # Раздел со ссылками на списки — на странице не нужен (всё есть во вкладках); README.md не меняется
  $readme = $readme -replace '(?ms)^##[ \t]+Список модификаций и прочее[ \t]*\n.*?(?=^#{1,2}[ \t]|\z)', ''
  # Ссылка README → HTML-версия (GitHub Pages) на самой странице не нужна
  $readme = (($readme -split '\n') | Where-Object { $_ -notmatch '^\s*(TODO|ToDo)\b' -and $_ -notmatch '^\s*>.*\]\(https?://[^)]*\.github\.io/' } | ForEach-Object { $_.TrimEnd() }) -join "`n"
  $readme = $readme.Trim()
}

# --- Иконка: <лаунчер>\icons\<iconKey> (PNG/JPEG/GIF) ---
$icon = ''; $heroSrc = ''; $brandSrc = ''
if ($pi.iconKey) {
  $iconsDir = Join-Path (Split-Path -Parent (Split-Path -Parent $root)) 'icons'
  foreach ($n in @($pi.iconKey, "$($pi.iconKey).png", "$($pi.iconKey).jpg")) {
    $p = Join-Path $iconsDir $n
    if (Test-Path -LiteralPath $p -PathType Leaf) {
      $ib = [IO.File]::ReadAllBytes($p); $icon = Data-Uri $ib
      # Исходник не меняется; для страницы — копии 2x от размера показа (96 и 28 px)
      if ($icon) { $heroSrc = Data-Uri (Resize-Image $ib 192); $brandSrc = Data-Uri (Resize-Image $ib 56); break }
    }
  }
}

# --- Моды: карточки, у которых есть jar в minecraft\mods ---
$jarNames = @{}
if (Test-Path -LiteralPath $modsDir) { foreach ($j in (Get-ChildItem -LiteralPath $modsDir -File -Filter *.jar)) { $jarNames[$j.Name] = 1 } }
$mods = @()
foreach ($c in (Get-ChildItem -LiteralPath $cardsDir -Filter *.md | Where-Object { $_.Name -ne 'README.md' -and -not $_.Name.StartsWith('_') })) {
  $d = Parse-Card ([IO.File]::ReadAllText($c.FullName, $enc)); $f = $d.fm
  if ($jarNames.Count -and -not $jarNames[[string]$f.file]) { continue }
  $ds = Get-Section $d.body 'Описание'
  $short = (($ds -replace '\s+', ' ').Trim() -split '(?<=[.!?])\s')[0]
  $mods += [ordered]@{ key = $c.BaseName; name = [string]$f.name; modid = [string]$f.modid; version = [string]$f.version; file = [string]$f.file
    category = $(if ($f.category) { [string]$f.category } else { $noCategory }); modrinth = [string]$f.modrinth; curseforge = [string]$f.curseforge; git = [string]$f.git
    short = $short; desc = $ds; notes = (Get-Section $d.body 'Заметки') }
}
$mods = @($mods | Sort-Object { $_.name })
$cats = @(Get-CategoryOrder @($mods | ForEach-Object { $_.category }) | ForEach-Object { [ordered]@{ name = $_.name; icon = $_.icon; id = $_.id } })

# --- Ресурспаки и порядок из options.txt — Get-ResourcePacks в _common.ps1 ---
$rpData = Get-ResourcePacks $root $rpCardsDir; $packs = @($rpData.packs); $packsOrder = $rpData.order


# --- Музыка: файлы и события Music Triggers — Get-MusicData в _common.ps1 ---
$music = Get-MusicData $root

# --- Сборка страницы ---
$data = [ordered]@{ pack = $pack; cats = $cats; mods = $mods; packs = $packs; packsOrder = $packsOrder; music = $music; readme = $readme }
$json = ConvertTo-Json -InputObject $data -Compress -Depth 8
$json = $json -replace '<', '\u003c' -replace '>', '\u003e' -replace '&', '\u0026'
$title = "Z@RYA Deep Dark Fantasies$(if ($pi.version) { " $($pi.version)" }) — страница сборки"
$brandIcon = if ($brandSrc) { "<img src=`"$brandSrc`" alt=`"`">" } else { '' }
$heroIcon = if ($heroSrc) { "<img class=`"icon`" src=`"$heroSrc`" alt=`"Z@RYA`">" } else { '' }
$html = @'
<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>__TITLE__</title>
<link rel="icon" href="__ICON__">
<script>/* выбор вкладки до первой отрисовки — без «прыжка» футера */(function(){var T=['home','install','help','mods','packs','music'],h='',d=document.documentElement;try{h=decodeURIComponent(location.hash.replace(/^#/,''));}catch(e){}var t=T.indexOf(h)>=0?h:(h?'':'home');window.__T=t;d.setAttribute('data-t',t||'?');d.classList.add('boot');var M='auto';try{localStorage.removeItem('zarya-theme');M=localStorage.getItem('zarya-theme2')||'auto';}catch(e){}if(!/^(day|night|auto)$/.test(M))M='auto';var CY=120000,ph=function(){return (Date.now()%CY)/CY;},ss=function(a,b,x){x=Math.min(1,Math.max(0,(x-a)/(b-a)));return x*x*(3-2*x);},kk=function(p){return ss(0,.075,p)-ss(.5,.575,p);};window.__TH={CY:CY,ph:ph,k:kk};var K=M==='day'?1:M==='night'?0:kk(ph());if(M==='auto'&&window.matchMedia&&matchMedia('(prefers-reduced-motion: reduce)').matches)K=K>=.5?1:0;d.setAttribute('data-theme',M);d.style.setProperty('--dk',K.toFixed(3));if(K>=.5)d.classList.add('day');if(t==='home')d.classList.add('home');if(/^(mods|packs|music)$/.test(t))d.classList.add('fit');})();</script>
<style>
:root{--fh:clamp(72px,24vh,170px);--dk:0;--bg:#0b0a0f;--panel:#14121b;--panel2:#1b1824;--line:#2a2535;--text:#d9d4e3;--dim:#8a8299;--acc:#c9a227;--acc2:#8b5cf6;--red:#b5302f;--nav:52px}
*{box-sizing:border-box}
html{scroll-padding-top:calc(var(--nav) + 12px)}
html,body{margin:0;background:radial-gradient(ellipse at top,#1a1426 0%,var(--bg) 60%) fixed;color:var(--text);font:15px/1.55 "Segoe UI",Tahoma,system-ui,sans-serif}
a{color:#b79cff;text-decoration:none}a:hover{text-decoration:underline}
code{background:#221d2d;padding:1px 5px;border-radius:4px;font:13px Consolas,"Courier New",monospace;color:#e6c86e}
/* навигация */
nav.top{position:sticky;top:0;z-index:10;height:var(--nav);display:flex;align-items:center;gap:6px;padding:0 18px;background:rgba(11,10,15,.92);backdrop-filter:blur(6px);border-bottom:1px solid var(--line)}
nav.top .brand{display:flex;align-items:center;gap:8px;margin-right:12px;color:#e8dcb5;font:600 15px Georgia,"Times New Roman",serif;letter-spacing:.18em;white-space:nowrap}
nav.top .brand img{width:28px;height:28px;object-fit:contain;border-radius:6px;image-rendering:auto}
nav.top .tabs{display:flex;gap:2px;overflow-x:auto;flex:1}
nav.top .tabs a{padding:7px 12px;border-radius:7px;color:var(--dim);white-space:nowrap;font-size:14px}
nav.top .tabs a:hover{color:var(--text);background:var(--panel2);text-decoration:none}
nav.top .tabs a.on{color:#fff;background:var(--panel2);box-shadow:inset 0 -2px 0 var(--acc)}
nav.top .tabs a i{font-style:normal;opacity:.55;margin-left:4px;font-size:12px}
nav.top a.gh{color:var(--acc);white-space:nowrap;font-size:14px}
a.gh svg{width:14px;height:14px;vertical-align:-2px;margin-right:4px;fill:currentColor}
.wrap{max-width:1180px;margin:0 auto;padding:22px 20px 60px}
.tab{display:none}.tab.on{display:block}
/* главная */
.hero{text-align:center;margin-bottom:22px}
.hero img.icon{width:96px;height:96px;object-fit:contain;border-radius:16px;image-rendering:auto;filter:drop-shadow(0 0 14px rgba(201,162,39,.3));margin-bottom:10px}
pre.ascii{margin:0 auto 6px;width:max-content;max-width:100%;overflow-x:auto;color:var(--acc);font:12px/1.15 Consolas,"Courier New",monospace;text-shadow:0 0 6px rgba(201,162,39,.35);text-align:left}
h1.title{margin:6px 0 2px;text-align:center;font:600 26px/1.2 Georgia,"Times New Roman",serif;letter-spacing:.35em;color:#e8dcb5}
.sub{text-align:center;color:var(--dim);letter-spacing:.06em}
.sub b{color:var(--acc)}
.sub a.gh{color:var(--acc);white-space:nowrap}.sub a.gh:hover{color:#fff;text-decoration:none}
.tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:12px;margin:22px 0 8px}
.tile{display:block;padding:14px 16px;background:var(--panel);border:1px solid var(--line);border-radius:10px;color:var(--text)}
.tile:hover{border-color:var(--acc2);text-decoration:none}
.tile b{display:block;font:600 24px Georgia,serif;color:var(--acc)}
.tile span{color:var(--dim);font-size:13px}
/* текст из README */
.doc{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:6px 28px 22px;margin-top:16px}
.doc h1,.doc h2{margin:22px 0 8px;padding-bottom:6px;border-bottom:1px solid var(--line);font:600 21px/1.3 Georgia,"Times New Roman",serif;color:#e8dcb5;letter-spacing:.04em}
.doc h3{margin:20px 0 6px;font:600 17px/1.3 "Segoe UI",sans-serif;color:var(--acc)}
.doc h4,.doc h5,.doc h6{margin:16px 0 4px;color:var(--acc)}
.doc p{margin:8px 0}
.doc ul,.doc ol{margin:6px 0;padding-left:26px}
.doc li{margin:3px 0}
.doc li>ul,.doc li>ol{margin:2px 0}
.doc blockquote{margin:10px 0;padding:6px 14px;border-left:3px solid var(--acc2);background:#18142280;color:#c9c0d8;border-radius:0 8px 8px 0}
.doc blockquote p{margin:4px 0}
.doc table{border-collapse:collapse;margin:10px 0}
.doc th,.doc td{border:1px solid var(--line);padding:5px 10px}
.doc pre.code{background:#0f0d14;border:1px solid var(--line);border-radius:8px;padding:10px 12px;overflow-x:auto}
.doc pre.code code{background:none;padding:0}
.doc hr{border:0;border-top:1px solid var(--line);margin:18px 0}
/* таблицы-каталоги */
.bar{position:sticky;top:var(--nav);z-index:5;display:flex;gap:12px;align-items:center;padding:10px 0;background:linear-gradient(var(--bg) 70%,transparent)}
.bar input{flex:1;padding:10px 14px;border:1px solid var(--line);border-radius:8px;background:var(--panel);color:var(--text);font-size:15px;outline:none}
.bar input:focus{border-color:var(--acc2);box-shadow:0 0 0 3px rgba(139,92,246,.2)}
.cnt{color:var(--dim);white-space:nowrap}
.chips{display:flex;flex-wrap:wrap;gap:6px;margin:0 0 12px}
.chip{padding:4px 10px;border:1px solid var(--line);border-radius:999px;background:var(--panel);color:var(--text);font:13px "Segoe UI",sans-serif;cursor:pointer}
.chip:hover{border-color:var(--acc2)}.chip.on{background:var(--acc2);border-color:var(--acc2);color:#fff}
.chip i{font-style:normal;opacity:.6;margin-left:4px}
table.cat{width:100%;border-collapse:collapse;background:var(--panel);border:1px solid var(--line);border-radius:10px;overflow:hidden}
table.cat th,table.cat td{padding:8px 12px;text-align:left;vertical-align:top;border-bottom:1px solid var(--line)}
table.cat th{background:var(--panel2);color:var(--acc);font-weight:600;font-size:13px;text-transform:uppercase;letter-spacing:.06em;user-select:none}
th.s{cursor:pointer}th.s:hover{color:#fff}
th .ar{opacity:.35;margin-left:4px}th.on .ar{opacity:1}
tr.m{cursor:pointer}tr.m:hover td{background:#1d1928}
tr.m.open td{background:#211c2e}
td.n{font-weight:600;color:#ece6f5}
td.n .id{display:block;font:12px Consolas,monospace;color:var(--dim);font-weight:400;word-break:break-all}
td.d{color:#b9b1c7}
td.v{font:13px Consolas,monospace;color:#9fd3a8;white-space:nowrap}
td.l,td.c{white-space:nowrap}
td.num{color:var(--dim);font:13px Consolas,monospace;white-space:nowrap;text-align:right}
table.cat th.r{text-align:right}
td.ch{width:28px;padding-right:0;color:var(--dim)}
.chev{display:inline-block;transition:transform .22s ease,color .22s ease;font-size:13px}
tr.m:hover .chev{color:var(--acc)}tr.m.open .chev{transform:rotate(90deg);color:var(--acc)}
.hint{display:flex;justify-content:space-between;align-items:center;gap:12px;margin:0 0 8px;color:var(--dim);font-size:13px}
.btn{padding:4px 12px;border:1px solid var(--line);border-radius:7px;background:var(--panel);color:var(--text);font:13px "Segoe UI",sans-serif;cursor:pointer}
.btn:hover{border-color:var(--acc2)}
.lk{display:inline-block;margin-right:4px;padding:1px 7px;border:1px solid var(--line);border-radius:5px;font-size:12px;color:var(--text)}
.lk:hover{text-decoration:none;border-color:var(--acc2)}
.lk.mr{color:#5fd07a}.lk.cf{color:#f0874b}.lk.gt{color:#c8c8c8}.lk.fl{color:var(--acc)}
.badge{display:inline-block;margin:1px 4px 1px 0;padding:1px 8px;border-radius:999px;font-size:12px;border:1px solid;background:rgba(0,0,0,.25);white-space:nowrap}
table.cat tr.x td{background:#0f0d14;padding:0;border-bottom:1px solid var(--acc2)}
.xw{display:grid;grid-template-rows:0fr;transition:grid-template-rows .22s ease}
.xw.on{grid-template-rows:1fr}
.xi{overflow:hidden;min-height:0}
.xp{padding:14px 22px 18px;opacity:0;transform:translateY(-4px);transition:opacity .22s ease,transform .22s ease}
.xw.on .xp{opacity:1;transform:none}
@media (prefers-reduced-motion:reduce){.xw,.xp,.chev{transition:none!important}}
.card h3{margin:10px 0 4px;color:var(--acc);font:600 13px/1.3 "Segoe UI",sans-serif;text-transform:uppercase;letter-spacing:.08em}
.card h3:first-child{margin-top:0}
.card p{margin:4px 0}.card ul,.card ol{margin:4px 0;padding-left:22px}
.card .meta{margin-top:10px;color:var(--dim);font:12px Consolas,monospace}
.empty{color:var(--dim);font-style:italic}
.none{padding:30px;text-align:center;color:var(--dim)}
.note{color:var(--dim);font-size:13px;margin:8px 0}
.st{display:inline-block;margin-right:8px;padding:0 7px;border-radius:5px;font-size:11px;font-weight:600;vertical-align:1px;border:1px solid var(--line);color:var(--dim)}
.st.on{color:#5fd07a;border-color:#2f6b3d}.st.inc{color:#f0874b;border-color:#7a4526}
tr.m.off td{opacity:.5}tr.m.off:hover td{opacity:.8}
h2.tt{margin:4px 0 12px;font:600 22px Georgia,"Times New Roman",serif;color:#e8dcb5;letter-spacing:.06em}
footer{margin-top:22px;text-align:center;color:var(--dim);font-size:12px}
/* ---------- анимации и атмосфера ---------- */
#fx,#fxv{position:fixed;inset:0;width:100%;height:100%;pointer-events:none;z-index:0;opacity:calc(.32*(1 - var(--dk)));transition:opacity .9s ease}
html.home #fx{opacity:calc(.6*(1 - var(--dk)))}
#fire{position:fixed;left:0;right:0;bottom:0;width:100%;height:var(--fh);pointer-events:none;z-index:0;opacity:calc(.85*(1 - var(--dk)));transition:opacity .9s ease;image-rendering:pixelated;-webkit-mask-image:linear-gradient(to top,#000 35%,transparent);mask-image:linear-gradient(to top,#000 35%,transparent)}
html.home .doc{background:rgba(20,18,27,.9)}html.home .tile{background:rgba(20,18,27,.88)}
#fxv{background:radial-gradient(ellipse at center,transparent 50%,rgba(0,0,0,.55) 100%)}
#fxv::before{content:'';position:absolute;inset:0;background:radial-gradient(ellipse 70% 45% at 50% 105%,rgba(24,170,180,.20),transparent 70%),radial-gradient(ellipse 40% 30% at 15% 10%,rgba(139,92,246,.08),transparent 70%);animation:fxPulse 8s ease-in-out infinite alternate}
#fxv{opacity:calc(.6*(1 - var(--dk)))}html.home #fxv{opacity:calc(1 - var(--dk))}
@keyframes fxPulse{from{opacity:.45}to{opacity:1}}
.wrap{position:relative;z-index:1}
.tab.on{animation:tabIn .32s ease both}
@keyframes tabIn{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:none}}
nav.top .tabs a{position:relative;transition:color .2s ease,background-color .2s ease,text-shadow .2s ease}
nav.top .tabs a::after{content:'';position:absolute;left:12px;right:12px;bottom:2px;height:2px;border-radius:2px;background:var(--acc);box-shadow:0 0 8px rgba(201,162,39,.7);transform:scaleX(0);opacity:0;transition:transform .28s ease,opacity .28s ease}
nav.top .tabs a:hover{text-shadow:0 0 10px rgba(201,162,39,.35)}
nav.top .tabs a:hover::after{transform:scaleX(.45);opacity:.6}
nav.top .tabs a.on{box-shadow:none}
nav.top .tabs a.on::after{transform:scaleX(1);opacity:1}
nav.top .brand img{transition:transform .5s ease,filter .5s ease}
nav.top .brand:hover{text-decoration:none}
nav.top a.gh{transition:color .2s ease,text-shadow .2s ease}nav.top a.gh:hover{color:#fff;text-shadow:0 0 10px rgba(201,162,39,.6);text-decoration:none}
.hero img.icon{transition:transform .6s cubic-bezier(.2,.8,.2,1),filter .6s ease}
pre.ascii{animation:asciiGlow 6s ease-in-out infinite alternate}
@keyframes asciiGlow{from{text-shadow:0 0 4px rgba(201,162,39,.25)}to{text-shadow:0 0 10px rgba(201,162,39,.55),0 0 22px rgba(24,170,180,.15)}}
.tile{transition:transform .22s ease,border-color .22s ease,box-shadow .22s ease}
.tile:hover{transform:translateY(-3px);box-shadow:0 8px 24px rgba(0,0,0,.4),0 0 0 1px rgba(201,162,39,.25),0 0 18px rgba(201,162,39,.12)}
.chip,.btn,.lk{transition:transform .18s ease,border-color .18s ease,background-color .18s ease,box-shadow .18s ease,color .18s ease}
.chip:hover,.btn:hover{transform:translateY(-1px);box-shadow:0 4px 12px rgba(0,0,0,.35),0 0 10px rgba(139,92,246,.25)}
.chip:active,.btn:active{transform:translateY(0) scale(.97)}
.chip.on{box-shadow:0 0 12px rgba(139,92,246,.45)}
.lk:hover{transform:translateY(-1px);box-shadow:0 0 8px currentColor}
.badge{transition:filter .18s ease}tr.m:hover .badge{filter:brightness(1.25)}
table.cat td{transition:background-color .16s ease}
th.s{transition:color .18s ease}
.bar input{transition:border-color .2s ease,box-shadow .25s ease}
.bar input:focus{border-color:var(--acc);box-shadow:0 0 0 3px rgba(201,162,39,.16),0 0 18px rgba(201,162,39,.14)}
/* ---------- таблицы во весь экран: прокрутка внутри, шапка таблицы липкая ---------- */
.tw{background:var(--panel);border:1px solid var(--line);border-radius:10px;overflow:auto}
.tw table.cat{border:0;border-radius:0;overflow:visible}
.tw table.cat thead th{position:sticky;top:0;z-index:2;box-shadow:0 1px 0 var(--line)}
.wrap{padding-bottom:120px}
footer{position:relative;z-index:2;margin-top:22px}
footer span{display:inline-block;padding:5px 14px;border-radius:999px;background:rgba(11,10,15,.8);border:1px solid var(--line);color:#c9c0d8;text-shadow:0 1px 2px #000;-webkit-backdrop-filter:blur(3px);backdrop-filter:blur(3px)}
html.fit body{overflow-x:hidden}
html.fit .wrap{height:calc(100vh - var(--nav));height:calc(100dvh - var(--nav));display:flex;flex-direction:column;padding-top:14px;padding-bottom:0}
html.fit .tab.on{display:flex;flex-direction:column;flex:1 1 auto;min-height:0}
html.fit .tab.on>*{flex:0 0 auto}
html.fit .tab.on>.tw{flex:1 1 auto;min-height:220px}
html.fit .bar{position:static;background:none;padding:6px 0 8px}
html.fit h2.tt{margin:0 0 6px}
html.fit footer{flex:0 0 64px;margin:0;display:flex;align-items:center;justify-content:center}
/* ---------- музыка: панель «Как настроены события» поверх таблицы ---------- */
.twbox{position:relative}
html.fit .tab.on>.twbox{flex:1 1 auto;min-height:220px;display:flex;flex-direction:column}
html.fit .twbox>.tw{flex:1 1 auto;min-height:0}
#mtcfg{margin:0 0 8px}
.cfgbtn{color:var(--acc);padding:6px 14px}.cfgbtn .chev{margin-left:8px}.cfgbtn.on{border-color:var(--acc);box-shadow:0 0 12px rgba(201,162,39,.25)}.cfgbtn.on .chev{transform:rotate(90deg)}
.ov{position:absolute;inset:0;z-index:4;display:flex;align-items:flex-start;justify-content:center;padding:14px;border-radius:10px;background:rgba(8,6,12,.5);-webkit-backdrop-filter:blur(6px);backdrop-filter:blur(6px);opacity:0;visibility:hidden;transition:opacity .22s ease,visibility 0s linear .22s}
.ov.on{opacity:1;visibility:visible;transition:opacity .22s ease,visibility 0s}
.ovp{display:flex;flex-direction:column;width:min(980px,100%);max-height:100%;background:rgba(20,18,27,.97);border:1px solid var(--acc2);border-radius:12px;box-shadow:0 18px 50px rgba(0,0,0,.6),0 0 24px rgba(139,92,246,.18);transform:translateY(-10px) scale(.98);transition:transform .22s ease}
.ov.on .ovp{transform:none}
.ovh{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:10px 16px;border-bottom:1px solid var(--line);color:var(--acc)}
.ovh span{color:var(--dim);font-weight:400}
.ovx{width:30px;height:30px;border:1px solid var(--line);border-radius:8px;background:var(--panel2);color:var(--text);font-size:18px;line-height:1;cursor:pointer;transition:border-color .18s,color .18s,transform .18s}
.ovx:hover{border-color:var(--acc);color:var(--acc);transform:rotate(90deg)}
.ovb{overflow:auto;padding:0 16px 14px}
table.cfgt{width:100%;border-collapse:separate;border-spacing:0}
table.cfgt th{position:sticky;top:0;z-index:3;background:#16141d;color:var(--dim);font-weight:600;cursor:help;border-bottom:0;box-shadow:inset 0 -1px 0 var(--acc2),0 4px 8px -4px rgba(0,0,0,.7)}
table.cfgt td.pc{cursor:help}
code.pp{cursor:help;border-bottom:1px dotted rgba(201,162,39,.45)}
small.u{color:var(--dim);font-size:11px;margin:0 6px 0 3px;white-space:nowrap}
.cfgleg{margin-top:14px;border-top:1px solid var(--line);padding-top:6px}
.cfgleg h4{margin:10px 0 4px;color:var(--acc);font-size:14px}
.cfgleg h4 span{color:var(--dim);font-weight:400}
.cfgleg dl{display:grid;grid-template-columns:minmax(150px,max-content) 1fr;gap:6px 14px;margin:6px 0 4px;font-size:13px}
.cfgleg dt{color:var(--text);white-space:nowrap}
.cfgleg dt b{display:block;color:var(--dim);font-weight:400;font-size:12px}
.cfgleg dd{margin:0;color:var(--text);line-height:1.45}
.cfgleg dd i{display:block;color:var(--dim);font-style:normal;font-size:12px}
@media (max-width:640px){.cfgleg dl{grid-template-columns:1fr}.cfgleg dd{margin-bottom:6px}}
table.cfgt td,table.cfgt th{padding:6px 8px;border-bottom:1px solid var(--line);text-align:left;vertical-align:top;font-size:13px}
/* ---------- полосы прокрутки ---------- */
::-webkit-scrollbar{width:10px;height:10px}
::-webkit-scrollbar-track{background:#0f0d14}
::-webkit-scrollbar-thumb{background:linear-gradient(180deg,#7a6420,#1c6a70);border:2px solid #0f0d14;border-radius:8px}
::-webkit-scrollbar-thumb:hover{background:linear-gradient(180deg,#c9a227,#24a3aa)}
::-webkit-scrollbar-corner{background:#0f0d14}
@supports (-moz-appearance:none){*{scrollbar-width:thin;scrollbar-color:#8a7020 #0f0d14}}
/* ---------- логотип: сердцебиение при наведении ---------- */
@keyframes heartbeat{0%{transform:scale(1);filter:drop-shadow(0 0 6px rgba(190,25,25,.35))}14%{transform:scale(1.08);filter:drop-shadow(0 0 20px rgba(235,30,30,.9))}28%{transform:scale(1);filter:drop-shadow(0 0 8px rgba(190,25,25,.45))}42%{transform:scale(1.05);filter:drop-shadow(0 0 15px rgba(235,30,30,.75))}70%,100%{transform:scale(1);filter:drop-shadow(0 0 6px rgba(190,25,25,.35))}}
html:not(.day) .hero img.icon:hover{animation:heartbeat .92s ease-in-out infinite}
nav.top .brand:hover img{transform:rotate(-8deg) scale(1.08);filter:drop-shadow(0 0 6px rgba(201,162,39,.6))}
#sparks{position:fixed;inset:0;width:100%;height:100%;pointer-events:none;z-index:6}
@media (prefers-reduced-motion:reduce){*,*::before,*::after{animation:none!important;transition:none!important}html:not(.day) .hero img.icon:hover{filter:drop-shadow(0 0 14px rgba(230,30,30,.8))}}
/* до запуска основного скрипта: вкладка выбирается по #hash в <head>, футер нефиксированных вкладок скрыт до рендера */
html.boot:not(.fit) #foot{visibility:hidden}
#lava{position:fixed;inset:0;width:100%;height:100%;pointer-events:none;z-index:0;opacity:calc(1 - var(--dk))}
/* ---------- день / ночь ---------- */
@supports (color:color-mix(in srgb,red 50%,blue)){:root{--acc2:color-mix(in srgb,#8b5cf6 calc(100% - var(--dk)*100%),#2fae74);--acc:color-mix(in srgb,#c9a227 calc(100% - var(--dk)*100%),#e8b923)}}
body::before{content:'';position:fixed;inset:0;z-index:0;pointer-events:none;background:linear-gradient(#4287de,#aad7ff 60%,#62ae3e 60%);opacity:var(--dk)}
#day{position:fixed;inset:0;width:100%;height:100%;pointer-events:none;z-index:0;opacity:var(--dk);image-rendering:pixelated;image-rendering:crisp-edges}
#day{image-rendering:pixelated}
#moon{position:fixed;left:30%;top:120px;width:56px;height:56px;margin-left:-28px;pointer-events:none;z-index:0;image-rendering:pixelated;opacity:calc((1 - var(--dk))*.8);filter:drop-shadow(0 0 14px rgba(190,210,255,.45))}
/* днём — тёмное «стекло» под содержимым, чтобы текст оставался читаемым на яркой сцене */
.tab{border-radius:14px;padding:calc(var(--dk)*12px) calc(var(--dk)*16px);background:rgba(10,9,16,calc(var(--dk)*.66))}
#t-home,#t-install,#t-help{padding:0;background:none}
html.day .tab.on:not(#t-home):not(#t-install):not(#t-help){-webkit-backdrop-filter:blur(10px);backdrop-filter:blur(10px);box-shadow:0 10px 40px rgba(0,0,0,.3),inset 0 0 0 1px rgba(255,255,255,.08)}
.hero{width:max-content;max-width:100%;box-sizing:border-box;margin-left:auto;margin-right:auto;border-radius:18px;padding:calc(var(--dk)*14px) calc(var(--dk)*26px);background:rgba(10,9,16,calc(var(--dk)*.8))}
/* днём NFO-шапка: светлее и с тёмной обводкой, без мерцающего свечения */
html.day pre.ascii{animation:none;color:#ffd969;text-shadow:0 1px 0 #000,1px 0 0 #000,0 -1px 0 rgba(0,0,0,.7),-1px 0 0 rgba(0,0,0,.7),0 0 6px rgba(0,0,0,.85)}
html.day h1.title{color:#fff3cf;text-shadow:0 2px 3px #000,0 0 10px rgba(0,0,0,.7)}
html.day .sub{color:#c9c1d8;text-shadow:0 1px 2px #000}
html.day .hero{-webkit-backdrop-filter:blur(8px);backdrop-filter:blur(8px);box-shadow:inset 0 0 0 1px rgba(255,255,255,.1),0 10px 30px rgba(0,0,0,.25)}
html.day .doc,html.day .tile{-webkit-backdrop-filter:blur(8px);backdrop-filter:blur(8px)}
html.day .hero img.icon{transform-origin:50% 92%}
html.day .hero img.icon:hover{animation:sway 2.4s ease-in-out infinite;filter:drop-shadow(0 0 14px rgba(255,240,170,.6))}
@keyframes sway{0%,100%{transform:rotate(-5deg)}50%{transform:rotate(5deg) translateY(-3px)}}
/* переключатель темы */
.thm{display:flex;gap:2px;margin-right:14px;padding:2px;border:1px solid var(--line);border-radius:999px;background:rgba(20,18,27,.75)}
.thm button{display:flex;align-items:center;gap:5px;padding:4px 10px;border:0;border-radius:999px;background:none;color:var(--dim);font:13px "Segoe UI",sans-serif;cursor:pointer;transition:color .2s ease,background-color .2s ease,box-shadow .2s ease}
.thm button b{font-weight:400;font-size:14px;line-height:1}
.thm button:hover{color:var(--text);background:rgba(255,255,255,.05)}
html[data-theme=day] .thm [data-m=day],html[data-theme=night] .thm [data-m=night],html[data-theme=auto] .thm [data-m=auto]{background:var(--panel2);color:#fff;box-shadow:inset 0 0 0 1px var(--acc),0 0 10px rgba(201,162,39,.25)}
html[data-theme=day] .thm [data-m=day] b{color:#ffd54a;text-shadow:0 0 8px rgba(255,213,74,.7)}
html[data-theme=night] .thm [data-m=night] b{color:#b9c6ff;text-shadow:0 0 8px rgba(185,198,255,.7)}
html[data-theme=auto] .thm [data-m=auto] b{color:#5fe0d0;text-shadow:0 0 8px rgba(95,224,208,.7)}
@media (max-width:980px){.thm button span{display:none}}
/* ---------- подсказки (data-tip) ---------- */
#tip{position:fixed;left:0;top:0;z-index:60;max-width:min(380px,calc(100vw - 16px));padding:7px 11px;border-radius:9px;background:rgba(16,14,22,.9);border:1px solid rgba(201,162,39,.55);box-shadow:0 8px 24px rgba(0,0,0,.55),0 0 0 1px rgba(36,197,197,.12),0 0 18px rgba(36,197,197,.14);-webkit-backdrop-filter:blur(8px);backdrop-filter:blur(8px);color:var(--text);font:12.5px/1.45 system-ui,'Segoe UI',sans-serif;white-space:pre-line;overflow-wrap:anywhere;pointer-events:none;opacity:0;visibility:hidden;transform:translateY(4px);transition:opacity .14s ease,transform .14s ease,visibility 0s linear .14s}
#tip.on{opacity:1;visibility:visible;transform:none;transition:opacity .14s ease,transform .14s ease,visibility 0s}
#tip.up{transform:translateY(-4px)}#tip.up.on{transform:none}
[data-tip]:focus-visible{outline:1px solid rgba(201,162,39,.7);outline-offset:2px}
/* ---------- смартфоны и тач ---------- */
#tip{pointer-events:none}
html:not(.day) .hero img.icon.tap{animation:heartbeat .92s ease-in-out 2}
html.day .hero img.icon.tap{animation:sway 1.84s ease-in-out 1;filter:drop-shadow(0 0 14px rgba(255,240,170,.6))}
@media (hover:none){
.tile:hover,.chip:hover,.btn:hover,.lk:hover,.ovx:hover{transform:none;box-shadow:none}
.chip.on,.chip.on:hover{box-shadow:0 0 12px rgba(139,92,246,.45)}
tr.m:hover td{background:none}tr.m.open td{background:#211c2e}tr.m:hover .badge{filter:none}
nav.top .tabs a:hover{background:none;text-shadow:none;color:var(--dim)}nav.top .tabs a:hover::after{opacity:0}
nav.top .tabs a.on,nav.top .tabs a.on:hover{color:#fff;background:var(--panel2)}nav.top .tabs a.on::after{opacity:1;transform:scaleX(1)}
nav.top .brand:hover img{transform:none;filter:none}
.thm button:hover{background:none;color:var(--dim)}
html:not(.day) .hero img.icon:hover,html.day .hero img.icon:hover{animation:none;filter:drop-shadow(0 0 14px rgba(201,162,39,.3))}
html:not(.day) .hero img.icon.tap{animation:heartbeat .92s ease-in-out 2}
html.day .hero img.icon.tap{animation:sway 1.84s ease-in-out 1}
}
@media (max-width:760px){
:root{--nav:96px}
body{overflow-x:clip}
nav.top{flex-wrap:wrap;align-content:flex-start;gap:0 6px;padding:0 10px}
nav.top .brand{height:48px;margin-right:auto;font-size:14px;letter-spacing:.12em}
nav.top .thm{margin-right:2px}
.thm button{justify-content:center;min-width:40px;min-height:40px;padding:0 8px}
.thm button b{font-size:17px}
nav.top a.gh{display:inline-flex;align-items:center;justify-content:center;min-width:40px;height:40px;font-size:0}
nav.top a.gh svg{width:22px;height:22px;margin:0;vertical-align:0}
nav.top .tabs{order:5;flex:1 0 100%;height:48px;align-items:center;margin:0 -10px;padding:0 6px;border-top:1px solid var(--line);scrollbar-width:none;-webkit-mask-image:linear-gradient(90deg,transparent,#000 12px,#000 calc(100% - 18px),transparent);mask-image:linear-gradient(90deg,transparent,#000 12px,#000 calc(100% - 18px),transparent)}
nav.top .tabs::-webkit-scrollbar{display:none}
nav.top .tabs a{display:flex;align-items:center;min-height:40px;padding:0 12px;font-size:15px}
.wrap{padding:14px 12px 40px}
h1.title{font-size:20px;letter-spacing:.2em}
.sub{font-size:14px}
.tiles{grid-template-columns:repeat(2,1fr);gap:10px}
.tile{padding:12px}
.doc{padding:4px 16px 16px}
.doc ul,.doc ol{padding-left:22px}
.doc table{display:block;overflow-x:auto}
.doc h1,.doc h2{font-size:19px}
.tab{padding:calc(var(--dk)*10px);background:rgba(10,9,16,calc(var(--dk)*.84))}
html.day .tab.on:not(#t-home):not(#t-install):not(#t-help){-webkit-backdrop-filter:none;backdrop-filter:none}
html.day .doc,html.day .tile,html.day .hero{-webkit-backdrop-filter:none;backdrop-filter:none}
html.day .doc{background:rgba(20,18,27,.9)}html.day .tile{background:rgba(20,18,27,.88)}
.hero{padding:calc(var(--dk)*12px) calc(var(--dk)*14px)}
#fire{--fh:clamp(56px,14vh,110px);height:var(--fh)}
/* таблицы — обычная прокрутка страницы, строки — карточки */
html.fit .wrap{height:auto;display:block;padding-top:10px;padding-bottom:24px}
html.fit .tab.on{display:block}
html.fit .tab.on>.tw,html.fit .tab.on>.twbox,html.fit .twbox>.tw{min-height:0}
.tw{overflow:visible}
html.fit .bar,.bar{position:sticky;top:var(--nav);flex-wrap:wrap;gap:4px 10px;padding:8px 0 6px;background:linear-gradient(var(--bg) 80%,transparent)}
html.day .bar{background:linear-gradient(rgba(10,9,16,.92) 80%,transparent);margin:0 -10px;padding-left:10px;padding-right:10px}
.bar input{flex:1 1 100%;min-height:44px;font-size:16px}
.cnt{font-size:13px}
.chips{flex-wrap:nowrap;overflow-x:auto;margin:0 -12px 10px;padding:2px 12px 4px;scrollbar-width:none;-webkit-mask-image:linear-gradient(90deg,transparent,#000 12px,#000 calc(100% - 24px),transparent);mask-image:linear-gradient(90deg,transparent,#000 12px,#000 calc(100% - 24px),transparent)}
.chips::-webkit-scrollbar{display:none}
.chip{flex:0 0 auto;min-height:40px;padding:0 14px;font-size:14px}
.hint{flex-wrap:wrap}
.btn{min-height:40px;padding:0 14px;font-size:14px}
.lk{display:inline-flex;align-items:center;justify-content:center;min-width:44px;min-height:40px;margin:2px 4px 2px 0;font-size:13px}
html.fit footer{display:block;margin:18px 0 0}
footer span{font-size:11px;padding:6px 12px}
table.cat thead{display:none}
table.cat,table.cat tbody{display:block;width:100%}
table.cat tr{display:flex;flex-wrap:wrap;align-items:center;gap:4px 10px;padding:12px 12px 12px 10px;border-bottom:1px solid var(--line)}
table.cat tr td{display:block;padding:0;border:0;white-space:normal}
table.cat tr.m td,table.cat tr.m:hover td,table.cat tr.m.open td{background:none}
table.cat tr.m.open{background:#211c2e}
tr.m td.ch{width:18px;flex:0 0 18px;align-self:flex-start;padding-top:2px}
tr.m td.n{flex:1 1 calc(100% - 30px)}
tr.m td.c,tr.m td.d{flex:1 0 100%;padding-left:28px}
tr.m td.d{font-size:14px}
tr.m td.v,tr.m td.num{padding-left:28px;font-size:12px;text-align:left;max-width:100%;overflow-wrap:anywhere}
tr.m td.num{padding-left:0}
tr.m td.l{margin-left:auto}
table.cat tr.x{padding:0;border-bottom:0}
table.cat tr.x td{flex:1 0 100%}table.cat tr.x td:first-child{display:none}
.xp{padding:12px 14px 14px}
#t-music table.cat tr td.n{flex:1 0 100%}
#t-music table.cat tr td:nth-child(2){flex:1 0 100%}
#t-music table.cat tr td.num{text-align:left;font-size:12px}
#t-music table.cat tr td.num:nth-child(3)::before{content:'⏱ '}
td.none{flex:1 0 100%;text-align:center}
.cfgbtn{min-height:40px}
/* «Как настроены события» — во весь экран под навигацией, прокрутка внутри */
.tab.on{animation-fill-mode:backwards}
.ov{position:fixed;inset:var(--nav) 0 0 0;z-index:20;padding:8px;border-radius:0}
.ovp{width:100%;max-height:100%}
.ovh{padding:8px 10px 8px 14px}
.ovx{width:40px;height:40px;flex:0 0 40px}
.ovb{padding:0 12px 14px;-webkit-overflow-scrolling:touch}
table.cfgt thead{display:none}
table.cfgt,table.cfgt tbody{display:block}
table.cfgt tr{display:flex;flex-wrap:wrap;gap:4px 14px;padding:10px 0;border-bottom:1px solid var(--line)}
table.cfgt td{border:0;padding:0}
table.cfgt td:first-child,table.cfgt td:nth-child(4){flex:1 0 100%}
table.cfgt td.pc::before{content:'Приоритет: ';color:var(--dim)}
table.cfgt td:nth-child(3)::before{content:'Треков: ';color:var(--dim)}
.cfgleg dt{white-space:normal}
}
@media (max-width:760px){#moon{width:40px;height:40px;margin-left:-20px;opacity:calc((1 - var(--dk))*.5)}
}
@media (pointer:coarse) and (min-width:761px){
nav.top .tabs a{display:flex;align-items:center;min-height:40px}
.thm button{justify-content:center;min-width:40px;min-height:40px}
nav.top a.gh{display:inline-flex;align-items:center;min-height:40px}
nav.top .brand{min-height:40px}
.chip,.btn{min-height:40px}
.lk{display:inline-flex;align-items:center;justify-content:center;min-width:40px;min-height:40px}
.bar input{min-height:44px}
.ovx{width:40px;height:40px}
}
/* ночь: подписи шапки читаемы на любом фоне (огонь, луна, лава) — тёмная «стеклянная» плашка + тёмная обводка */
html:not(.day) h1.title{text-shadow:0 0 2px #000,0 0 6px rgba(0,0,0,.95),0 2px 12px rgba(0,0,0,.85)}
html:not(.day) .sub{width:max-content;max-width:calc(100% - 8px);box-sizing:border-box;margin:6px auto 0;padding:3px 14px;border-radius:999px;background:rgba(9,7,13,.74);-webkit-backdrop-filter:blur(4px);backdrop-filter:blur(4px);box-shadow:inset 0 0 0 1px rgba(255,255,255,.07),0 2px 12px rgba(0,0,0,.5);color:#bdb5cf;text-shadow:0 1px 2px #000}
html:not(.day) .sub b{color:#e6c045}
html:not(.day) pre.ascii{text-shadow:0 0 2px #000,0 0 6px rgba(201,162,39,.35)}
html:not(.day) .tile span{color:#a79fb8}
/* главная ночью: низ страницы можно прокрутить выше огня */
html.home:not(.day) .wrap{padding-bottom:calc(var(--fh) + 8px)}
@media (max-width:760px){html:not(.day) .sub{border-radius:12px;padding:4px 12px}html.home:not(.day) .wrap{padding-bottom:calc(clamp(56px,14vh,110px) + 8px)}}
</style>
</head>
<body>
<canvas id="day" aria-hidden="true"></canvas><canvas id="moon" width="16" height="16" aria-hidden="true"></canvas><canvas id="fx" aria-hidden="true"></canvas><div id="fxv" aria-hidden="true"></div><canvas id="fire" aria-hidden="true"></canvas><canvas id="lava" aria-hidden="true"></canvas><canvas id="sparks" aria-hidden="true"></canvas>
<nav class="top">
  <a class="brand" href="#home">__BRANDICON__Z@RYA DDF</a>
  <div class="tabs" id="tabs"></div>
  <div class="thm" id="thm" role="radiogroup" aria-label="Тема оформления"><button type="button" role="radio" data-m="day" aria-label="Дневная тема"><b>☀</b><span>День</span></button><button type="button" role="radio" data-m="night" aria-label="Ночная тема"><b>☾</b><span>Ночь</span></button><button type="button" role="radio" data-m="auto" aria-label="Авто: смена дня и ночи примерно каждую минуту"><b>⟳</b><span>Авто</span></button></div>
  <span id="navgh"></span>
</nav>
<div class="wrap">
<section class="tab" id="t-home"><script>__T==='home'&&document.currentScript.parentNode.classList.add('on')</script>
  <div class="hero">
    __HEROICON__
    <pre class="ascii">__HEADER__</pre><script>/* NFO-шапка: на узких экранах уменьшаем шрифт, чтобы влезла по ширине */window.__fitA=function(){var p=document.querySelector('pre.ascii');if(!p||!p.offsetParent)return;var w=p.parentNode.parentNode.clientWidth;if(w===p.__w)return;p.__w=w;p.style.fontSize='';var need=p.scrollWidth,av=w-(w<700?32:56);if(need>av)p.style.fontSize=Math.max(5,Math.floor(1200*av/need)/100)+'px';};__fitA();</script>
    <h1 class="title">Z@RYA DEEP DARK FANTASIES</h1>
    <div class="sub" id="subline"></div>
  </div>
  <div class="tiles" id="tiles"></div>
  <div class="doc" id="doc-home"></div>
</section>
<section class="tab" id="t-install"><script>__T==='install'&&document.currentScript.parentNode.classList.add('on')</script><div class="doc" id="doc-install"></div></section>
<section class="tab" id="t-help"><script>__T==='help'&&document.currentScript.parentNode.classList.add('on')</script><div class="doc" id="doc-help"></div></section>
<section class="tab" id="t-mods"><script>__T==='mods'&&document.currentScript.parentNode.classList.add('on')</script>
  <h2 class="tt">Моды</h2>
  <div class="bar"><input id="mq" type="search" placeholder="Поиск: название, modid, категория, описание, заметки…"><span class="cnt" id="mcnt"></span></div>
  <div class="chips" id="mcats"></div>
  <p class="note">У некоторых модов есть приписка <code>ZaryaEdition</code> — это означает, что мод допиливался под потребности сборки</p>
  <div class="hint"><span>▸ Нажмите на строку, чтобы увидеть описание и заметки</span><button class="btn" id="mall" type="button">Раскрыть все</button></div>
  <div class="tw"><table class="cat">
  <thead><tr><th></th><th class="s" data-k="name">Мод<span class="ar">▲</span></th><th class="s" data-k="cat">Категория<span class="ar">▲</span></th><th>Описание</th><th>Версия</th><th>Ссылки</th></tr></thead>
  <tbody id="mtb"></tbody>
  </table></div>
</section>
<section class="tab" id="t-packs"><script>__T==='packs'&&document.currentScript.parentNode.classList.add('on')</script>
  <h2 class="tt">Ресурспаки</h2>
  <p class="note">Файлы и папки из <code>minecraft/resourcepacks</code>. Название, ссылки, описание и заметки — из карточек <code>_Helpful Stuff/resourcepacks</code>.</p>
  <p class="note" id="porder"></p>
  <div class="bar"><input id="pq" type="search" placeholder="Поиск: название, файл, описание, заметки…"><span class="cnt" id="pcnt"></span></div>
  <div class="hint"><span>▸ Нажмите на строку, чтобы увидеть описание и заметки</span><button class="btn" id="pall" type="button">Раскрыть все</button></div>
  <div class="tw"><table class="cat">
  <thead><tr><th></th><th>Ресурспак</th><th>Описание</th><th>Версия</th><th>Размер</th><th>Ссылки</th></tr></thead>
  <tbody id="ptb"></tbody>
  </table></div>
</section>
<section class="tab" id="t-music"><script>__T==='music'&&document.currentScript.parentNode.classList.add('on')</script>
  <h2 class="tt">Музыка</h2>
  <p class="note">Треки Music Triggers из <code>minecraft/config/MusicTriggers/songs</code>. События — из <code>config/MusicTriggers/general/main.toml</code>.</p>
  <div id="mtcfg"></div>
  <div class="bar"><input id="sq" type="search" placeholder="Поиск: название трека, файл, событие…"><span class="cnt" id="scnt"></span></div>
  <div class="chips" id="strig"></div>
  <div class="twbox"><div class="tw"><table class="cat">
  <thead><tr><th>Трек</th><th>События</th><th class="r" data-tip="Длительность (м:сс) — посчитана скриптом по самим файлам">Длит.</th><th class="r">Размер</th></tr></thead>
  <tbody id="stb"></tbody>
  </table></div>
  <div class="ov" id="mtov" aria-hidden="true"><div class="ovp" role="dialog" aria-label="Как настроены события"><div class="ovh"><b>Как настроены события <span>(main.toml)</span></b><button class="ovx" id="mtovx" type="button" data-tip="Закрыть (Esc)">×</button></div><div class="ovb" id="mtovb"></div></div></div></div>
</section>
<footer id="foot"><span>Сгенерировано скриптом <code>_Helpful Stuff/Update README and site.ps1</code></span></footer>
</div>
<script type="application/json" id="data">__DATA__</script>
<script>
(function(){
"use strict";
var D=JSON.parse(document.getElementById('data').textContent);
var P=D.pack||{};
function $(id){return document.getElementById(id);}
function esc(s){return String(s==null?'':s).replace(/[&<>"']/g,function(c){return{'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
function qTerms(v){v=String(v||'').trim().toLowerCase();return v?v.split(/\s+/):[];}
function qHit(s,terms){return terms.every(function(t){return s.indexOf(t)>=0;});}
/* Раскрываемые строки: одиночный клик — анимация (высота через grid 0fr→1fr + появление), «Раскрыть все» и поиск — без анимации */
var RM=!!(window.matchMedia&&matchMedia('(prefers-reduced-motion: reduce)').matches);
function xRow(id,inner,on){return '<tr class="x" data-x="'+esc(id)+'"><td></td><td colspan="5"><div class="xw'+(on?' on':'')+'"><div class="xi"><div class="xp"><div class="card">'+inner+'</div></div></div></div></td></tr>';}
function toggleRow(tr,isOpen,inner){
  var nx=tr.nextElementSibling,x=(nx&&nx.classList.contains('x'))?nx:null,w;
  tr.classList.toggle('open',isOpen);
  if(isOpen){
    if(!x){tr.insertAdjacentHTML('afterend',xRow(tr.getAttribute('data-id'),inner(),RM));x=tr.nextElementSibling;}
    clearTimeout(x._t);w=x.querySelector('.xw');void w.offsetHeight;w.classList.add('on');
  }else if(x){
    w=x.querySelector('.xw');w.classList.remove('on');
    x._t=setTimeout(function(){if(x.parentNode&&!w.classList.contains('on'))x.parentNode.removeChild(x);},RM?0:260);
  }
}
function safeUrl(u){u=String(u||'').trim();return /^https?:\/\//i.test(u)?u:'';}
function mss(s){if(s==null||s===''||isNaN(+s))return '—';s=Math.round(+s);return Math.floor(s/60)+':'+('0'+s%60).slice(-2);}
function hms(s){s=Math.round(+s||0);var h=Math.floor(s/3600),m=Math.floor(s%3600/60);return (h?h+' ч ':'')+m+' мин';}
function size(n){n=+n||0;if(n>=1048576)return (n/1048576).toFixed(1)+' МБ';if(n>=1024)return Math.round(n/1024)+' КБ';return n+' Б';}
var GH='<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/></svg>';
function repoLink(){var u=safeUrl(P.repo);if(!u)return '';return '<a class="gh" href="'+esc(u)+'" target="_blank" rel="noopener noreferrer">'+(P.repoLabel==='GitHub'?GH:'')+esc(P.repoLabel||'Git')+'</a>';}

/* ---------- Markdown → HTML (простой: заголовки, списки, цитаты, таблицы, код, ссылки, жирный/курсив) ---------- */
function slug(t){return String(t).toLowerCase().replace(/<[^>]*>/g,'').replace(/[^\p{L}\p{N}\s_-]/gu,'').trim().replace(/\s/g,'-');}
function href(u){
  var m;
  if(/^#/.test(u))return {h:u};
  if((m=u.match(/^(?:\.\.?\/)?(?:_Helpful(?:%20| )Stuff\/)?Z(?:%40|@)RYA\.html(#.*)?$/i)))return {h:m[1]||'#home'};
  if(/^(https?:|mailto:)/i.test(u))return {h:u,ext:1};
  if(/^[a-z][a-z0-9+.-]*:/i.test(u))return null;
  /* относительные ссылки README — от корня инстанса; страница лежит в P.base от него */
  return {h:(/^\//.test(u)?'':(P.base||''))+u,ext:1};
}
function fmt(t){
  t=esc(t);
  t=t.replace(/\*\*([^*]+)\*\*/g,'<b>$1</b>').replace(/__([^_]+)__/g,'<b>$1</b>');
  t=t.replace(/(^|[^*\w])\*([^*\s](?:[^*]*[^*\s])?)\*(?![\w*])/g,'$1<i>$2</i>');
  t=t.replace(/(^|[\s(])_([^_\s](?:[^_]*[^_\s])?)_(?=[\s).,!?:;]|$)/g,'$1<i>$2</i>');
  return t;
}
function inline(t){
  var codes=[],links=[];
  t=String(t).replace(/`([^`]+)`/g,function(_,c){codes.push(c);return '\u0000'+(codes.length-1)+'\u0000';});
  t=t.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g,function(m,txt,url){links.push([txt,url]);return '\u0001'+(links.length-1)+'\u0001';});
  t=fmt(t);
  t=t.replace(/(^|[\s(])(https?:\/\/[^\s<)]+)/g,function(m,p,url){return p+'<a href="'+url+'" target="_blank" rel="noopener noreferrer">'+url+'</a>';});
  t=t.replace(/\u0001(\d+)\u0001/g,function(_,i){var L=links[+i],r=href(L[1]);if(!r)return fmt(L[0]);return '<a href="'+esc(r.h)+'"'+(r.ext?' target="_blank" rel="noopener noreferrer"':'')+'>'+fmt(L[0])+'</a>';});
  return t.replace(/\u0000(\d+)\u0000/g,function(_,i){return '<code>'+esc(codes[+i])+'</code>';});
}
function ind(l){var m=l.match(/^[ \t]*/)[0];return m.replace(/\t/g,'    ').length;}
var RE_ITEM=/^([ \t]*)([-*+]|\d+[.)])[ \t]+(.*)$/;
function isTableSep(l){return /^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$/.test(l)&&l.indexOf('-')>=0;}
function isStart(l,next){return /^\s*```/.test(l)||/^#{1,6}\s/.test(l)||/^\s*>/.test(l)||RE_ITEM.test(l)||/^\s*([-*_])(\s*\1){2,}\s*$/.test(l)||(/^\s*\|/.test(l)&&next!=null&&isTableSep(next));}
function cells(l){l=l.trim().replace(/^\|/,'').replace(/\|$/,'');return l.split(/(?<!\\)\|/).map(function(c){return c.trim().replace(/\\\|/g,'|');});}
function blocks(lines,hshift){
  hshift=hshift||0;var out=[],i=0,m;
  while(i<lines.length){
    var l=lines[i];
    if(!l.trim()){i++;continue;}
    if((m=l.match(/^\s*```(.*)$/))){var buf=[];i++;while(i<lines.length&&!/^\s*```/.test(lines[i])){buf.push(lines[i]);i++;}i++;out.push('<pre class="code"><code>'+esc(buf.join('\n'))+'</code></pre>');continue;}
    if((m=l.match(/^(#{1,6})\s+(.*?)\s*#*\s*$/))){var lv=Math.min(6,m[1].length+hshift);out.push('<h'+lv+' id="'+esc(slug(m[2]))+'">'+inline(m[2])+'</h'+lv+'>');i++;continue;}
    if(/^\s*([-*_])(\s*\1){2,}\s*$/.test(l)){out.push('<hr>');i++;continue;}
    if(/^\s*>/.test(l)){var q=[];while(i<lines.length&&/^\s*>/.test(lines[i])){q.push(lines[i].replace(/^\s*>\s?/,''));i++;}out.push('<blockquote>'+blocks(q,hshift)+'</blockquote>');continue;}
    if(/^\s*\|/.test(l)&&i+1<lines.length&&isTableSep(lines[i+1])){
      var hd=cells(l),al=cells(lines[i+1]).map(function(c){return /^:-+:$/.test(c)?'center':/-:$/.test(c)?'right':'';});i+=2;
      var h='<table><thead><tr>'+hd.map(function(c,k){return '<th'+(al[k]?' style="text-align:'+al[k]+'"':'')+'>'+inline(c)+'</th>';}).join('')+'</tr></thead><tbody>';
      while(i<lines.length&&/^\s*\|/.test(lines[i])){h+='<tr>'+cells(lines[i]).map(function(c,k){return '<td'+(al[k]?' style="text-align:'+al[k]+'"':'')+'>'+inline(c)+'</td>';}).join('')+'</tr>';i++;}
      out.push(h+'</tbody></table>');continue;
    }
    if(RE_ITEM.test(l)){var r=list(lines,i,hshift);out.push(r.html);i=r.next;continue;}
    var p=[];
    while(i<lines.length&&lines[i].trim()&&!(p.length&&isStart(lines[i],lines[i+1]))){p.push(lines[i].trim());i++;}
    out.push('<p>'+inline(p.join('\n')).replace(/\n/g,' ')+'</p>');
  }
  return out.join('');
}
function list(lines,i,hshift){
  var m0=lines[i].match(RE_ITEM),base=ind(lines[i]),ord=/\d/.test(m0[2]),start=ord?parseInt(m0[2],10):1,items=[],prevBlank=false;
  while(i<lines.length){
    var l=lines[i];
    if(!l.trim()){
      var j=i+1;while(j<lines.length&&!lines[j].trim())j++;
      if(j>=lines.length)break;
      var mj=lines[j].match(RE_ITEM),ij=ind(lines[j]);
      if(ij>base+1||(mj&&ij<=base+1&&ij>=base&&/\d/.test(mj[2])===ord)){if(items.length)items[items.length-1].sub.push('');i=j;prevBlank=true;continue;}
      break;
    }
    var m=l.match(RE_ITEM),il=ind(l);
    if(m&&il>=base&&il<=base+1){
      if(/\d/.test(m[2])!==ord)break;
      items.push({text:[m[3]],sub:[]});i++;prevBlank=false;continue;
    }
    if(il>base+1){if(!items.length)break;items[items.length-1].sub.push(l);i++;continue;}
    if(!prevBlank&&items.length&&!items[items.length-1].sub.length&&!isStart(l,lines[i+1])){items[items.length-1].text.push(l.trim());i++;continue;}
    break;
  }
  var h=(ord?'<ol'+(start!==1?' start="'+start+'"':'')+'>':'<ul>');
  items.forEach(function(it){
    var sub=it.sub,mi=Infinity;sub.forEach(function(s){if(s.trim())mi=Math.min(mi,ind(s));});
    if(mi===Infinity)mi=0;
    sub=sub.map(function(s){return s.replace(/\t/g,'    ').slice(Math.min(mi,ind(s)));});
    h+='<li>'+inline(it.text.join('\n')).replace(/\n/g,' ')+(sub.length?blocks(sub,hshift):'')+'</li>';
  });
  return {html:h+(ord?'</ol>':'</ul>'),next:i};
}
function md(src,hshift){
  src=String(src||'').replace(/<!--[\s\S]*?-->/g,'').replace(/\r/g,'');
  if(!src.trim())return '<p class="empty">—</p>';
  return blocks(src.split('\n'),hshift);
}

/* ---------- README → вкладки ---------- */
var INSTALL=['ЧтоКудаКого?','Пояснения по версионированию'];   // разделы ## для вкладки «Установка»
var HELP_H1=['Помогите...'];                                    // раздел # (со всеми ## внутри) для вкладки «Помощь»
(function(){
  var secs={home:[],install:[],help:[]},cur='home',inHelp=false,fence=false;
  String(D.readme||'').replace(/\r/g,'').split('\n').forEach(function(l){
    if(/^\s*```/.test(l))fence=!fence;
    var m=!fence&&l.match(/^(#{1,2})\s+(.*?)\s*$/);
    if(m){
      if(m[1].length===1)inHelp=HELP_H1.indexOf(m[2])>=0;
      cur=inHelp?'help':(INSTALL.indexOf(m[2])>=0?'install':'home');
    }
    secs[cur].push(l);
  });
  ['home','install','help'].forEach(function(k){$('doc-'+k).innerHTML=md(secs[k].join('\n'));});
})();

/* ---------- шапка ---------- */
var parts=[];
if(P.version)parts.push('Версия <b>'+esc(P.version)+'</b>');
parts.push('Minecraft '+esc(P.mc));
if(P.neo)parts.push('NeoForge '+esc(P.neo));
parts.push('Модов: <b>'+(D.mods||[]).length+'</b>');
var rl=repoLink();
$('subline').innerHTML=parts.join(' · ');
$('navgh').innerHTML=rl;
var TABS=[['home','Главная'],['install','Установка'],['help','Помощь'],['mods','Моды',(D.mods||[]).length],['packs','Ресурспаки',(D.packs||[]).length],['music','Музыка',((D.music||{}).tracks||[]).length]];
$('tabs').innerHTML=TABS.map(function(t){return '<a href="#'+t[0]+'" data-t="'+t[0]+'">'+t[1]+(t[2]!=null?'<i>'+t[2]+'</i>':'')+'</a>';}).join('');
$('tiles').innerHTML=[['install','⬇️','Установка','PineconeMC, релиз, обновления'],['mods','🧩',(D.mods||[]).length,'модов — каталог с поиском'],['packs','🎨',(D.packs||[]).length,'ресурспаков'],['music','🎵',((D.music||{}).tracks||[]).length,'треков Music Triggers'],['help','🆘','Помощь','Java, шейдеры, лаги']].map(function(t){return '<a class="tile" href="#'+t[0]+'"><b>'+t[1]+' '+esc(t[2])+'</b><span>'+esc(t[3])+'</span></a>';}).join('');

/* ---------- фон: дрейфующие частицы скалка на всех вкладках (canvas), пауза в свёрнутой вкладке; reduce-motion — статичный кадр ---------- */
var REDUCE=!!(window.matchMedia&&matchMedia('(prefers-reduced-motion: reduce)').matches);
/* курсор (только мышь; на тач-устройствах эффектов нет) */
var MS={x:-1,y:-1,on:false};
document.addEventListener('pointermove',function(e){if(e.pointerType==='touch')return;MS.x=e.clientX;MS.y=e.clientY;MS.on=true;},{passive:true});
document.addEventListener('pointerout',function(e){if(e.pointerType!=='touch'&&!e.relatedTarget)MS.on=false;});
/* касание: огонёк/искры/извержение/цветы реагируют на точку касания ~1.4 с */
var TOUCHT=-1e9;document.addEventListener('pointerdown',function(e){if(e.pointerType!=='touch')return;TOUCHT=performance.now();MS.x=e.clientX;MS.y=e.clientY;MS.on=true;MS.tap=(MS.tap||0)+1;clearTimeout(MS.tm);MS.tm=setTimeout(function(){if(performance.now()-TOUCHT>=1350)MS.on=false;},1400);},{passive:true});
var LITE=!!(window.matchMedia&&matchMedia('(pointer:coarse)').matches)||window.innerWidth<700;
window.addEventListener('blur',function(){MS.on=false;});
var fxSet=(function(){
  var cv=$('fx'),ctx=cv&&cv.getContext?cv.getContext('2d'):null,want=false,raf=0,last=0,W=0,H=0,ps=[],spr=null;
  if(!ctx)return function(){};
  function sprite(){var c=document.createElement('canvas');c.width=c.height=64;var g=c.getContext('2d'),gr=g.createRadialGradient(32,32,0,32,32,32);
    gr.addColorStop(0,'rgba(200,255,250,1)');gr.addColorStop(.18,'rgba(60,220,215,.9)');gr.addColorStop(.5,'rgba(20,140,160,.25)');gr.addColorStop(1,'rgba(10,60,80,0)');g.fillStyle=gr;g.fillRect(0,0,64,64);return c;}
  function mk(init){return {x:Math.random()*W,y:init?Math.random()*H:H+20,r:Math.random()*5+3,vx:(Math.random()-.5)*.15,vy:-(Math.random()*.28+.06),ph:Math.random()*6.283,sp:Math.random()*.02+.006,a:Math.random()*.45+.2};}
  var G={x:0,y:0,a:0,f:1,ft:1,fn:0,px:0,py:0},SP=[],SPC=['#d01a12','#a80f0c','#ff5a1a','#ff8a2a','#e8301a'];
  function draw(){
    ctx.clearRect(0,0,W,H);ctx.globalCompositeOperation='lighter';
    if(G.a>.01){/* ночью у курсора — слабый кроваво-красный «огонёк»: пиксельные блоки 8px, ступенчатое затухание, мерцание как у пламени */
      var B=8,RR=104,fl=G.f,gx=G.x,gy=G.y-6*fl,x0=Math.floor((gx-RR)/B)*B,y0=Math.floor((gy-RR*1.2)/B)*B;ctx.globalAlpha=1;
      for(var by=y0;by<gy+RR;by+=B)for(var bx=x0;bx<gx+RR;bx+=B){var dx=(bx+B/2-gx)/RR,dy=(by+B/2-gy)/RR;dy=dy<0?dy*(.78-.12*fl):dy*1.15;var d=Math.sqrt(dx*dx+dy*dy);if(d>=1)continue;
        var lv=Math.ceil(Math.pow(1-d,1.4)*fl*4)/4;if(lv<=0)continue;ctx.fillStyle='rgba('+(150+Math.round(70*lv))+','+Math.round(8+22*lv*lv)+','+Math.round(10+6*lv)+','+(.45*lv*G.a).toFixed(3)+')';ctx.fillRect(bx,by,B,B);}}
    /* редкие пиксельные искры из огонька: квадраты 2–4px по сетке 2px, мерцают и гаснут */
    for(var j=0;j<SP.length;j++){var q=SP[j],k=1-q.t/q.T,fa=k*(Math.random()<.18?.35:1);if(fa<=0)continue;ctx.globalAlpha=Math.min(1,fa*1.1*G.a);ctx.fillStyle=q.c;ctx.fillRect(Math.round(q.x/2)*2,Math.round(q.y/2)*2,q.s,q.s);}
    ctx.globalAlpha=1;
    for(var i=0;i<ps.length;i++){var p=ps[i],a=p.a*(.55+.45*Math.sin(p.ph*1.7)),r=p.r*(.85+.15*Math.sin(p.ph*2.3));ctx.globalAlpha=a;ctx.drawImage(spr,p.x-r,p.y-r,r*2,r*2);}
    ctx.globalAlpha=1;
  }
  function size(){var d=Math.min(window.devicePixelRatio||1,LITE?1:2);W=window.innerWidth;H=window.innerHeight;cv.width=Math.round(W*d);cv.height=Math.round(H*d);ctx.setTransform(d,0,0,d,0,0);
    var n=LITE?Math.max(16,Math.min(36,Math.round(W*H/24000))):Math.max(40,Math.min(90,Math.round(W*H/16000)));while(ps.length<n)ps.push(mk(true));ps.length=n;if(REDUCE)draw();}
  function frame(t){
    raf=0;if(!want||document.hidden)return;
    var dt=last?Math.min((t-last)/16.67,3):1;last=t;
    var mon=MS.on&&!document.documentElement.classList.contains('day');if(mon){if(G.a<.01){G.x=MS.x;G.y=MS.y;}G.x+=(MS.x-G.x)*.12*dt;G.y+=(MS.y-G.y)*.12*dt;}G.a+=((mon?1:0)-G.a)*.05*dt;if(t>G.fn){G.ft=.72+Math.random()*.36;G.fn=t+60+Math.random()*90;}G.f+=(G.ft-G.f)*.25*dt;
    var mv=Math.min(1,Math.hypot(MS.x-G.px,MS.y-G.py)/(8*dt));G.px=MS.x;G.py=MS.y;
    if(MS.tap&&MS.tap!==G.tp){G.tp=MS.tap;if(mon){G.x=MS.x;G.y=MS.y;G.a=Math.max(G.a,.75);for(var k3=0;k3<7&&SP.length<24;k3++){var an3=-Math.PI/2+(Math.random()-.5)*2.6,v3=.8+Math.random()*1.3;SP.push({x:G.x+(Math.random()-.5)*12,y:G.y-4+(Math.random()-.5)*8,vx:Math.cos(an3)*v3,vy:Math.sin(an3)*v3-.3,t:0,T:36+Math.random()*36,s:2+2*(Math.random()*2|0),c:SPC[Math.random()*SPC.length|0]});}}}
    if(mon&&G.a>.5&&SP.length<24&&Math.random()<(1.6+3*mv)/60*dt){var an=-Math.PI/2+(Math.random()-.5)*2.2,v=.6+Math.random()*1.1;SP.push({x:G.x+(Math.random()-.5)*14,y:G.y-4+(Math.random()-.5)*10,vx:Math.cos(an)*v,vy:Math.sin(an)*v-.3,t:0,T:36+Math.random()*36,s:2+2*(Math.random()*2|0),c:SPC[Math.random()*SPC.length|0]});}
    for(var j=SP.length-1;j>=0;j--){var q=SP[j];q.t+=dt;q.x+=q.vx*dt;q.y+=q.vy*dt;q.vy+=.025*dt;q.vx*=Math.pow(.985,dt);if(q.t>=q.T)SP.splice(j,1);}
    for(var i=0;i<ps.length;i++){var p=ps[i];p.ph+=p.sp*dt;p.x+=(p.vx+Math.sin(p.ph)*.18)*dt;p.y+=p.vy*dt;
      if(MS.on){var dx=p.x-MS.x,dy=p.y-MS.y,d2=dx*dx+dy*dy;if(d2<14400&&d2>1){var d=Math.sqrt(d2),f=(1-d/120)*1.6*dt;p.x+=dx/d*f;p.y+=dy/d*f;}}
      if(p.y<-20||p.x<-20||p.x>W+20)ps[i]=mk(false);}
    draw();raf=requestAnimationFrame(frame);
  }
  function kick(){if(!REDUCE&&want&&!document.hidden&&!raf){last=0;raf=requestAnimationFrame(frame);}}
  spr=sprite();size();
  window.addEventListener('resize',size);
  document.addEventListener('visibilitychange',kick);
  return function(on){want=!!on;if(on)kick();else if(raf){cancelAnimationFrame(raf);raf=0;}};
})();

/* ---------- главная: пиксельный огонь внизу (doom-fire, буфер 1/4, ~30 к/с), только на главной; reduce-motion — статичный кадр ---------- */
var fireSet=(function(){
  var cv=$('fire'),ctx=cv&&cv.getContext?cv.getContext('2d'):null,want=false,raf=0,acc=0,last=0,bw=0,bh=0,buf=null,img=null,pal=[],embers=[],TOP=28,PX=4,E=0,ex=0,ecd=0;
  if(!ctx)return function(){};
  var P=[7,7,7,31,7,7,47,15,7,71,15,7,87,23,7,103,31,7,119,31,7,143,39,7,159,47,7,175,63,7,191,71,7,199,71,7,223,79,7,223,87,7,223,87,7,215,95,7,215,95,7,215,103,15,207,111,15,207,119,15,207,127,15,207,135,23,199,135,23,199,143,23,199,151,31,191,159,31,191,159,31,191,167,39,191,167,39,191,175,47,183,175,47,183,183,47,183,183,55,207,207,111,223,223,159,239,239,199,255,255,255];
  for(var k=0;k<P.length/3;k++)pal.push([P[k*3],P[k*3+1],P[k*3+2],Math.min(255,k*30)]);
  function size(){
    bw=Math.max(40,Math.ceil(window.innerWidth/PX));bh=Math.ceil(cv.clientHeight/PX)||43;
    cv.width=bw;cv.height=bh;buf=new Uint8Array(bw*bh);img=ctx.createImageData(bw,bh);
    for(var x=0;x<bw;x++)buf[(bh-1)*bw+x]=TOP;
    embers=[];for(var e=0;e<Math.min(24,Math.round(bw/16));e++)embers.push(mkE(true));
    if(REDUCE){for(var n=0;n<bh*2;n++)step();paint();}
  }
  function mkE(init){return {x:Math.random()*bw,y:init?Math.random()*bh:bh-2,v:Math.random()*.35+.15,c:12+(Math.random()*14|0)};}
  function step(){
    for(var x=0;x<bw;x++)buf[(bh-1)*bw+x]=TOP-(Math.random()<.08?(Math.random()*6|0):0);
    /* извержение: курсор над зоной огня — столб пламени под курсором, выбросы лавы (оверлей), свечение низа экрана */
    var hot=MS.on&&MS.y>window.innerHeight-cv.clientHeight&&!document.documentElement.classList.contains('day');
    if(hot){ex=MS.x;E=Math.min(1,E+.07);}else E=Math.max(0,E-.045);
    if(E>0){var cx=ex/PX|0,w=Math.round(6+10*E);
      for(var fx2=Math.max(0,cx-w);fx2<Math.min(bw,cx+w+1);fx2++){var k2=1-Math.abs(fx2-cx)/(w+1);buf[(bh-1)*bw+fx2]=Math.min(36,TOP+Math.round(8*k2*E+.5));}
      if(Math.random()<.5*E){embers.push(mkE(false));embers[embers.length-1].x=cx+(Math.random()-.5)*w;embers[embers.length-1].v*=1+2*E;}if(embers.length>70)embers.splice(0,embers.length-70);
      if(OV){
        if(E>.25&&Math.random()<.35+.5*E)OV.lava(ex+(Math.random()-.5)*24,1+(Math.random()*2.2*E|0),E);
        ecd-=33;if(E>.75&&ecd<=0){OV.lava(ex,16,1.25);ecd=1300+Math.random()*900;}
        OV.glow(ex,E);
      }
    }
    for(var y=1;y<bh;y++){var row=y*bw;for(var x2=0;x2<bw;x2++){
      var src=row+x2,pv=buf[src];
      if(!pv){buf[src-bw]=0;continue;}
      var r=(Math.random()*3)|0,dst=src-r+1;if(dst-bw<0||dst-bw>=bw*bh)continue;
      var nv=pv-((Math.random()*3)|0);buf[dst-bw]=nv>0?nv:0;
    }}
    if(E>.05){var cx3=ex/PX|0,w3=2+Math.round(4*E),colH=Math.round(bh*(.3+.65*E));/* столб: подкачиваем жар вверх по колонке */
      for(var dx=-w3;dx<=w3;dx++){var xx=cx3+dx;if(xx<0||xx>=bw)continue;var kk=1-Math.abs(dx)/(w3+1),hh=colH*kk*(.75+Math.random()*.4);
        for(var r2=0;r2<hh&&r2<bh-1;r2++){var id=(bh-1-r2)*bw+xx,v2=36-Math.round(r2/colH*13+Math.random()*2);if(buf[id]<v2)buf[id]=v2;}}}
    for(var e=0;e<embers.length;e++){var m=embers[e];m.y-=m.v;m.x+=(Math.random()-.5)*.6;if(m.y<0)embers[e]=mkE(false);}
  }
  function paint(){
    var d=img.data;
    for(var i=0,n=buf.length;i<n;i++){var c=pal[buf[i]],o=i*4;d[o]=c[0];d[o+1]=c[1];d[o+2]=c[2];d[o+3]=c[3];}
    for(var e=0;e<embers.length;e++){var m=embers[e],ix=(m.y|0)*bw+(m.x|0);if(ix>=0&&ix<buf.length){var c2=pal[Math.max(6,m.c-((bh-m.y)/bh*8|0))],o2=ix*4;d[o2]=c2[0];d[o2+1]=c2[1];d[o2+2]=c2[2];d[o2+3]=255;}}
    ctx.putImageData(img,0,0);
  }
  function frame(t){
    raf=0;if(!want||document.hidden)return;
    acc+=last?Math.min(t-last,100):33;last=t;
    if(acc>=33){acc=0;step();paint();}
    raf=requestAnimationFrame(frame);
  }
  function kick(){if(!REDUCE&&want&&!document.hidden&&!raf){last=0;raf=requestAnimationFrame(frame);}}
  size();
  window.addEventListener('resize',function(){if(Math.ceil(window.innerWidth/PX)!==bw||Math.ceil(cv.clientHeight/PX)!==bh)size();});
  document.addEventListener('visibilitychange',kick);
  return function(on){want=!!on;if(on)kick();else if(raf){cancelAnimationFrame(raf);raf=0;}};
})();
/* ---------- ДЕНЬ: пиксельная сцена в духе Minecraft (буфер 1/4, апскейл pixelated, ~30 к/с) ---------- */
var THS={w:0,sun:.62,moon:.35};
var daySet=(function(){
  var cv=$('day'),ctx=cv&&cv.getContext?cv.getContext('2d'):null;
  if(!ctx)return function(){};
  var PX=4,bw=0,bh=0,hz=0,gy=0,want=false,raf=0,acc=0,last=0,T=0,sky=null,land=null,wk=-1,
      clouds=[],veg=[],flw=[],bfs=[],petals=[],pollen=[],trees=[],parrots=[],nextP=8,pmx=-1,pmy=-1;
  function R(a,b){return a+Math.random()*(b-a);}
  function mix(a,b,t){return [Math.round(a[0]+(b[0]-a[0])*t),Math.round(a[1]+(b[1]-a[1])*t),Math.round(a[2]+(b[2]-a[2])*t)];}
  function rgb(c,a){return a==null?'rgb('+c[0]+','+c[1]+','+c[2]+')':'rgba('+c[0]+','+c[1]+','+c[2]+','+a+')';}
  function off(w,h){var c=document.createElement('canvas');c.width=w;c.height=h;return c;}
  function hillY(i,x){var b=[.55,.62,.69][i],a=[.05,.045,.035][i],f=[.021,.034,.05][i],p=[1.3,4.1,2.2][i];return Math.round(bh*b-bh*a*(Math.sin(x*f+p)+.5*Math.sin(x*f*2.3+p*1.7)));}
  var FC=[[250,214,40],[214,32,32],[72,112,232]],FC2=[[255,242,130],[40,20,20],[140,176,255]];/* одуванчик, мак, василёк */
  var GC=[[70,150,45],[90,175,55],[112,192,66],[60,134,40]];
  var PAR=[{b:[215,40,40],w:[40,90,210],t:[40,90,210]},{b:[45,95,225],w:[240,205,50],t:[30,60,160]},{b:[80,190,60],w:[40,130,40],t:[230,200,40]},{b:[70,200,215],w:[40,120,190],t:[235,235,235]},{b:[170,170,170],w:[120,120,120],t:[90,90,90]}];
  var SP={sit:["....bb.","...bbek","...bbb.","..bwwb.","..bwwb.","..bbb..",".tt.k..","tt....."],f1:["...ww....","...www...","ttbbbbbek","..bbbbb..","........."],f2:[".........",".........","ttbbbbbek","..bbwww..","...ww...."]};
  function sprite(map,x,y,flip,pc){var w=map[0].length;for(var j=0;j<map.length;j++){var row=map[j];for(var i=0;i<w;i++){var ch=row.charAt(i);if(ch==='.')continue;
    var c=ch==='b'?pc.b:ch==='w'?pc.w:ch==='t'?pc.t:ch==='e'?[15,15,15]:[70,70,70];ctx.fillStyle=rgb(c);ctx.fillRect(Math.round(x+(flip?w-1-i:i)),Math.round(y+j),1,1);}}}
  function seedRand(s){return function(){s=(s*1103515245+12345)&0x7fffffff;return s/0x7fffffff;};}
  function paintBG(w){
    wk=w;var g=sky.getContext('2d');
    var top=mix([66,135,222],[64,52,128],w*.85),bot=mix([170,215,255],[255,152,92],w*.9);
    for(var y=0;y<bh;y++){g.fillStyle=rgb(mix(top,bot,Math.min(1,y/(bh*.6))));g.fillRect(0,y,bw,1);}
    var RC=[[230,60,60],[245,150,50],[250,225,70],[90,200,90],[70,140,235],[90,80,200],[150,80,200]],rx=bw*.3,ry=bh*.72,r0=bh*.46;
    g.globalAlpha=.34*(1-w);g.lineWidth=1.3;
    for(var i=0;i<7;i++){g.strokeStyle=rgb(RC[i]);g.beginPath();g.arc(rx,ry,r0-i*1.25,Math.PI,2*Math.PI);g.stroke();}
    g.globalAlpha=1;
    var l=land.getContext('2d'),tint=[120,78,82],HC=[[136,192,122],[104,172,84],[84,156,62]];l.clearRect(0,0,bw,bh);
    for(var h=0;h<3;h++){var hc=mix(HC[h],tint,w*.35),he=mix(mix(HC[h],[255,255,255],.18),tint,w*.35);
      for(var x=0;x<bw;x++){var yy=hillY(h,x);l.fillStyle=rgb(hc);l.fillRect(x,yy,1,bh-yy);l.fillStyle=rgb(he);l.fillRect(x,yy,1,1);}
      if(h===1)trees.forEach(function(t){/* дубы на среднем холме */
        l.fillStyle=rgb(mix([104,76,44],tint,w*.3));l.fillRect(t.x,t.by-5,1,5);
        l.fillStyle=rgb(mix([46,118,38],tint,w*.3));l.fillRect(t.x-3,t.by-9,7,4);l.fillRect(t.x-2,t.by-10,5,1);
        l.fillStyle=rgb(mix([70,148,54],tint,w*.3));l.fillRect(t.x-2,t.by-9,2,1);l.fillRect(t.x+1,t.by-8,1,1);l.fillRect(t.x-1,t.by-10,2,1);});}
    var rnd=seedRand(7);
    for(var y2=gy;y2<bh;y2++){l.fillStyle=rgb(mix(mix([98,174,62],[60,126,40],(y2-gy)/Math.max(1,bh-gy)),tint,w*.3));l.fillRect(0,y2,bw,1);}
    for(var n=0;n<bw*(bh-gy)*.08;n++){l.fillStyle=rgb(mix(rnd()<.5?[80,152,48]:[118,194,72],tint,w*.3));l.fillRect(rnd()*bw|0,gy+1+(rnd()*(bh-gy)|0),1,1);}
    l.fillStyle=rgb(mix([118,196,72],tint,w*.3));l.fillRect(0,gy,bw,1);
  }
  function size(){
    bw=Math.max(60,Math.ceil(window.innerWidth/PX));bh=Math.max(60,Math.ceil(window.innerHeight/PX));cv.width=bw;cv.height=bh;
    hz=Math.round(bh*.55);gy=bh-Math.round(Math.min(170,window.innerHeight*.24)/PX);sky=off(bw,bh);land=off(bw,bh);wk=-1;
    trees=[];[.06,.17,.62,.74,.9].forEach(function(f){var x=Math.round(bw*f);trees.push({x:x,by:hillY(1,x)+1});});
    clouds=[];for(var c=0;c<Math.max(5,Math.round(bw/45));c++)clouds.push(mkCloud(R(0,bw)));
    veg=[];flw=[];
    var ng=Math.round(bw*1.5),nf=Math.round(bw/4.5);
    for(var i=0;i<ng+nf;i++){var y=gy+1+Math.floor(Math.pow(Math.random(),1.4)*(bh-gy-1)),d=(y-gy)/Math.max(1,bh-gy),isF=i>=ng;
      var v={x:R(0,bw),y:y,h:Math.round(R(2,4)+d*3+(isF?2:0)),ph:R(0,6.283),f:isF?(Math.random()*3|0):-1,c:GC[Math.random()*GC.length|0],hx:0,hy:0};veg.push(v);if(isF)flw.push(v);}
    veg.sort(function(a,b){return a.y-b.y;});
    bfs=[];var BC=[[255,255,255],[255,220,60],[255,140,40],[130,185,255],[240,120,200]];
    for(var b=0;b<Math.min(7,Math.max(3,Math.round(bw/50)));b++){var fl=flw[Math.random()*flw.length|0];bfs.push({f:fl,x:fl.x,y:fl.y-fl.h,st:0,vx:0,vy:0,c:BC[b%BC.length],tm:0,ph:R(0,6.283),tf:null});}
    pollen=[];for(var p=0;p<Math.round(bw*bh/1400);p++)pollen.push({x:R(0,bw),y:R(0,bh),vx:R(.03,.12),ph:R(0,6.283),a:R(.35,.85),fl:Math.random()<.3});
    petals=[];parrots=[];
    if(REDUCE||!want)draw();
  }
  function mkCloud(x){var w=Math.round(R(10,26)),h=Math.round(R(2,4)),b=[];for(var i=0;i<Math.round(R(1,3));i++)b.push([Math.round(R(1,w-6)),Math.round(R(3,7)),Math.round(R(1,2))]);return {x:x,y:Math.round(R(4,bh*.3)),w:w,h:h,v:R(.02,.06),b:b};}
  function cur(){return MS.on?{x:MS.x/PX,y:MS.y/PX}:null;}
  function bend(v,c){var o=Math.sin(T*1.15+v.x*.15+v.ph)*.55+Math.sin(T*.37+v.x*.02)*.45;
    if(c){var dx=v.x-c.x,dy=v.y-c.y;if(dx>-16&&dx<16&&dy>-14&&dy<12){var k=(1-Math.abs(dx)/16)*(1-Math.max(0,-dy)/14);o+=(dx<0?-1:1)*k*4.5;}}return o;}
  function step(dts){
    var c=cur();
    clouds.forEach(function(cl){cl.x+=cl.v*dts*30;if(cl.x>bw+4){var n=mkCloud(-30);cl.x=-cl.w-4;cl.y=n.y;cl.w=n.w;cl.b=n.b;}});
    pollen.forEach(function(p){p.ph+=.03;p.x+=p.vx;p.y+=Math.sin(T*.8+p.ph)*.04-.004;
      if(c){var dx=p.x-c.x,dy=p.y-c.y,d2=dx*dx+dy*dy;if(d2<100&&d2>.01){var d=Math.sqrt(d2);p.x+=dx/d*(1-d/10)*.7;p.y+=dy/d*(1-d/10)*.7;}}
      if(p.x>bw+2)p.x=-2;if(p.y<-2)p.y=bh;if(p.y>bh+2)p.y=0;});
    /* лепестки: курсор быстро проходит по цветам */
    if(c&&pmx>=0&&c.y>gy-12){var mdx=c.x-pmx,mdy=c.y-pmy;if(mdx*mdx+mdy*mdy>1.5)flw.forEach(function(f){var dx=f.hx-c.x,dy=f.hy-c.y;if(dx*dx+dy*dy<90&&Math.random()<.3&&petals.length<70)petals.push({x:f.hx,y:f.hy,vx:R(-.4,.4)+mdx*.12,vy:R(-.7,-.25),c:FC[f.f],l:0,L:R(60,120)});});}
    if(c){pmx=c.x;pmy=c.y;}else pmx=-1;
    for(var i=petals.length-1;i>=0;i--){var p=petals[i];p.l++;p.vy=Math.min(.35,p.vy+.012);p.vx=p.vx*.98+Math.sin(T*3+i)*.02+.01;p.x+=p.vx;p.y+=p.vy;if(p.l>p.L||p.y>bh)petals.splice(i,1);}
    /* бабочки: сидят на цветах, вспархивают от курсора, потом возвращаются */
    bfs.forEach(function(b){
      if(b.st===0){b.x=b.f.hx;b.y=b.f.hy-1;if(c){var dx=b.x-c.x,dy=b.y-c.y;if(dx*dx+dy*dy<150){b.st=1;b.vx=(dx<0?-1:1)*R(.4,1);b.vy=R(-1.2,-.6);b.tm=T+R(3,6);b.tf=null;}}return;}
      b.vx+=R(-.06,.06);b.vy+=Math.sin(T*9+b.ph)*.07-.004;
      if(T>b.tm&&!b.tf)b.tf=flw[Math.random()*flw.length|0];
      if(b.tf){var tx=b.tf.hx-b.x,ty=b.tf.hy-1-b.y;b.vx+=tx*.006;b.vy+=ty*.006;if(tx*tx+ty*ty<2.5){b.st=0;b.f=b.tf;b.tf=null;}
        if(c){var ex=b.x-c.x,ey=b.y-c.y;if(ex*ex+ey*ey<150){b.tf=null;b.tm=T+R(2,4);b.vy-=.5;}}}
      b.vx*=.94;b.vy*=.94;b.x+=b.vx;b.y+=b.vy;if(b.y<bh*.25)b.vy+=.08;if(b.y>bh-2)b.vy-=.1;if(b.x<1)b.vx+=.1;if(b.x>bw-2)b.vx-=.1;});
    /* попугаи: иногда пролетают, могут присесть на дерево */
    if(T>nextP&&parrots.length<2){var dir=Math.random()<.5?1:-1,tr=Math.random()<.6&&trees.length?trees[Math.random()*trees.length|0]:null;
      parrots.push({x:dir>0?-10:bw+10,y:R(bh*.1,bh*.35),dir:dir,v:R(.55,.85),pc:PAR[Math.random()*PAR.length|0],st:tr?'to':'fly',tr:tr,tm:0,ph:R(0,6.283)});nextP=T+R(14,26);}
    for(var j=parrots.length-1;j>=0;j--){var q=parrots[j];
      if(q.st==='sit'){if(T>q.tm||(c&&Math.abs(c.x-q.x-3)<8&&Math.abs(c.y-q.y-4)<8)){q.st='fly';q.dir=Math.random()<.5?1:-1;q.y-=1;}continue;}
      if(q.st==='to'){var px=q.tr.x-3,py=q.tr.by-10-8,dx2=px-q.x,dy2=py-q.y,dd=Math.sqrt(dx2*dx2+dy2*dy2);q.dir=dx2>=0?1:-1;
        if(dd<1.2){q.x=px;q.y=py;q.st='sit';q.tm=T+R(4,9);continue;}var sp=Math.min(q.v,dd);q.x+=dx2/dd*sp;q.y+=dy2/dd*sp+Math.sin(T*3+q.ph)*.1;continue;}
      q.x+=q.dir*q.v;q.y+=Math.sin(T*3+q.ph)*.15-.02;if(q.x<-14||q.x>bw+14)parrots.splice(j,1);}
  }
  function draw(){
    var w=Math.round(THS.w*12)/12;if(w!==wk)paintBG(w);
    ctx.clearRect(0,0,bw,bh);ctx.drawImage(sky,0,0);
    /* солнце (квадратное, как в Minecraft) движется по дуге */
    var s=THS.sun,sx=Math.round(bw*(.1+.8*s)),sy=Math.round(hz+6-Math.sin(Math.PI*s)*(hz-10)),sc=mix([255,250,196],[255,170,90],THS.w);
    ctx.fillStyle=rgb(sc,.12);ctx.fillRect(sx-9,sy-9,18,18);ctx.fillStyle=rgb(sc,.22);ctx.fillRect(sx-7,sy-7,14,14);
    ctx.fillStyle=rgb(sc);ctx.fillRect(sx-5,sy-5,10,10);ctx.fillStyle=rgb(mix(sc,[255,255,255],.6));ctx.fillRect(sx-3,sy-3,6,6);
    var cc=mix([255,255,255],[255,196,176],THS.w*.7),cs=mix([226,234,246],[220,160,150],THS.w*.7);
    clouds.forEach(function(cl){var x=Math.round(cl.x);ctx.fillStyle=rgb(cc,.93);ctx.fillRect(x,cl.y,cl.w,cl.h);cl.b.forEach(function(b){ctx.fillRect(x+b[0],cl.y-b[2],b[1],b[2]);});ctx.fillStyle=rgb(cs,.93);ctx.fillRect(x,cl.y+cl.h,cl.w,1);});
    ctx.drawImage(land,0,0);
    parrots.forEach(function(q){if(q.st==='sit')sprite(SP.sit,q.x,q.y+(Math.sin(T*2+q.ph)>.92?1:0),q.dir<0,q.pc);});
    var c=cur();
    for(var i=0;i<veg.length;i++){var v=veg[i],o=bend(v,c),hx=v.x,hy=v.y;
      ctx.fillStyle=rgb(v.f>=0?[58,128,40]:v.c);
      for(var j=1;j<=v.h;j++){var r=j/v.h;hx=Math.round(v.x+o*r*r);hy=v.y-j;ctx.fillRect(hx,hy,1,1);}
      if(v.f>=0){v.hx=hx;v.hy=hy-1;ctx.fillStyle=rgb(FC[v.f]);
        if(v.f===0){ctx.fillRect(hx,hy-1,2,2);ctx.fillStyle=rgb(FC2[0]);ctx.fillRect(hx,hy-1,1,1);}
        else{ctx.fillRect(hx-1,hy-1,3,1);ctx.fillRect(hx,hy-2,1,3);ctx.fillStyle=rgb(FC2[v.f]);ctx.fillRect(hx,hy-1,1,1);}}}
    bfs.forEach(function(b){var x=Math.round(b.x),y=Math.round(b.y),open=b.st?Math.sin(T*22+b.ph)>0:Math.sin(T*3+b.ph)>.5;
      ctx.fillStyle='rgb(40,30,30)';ctx.fillRect(x,y,1,1);ctx.fillStyle=rgb(b.c);
      if(open){ctx.fillRect(x-1,y-1,1,2);ctx.fillRect(x+1,y-1,1,2);}else ctx.fillRect(x,y-1,1,1);});
    petals.forEach(function(p){ctx.fillStyle=rgb(p.c,Math.max(0,1-p.l/p.L));ctx.fillRect(Math.round(p.x),Math.round(p.y),1,1);});
    pollen.forEach(function(p){var x=Math.round(p.x),y=Math.round(p.y);if(p.fl){ctx.fillStyle='rgba(255,255,255,'+(p.a*.8)+')';ctx.fillRect(x,y,1,1);ctx.fillStyle='rgba(255,255,255,'+(p.a*.35)+')';ctx.fillRect(x-1,y,3,1);ctx.fillRect(x,y-1,1,3);}
      else{ctx.fillStyle='rgba(255,236,140,'+p.a+')';ctx.fillRect(x,y,1,1);}});
    parrots.forEach(function(q){if(q.st!=='sit')sprite(Math.sin(T*12+q.ph)>0?SP.f1:SP.f2,q.x,q.y,q.dir<0,q.pc);});
  }
  function frame(t){
    raf=0;if(!want||document.hidden)return;
    var d=last?Math.min(t-last,100):33;last=t;acc+=d;
    if(acc>=33){var s=acc/1000;T+=s;acc=0;step(s);draw();}
    raf=requestAnimationFrame(frame);
  }
  function kick(){if(REDUCE){draw();return;}if(want&&!document.hidden&&!raf){last=0;raf=requestAnimationFrame(frame);}}
  size();
  window.addEventListener('resize',function(){if(Math.ceil(window.innerWidth/PX)!==bw||Math.ceil(window.innerHeight/PX)!==bh)size();});
  document.addEventListener('visibilitychange',kick);
  return function(on){var was=want;want=!!on;if(on){if(!was)wk=-1;kick();}else if(raf){cancelAnimationFrame(raf);raf=0;}};
})();

/* оверлей #sparks: капли крови с логотипа главной в такт сердцебиению (@keyframes heartbeat .92s: lub 14%, dub 42%) и лава извержения огня */
var OV=null;
(function(){
  var img=document.querySelector('.hero img.icon'),cv=$('sparks'),ctx=cv&&cv.getContext?cv.getContext('2d'):null,lcv=$('lava'),lc=lcv&&lcv.getContext?lcv.getContext('2d'):null;
  if(!ctx||!lc||REDUCE)return;
  var CYC=920,LUB=.14*CYC,DUB=.42*CYC,hov=false,t0=0,bl=[],lv=[],sd=[],raf=0,last=0,W=0,H=0,gX=0,gE=0,gT=0,spr;
  spr=(function(){var c=document.createElement('canvas');c.width=c.height=32;var g=c.getContext('2d'),gr=g.createRadialGradient(16,16,0,16,16,16);gr.addColorStop(0,'rgba(255,245,200,1)');gr.addColorStop(.25,'rgba(255,170,50,.9)');gr.addColorStop(.6,'rgba(255,70,10,.3)');gr.addColorStop(1,'rgba(180,20,0,0)');g.fillStyle=gr;g.fillRect(0,0,32,32);return c;})();
  function size(){var d=Math.min(window.devicePixelRatio||1,LITE?1.5:2);W=window.innerWidth;H=window.innerHeight;cv.width=lcv.width=Math.round(W*d);cv.height=lcv.height=Math.round(H*d);ctx.setTransform(d,0,0,d,0,0);lc.setTransform(d,0,0,d,0,0);}
  /* капли: сначала набухают на краю логотипа, затем стекают вниз с гравитацией; у «пола» под логотипом — клякса и затухание */
  function bleed(n){
    if(!img)return;var r=img.getBoundingClientRect();if(!r.width)return;var cx=r.left+r.width/2,cy=r.top+r.height/2,R=r.width/2*.93;
    for(var i=0;i<n;i++){var a=Math.PI*(.08+Math.random()*.84)+(Math.random()<.25?Math.PI*(Math.random()-.5)*.9:0);/* в основном нижняя половина круга */
      if(bl.length>140)break;
      bl.push({x:cx+Math.cos(a)*R,y:cy+Math.sin(a)*R,vx:Math.cos(a)*(.25+Math.random()*.6)+(Math.random()-.5)*.35,vy:Math.sin(a)*.4-Math.random()*.55,
        s:2.4+Math.random()*2.4,hang:5+Math.random()*12,l:0,fl:r.bottom+40+Math.random()*70,sp:0,sl:0,sh:.75+Math.random()*.4});}
  }
  function drop(p){
    var sp=Math.sqrt(p.vx*p.vx+p.vy*p.vy),s=p.s*(p.hang>0?Math.max(.25,1-p.hang/16):1),L=s*(1.2+Math.min(4.5,sp*.9));
    ctx.save();ctx.translate(p.x,p.y);ctx.rotate(Math.atan2(p.vy,p.vx));
    ctx.beginPath();ctx.moveTo(-L,0);ctx.quadraticCurveTo(-L*.35,-s,0,-s);ctx.arc(0,0,s,-Math.PI/2,Math.PI/2);ctx.quadraticCurveTo(-L*.35,s,-L,0);ctx.closePath();
    var g=ctx.createLinearGradient(0,-s,0,s);g.addColorStop(0,'#c8102e');g.addColorStop(.55,'#8a0618');g.addColorStop(1,'#4a020c');ctx.fillStyle=g;ctx.fill();
    ctx.restore();
    ctx.fillStyle='rgba(255,215,215,.75)';ctx.beginPath();ctx.ellipse(p.x-s*.3,p.y-s*.35,s*.32,s*.2,-.6,0,6.283);ctx.fill();/* блик */
  }
  function splat(p){var q=1-p.sl/48;ctx.globalAlpha=Math.max(0,q)*.9;var w=p.s*(2.2+1.2*Math.min(1,p.sl/6))*p.sh;
    var g=ctx.createRadialGradient(p.x,p.y,0,p.x,p.y,w);g.addColorStop(0,'#a00a20');g.addColorStop(.7,'#6a0412');g.addColorStop(1,'rgba(60,2,10,0)');ctx.fillStyle=g;
    ctx.beginPath();ctx.ellipse(p.x,p.y,w,w*.32,0,0,6.283);ctx.fill();
    ctx.fillStyle='rgba(255,190,190,.45)';ctx.beginPath();ctx.ellipse(p.x-w*.3,p.y-w*.08,w*.22,w*.06,0,0,6.283);ctx.fill();ctx.globalAlpha=1;}
  function seeds(n){
    if(!img)return;var r=img.getBoundingClientRect();if(!r.width)return;var cx=r.left+r.width/2,cy=r.top+r.height/2,R=r.width/2*.9;
    for(var i=0;i<n&&sd.length<90;i++){var a=-Math.PI*(.05+Math.random()*.9);
      sd.push({x:cx+Math.cos(a)*R,y:cy+Math.sin(a)*R,vx:Math.cos(a)*.6+.2,vy:-.35-Math.random()*.45,wx:.35+Math.random()*.75,ph:Math.random()*6.283,s:1.15+Math.random()*.6,l:0,L:280+Math.random()*240});}
  }
  function pappus(p,a){/* семечко: коричневое зёрнышко, тонкая ножка и белый пушистый зонтик */
    var tl=Math.sin(p.ph)*.35,s=p.s,L=8*s,tx=p.x+Math.sin(tl)*L,ty=p.y-Math.cos(tl)*L;
    ctx.globalAlpha=a;ctx.strokeStyle='rgba(235,232,215,.85)';ctx.lineWidth=.7;ctx.beginPath();ctx.moveTo(p.x,p.y);ctx.lineTo(tx,ty);ctx.stroke();
    ctx.fillStyle='#8a6a40';ctx.beginPath();ctx.ellipse(p.x,p.y+1,1,2.2,tl,0,6.283);ctx.fill();
    var g=ctx.createRadialGradient(tx,ty,0,tx,ty,6*s);g.addColorStop(0,'rgba(255,255,255,.55)');g.addColorStop(1,'rgba(255,255,255,0)');ctx.fillStyle=g;ctx.beginPath();ctx.arc(tx,ty,6*s,0,6.283);ctx.fill();
    ctx.strokeStyle='rgba(255,255,255,.85)';ctx.lineWidth=.55;ctx.beginPath();
    for(var i=0;i<11;i++){var an=-Math.PI/2+tl+(i/10-.5)*Math.PI*1.25,rr=5.5*s;ctx.moveTo(tx,ty);ctx.lineTo(tx+Math.cos(an)*rr,ty+Math.sin(an)*rr);}
    ctx.stroke();ctx.globalAlpha=1;
  }
  function lava(x,n,pow){
    for(var i=0;i<n&&lv.length<180;i++)lv.push({x:x+(Math.random()-.5)*10,y:H-6-Math.random()*26,vx:(Math.random()-.5)*2.6*pow,vy:-(5+Math.random()*7.5)*(.55+.45*pow),s:1.8+Math.random()*2.8,l:0,L:70+Math.random()*50,px:0,py:0});
    go();
  }
  function frame(t){
    raf=0;var dt=last?Math.min((t-last)/16.67,3):1;last=t;
    if(hov){var e=performance.now()-t0,c=Math.floor(e/CYC),ph=e-c*CYC,k=c*2+(ph>=DUB?2:ph>=LUB?1:0);/* k нечётный — lub, чётный — dub */
      if(k!==hov.k){if(hov.k!==undefined){if(document.documentElement.classList.contains('day'))seeds(k%2===1?2:1);else bleed(k%2===1?11:5);}hov.k=k;}}
    ctx.clearRect(0,0,W,H);
    /* кровь (обычное наложение) */
    for(var i=bl.length-1;i>=0;i--){var p=bl[i];
      if(p.sp){p.sl+=dt;if(p.sl>=48){bl.splice(i,1);continue;}splat(p);continue;}
      p.l+=dt;
      if(p.hang>0){p.hang-=dt;p.x+=p.vx*.15*dt;p.y+=.12*dt;}
      else{p.vx*=Math.pow(.985,dt);p.vy=p.vy*Math.pow(.99,dt)+.16*dt;p.x+=p.vx*dt;p.y+=p.vy*dt;}
      if(p.y>=p.fl){p.y=p.fl;p.sp=1;p.sl=0;splat(p);continue;}
      if(p.y>H+20){bl.splice(i,1);continue;}
      drop(p);}
    /* семена одуванчика (днём): плывут по ветру и медленно опускаются */
    for(var s2=sd.length-1;s2>=0;s2--){var e2=sd[s2];e2.l+=dt;if(e2.l>=e2.L||e2.x>W+30||e2.y>H+30){sd.splice(s2,1);continue;}
      e2.ph+=.045*dt;e2.vx+=(e2.wx-e2.vx)*.01*dt;e2.vy=Math.min(.32,e2.vy+.004*dt);e2.x+=(e2.vx+Math.sin(e2.ph)*.35)*dt;e2.y+=(e2.vy+Math.cos(e2.ph*1.3)*.12)*dt;
      pappus(e2,Math.min(1,e2.l/12,(e2.L-e2.l)/60));}
    /* лава и свечение — на холсте #lava под контентом (аддитивно) */
    lc.clearRect(0,0,W,H);lc.globalCompositeOperation='lighter';
    gE+=(gT-gE)*.12;gT*=.9;
    if(gE>.01){var R=Math.max(200,W*.22)*(.7+.3*gE),gr=lc.createRadialGradient(gX,H+30,0,gX,H+30,R);gr.addColorStop(0,'rgba(255,140,40,'+(.38*gE)+')');gr.addColorStop(.5,'rgba(255,70,10,'+(.16*gE)+')');gr.addColorStop(1,'rgba(255,40,0,0)');lc.fillStyle=gr;lc.fillRect(gX-R,H-R,R*2,R+30);
      var lg=lc.createLinearGradient(0,H,0,H-110);lg.addColorStop(0,'rgba(255,90,20,'+(.12*gE)+')');lg.addColorStop(1,'rgba(255,60,0,0)');lc.fillStyle=lg;lc.fillRect(0,H-110,W,110);}
    for(var j=lv.length-1;j>=0;j--){var b=lv[j];b.l+=dt;b.px=b.x;b.py=b.y;
      b.vx*=Math.pow(.992,dt);b.vy+=.22*dt;b.x+=b.vx*dt;b.y+=b.vy*dt;
      if(b.l>=b.L||b.y>H+20){lv.splice(j,1);continue;}
      var q=1-b.l/b.L,sz=b.s*(1.6+2*q);
      lc.globalAlpha=Math.min(1,q*1.5)*.85;lc.drawImage(spr,b.x-sz*2,b.y-sz*2,sz*4,sz*4);
      lc.globalAlpha=q;lc.strokeStyle=q>.65?'#fff1b8':q>.35?'#ffab30':'#e2420e';lc.lineWidth=b.s*.9;lc.lineCap='round';
      lc.beginPath();lc.moveTo(b.px-b.vx*1.5,b.py-b.vy*1.5);lc.lineTo(b.x,b.y);lc.stroke();}
    lc.globalAlpha=1;lc.globalCompositeOperation='source-over';
    if(hov||bl.length||lv.length||sd.length||gE>.01||gT>.01)raf=requestAnimationFrame(frame);else{ctx.clearRect(0,0,W,H);lc.clearRect(0,0,W,H);}
  }
  function go(){if(!raf){last=0;raf=requestAnimationFrame(frame);}}
  size();window.addEventListener('resize',size);
  if(img){img.addEventListener('mouseenter',function(){if(performance.now()-TOUCHT<1500)return;t0=performance.now();hov={};go();});
    img.addEventListener('pointerdown',function(e){if(e.pointerType!=='touch')return;t0=performance.now();hov={};go();img.classList.remove('tap');void img.offsetWidth;img.classList.add('tap');clearTimeout(img.__tt);img.__tt=setTimeout(function(){hov=false;img.classList.remove('tap');},1840);});
    img.addEventListener('mouseleave',function(){hov=false;});}
  window.addEventListener('hashchange',function(){hov=false;});
  OV={lava:lava,glow:function(x,e){gX=x;gT=Math.max(gT,e);if(e>.01)go();}};
})();
/* ---------- день / ночь / авто: плавная смена сцен и акцента; режим хранится в localStorage ---------- */
(function(){
  var de=document.documentElement,H=window.__TH||{},mode=de.getAttribute('data-theme')||'auto',k=parseFloat(de.style.getPropertyValue('--dk'))||0,anim=null,iv=0,moon=$('moon'),seg=$('thm');
  if(moon&&moon.getContext){var g=moon.getContext('2d');g.fillStyle='#bfc6d4';g.fillRect(2,2,12,12);g.fillStyle='#e6e9f0';g.fillRect(3,3,10,10);g.fillStyle='#f6f7fb';g.fillRect(4,4,5,4);
    g.fillStyle='#b9c0cf';g.fillRect(9,5,2,2);g.fillRect(5,9,3,2);g.fillRect(10,10,2,2);g.fillStyle='#cdd3df';g.fillRect(7,7,1,1);g.fillRect(11,8,1,1);}
  function phase(){var p=H.ph?H.ph():0;return {k:H.k?H.k(p):0,sun:Math.min(1,Math.max(0,p/.575)),moon:Math.min(1,((p-.5+1)%1)/.575)};}
  function target(){if(mode!=='auto')return {k:mode==='day'?1:0,sun:.62,moon:.3};var f=phase();if(REDUCE)f.k=f.k>=.5?1:0;return f;}
  function apply(v,f){
    k=v;de.style.setProperty('--dk',v.toFixed(3));de.classList.toggle('day',v>=.5);
    THS.w=mode==='auto'||anim?1-Math.abs(2*v-1):0;THS.sun=f.sun;THS.moon=f.moon;
    if(moon){var s=Math.min(1,Math.max(0,f.moon));moon.style.left=(6+84*s).toFixed(2)+'%';moon.style.top=Math.round(70+(1-Math.sin(Math.PI*s))*Math.max(110,window.innerHeight*.42))+'px';}
    fxSet(v<.995);fireSet(v<.995);daySet(v>.005);
  }
  function ease(e){return e<.5?2*e*e:1-Math.pow(-2*e+2,2)/2;}
  function run(){
    var tg=target();
    if(anim){var e=Math.min(1,(performance.now()-anim.t0)/1500);apply(anim.from+(tg.k-anim.from)*ease(e),tg);if(e<1){anim.raf=requestAnimationFrame(run);return;}anim=null;apply(tg.k,tg);}
    else apply(tg.k,tg);
  }
  function tick(){clearInterval(iv);iv=0;if(mode==='auto'&&!document.hidden)iv=setInterval(function(){if(!anim)run();},REDUCE?30000:100);}
  function marks(){if(!seg)return;Array.prototype.forEach.call(seg.querySelectorAll('button'),function(b){b.setAttribute('aria-checked',b.getAttribute('data-m')===mode?'true':'false');});}
  function set(m,init){
    mode=m;de.setAttribute('data-theme',m);marks();
    if(!init)try{localStorage.setItem('zarya-theme2',m);}catch(e){}
    if(anim){cancelAnimationFrame(anim.raf);anim=null;}
    if(!init&&!REDUCE)anim={from:k,t0:performance.now(),raf:0};
    run();tick();
  }
  if(seg)seg.addEventListener('click',function(e){var b=e.target.closest('button[data-m]');if(b&&b.getAttribute('data-m')!==mode)set(b.getAttribute('data-m'));});
  document.addEventListener('visibilitychange',function(){if(!document.hidden&&mode==='auto'&&!anim)run();tick();});
  window.addEventListener('storage',function(e){if(e.key==='zarya-theme'&&/^(day|night|auto)$/.test(e.newValue||'')&&e.newValue!==mode)set(e.newValue);});
  window.__setTheme=function(m){set(m);};
  set(mode,true);
})();
/* логотип: после наведения плавно возвращается из текущей фазы «сердцебиения» */
(function(){
  function calm(host,img){if(!host||!img)return;host.addEventListener('mouseleave',function(){if(REDUCE)return;var cs=getComputedStyle(img),t=cs.transform,f=cs.filter;img.style.transition='none';img.style.transform=t;img.style.filter=f;void img.offsetWidth;img.style.transition='transform .4s ease,filter .5s ease';img.style.transform='';img.style.filter='';});}
  var h=document.querySelector('.hero img.icon'),b=document.querySelector('nav.top .brand img');
  calm(h,h);
})();

/* ---------- роутинг по #hash ---------- */
var tabIds=TABS.map(function(t){return t[0];});
function route(){
  var h=decodeURIComponent(location.hash.replace(/^#/,'')),tab=h,el=null;
  if(tabIds.indexOf(h)<0){el=h?document.getElementById(h):null;var sec=el&&el.closest('.tab');tab=sec?sec.id.replace(/^t-/,''):'home';}
  tabIds.forEach(function(t){$('t-'+t).classList.toggle('on',t===tab);});
  var de=document.documentElement;de.classList.toggle('home',tab==='home');de.classList.toggle('fit',/^(mods|packs|music)$/.test(tab));de.setAttribute('data-t',tab);de.classList.remove('boot');
  Array.prototype.forEach.call(document.querySelectorAll('#tabs a'),function(a){a.classList.toggle('on',a.getAttribute('data-t')===tab);});
  if(el)el.scrollIntoView();else window.scrollTo(0,0);
  var tb=$('tabs'),ta=tb&&tb.querySelector('a.on');if(ta&&tb.scrollWidth>tb.clientWidth){var r1=tb.getBoundingClientRect(),r2=ta.getBoundingClientRect();tb.scrollLeft+=(r2.left+r2.width/2)-(r1.left+r1.width/2);}
  if(window.__fitA)__fitA();
}
window.addEventListener('hashchange',route);
if(window.ResizeObserver&&window.__fitA)new ResizeObserver(function(){__fitA();}).observe($('t-home'));

/* ---------- Моды ---------- */
(function(){
  var mods=D.mods||[],cats=D.cats||[],catIdx={},catIcon={},catSel='',sortK='name',sortD=1,open={};
  cats.forEach(function(c,i){catIdx[c.name]=i;catIcon[c.name]=c.icon;});
  var tb=$('mtb'),q=$('mq'),cnt=$('mcnt'),chipsEl=$('mcats'),allBtn=$('mall'),shown=[];
  function hue(c){var i=catIdx[c];return i==null?0:Math.round(i*360/Math.max(cats.length,1));}
  function badge(c){var h=hue(c);return '<span class="badge" style="color:hsl('+h+',65%,72%);border-color:hsl('+h+',45%,38%)">'+esc((catIcon[c]?catIcon[c]+' ':'')+c)+'</span>';}
  function links(m){
    var h='',u;
    if((u=safeUrl(m.modrinth)))h+='<a class="lk mr" href="'+esc(u)+'" target="_blank" rel="noopener noreferrer">MR</a>';
    if((u=safeUrl(m.curseforge)))h+='<a class="lk cf" href="'+esc(u)+'" target="_blank" rel="noopener noreferrer">CF</a>';
    if((u=safeUrl(m.git)))h+='<a class="lk gt" href="'+esc(u)+'" target="_blank" rel="noopener noreferrer">git</a>';
    return h;
  }
  mods.forEach(function(m){m.category=m.category||'Без категории';m._s=[m.name,m.modid,m.category,m.desc,m.notes].join('\n').toLowerCase();});
  function chips(){
    var n={};mods.forEach(function(m){n[m.category]=(n[m.category]||0)+1;});
    var h='<button class="chip'+(catSel?'':' on')+'" data-c="">Все<i>'+mods.length+'</i></button>';
    cats.forEach(function(c){if(n[c.name])h+='<button class="chip'+(catSel===c.name?' on':'')+'" data-c="'+esc(c.name)+'">'+esc(c.icon+' '+c.name)+'<i>'+n[c.name]+'</i></button>';});
    chipsEl.innerHTML=h;
  }
  chipsEl.addEventListener('click',function(e){var b=e.target.closest('.chip');if(!b)return;var c=b.getAttribute('data-c');catSel=(catSel===c)?'':c;chips();render();});
  function ck(m){return ('000'+(catIdx[m.category]==null?999:catIdx[m.category])).slice(-3)+String(m.name).toLowerCase();}
  function render(){
    var terms=qTerms(q.value);
    var list=shown=mods.filter(function(m){return (!catSel||m.category===catSel)&&qHit(m._s,terms);});
    list.sort(function(a,b){var x,y;if(sortK==='cat'){x=ck(a);y=ck(b);}else{x=String(a.name).toLowerCase();y=String(b.name).toLowerCase();}return (x<y?-1:x>y?1:0)*sortD;});
    var h=[];
    list.forEach(function(m){
      var id=esc(m.key),o=open[m.key];
      h.push('<tr class="m'+(o?' open':'')+'" data-id="'+id+'"><td class="ch"><span class="chev">▸</span></td><td class="n">'+esc(m.name)+'<span class="id">'+esc(m.modid)+'</span></td><td class="c">'+badge(m.category)+'</td><td class="d">'+esc(m.short)+'</td><td class="v">'+esc(m.version)+'</td><td class="l">'+links(m)+'</td></tr>');
      if(o)h.push(xRow(m.key,detail(m),true));
    });
    tb.innerHTML=h.length?h.join(''):'<tr><td colspan="6" class="none">Ничего не найдено</td></tr>';
    updAll();
    cnt.textContent=(list.length===mods.length&&!catSel)?(mods.length+' модов'):(list.length+' из '+mods.length);
  }
  function detail(m){return '<h3>Описание</h3>'+md(m.desc)+'<h3>Заметки</h3>'+md(m.notes)+'<div class="meta">'+esc(m.file)+'</div>';}
  function updAll(){allBtn.textContent=(shown.length&&shown.every(function(m){return open[m.key];}))?'Свернуть все':'Раскрыть все';}
  var byKey={};mods.forEach(function(m){byKey[m.key]=m;});
  tb.addEventListener('click',function(e){if(e.target.closest('a'))return;var tr=e.target.closest('tr.m');if(!tr)return;var k=tr.getAttribute('data-id');open[k]=!open[k];toggleRow(tr,open[k],function(){return detail(byKey[k]);});updAll();});
  Array.prototype.forEach.call(document.querySelectorAll('#t-mods th.s'),function(th){
    th.addEventListener('click',function(){
      var k=th.getAttribute('data-k');if(sortK===k)sortD=-sortD;else{sortK=k;sortD=1;}
      Array.prototype.forEach.call(document.querySelectorAll('#t-mods th.s'),function(t){t.classList.toggle('on',t===th);t.querySelector('.ar').textContent=(t===th&&sortD<0)?'▼':'▲';});
      render();
    });
  });
  document.querySelector('#t-mods th.s[data-k=name]').classList.add('on');
  allBtn.addEventListener('click',function(){var v=!(shown.length&&shown.every(function(m){return open[m.key];}));shown.forEach(function(m){open[m.key]=v;});render();});
  q.addEventListener('input',render);
  chips();render();
})();

/* ---------- Ресурспаки ---------- */
(function(){
  var packs=D.packs||[],open={},tb=$('ptb'),allBtn=$('pall'),q=$('pq'),cnt=$('pcnt'),shown=[],game=D.packsOrder==='game';
  packs.forEach(function(p){p._s=[p.name,p.file,p.short,p.desc,p.notes,p.mcdesc].join('\n').toLowerCase();});
  $('porder').textContent=game?'Порядок как в игре (options.txt): сначала включённые — сверху высший приоритет, как в списке «Выбранные»; ниже выключенные по алфавиту.':'По алфавиту — options.txt ещё нет.';
  function st(p){if(!game)return '';return (p.on?'<span class="st on" data-tip="Включён, позиция в списке «Выбранные»">Вкл '+p.pos+'</span>':'<span class="st">выкл</span>')+(p.incompat?'<span class="st inc" data-tip="Помечен игрой как несовместимый (incompatibleResourcePacks)">несовм.</span>':'');}
  function lk(u,c,t){u=safeUrl(u);return u?'<a class="lk '+c+'" href="'+esc(u)+'" target="_blank" rel="noopener noreferrer">'+t+'</a>':'';}
  function links(p){return lk(p.modrinth,'mr','MR')+lk(p.curseforge,'cf','CF')+lk(p.git,'gt','git')+lk(p.other,'fl','сайт');}
  function render(){
    var h=[],terms=qTerms(q.value);
    shown=packs.filter(function(p){return qHit(p._s,terms);});
    shown.forEach(function(p){
      var id=esc(p.key),o=open[p.key];
      h.push('<tr class="m'+(o?' open':'')+(game&&!p.on?' off':'')+'" data-id="'+id+'"><td class="ch"><span class="chev">▸</span></td><td class="n">'+st(p)+esc(p.name)+'<span class="id">'+(p.kind==='folder'?'папка':'zip')+'</span></td><td class="d">'+esc(p.short||'')+'</td><td class="v">'+esc(p.version||'')+'</td><td class="num">'+size(p.size)+'</td><td class="l">'+links(p)+'</td></tr>');
      if(o)h.push(xRow(p.key,detail(p),true));
    });
    tb.innerHTML=h.length?h.join(''):'<tr><td colspan="6" class="none">'+(packs.length?'Ничего не найдено':'Ресурспаков нет')+'</td></tr>';
    updAll();
    cnt.textContent=shown.length===packs.length?(packs.length+' ресурспаков'):(shown.length+' из '+packs.length);
  }
  function detail(p){return '<h3>Описание</h3>'+md(p.desc||'')+'<h3>Заметки</h3>'+md(p.notes||'')+'<div class="meta">'+esc(p.file)+(p.mcdesc?' · pack.mcmeta: '+esc(p.mcdesc):'')+'</div>';}
  function updAll(){allBtn.textContent=(shown.length&&shown.every(function(p){return open[p.key];}))?'Свернуть все':'Раскрыть все';}
  var byKey={};packs.forEach(function(p){byKey[p.key]=p;});
  tb.addEventListener('click',function(e){if(e.target.closest('a'))return;var tr=e.target.closest('tr.m');if(!tr)return;var k=tr.getAttribute('data-id');open[k]=!open[k];toggleRow(tr,open[k],function(){return detail(byKey[k]);});updAll();});
  allBtn.addEventListener('click',function(){var v=!(shown.length&&shown.every(function(p){return open[p.key];}));shown.forEach(function(p){open[p.key]=v;});render();});
  q.addEventListener('input',render);
  render();
})();

/* ---------- Музыка ---------- */
(function(){
  var M=D.music||{},tracks=M.tracks||[],trigs=M.triggers||[],sel='';
  var I=M.info||{},TN=I.tn||{};
  var tmap={};trigs.forEach(function(t){tmap[t.key]=t;});
  function tlabel(k){var t=tmap[k],type=t?t.type:String(k).split('-')[0],id=t?t.id:String(k).split('-').slice(1).join('-');return (TN[type]||type)+(id?': '+id:'');}
  function tbadge(k,i){var h=Math.round((i*47)%360);return '<span class="badge" data-tip="'+esc(k)+'" style="color:hsl('+h+',65%,72%);border-color:hsl('+h+',45%,38%)">'+esc(tlabel(k))+'</span>';}
  var order={};trigs.forEach(function(t,i){order[t.key]=i;});
  tracks.forEach(function(s){if(!Array.isArray(s.triggers))s.triggers=s.triggers?[s.triggers]:[];});
  tracks.forEach(function(s){(s.triggers||[]).forEach(function(k){if(order[k]==null)order[k]=Object.keys(order).length;});s._s=[s.title,s.file,(s.triggers||[]).map(tlabel).join(' '),(s.triggers||[]).join(' ')].join('\n').toLowerCase();});
  if(M.parsed&&trigs.length){
    /* Пояснения параметров — по документации и исходникам Music Triggers 7.0.4 (docs/musictriggers/triggers/*.mdx, lang/en_us.json, MTConfigV6.java) */
    /* подписи и пояснения — $mtParams/$mtTypeNames/$mtTypeDesc в _common.ps1 (общие с MUSIC.md) */
    var PD=I.pd||{},TICKP={},TD=I.td||{};(I.tick||[]).forEach(function(k){TICKP[k]=1;});
    function ptip(k){var d=PD[k];return d?(k+' — '+d[0]+'. '+d[1].replace(/<[^>]+>/g,'')+' ['+d[2]+']'):(k+' — не уточнено');}
    function pval(k,v){var t=Array.isArray(v)?'['+v.join(', ')+']':String(v);var u=(TICKP[k]&&/^\d+$/.test(String(v)))?'<small class="u">≈ '+(+v/20).toString().replace('.',',')+' с</small>':'';return '<code class="pp" tabindex="0" data-tip="'+esc(ptip(k))+'">'+esc(k)+' = '+esc(t)+'</code>'+u;}
    var used={identifier:1,priority:1},uni=null;
    var rows=trigs.filter(function(t){if(t.type==='universal'){uni=t;return false;}return true;}).map(function(t){
      Object.keys(t.params||{}).forEach(function(k){used[k]=1;});
      var ps=Object.keys(t.params||{}).map(function(k){return pval(k,t.params[k]);}).join(' ');
      var n=tracks.filter(function(s){return (s.triggers||[]).indexOf(t.key)>=0;}).length;
      var tt=(TN[t.type]||t.type)+(TD[t.type]?' — '+TD[t.type]:'')+'\nтип: '+t.type+(t.id?'\nidentifier = '+t.id:'');
      return '<tr><td><span tabindex="0" data-tip="'+esc(tt)+'">'+tbadge(t.key,order[t.key]).replace(/ data-tip="[^"]*"/,'')+'</span></td><td class="pc" tabindex="0" data-tip="'+esc(ptip('priority'))+'">'+esc(t.priority||'—')+'</td><td>'+n+'</td><td>'+ps+'</td></tr>';
    }).join('');
    var usedS={triggers:1};tracks.forEach(function(s){if(s.playOnce)usedS.play_once=1;});
    function leg(keys){return keys.map(function(k){var d=PD[k];return '<dt><code>'+esc(k)+'</code>'+(d?' <b>'+esc(d[0])+'</b>':'')+'</dt><dd>'+(d?d[1]+' <i>'+esc(d[2])+'</i>':'<i>не уточнено</i>')+'</dd>';}).join('');}
    var ordK=['identifier','priority'].concat(Object.keys(used).filter(function(k){return k!=='identifier'&&k!=='priority';}).sort());
    var uniH=uni&&Object.keys(uni.params||{}).length?'<p class="note">Общие настройки <code>[triggers.universal]</code>: '+Object.keys(uni.params).map(function(k){return pval(k,uni.params[k]);}).join(' ')+' — применяются ко всем событиям, у которых этот параметр не задан (оставлен по умолчанию).</p>':'';
    var legend='<div class="cfgleg"><h4>Что означают параметры</h4><p class="note">По документации и исходникам Music Triggers 7.0.4. Время указывается в тиках: 20 тиков = 1 секунда. Наведите на параметр в таблице — появится подсказка.</p>'+uniH+'<dl>'+leg(ordK)+'</dl><h4>Параметры треков <span>([songs.*])</span></h4><dl>'+leg(Object.keys(usedS).sort())+'</dl></div>';
    $('mtcfg').innerHTML='<button class="btn cfgbtn" id="mtbtn" type="button" aria-expanded="false">⚙ Как настроены события (main.toml)<span class="chev">▸</span></button>';
    $('mtovb').innerHTML='<table class="cfgt"><thead><tr><th tabindex="0" data-tip="Тип события Music Triggers и его identifier (наведите на значок — подробности)">Событие</th><th tabindex="0" data-tip="'+esc(ptip('priority'))+'">Приоритет</th><th tabindex="0" data-tip="Сколько треков привязано к событию">Треков</th><th data-tip="Параметры события из main.toml; наведите на параметр — пояснение">Параметры</th></tr></thead><tbody>'+rows+'</tbody></table>'+(M.missing&&M.missing.length?'<p class="note">В конфиге есть треки без файла: '+M.missing.map(function(x){return '<code>'+esc(x)+'</code>';}).join(' ')+'</p>':'')+legend;
    (function(){
      var ov=$('mtov'),btn=$('mtbtn'),pan=ov.querySelector('.ovp');
      function set(on){ov.classList.toggle('on',on);ov.setAttribute('aria-hidden',on?'false':'true');btn.setAttribute('aria-expanded',on?'true':'false');btn.classList.toggle('on',on);}
      btn.addEventListener('click',function(){set(!ov.classList.contains('on'));});
      $('mtovx').addEventListener('click',function(){set(false);});
      document.addEventListener('keydown',function(e){if(e.key==='Escape'&&ov.classList.contains('on'))set(false);});
      document.addEventListener('mousedown',function(e){if(ov.classList.contains('on')&&!pan.contains(e.target)&&!btn.contains(e.target))set(false);});
      window.addEventListener('hashchange',function(){set(false);});
    })();
  } else if(!M.parsed){$('mtcfg').innerHTML='<p class="note">main.toml не найден или не разобран — показаны только файлы.</p>';}
  var chipsEl=$('strig');
  function chips(){
    var n={},none=0;tracks.forEach(function(s){if(!(s.triggers||[]).length)none++;(s.triggers||[]).forEach(function(k){n[k]=(n[k]||0)+1;});});
    var keys=Object.keys(n).sort(function(a,b){return order[a]-order[b];});
    var h='<button class="chip'+(sel?'':' on')+'" data-k="">Все<i>'+tracks.length+'</i></button>';
    keys.forEach(function(k){h+='<button class="chip'+(sel===k?' on':'')+'" data-k="'+esc(k)+'">'+esc(tlabel(k))+'<i>'+n[k]+'</i></button>';});
    if(none&&M.parsed)h+='<button class="chip'+(sel==='\u0000'?' on':'')+'" data-k="\u0000">Без события<i>'+none+'</i></button>';
    chipsEl.innerHTML=h;
  }
  chipsEl.addEventListener('click',function(e){var b=e.target.closest('.chip');if(!b)return;var k=b.getAttribute('data-k');sel=(sel===k)?'':k;chips();render();});
  var q=$('sq');
  function render(){
    var s=q.value.trim().toLowerCase(),terms=s?s.split(/\s+/):[];
    var list=tracks.filter(function(t){var tr=t.triggers||[];return (!sel||(sel==='\u0000'?!tr.length:tr.indexOf(sel)>=0))&&terms.every(function(x){return t._s.indexOf(x)>=0;});});
    $('stb').innerHTML=list.length?list.map(function(t){
      return '<tr><td class="n">'+esc(t.title)+'<span class="id">'+esc(t.file)+(t.playOnce?' · play_once = '+esc(t.playOnce):'')+'</span></td><td>'+((t.triggers||[]).map(function(k){return tbadge(k,order[k]);}).join('')||'<span class="empty">—</span>')+'</td><td class="num">'+mss(t.dur)+'</td><td class="num">'+size(t.size)+'</td></tr>';
    }).join(''):'<tr><td colspan="4" class="none">Ничего не найдено</td></tr>';
    var ld=list.reduce(function(a,t){return a+(+t.dur||0);},0);
    $('scnt').textContent=(list.length===tracks.length?(tracks.length+' треков'):(list.length+' из '+tracks.length))+(ld?' · '+hms(ld):'');
  }
  q.addEventListener('input',render);
  chips();render();
})();

/* ---------- подсказки: один элемент #tip для всех [data-tip]; нативные title переводятся в data-tip ---------- */
(function(){
  var tip=document.createElement('div');tip.id='tip';tip.setAttribute('role','tooltip');document.body.appendChild(tip);
  var cur=null,tm=0,px=0,py=0,byPtr=false;
  function conv(el){if(el.nodeType!==1)return;if(el.hasAttribute('title')&&el.id!=='tip'){var v=el.getAttribute('title');el.removeAttribute('title');if(v)el.setAttribute('data-tip',v);}}
  function convAll(root){conv(root);if(root.querySelectorAll)Array.prototype.forEach.call(root.querySelectorAll('[title]'),conv);}
  convAll(document.body);
  new MutationObserver(function(ms){ms.forEach(function(m){if(m.type==='attributes')conv(m.target);else Array.prototype.forEach.call(m.addedNodes,function(n){if(n.nodeType===1)convAll(n);});});}).observe(document.body,{subtree:true,childList:true,attributes:true,attributeFilter:['title']});
  function place(){
    if(!cur)return;var r=cur.getBoundingClientRect(),vw=window.innerWidth,vh=window.innerHeight,tw=tip.offsetWidth,th=tip.offsetHeight,M=8,x,y,up;
    if(byPtr&&r.width>360){x=px-tw/2;up=py-th-14>M;y=up?py-th-14:py+18;}
    else{x=r.left+r.width/2-tw/2;up=r.top-th-8>M;y=up?r.top-th-8:r.bottom+8;}
    x=Math.max(M,Math.min(vw-tw-M,x));y=Math.max(M,Math.min(vh-th-M,y));
    tip.style.transform='';tip.classList.toggle('up',!up);tip.style.left=Math.round(x)+'px';tip.style.top=Math.round(y)+'px';
  }
  function show(el,ptr){
    var t=el.getAttribute('data-tip');if(!t){hide();return;}
    cur=el;byPtr=ptr;tip.textContent=t;el.setAttribute('aria-describedby','tip');place();tip.classList.add('on');
  }
  function hide(){clearTimeout(tm);if(cur)cur.removeAttribute('aria-describedby');cur=null;tip.classList.remove('on');}
  document.addEventListener('pointerover',function(e){if(e.pointerType==='touch')return;var el=e.target.closest&&e.target.closest('[data-tip]');if(el===cur)return;clearTimeout(tm);
    if(!el){if(cur&&cur!==document.activeElement)hide();return;}
    var big=el.getBoundingClientRect().width>360;tm=setTimeout(function(){show(el,true);},cur?60:(big?650:280));},{passive:true});
  document.addEventListener('pointermove',function(e){px=e.clientX;py=e.clientY;if(cur&&byPtr&&cur.getBoundingClientRect().width>360)place();},{passive:true});
  document.addEventListener('pointerout',function(e){if(!e.relatedTarget){clearTimeout(tm);if(cur&&byPtr)hide();}});
  document.addEventListener('focusin',function(e){var el=e.target.closest&&e.target.closest('[data-tip]');clearTimeout(tm);if(el&&el.matches(':focus-visible'))show(el,false);else if(cur&&!byPtr)hide();});
  document.addEventListener('focusout',function(){if(cur&&!byPtr)hide();});
  document.addEventListener('pointerdown',hide,true);
  document.addEventListener('keydown',function(e){if(e.key==='Escape')hide();});
  window.addEventListener('scroll',function(){if(cur)place();},true);
  window.addEventListener('resize',hide);window.addEventListener('hashchange',hide);
})();

route();
})();
</script>
</body>
</html>
'@
$iconLink = if ($icon) { "<link rel=`"icon`" href=`"$icon`">" } else { '' }
$html = $html.Replace('<link rel="icon" href="__ICON__">', $iconLink).Replace('__TITLE__', [Net.WebUtility]::HtmlEncode($title)).Replace('__BRANDICON__', $brandIcon).Replace('__HEROICON__', $heroIcon).Replace('__HEADER__', $header).Replace('__DATA__', $json)
[IO.File]::WriteAllText($outPath, $html, $enc)
Write-Host "Z@RYA.html: модов $($mods.Count), ресурспаков $($packs.Count), треков $(@($music.tracks).Count)$(if ($music.parsed) { ", событий $(@($music.triggers).Count)" } else { ', main.toml не разобран' })"
if ($music.missing.Count) { Write-Host "В main.toml треки без файла: $($music.missing -join ', ')" }

# --- index.html в корне: переадресация на Z@RYA.html (для GitHub Pages: https://<user>.github.io/<repo>/), #вкладка сохраняется ---
if (-not $OutFile) {
  $outFull = [IO.Path]::GetFullPath($outPath); $rootFull = [IO.Path]::GetFullPath($root).TrimEnd('\')
  $leaf = if ($outFull.StartsWith($rootFull + '\', [StringComparison]::OrdinalIgnoreCase)) { $outFull.Substring($rootFull.Length + 1) } else { Split-Path -Leaf $outPath }
  $target = Url-Path $leaf   # _Helpful Stuff\Z@RYA.html -> _Helpful%20Stuff/Z%40RYA.html
  $tE = [Net.WebUtility]::HtmlEncode($title); $lE = [Net.WebUtility]::HtmlEncode(($leaf -replace '\\', '/'))
  $idx = @"
<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex">
<title>$tE</title>
<link rel="canonical" href="$target">
<link rel="icon" href="data:,">
<script>location.replace('$target'+location.search+location.hash);</script>
<meta http-equiv="refresh" content="1; url=$target">
<style>html{background:#0d0b0c;color:#d8d0d0;font:16px/1.5 system-ui,sans-serif}body{margin:0;min-height:100vh;display:grid;place-items:center}a{color:#e0483a}</style>
</head>
<body>
<p><a id="go" href="$target">$tE &mdash; $lE</a></p>
<script>document.getElementById('go').href='$target'+location.hash;</script>
</body>
</html>

"@ -replace "`r`n", "`n"
  $idxPath = Join-Path $root 'index.html'
  $old = if (Test-Path -LiteralPath $idxPath) { [IO.File]::ReadAllText($idxPath, $enc) } else { $null }
  if ($old -cne $idx) { [IO.File]::WriteAllText($idxPath, $idx, $enc); Write-Host "index.html -> $target" }
  # GitHub Pages: без .nojekyll Jekyll пропускает папки на «_», и _Helpful Stuff/Z@RYA.html не опубликуется
  $nj = Join-Path $root '.nojekyll'
  if (-not (Test-Path -LiteralPath $nj)) { [IO.File]::WriteAllBytes($nj, [byte[]]@()); Write-Host '.nojekyll создан (нужен для GitHub Pages)' }
}
