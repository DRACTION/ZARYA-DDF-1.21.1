# Скрипт для пересчета хеш-суммы модов
# Работает из любой текущей папки: пути считаются от расположения скрипта (корень инстанса = папка выше).
$root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $root 'minecraft\mods'
if (-not (Test-Path -LiteralPath $dir)) { Write-Error "Папка не найдена: $dir"; exit 1 }
$output = "## Список модов и ХЭШ-суммы`n"
$output += "`n"
foreach($f in (Get-ChildItem -LiteralPath $dir -File | Sort-Object Name)){
	if($f.Extension -eq ".jar"){
		$output += "    Имя файла: " + $f.Name + "`n"
		$output += "    MD5: " + (Get-FileHash -LiteralPath $f.FullName -Algorithm MD5).Hash + "`n"
		$output +=  "---`n"
}}
Out-File -FilePath (Join-Path $dir 'MODLIST.md') -InputObject $output -Encoding utf8
Write-Host "Обновлён: $(Join-Path $dir 'MODLIST.md')"

# Mod cards + MODS.md
& (Join-Path $PSScriptRoot 'Update MODS cards.ps1')
