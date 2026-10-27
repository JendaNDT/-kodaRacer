# Webová verze — průběh ověření

## W00 — příprava výchozího stavu

Stav: probíhá. Výchozí herní kód nebyl měněn.

- Zdroj: `main`, commit `870ba46e85eb0ae5fad1875bee585dd55752e7e9`, hra 1.19.1.
- Editor: `4.7.1.stable.official.a13da4feb`, ověřený SHA256 oficiálního stažení.
- Pracovní větev: `codex/web-version`.
- Předchozí GitHub Actions pro tento commit úspěšné: https://github.com/JendaNDT/-kodaRacer/actions/runs/37751242918.
- Nové místní ověření znovu spouští import a všech 17 původních testovacích kroků pomocí `tools/run_web_baseline.py`.
- Režim: Linux x86_64 bez grafického výstupu. Výsledky neprokazují výkon v prohlížeči, slyšitelný zvuk, skutečný senzor ani funkci telefonu.
- Webové šablony 4.7.1 se ověřují z oficiálního exportního balíku. Nový export hry patří až do W01.
- Doplněk WebRTC 1.2.2 obsahuje Windows x86_64 a Android arm64; hotová Android arm32 knihovna chybí. Spojení ve hře zatím neověřeno.
- Lokální pokus WebRTC se zastavil při získávání adres síťových rozhraní: `getifaddrs failed, errno=1`. Nejde o důkaz nekompatibility Godotu; prostředí omezuje síťová rozhraní. Záznam bude přiložen k výsledkům.

## Opakování původní testovací sady

Je potřeba Python 3, PyYAML, Bash a Godot přesně ve verzi uvedené v `.github/workflows/build.yml`.

```bash
python3 tools/run_web_baseline.py --godot /cesta/ke/godotu --output-dir /cesta/k/vysledkum
```

Nástroj načte stávající testovací kroky z workflow, vynechá exporty i zveřejňování, oddělí ukládaná herní data a pro každý krok uchová protokol i výsledek. Změnu existujících testů tímto krokem neprovádíme.
