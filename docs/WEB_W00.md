# W00 — ověřený výchozí stav webové verze

Datum: **27. října 2026**. **Stav: W00 dokončeno s evidovanými omezeními.** W00 připravuje převod hry; první export samotné Škoda Racer je až předmětem W01.

## Výchozí verze a uložená práce

- Vydaná hra: **1.19.1**, větev `main`, commit `870ba46e85eb0ae5fad1875bee585dd55752e7e9`.
- Poslední `testovaci-build` při zahájení odpovídá tomuto commitu a obsahuje APK a EXE.
- Výchozí větev repozitáře je stále starší `ccr-05c4e7fe-qo3pmx`; pracovní větev **`codex/web-version`** vychází z výslovně ověřeného `main`.
- Při zahájení nebyl otevřený žádný pull request. Vzdálený základ pracovní větve byl vytvořen commitem `f5688a5f39b6eca7aa56573ca02487aa7d4e97e9`.
- Všechny **119 sledované soubory v `godot/` zůstaly obsahově stejné** jako v původní verzi. Kontrolní součty jsou v [soupisu souborů](web/w00-game-files.json).

## Editor a exportní šablony

Oficiální Godot **4.7.1.stable.official.a13da4feb** byl stažen, ověřen proti SHA256 vydání a spuštěn. Úspěšně importoval původní herní projekt.

Z oficiálního exportního balíku 4.7.1 byly získány a zkontrolovány všechny webové varianty šablon. Kontrola zahrnovala CRC32 položek a obsahu ZIP; úplný SHA256 celého 1,28GB balíku nebyl při částečném stažení kontrolován. Vlastní SHA256 získaných šablon je uložen v [záznamu nástrojů](web/w00-toolchain.json).

Editor úspěšně vytvořil **jednovláknový Web export prázdného odděleného ověřovacího projektu**. Byl ověřen správný začátek WebAssembly souboru a přítomnost výsledných souborů; při konečném exportu nebyly chyby enginu. Tato zkouška potvrzuje použitelnost nástrojů, nikoli spuštění Škoda Racer v prohlížeči.

## Původní testovací sada

Nástroj [run_web_baseline.py](../tools/run_web_baseline.py) načítá přímo původní testovací příkazy z `.github/workflows/build.yml`. Nespouští exporty ani zveřejňování. Jednotlivé místní zkoušky mají oddělená ukládaná data; výsledky se uchovávají i při selhání některého kroku.

První místní průchod skončil **16 úspěšnými kroky z 18** (import a 17 testovacích kroků). Celková doba jednotlivých kroků byla přibližně **15 minut**. Neúspěchy jsou zachované v původním záznamu a nebyly přepsány opakováním.

| Krok | Zkouška | První místní výsledek | Doba |
| --- | --- | --- | --- |
| 01 | Import projektu | PROŠLO | 10.7 s |
| 02 | Celý závod proti soupeřům | PROŠLO | 19.1 s |
| 03 | Mistrovství všech tratí | PROŠLO | 132.0 s |
| 04 | Časovka s uloženým duchem | PROŠLO | 40.0 s |
| 05 | Zkratky a počítání kol | PROŠLO | 149.8 s |
| 06 | Soupeři na všech tratích | PROŠLO | 84.1 s |
| 07 | Nové předměty | PROŠLO | 20.5 s |
| 08 | Skoky běžných tratí | PROŠLO | 41.2 s |
| 09 | Skoky zrcadlených tratí | PROŠLO | 40.4 s |
| 10 | Odměny a odemykaný obsah | PROŠLO | 6.3 s |
| 11 | Naklánění se simulovaným senzorem | PROŠLO | 7.4 s |
| 12 | Vibrace se záznamem událostí, 1 i 2 hráči | PROŠLO | 40.0 s |
| 13 | Hudba a přechody přehrávání | PROŠLO | 2.3 s |
| 14 | Obě bitvy na všech obtížnostech | PROŠLO | 68.3 s |
| 15 | Síťový závod s umělým zpožděním | NEPROŠLO | 139.4 s |
| 16 | Síťová bitva a odchod třetího hráče | PROŠLO | 71.8 s |
| 17 | Vyhledání hostitele v síti | NEPROŠLO | 22.4 s |
| 18 | Odmítnutí odlišné herní verze | PROŠLO | 17.7 s |

Podrobné výsledky, návratové kódy, doby běhu a vybrané důkazní řádky obsahuje [místní záznam JSON](web/w00-native-baseline.json). Úplné textové protokoly jsou v [archivu](web/w00-native-logs.tar.gz); herní uložená data ani stažené knihovny archiv neobsahuje.

### Síťový závod — samostatné opakování

Samostatný opakovaný pokus **prošel** beze změny hry a limitu. Jeho 95. percentil odchylky byl **0,62 m**; první pokus měl 1,14 m. Výsledek tedy nebyl ve dvou pokusech shodný. Podrobný [záznam opakování](web/w00-network-recheck.json) je oddělený od prvního průchodu.

```text
PREDICTION lag=120 ms: error avg 0.23 p95 0.62 max 8.40 m (3578), correction avg 0.25 p95 0.67 max 10.47 m
```

První neúspěšný pokus měl při umělém zpoždění 120 ms každým směrem odchylku předpovědi v 95. percentilu **1,14 m**, zatímco původní limit je **1,00 m**. Hostitel i klient dojeli a klient přijal všechny kontrolované předměty i další stavy. Selhala přesnost předpovědi, nikoli dokončení závodu. Testovací limit ani herní pravidla nebyly měněny.

Výsledky jednotlivých pokusů nejsou důkazem stabilní přesnosti na všech sítích; prostředí, náhoda a plánování snímků mohou výsledek ovlivnit. Příčina rozdílu zatím nebyla prokázána. Při práci na online části se zachová kontrola předpovědi i zátěžové scénáře.

### Ověření na GitHubu

Nový [běh W00 na GitHubu](https://github.com/JendaNDT/-kodaRacer/actions/runs/40495480190) skončil **úspěšně**. Prošlo všech **18 kontrolních kroků** (import + 17 testovacích kroků), včetně síťového závodu, síťové bitvy, vyhledávání hostitele a odmítnutí jiné verze. Prošly rovněž exporty APK a EXE. Krok zveřejnění byl **přeskočen** podmínkou pro `main`; veřejné vydání zůstalo na původním commitu a jeho soubory mají stejné kontrolní součty.

Strojově čitelné [výsledky kroků](web/w00-github-actions.json) a [vybrané důkazní řádky](web/w00-github-checks.log) jsou uchovány v projektu. Úspěch na GitHubu neruší záznam dvou odlišných místních výsledků.

Předchozí běh stejných herních zdrojů na `main` byl rovněž [úspěšný](https://github.com/JendaNDT/-kodaRacer/actions/runs/37751242918). Nové ověření běží z první změny W00; pozdější dokončovací zápis mění pouze dokumentaci a pomocný nástroj, nikoli herní zdroje.

## Zjištěné problémy a omezení

| Bod | Co se skutečně projevilo | Další postup |
| --- | --- | --- |
| N01 — předpověď pohybu | První místní síťový závod překročil dosavadní limit 1 m | Zachovat obě měření; před online vydáním znovu měřit a vysvětlit případné kolísání |
| N02 — vyhledávání hostitele | Místní zkouška v izolovaném prostředí skončila `NO HOSTS FOUND` | Zdejší výsledek není fyzický test Wi-Fi; porovnat s GitHubem a později se skutečnými zařízeními |
| N03 — materiál v režimu bez grafiky | Časovka a odměny hlásí `Parameter "material" is null` z `servers/rendering/dummy/storage/material_storage.cpp` | Existující chování výchozí hry; při grafickém ověřování prověřit, zda se týká i skutečného vykreslování |
| N04 — ukončení procesu | Některé zkoušky hlásí neuvolněné objekty nebo prostředky při ukončení | Uchovat jako výchozí stav; skutečný dlouhodobý únik posoudit při W06 opakovaným hraním a měřením |
| N05 — doplněk Android arm32 | V hotovém balíku WebRTC 1.2.2 není knihovna pro stávající 32bitový Android | Před společným hraním W13 ověřit vlastní sestavení; podporu 32bitové hry potichu neodstraňovat |
| N06 — přenos WebRTC v cloudu | Pokus o skutečnou lokální výměnu dat zastavilo `getifaddrs failed, errno=1`; nebyly získány hostitelské ICE kandidáty | Před W10 ověřit skutečný přenos v prostředí s dostupnými síťovými rozhraními; tento pokus neoznačovat za úspěšné spojení |
| N07 — zkušební import doplňku | První import odděleného zkušebního projektu skončil signálem ABRT po skenování; následný samostatný test API skončil úspěšně | Před nasazením doplňku ověřit import a životní cyklus v cílovém prostředí; doplněk zatím nebyl přidán do hry |

Úspěšné výsledky původních testovacích podmínek neznamenají, že protokoly neobsahují žádné hlášení enginu. Původní workflow vyhodnocuje především dokončení scénářů, jejich výsledky a chyby skriptů; výše uvedená další hlášení jsou zachovaná zvlášť.

## Předběžná prověrka WebRTC

Byl stažen oficiální doplněk **1.2.2-stable** a ověřen jeho SHA256. Deklaruje Godot 4.3+; balík obsahuje skutečné Windows x86_64 a Android arm64 knihovny. Manifest i binární hlavičky byly zkontrolovány, hotová Android arm32 knihovna chybí.

V odděleném Linuxovém projektu pod Godotem 4.7.1 prošlo vytvoření spojení, jeho inicializace a vytvoření spolehlivého i nespolehlivého datového kanálu: [protokol API](web/w00-webrtc-api.log). To potvrzuje načtení doplňku a základ API v tomto prostředí. [Pokus o přenos](web/w00-webrtc-roundtrip.log) je veden jako blokovaný síťovým prostředím. Windows a Android zde nebyly spuštěny; samotná přítomnost knihovny neprokazuje funkční společné hraní.

## Připravené srovnávací scény a zařízení

V [souboru scénářů](web/w00-scenarios.json) jsou připravené parametry pro menu, Podzimní les, Noční město, obě bitevní arény a dvacet opakovaných přechodů. Obsahuje také rozlišení, kvalitu, délku vzorku a upozornění na dosud neřízenou náhodu režimu `--bench`.

Dostupný zde byl cloudový Linux x86_64 v režimu bez grafiky. **FPS a grafická paměť na skutečném GPU nebyly měřeny.** MacBook Air M4, Samsung S24 Ultra a Lenovo IdeaTab jsou připravené cíle pozdějšího fyzického ověření; v této relaci nebyly připojené ani ovládané. iPhone/iPad, Windows a Linux desktop zůstávají dalšími cíli k ověření podle dostupnosti.

## Ochrana současného vydání

V původním workflow přibyla podmínka, že krok přepisující veřejné `testovaci-build` smí běžet jen na `main`. Pracovní větev může vytvářet testovací artefakty, ale nesmí smazat veřejné APK a EXE. Žádné herní změny, nová verze hry ani webové nasazení nebyly součástí W00.

## Uzavření W00

W00 je přípravný krok s evidovanými výsledky a omezeními, nikoli potvrzení bezchybnosti všech nativních režimů. Jsou připravené správný zdroj, pracovní větev, editor a webové šablony, původní kontroly, známé problémy, srovnávací scény a cílová zařízení.

**Další nejvhodnější krok: W01 — první Web export a rozhraní pro možnosti zařízení.** První webové hraní na jednom zařízení může postupovat; pro následné online vydání zůstávají závazné záznamy N01, N02 a N05–N07.
