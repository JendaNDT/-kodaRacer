# W01 — první export hry pro web

Datum: 27. října 2026. Stav: implementace připravená, probíhá ověření v prohlížeči na GitHubu.

Výchozí commit: `3d03fa41fe708f2d1d886d9efe4a0a9e1ae316f4`, větev `codex/web-version`, herní verze 1.19.1.

## Změny

- Nový jednovláknový export `Web`; zahrnuje všechny soubory duchů, hudbu a fonty současné hry.
- Česká spouštěcí stránka s tlačítkem Hrát, průběhem načítání, ověřením potřebných možností, vysvětlením chyby a opakováním načtení.
- `PlatformCaps` a předřazený autoload `WebBridge` oddělují web od nativních platforem: dotyk, mobilní rozvržení, ovladače, stav úložiště a celá obrazovka. Šířka displeje není jediným kritériem.
- Stránka dostane potvrzení připravenosti až po vytvoření menu a 3D světa a následných snímcích enginu.
- Web nepoužívá ENet ani UDP vyhledávání. Nabídka online je viditelně označená jako připravovaná; nepodporované operace mají ochranu i pod nabídkou.
- První start používá nízkou grafickou kvalitu. Mobilní web se řídí mobilními možnostmi a zachovává dosavadní vypnutí MSAA.
- Nové nástroje připraví přesnou verzi Godotu, vytvoří a ověří balík a uchovají kontrolní součty i informaci o zdrojovém commitu.
- Samostatné workflow sestavuje webový artefakt a provádí testy v Chromium. Má pouze oprávnění číst repozitář a nic nezveřejňuje na web ani do Releases.

## Dočasné části W01

W02 nahradí středovou jízdní stopu soupeřů předpočítanými daty. Původní vláknový výpočet se ve webovém prototypu nespouští a čekací smyčka ho neblokuje.

Zvuk se na webu zatím nevytváří ani nespouští; v nabídce je označen jako připravovaný. W03 doplní webové přehrávání a motor. Nativní zvuk se tímto přepínačem nemění.

Senzory, vibrace a důkladné ověření ovládání patří do W04. Trvalé uchování skutečného herního postupu a jeho migrace patří do W05; zkouška IndexedDB ve stránce sama o sobě neprokazuje bezpečné ukládání postupu. Výkonové profily a kompletní místní režimy budou ověřeny ve W06–W07. PWA a offline režim jsou zatím vypnuté.

## Ověření

- Import a export v Godotu 4.7.1 prošly bez chyb skriptů a bez chyb exportu.
- Pět cílených původních nativních kroků prošlo: import, závod, naklánění se simulovanými daty, vibrace pro jednoho i dva hráče a hudba. [Záznam](web/w01-native-checks.json).
- Zdejší cloudový prohlížeč nemá dostupné WebGL 2.0. Na skutečné stránce byla ověřena česká informace o nepodporované grafice a tlačítko Zkusit znovu. Tato zkouška není vydávána za spuštění 3D scény.
- Automatický browser test na GitHubu ověří start na desktopu a při emulaci dotyku, skutečné snímky scény a chybové stavy: WebGL, WebAssembly, chybějící spouštěcí skript a herní balík.
- Snímky z automatického testu budou výstupem workflow. Softwarové vykreslování v CI neposkytuje výkonový výsledek pro MacBook ani telefon.

## Opakování sestavení

S odpovídajícím editorem a webovými šablonami:

```bash
python3 tools/export_web.py --godot /cesta/ke/godotu
```

Výstup je `dist/web/`, včetně `build-manifest.json`. Pro přehrání je nutný HTTP server; přímé otevření HTML jako místního souboru není způsob spuštění exportu.

Na běžném Linuxovém CI připraví editor a jednovláknové šablony `tools/setup_web_toolchain.py`. Samostatný automatický test používá Playwright 1.64.1. V prostředí se správou náhledů Sites se používá cloudový prohlížeč a předepsaný náhled, nikoli tento lokální automatizační skript.

Další etapa po úspěšném ověření W01: **W02 — soupeři a načítání bez blokování stránky**.
