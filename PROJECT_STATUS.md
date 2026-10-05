# Škoda Racer – Project Status
*Naposled aktualizováno: 05. 10. 2026*

## 🎯 Co to je
3D motokárové závody ve stylu Mario Kart. Teď existuje hratelný webový prototyp, cílem je verze v Godotu pro Android a Windows s crossplay.
Stack prototypu: `web/index.html`, Three.js r128 a písma přibalené lokálně (funguje offline), zvuky a hudba přes WebAudio, rekordy v localStorage.
Cílový stack: Godot 4.7.1 (Jenda ho má na Macu), export APK a EXE přes GitHub Actions.

## ⏭️ Příští krok
**Rozhodnout, jak má fungovat crossplay (přes stejnou Wi-Fi, nebo přes internet se serverem), a pak začít přepis do Godotu.**
Webový prototyp slouží jako předloha: tratě, fyzika, AI a předměty se přenesou 1:1.

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
- Přejmenováno na **Škoda Racer** (menu, startovní brána), poznámka „neoficiální fanouškovská hra“
- Webová verze funguje offline (Three.js a písma přibalené ve `web/`)

## 📝 TODO
### MVP Godot verze (nutné pro v1)
- Přepis hry do Godotu 4.7 (tratě, motokáry, drift, AI, předměty, HUD, menu, dotykové ovládání)
- Crossplay multiplayer Android ↔ Windows
- GitHub Actions: automatický export APK (Android) a EXE (Windows) ke stažení

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
- **Engine: Godot 4.7.1.** Jenda chce crossplay mezi Androidem a Windows a Godot exportuje na obě platformy a má vestavěný multiplayer. Webová verze zůstává jako prototyp.
- **Balení webu přes Capacitor/Electron zrušeno:** nahradí ho export z Godotu.
- **Webový prototyp:** jeden soubor HTML, Three.js r128 přibalené lokálně (klasický globální `THREE`, funguje i z `file://`).
- **Název Škoda Racer + poznámka „neoficiální fanouškovská hra“:** Škoda je ochranná známka, poznámka jasně říká, že hra není oficiální. Pro Google Play by název mohl být problém.
- **Vlastní postavy a předměty:** žádné postavy ani názvy z Nintenda, aby se hra dala bez problémů sdílet.
- **Fyzika s pevným krokem 1/120 s:** stabilní chování nezávisle na FPS telefonu.
- **Na mobilu plyn automaticky:** palcem se nedá zároveň držet plyn a driftovat.

## 📁 Stav souborů
- `web/index.html` – webový prototyp hry (HTML, CSS, JavaScript)
- `web/vendor/`, `web/fonts/` – přibalená 3D knihovna a písma
- `README.md` – jak hrát a jak hru spustit
- `PROJECT_STATUS.md` – tenhle přehled
