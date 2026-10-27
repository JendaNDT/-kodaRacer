# Webová verze — průběh ověření

## W00 — dokončeno s evidovanými omezeními

Podrobný [záznam W00](WEB_W00.md) obsahuje přesný výchozí stav, tabulku původních kontrol, známé problémy a podklady pro pokračování.

- Zdroj hry: `main`, commit `870ba46e85eb0ae5fad1875bee585dd55752e7e9`, verze 1.19.1. Všech 119 sledovaných souborů v `godot/` zůstalo beze změny.
- Pracovní větev: `codex/web-version`.
- Godot 4.7.1 i webové šablony ověřeny; jednovláknový export odděleného prázdného projektu prošel. Samotná hra se pro web v tomto kroku neexportovala.
- První místní běh: **16/18 kroků prošlo**. Síťový závod překročil limit přesnosti a vyhledávání hostitele zde nenašlo hostitele.
- Jediné cílené opakování síťového závodu: **prošlo**, 95. percentil odchylky 0,62 m místo původních 1,14 m. Oba výsledky jsou zachované samostatně.
- Nový [běh na GitHubu](https://github.com/JendaNDT/-kodaRacer/actions/runs/40495480190): **18/18 kontrolních kroků prošlo**, exporty APK i EXE prošly, zveřejnění z pracovní větve bylo přeskočeno.
- Veřejný `testovaci-build` a jeho APK/EXE zůstaly stejné.
- Existující hlášení enginu při běhu bez grafiky a omezení síťového doplňku jsou uvedené v podrobném záznamu. Úspěšný test není vydáván za nepřítomnost všech varování.
- Fyzická zařízení, výkon GPU, prohlížeče a skutečné spojení WebRTC nejsou v tomto kroku potvrzené.

## Opakování původní testovací sady

Je potřeba Python 3, PyYAML, Bash a Godot přesně ve verzi uvedené v `.github/workflows/build.yml`.

```bash
python3 tools/run_web_baseline.py --godot /cesta/ke/godotu --output-dir /cesta/k/vysledkum
```

Nástroj načte stávající testovací kroky z workflow, vynechá exporty i zveřejňování, oddělí ukládaná herní data a pro každý krok uchová protokol, návratový kód i další hlášení enginu. Výsledky z různých pokusů ukládat do různých výstupních adresářů.

## Další krok

**W01 — první Web export a rozhraní pro možnosti zařízení** podle [plánu](PLAN_WEB.md). Síťové výsledky W00 jsou závazný výchozí záznam pro pozdější online etapy.
