# KodaRacer – Project Status
*Naposled aktualizováno: 05. 10. 2026*

## 🎯 Co to je
3D motokárové závody ve stylu Mario Kart, které běží přímo v prohlížeči (počítač i mobil).
Stack: jeden soubor `index.html`, Three.js r128 z CDN, zvuky a hudba syntetizované přes WebAudio, rekordy v localStorage.

## ⏭️ Příští krok
**Zahrát si to na mobilu a říct, co ladit (rychlost, obtížnost, ovládání).**
Hodnoty pro jízdu jsou v `index.html` v objektu `BASE` a v poli `DIFFS`, takže se dají snadno upravit.

## ✅ Hotovo
- 3D svět: 3 tratě (Zelené údolí, Pouštní kaňon, Ledová laguna) s obrubníky, bariérami z pneumatik, startovní bránou, stromy / kaktusy / smrky, horami, mraky a jezerem
- 6 jezdců s vlastní barvou a statistikami (rychlost, zrychlení, ovladatelnost, váha)
- 3 obtížnosti (50 / 100 / 150 ccm)
- Jízdní model: plyn, brzda, couvání, zpomalení v trávě, odraz od bariér, srážky motokár
- Drift s nabíjením (modré → oranžové jiskry) a mini-turbem po puštění
- Raketový start (plyn ve chvíli, kdy se objeví „1“)
- Předměty z otazníkových krabic: turbo, 3× turbo, banán, naváděná raketa, hvězda (nesmrtelnost); co padne, záleží na pořadí
- 5 AI soupeřů: drží stopu, zpomalují v zatáčkách, vyhýbají se banánům, používají předměty, mírný „rubber band“
- 3 kola, počítání pořadí, časy kol, detekce jízdy v protisměru
- HUD: pořadí, kolo, čas, předmět, rychlost, minimapa
- Menu s živou ukázkou závodu v pozadí, pauza, výsledková tabulka, rekordy tratí
- Dotykové ovládání na mobilu (volant vlevo, drift / předmět / brzda vpravo, plyn automaticky)
- Zvuky (motor, efekty) a hudba, tlačítko pro ztlumení

## 📝 TODO
### Backlog (později)
- Kopce a skoky na trati (teď je trať rovná)
- Ghost / časovka proti vlastnímu rekordu
- Víc tratí a mistrovství (Grand Prix ze 3 tratí s body)
- Mince, které zvyšují maximální rychlost
- Lokální multiplayer na dělené obrazovce
- Instalace jako PWA (ikona na ploše, offline režim)

## 🐛 Známé bugy
- Zatím žádné známé. Ověřeno v headless Chromiu: celý závod do cíle na počítači i v mobilním zobrazení, bez chyb v konzoli. Na skutečném telefonu zatím netestováno.

## 🏗️ Klíčová rozhodnutí
*(Aby ses k tomu zase zbytečně nevracel.)*
- **Jeden soubor HTML:** jde otevřít kdekoliv a jednoduše publikovat, žádný build.
- **Three.js r128 z cdnjs:** poslední verze s klasickým globálním `THREE`, funguje bez modulů i z `file://`. Potřebuje internet při prvním načtení.
- **Vlastní postavy a předměty:** žádné postavy ani názvy z Nintenda, aby se hra dala bez problémů sdílet.
- **Fyzika s pevným krokem 1/120 s:** stabilní chování nezávisle na FPS telefonu.
- **Na mobilu plyn automaticky:** palcem se nedá zároveň držet plyn a driftovat.

## 📁 Stav souborů
- `index.html` – celá hra (HTML, CSS, JavaScript)
- `README.md` – jak hrát a jak hru spustit
- `PROJECT_STATUS.md` – tenhle přehled
