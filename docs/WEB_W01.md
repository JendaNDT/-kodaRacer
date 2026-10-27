# W01 — první export hry pro web

Datum: 27. října 2026. Stav: **dokončeno — první technický prototyp**, bez veřejného vydání.

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
- Kompletní původní [CI pro Windows a Android](https://github.com/JendaNDT/-kodaRacer/actions/runs/40504550565) prošlo **18/18 kontrolními kroky** (import a 17 testovacích kroků), včetně všech síťových scénářů; prošly i exporty APK a EXE. [Záznam kroků a diagnostiky](web/w01-native-actions.json). V nativních protokolech zůstává sedm hlášení enginu známých typů z W00 (materiál a zdroje při ukončení), bez chyb skriptů. Negativní kontrola jiné verze vyhodnocuje očekávané odmítnutí připojení; následný timeout klienta původní test toleruje.
- Zveřejnění nativního sestavení bylo přeskočeno. Veřejné APK a EXE mají stejné kontrolní součty jako ve W00.
- Zdejší cloudový prohlížeč nemá dostupné WebGL 2.0. Na skutečné stránce byla ověřena česká informace o nepodporované grafice a tlačítko Zkusit znovu. Tato zkouška není vydávána za spuštění 3D scény.
- Automatický browser test na GitHubu úspěšně ověřil všech šest scénářů: desktop, emulovaný dotyk, chybějící WebGL, WebAssembly, spouštěcí skript a herní balík. V obou úspěšných startech se zobrazilo skutečné 3D menu, byl zaznamenán vykreslený snímek a nebyly chyby skriptů ani hlášení `ERROR:` enginu. [Výsledky](web/w01-browser-results.json).
- Snímky z automatického testu jsou součástí artefaktu `SkodaRacer-Web-W01` v [úspěšném běhu](https://github.com/JendaNDT/-kodaRacer/actions/runs/40504550644). Softwarové vykreslování v CI neposkytuje výkonový výsledek pro MacBook ani telefon.

## Opakování sestavení

S odpovídajícím editorem a webovými šablonami:

```bash
python3 tools/export_web.py --godot /cesta/ke/godotu
```

Výstup je `dist/web/`, včetně `build-manifest.json`. Pro přehrání je nutný HTTP server; přímé otevření HTML jako místního souboru není způsob spuštění exportu.

Na běžném Linuxovém CI připraví editor a jednovláknové šablony `tools/setup_web_toolchain.py`. Samostatný automatický test používá Playwright 1.64.1. V prostředí se správou náhledů Sites se používá cloudový prohlížeč a předepsaný náhled, nikoli tento lokální automatizační skript.

Další etapa: **W02 — soupeři a načítání bez blokování stránky**.

## Identita ověřeného webového balíku

Sestavení z commitu `a1e25eafbe02653d6c6dde63718089771d32eb54` má čisté sledované zdroje, 18 přibalených duchů a 46 360 406 bajtů herních souborů před kompresí. [Soupis a kontrolní součty](web/w01-ci-build-manifest.json) byly znovu porovnány se staženým výstupem CI. [Kroky webového workflow](web/w01-web-actions.json) zůstávají uchované zvlášť od výsledků nativní hry.
