# Škoda Racer

*Neoficiální fanouškovská hra, nesouvisí se společností Škoda Auto.*

3D motokárové závody ve stylu Mario Kart, postavené v enginu **Godot 4.7.1**. Hraje se na **Androidu** i **Windows**, dva hráči můžou jet na jednom počítači s rozdělenou obrazovkou a přes Wi-Fi spolu závodí telefony i počítače (crossplay).

## Stažení hotové hry

Každá změna v repozitáři spustí automatické sestavení (GitHub Actions). Hotové soubory najdeš v **Releases → „Škoda Racer – testovací build“**:

- **SkodaRacer.apk** pro Android: stáhni v telefonu a otevři. Telefon se zeptá na povolení instalace z neznámých zdrojů, to je u her mimo Google Play normální.
- **SkodaRacer.exe** pro Windows: stáhni a spusť, nic se neinstaluje. Windows může ukázat modré okno SmartScreen, protože hra není digitálně podepsaná: klikni na **Další informace → Přesto spustit**.

## Otevření v Godotu (Mac, Windows, Linux)

1. Na GitHubu klikni na **Code → Download ZIP** a rozbal ho.
2. V Godotu 4.7 klikni na **Import** a vyber soubor `godot/project.godot`.
3. Klávesou **F5** hru spustíš přímo v editoru.

## Režimy

- **Závod**: ty proti pěti počítačovým soupeřům, 3 kola.
- **2 hráči na jednom počítači**: obrazovka se rozdělí na horní a dolní půlku.
- **Hra po Wi-Fi (crossplay)**: až 6 hráčů na stejné Wi-Fi, telefony i počítače dohromady. Volná místa doplní počítač.

## Jezdci a motokáry

Každý jezdec má vlastní motokáru. Liší se jen vzhledem, jízdní vlastnosti určuje jezdec.

| Číslo | Jezdec | Motokára | Typ (jako v menu) |
| --- | --- | --- | --- |
| 1 | Turbo Tonda | formule s křídly | Vyvážený |
| 2 | Zuzka Zběsilá | zaoblená bublina | Hbitá |
| 3 | Pepa Plyn | dlouhý sporťák s velkým křídlem | Rychlík |
| 4 | Máňa Motor | buggy s velkými koly a rámem | Akcelerace |
| 5 | Karel Kolo | traktůrek s komínem | Tahoun |
| 6 | Bára Brzda | nízká futuristická střela | Zatáčky |

## Ovládání

| | Jeden hráč | Hráč 1 (2 hráči) | Hráč 2 (2 hráči) |
| --- | --- | --- | --- |
| Zatáčení | ← → nebo A D | A D | ← → |
| Plyn | ↑ nebo W | W | ↑ |
| Brzda / couvání | ↓ nebo S | S | ↓ |
| Drift | mezerník nebo Shift | mezerník nebo levý Shift | pravý Shift nebo Num 0 |
| Předmět | X, E nebo Enter | E nebo Q | Enter |

Další klávesy: **Esc** pauza, **F11** celá obrazovka.

**Herní ovladač**: A plyn, B brzda, RB/RT drift, LB/LT nebo X předmět, Start pauza. U dvou hráčů patří první ovladač hráči 1 a druhý hráči 2. Když je připojený jen jeden, ovládá hráče 2 a hráč 1 jede na klávesnici.

**Mobil**: plyn běží sám. Vlevo je volant (táhni palcem), vpravo **DRIFT**, **PŘEDMĚT** a **BRZDA**. Tlačítko Zpět hru pozastaví.

### Tipy

- **Drift**: v zatáčce drž drift a zatáčej. Jiskry se mění z modrých na oranžové a nakonec na fialové. Když drift pustíš, dostaneš turbo: čím dál jsi došel, tím delší.
- **Raketový start**: šlápni na plyn, až se při odpočtu objeví „1“.
- **Otazníky**: čím víc jsi vzadu, tím lepší předmět dostaneš.

| Předmět | Co dělá |
| --- | --- |
| Turbo (i 3×) | krátké zrychlení |
| Banán | položíš ho za sebe, kdo do něj najede, dostane smyk |
| Raketa | letí za soupeřem před tebou a vyhodí ho |
| Hvězda | 7 s nesmrtelnosti a vyšší rychlosti, srážkou shodíš soupeře |

## Grafika a výkon

V hlavním menu i v pauze jsou tři tlačítka:

- **Zvuk**: zapnout nebo vypnout.
- **Grafika**: Nízká / Střední / Vysoká. Telefon začíná na Střední, počítač na Vysoké. Když se hra na telefonu trhá, přepni na Nízkou.
  - **Nízká**: pod motokárami jen tmavé skvrny, bez záře, méně stromů, částic a stop smyku, vzdálené motokáry zjednodušené už od 10 m.
  - **Střední**: stíny od slunce, záře plamenů, jiskřiček a hvězdy, sněžení na Ledové laguně.
  - **Vysoká**: navíc měkčí a delší stíny, jemné stínování v rozích (SSAO), hustší sníh a detailní motokáry až do 32 m.
  - Barvy a nálada tratí jsou na všech kvalitách stejné: odpoledne v údolí, západ slunce v kaňonu, zatažená obloha na laguně.
  - Ostrost obrazu, vyhlazení hran, stíny a záře se změní hned. Hustota stromů, počet částic a stop smyku, sníh a zjednodušení vzdálených motokár se změní od dalšího závodu.
- **FPS**: ukáže dole uprostřed, kolik snímků za sekundu hra kreslí (60 = plynulé, pod 30 = trhání). Hodí se, když chceš napsat, jak hra běží.

## Hra po Wi-Fi

1. Všichni musí být připojení ke **stejné Wi-Fi**.
2. Jeden hráč dá **Hra po Wi-Fi → Založit hru**. Na obrazovce uvidí svou adresu, třeba `192.168.1.23`.
3. Ostatní dají **Hra po Wi-Fi** a hru buď uvidí v seznamu, nebo zadají adresu ručně.
4. Hostitel vybere trať a obtížnost a spustí závod.

Všichni musí mít **stejnou verzi hry** (je napsaná dole v hlavním menu). Hra s jinou verzí se v seznamu ukáže jako „jiná verze hry“ a připojení se odmítne s vysvětlením.

Na Windows se při prvním založení hry objeví dotaz brány firewall. Povol přístup pro **soukromé sítě**, jinak se ostatní nepřipojí. Hra používá porty UDP 24680 a 24681.

## Složky

- `godot/` – hra v Godotu (skripty v `godot/scripts/`, nastavení exportu v `godot/export_presets.cfg`)
- `web/` – původní webový prototyp (`web/index.html`), dá se otevřít v prohlížeči
- `build/debug.keystore` – testovací podpisový klíč pro APK (heslo `android`). Pro Google Play je potřeba vlastní tajný klíč.
- `.github/workflows/build.yml` – automatické testy a sestavení APK + EXE

## Licence přibalených souborů

- Písma Bungee a Barlow Semi Condensed: SIL Open Font License (`godot/fonts/`, `web/fonts/`)
- Three.js r128 (jen webový prototyp): MIT (`web/vendor/three-LICENSE.txt`)
