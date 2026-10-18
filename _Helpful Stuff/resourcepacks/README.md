# Карточки ресурспаков

Одна карточка на ресурспак (zip или папку) из `minecraft/resourcepacks`: `<имя>.md`. Устроены так же, как карточки модов в `_Helpful Stuff/mods`:

```yaml
---
name: 'Название'
file: 'имя-файла.zip'
version: '1.2.3'
modrinth: 'https://modrinth.com/resourcepack/...'
curseforge: 'https://www.curseforge.com/minecraft/texture-packs/...'
git: 'https://github.com/...'
other: 'https://...'
---

## Описание

1–2 предложения: что пак меняет в игре.

## Заметки
```

`_TEMPLATE.md` — шаблон карточки. Файлы на `_` и `README.md` карточками не считаются.

`_Helpful Stuff/Update resourcepacks.ps1`:
- обновляет `minecraft/resourcepacks/RESOURCEPACKLIST.md` (MD5 zip-файлов),
- создаёт заготовки карточек для новых паков (по `_TEMPLATE.md`); карточка связана с паком по полю `file`, при смене версии файла находится по имени без номеров версий,
- заполняет `file`, пустые `version` и `modrinth` (по имени файла и sha1 через Modrinth API); заполненные вручную поля и текст не трогает,
- сообщает о карточках, у которых больше нет пака, но не удаляет их,
- пишет сводку `_Helpful Stuff/RESOURCEPACKS.md` (порядок как в игре, описания, ссылки),
- в конце вызывает `Update README and site.ps1` (шапка `README.md` и страница сборки): вкладка «Ресурспаки» в `Z@RYA.html` берёт название, ссылки, описание и заметки из карточек.
