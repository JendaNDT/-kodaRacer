# KodaRacer

3D motokárové závody v prohlížeči ve stylu Mario Kart. Tři tratě, šest jezdců, předměty, drift s turbem a pět AI soupeřů. Funguje na počítači i na mobilu.

## Jak hrát

Otevři `index.html` v prohlížeči (Chrome, Safari, Firefox, Edge). Při prvním načtení je potřeba internet, protože se stahuje 3D knihovna Three.js.

1. Vyber jezdce, trať a obtížnost.
2. Klikni na **Závodit!**
3. Projeď 3 kola co nejrychleji a dojeď první.

### Ovládání na počítači

| Klávesa | Akce |
| --- | --- |
| ↑ / W | plyn |
| ↓ / S | brzda, couvání |
| ← → / A D | zatáčení |
| Mezerník / Shift | drift (drž v zatáčce, pusť po jiskrách = turbo) |
| X / E | použít předmět |
| Esc / P | pauza |
| M | zvuk zap/vyp |

### Ovládání na mobilu

Plyn běží automaticky. Vlevo je volant (táhni palcem doleva a doprava), vpravo tlačítka **DRIFT**, **PŘEDMĚT** a **BRZDA**. Nejlíp se hraje s telefonem na šířku.

### Tipy

- **Drift:** v zatáčce drž drift a zatáčej. Nejdřív odletují modré jiskry, pak oranžové. Když drift pustíš, dostaneš turbo (oranžové je silnější).
- **Raketový start:** šlápni na plyn, až se při odpočtu objeví „1“.
- **Otazníky:** čím víc jsi vzadu, tím lepší předměty dostáváš (hvězda, 3× turbo, raketa).
- **Tráva** tě zpomalí na polovinu, turbo nebo hvězda zpomalení vyruší.

## Předměty

| | Předmět | Co dělá |
| --- | --- | --- |
| ⚡ | Turbo (i 3×) | krátké zrychlení |
| 🍌 | Banán | položíš ho za sebe, kdo do něj najede, dostane smyk |
| 🚀 | Raketa | letí za soupeřem před tebou a vyhodí ho |
| ⭐ | Hvězda | 7 s nesmrtelnosti a vyšší rychlosti, srážkou shodíš soupeře |

## Zveřejnění přes GitHub Pages

V repozitáři: **Settings → Pages → Build and deployment → Deploy from a branch**, vyber větev a složku `/ (root)`. Hra pak poběží na adrese `https://<uživatel>.github.io/<repozitář>/`.
