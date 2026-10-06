# Škoda Racer – Project Status
*Naposled aktualizováno: 06. 10. 2026*

## 🎯 Co to je
3D motokárové závody ve stylu Mario Kart pro Android a Windows: dva hráči na jednom počítači a crossplay přes Wi-Fi.
Stack: Godot 4.7.1 (GDScript, renderer Compatibility), export APK + EXE přes GitHub Actions. Webový prototyp zůstává ve `web/`.

## ⏭️ Příští krok
**Vyzkoušet verzi 1.6.0 na telefonu a PC (zapnout FPS, projet všechny tři tratě na všech třech kvalitách, dojet do cíle a podívat se na stupně vítězů). Pak buď fáze 6 z `PLAN_GRAFIKA.md` (kopce a skoky, největší a volitelná), nebo něco z backlogu.**
Až napíšeš, kolik FPS ukazuje telefon na Střední, rozhodneme, jestli tam nechat stíny (nejdražší efekt), nebo je dát jen na Vysokou.

## ✅ Hotovo
- Přepis celé hry do Godotu 4.7.1: 3 tratě, 6 jezdců, 3 obtížnosti, drift s mini-turbem, raketový start, předměty (turbo, 3× turbo, banán, naváděná raketa, hvězda), 5 AI soupeřů, 3 kola, pořadí, časy kol, rekordy
- Low-poly svět generovaný kódem: obloha, mlha, silnice, obrubníky, bariéry z pneumatik, startovní brána s nápisem ŠKODA RACER, stromy / kaktusy / smrky, sněhuláci, hory, stolové hory, mraky, jezero
- Zvuky, hudba a zvuk motoru syntetizované v Godotu (žádné zvukové soubory)
- **2 hráči na jednom počítači**: rozdělená obrazovka nahoře/dole, vlastní HUD, klávesy WASD vs. šipky, podpora 2 ovladačů
- **Crossplay přes Wi-Fi**: hostitel/klient přes ENet, automatické hledání her v síti, ruční zadání adresy, lobby (výběr jezdce, trati, obtížnosti), až 6 hráčů, volná místa doplní AI. Když někdo odejde, jeho motokáru převezme AI.
- Menu s živou ukázkou závodu v pozadí, pauza, výsledková tabulka
- Dotykové ovládání pro Android (volant, drift, předmět, brzda, automatický plyn), tlačítko Zpět = pauza
- Ikona aplikace a úvodní obrazovka
- GitHub Actions: import projektu, test celého závodu, test Wi-Fi hry (hostitel + klient), export **APK** a **EXE**, zveřejnění v Releases jako „testovací build“
- **Fáze 0 grafiky:** kvalita grafiky Nízká/Střední/Vysoká v menu i v pauze, počítadlo FPS, kontrola verze u Wi-Fi hry, měření výkonu `--bench`, hudba se generuje na pozadí
- **Fáze 1 grafiky:** stíny od slunce (Střední a Vysoká), záře plamenů, jiskřiček, hvězdy, rakety, krabic a slunce, filmové barvy AgX se sytostí, SSAO na Vysoké, vlastní nálada tratí (údolí odpoledne, kaňon při západu slunce, laguna zatažená se sněžením), sluneční disk a plující mraky
- **Fáze 2 grafiky:** stopy smyku, rychlostní čáry, 3. úroveň driftu (fialové jiskry, nejdelší turbo), plamen turba se zábleskem, výbuch rakety s tlakovou vlnou, hvězdičky nad hlavou po zásahu, lesk a střepy krabic, konfety v cíli, vlající vlajky, prach / písek / sníh od kol podle trati
- **Fáze 3 grafiky:** 6 různých motokár z generátoru zaoblených tvarů (formule, bublina, sporťák, buggy, traktůrek, střela), živý jezdec (ruce na volantu, hlava do zatáčky, náklon, radost v cíli, motání hlavy po zásahu), helma s pruhy, startovní čísla na bocích, kola s ráfkem a vzorkem, pérování podvozku, zjednodušené modely pro vzdálené motokáry, režim `--showcase` na screenshoty
- **Spojení fází 1, 2 a 3 do verze 1.4.0** (větev `claude/amazing-faraday-a6w7aw`): plameny, záblesk turba, stopy smyku, prach od kol a hvězdičky po zásahu sedí na výfuky a kola každé motokáry. Do stínu se kreslí zjednodušené motokáry, ruce a volant stín nevrhají. Zářící krabice (fáze 1) a lesk krabic (fáze 2) jsou spojené v jednom shaderu.
- **Fáze 4 grafiky (verze 1.5.0):** semafor s pěti světly synchronizovaný s odpočtem, tribuny s mávajícími diváky, praporky a vlajky ve větru, reklamní panely vymyšlených sponzorů, balíky slámy a kužely v zatáčkách, stromy a kaktusy ve větru, vlnící se a třpytivé jezero. Dominanty: větrný mlýn a dřevěný most přes trať (údolí), skalní oblouk přes trať (kaňon), iglú, ledové krystaly a zamrzlé jezero (laguna). Hustota diváků podle kvality.
- **Fáze 5 grafiky (verze 1.6.0):** výběr jezdce s motokárou na otáčejícím se podstavci (menu, 2 hráči i Wi-Fi lobby) a 3D obrázky na tlačítkách jezdců, stupně vítězů u startovní rovinky (první tři motokáry, mávající jezdci, konfety, houpající se kamera, tabulka dole) i na rozdělené obrazovce a po Wi-Fi, losování předmětu jako hrací automat, „+1“ / „−1“ při změně pořadí, pás „KOLO 2/3“ / „POSLEDNÍ KOLO“ s časem kola, zatmívačka mezi menu a závodem
- Ověřeno v oficiálním Godotu 4.7.1: import bez chyb, závod do cíle sólo i ve 2 hráčích, síťový závod (hostitel + klient), hledání her, odmítnutí jiné verze, screenshoty všech tratí a efektů, měření výkonu

## 📝 TODO
### Vylepšení grafiky (podrobně v `PLAN_GRAFIKA.md`)
- Fáze 6 (volitelná): kopce, skoky a klopené zatáčky

### Backlog (později)
- Hra přes internet (ne jen stejná Wi-Fi): server nebo relay
- Rozdělená obrazovka i v síťové hře (2 hráči na jednom zařízení + další přes Wi-Fi)
- Predikce vlastní motokáry u síťového klienta (teď se ovládání projeví se zpožděním odezvy Wi-Fi)
- Vlastní podpisový klíč a verze pro Google Play
- Kopce a skoky na trati
- Mistrovství (Grand Prix ze 3 tratí s body), časovka proti vlastnímu rekordu
- Víc tratí

## 🐛 Známé bugy
- Zatím žádné známé. Na skutečném telefonu a na Windows zatím netestováno, stejně jako Wi-Fi mezi dvěma reálnými zařízeními (otestováno jen hostitel + klient na jednom počítači).
- Na softwarovém vykreslování v cloudu je verze 1.5.0 proti 1.1.0 na Nízké asi o 14 %, na Střední o ~35 % a na Vysoké o ~58 % pomalejší (Nízká 27,8 → 24,0, Střední 10,4 → 6,7, Vysoká 10,0 → 4,2 FPS). Většinu dělají stíny, záře a SSAO z fáze 1. Verze 1.6.0 je stejně rychlá jako 1.5.0 (měřeno vedle sebe). Na skutečném telefonu zatím neměřeno.
- Když se něco nového (jezero, tribuna) poprvé objeví na obrazovce, může hra jednou krátce zaškobrtnout, protože se teprve překládá jeho shader. Pak už ne.
- Hledání her v síti používá UDP broadcast, který některé routery nebo telefony blokují. Pak je potřeba zadat adresu ručně.

## 🏗️ Klíčová rozhodnutí
*(Aby ses k tomu zase zbytečně nevracel.)*
- **Engine: Godot 4.7.1**, protože Jenda chce crossplay Android ↔ Windows a má Godot na Macu. Webový prototyp zůstává jako předloha a hratelná ukázka.
- **Renderer Compatibility (OpenGL) i pro hezčí grafiku**: v Godotu 4.7.1 umí stíny od slunce, záři, základní SSAO i barvy AgX (ověřeno ve zdrojovém kódu enginu). Hra tak vypadá na PC i mobilu stejně a jde testovat v cloudu. Neumí decals, proto budou stopy smyku z vlastních pásů geometrie. Forward+ pro PC je jen volitelný bonus.
- **Grafika po fázích s nastavením kvality**: každá fáze se dá vyzkoušet zvlášť a slabé telefony si nastaví nižší kvalitu. Co která úroveň zapíná, je na jednom místě v `godot/scripts/gfx.gd`. Výchozí: telefon Střední, PC Vysoká.
- **Stejné barvy na všech kvalitách:** AgX se zvýšenou sytostí běží i na Nízké (stojí to asi 5 % výkonu), kvality se liší jen stíny, září, SSAO, sněžením a hustotou. Samotné AgX bez sytosti dělalo barvy vybledlé.
- **Vyrovnání jasu u stínů:** renderer Compatibility přidává slunce se stíny jako druhou vrstvu a sčítá ji tak, že je obraz přepálený. `Atmosphere._shadowed_sun` proto spočítá slabší slunce, aby osvětlená silnice a tráva měly stejný jas jako na Nízké. Kde jsou stíny zapnuté, musí být zapnutá i záře (tónování pak proběhne jednou za obě vrstvy).
- **Dvě slunce:** jedno kreslí jen disk na obloze (může být hodně jasné a zářit), druhé svítí na scénu. Vzdálené hory, mraky, země a silnice stíny nevrhají (šetří výkon a při západu slunce by hory zakryly celou trať).
- **Kontrola verze přes vestavěné ověření Godotu** (auth), ne přes běžné síťové volání: mezi různými verzemi hry se jinak síťová volání můžou pomíchat. Hráči musí mít stejnou verzi.
- **Všechno generované kódem** (tratě, modely, textury, zvuky): projekt je malý, snadno se upravuje a není potřeba žádné grafiky ani zvuky stahovat.
- **Motokáry z vlastního generátoru tvarů (`mesh_kit.gd`)**: zkosené kvádry, protažená zaoblená těla, soustružené díly (kola) a trubky. Všechno, co se na motokáře nehýbe, je jeden model s barvami ve vrcholech; lesk nebo matnost dílu nese malá textura. Hýbe se jen jezdec (trup, hlava, 4 díly rukou, volant) a 3 kola (přední zvlášť kvůli zatáčení, zadní na jedné ose).
- **Jízdní vlastnosti se fází 3 nezměnily**: nové motokáry mění jen vzhled, fyzika i síťová data jsou stejné jako dřív.
- **Vzdálené motokáry jednodušší (LOD)** podle kvality: Nízká od 10 m, Střední od 16 m, Vysoká od 32 m. Bez toho by detailní motokáry zbytečně zatěžovaly slabé telefony.
- **Fáze grafiky 1–3 vznikly paralelně** na samostatných větvích a jsou spojené ve verzi 1.4.0. Od fáze 4 je hlavní větev `main`, další práce staví na ní.
- **Svět kolem trati v `trackside.gd`**: co se hýbe (diváci, praporky, vlajky, stromy, voda), hýbe grafická karta přes shadery, takže to procesor nezatěžuje. Skript řídí jen semafor a lopatky mlýna. Pozice tribun, mostu a oblouku se hledají automaticky podle tvaru trati (rovinka, dost místa, mimo jiné části trati a jezero).
- **Pneumatiky bariér, balíky slámy, kužely a diváci nevrhají stín**: stín je u nich skoro neviditelný, ale kreslil by se pro každé pásmo stínů znovu. Díky tomu fáze 4 na výkonu nic nestojí.
- **Stupně vítězů stojí přímo u trati**, ne v samostatné scéně: nic se nenačítá, po Wi-Fi není potřeba nic posílat navíc (každý si pódium postaví sám podle výsledků) a motokáry na něm jsou stejné modely jako v závodě. Náhled v menu má vlastní malý 3D svět (SubViewport), takže nezávisí na trati v pozadí.
- **Stíny motokár ze zjednodušeného modelu:** detailní model stín nevrhá, místo něj ho vrhá neviditelná jednodušší kopie (stín se kreslí pro každé pásmo stínů zvlášť).
- **Crossplay nejdřív přes stejnou Wi-Fi** (bez serveru, zdarma). Hostitel počítá celý závod, ostatní posílají ovládání a dostávají stav 30× za sekundu.
- **Rozdělená obrazovka nahoře/dole** jako v Mario Kartu; každý hráč má vlastní kameru a HUD.
- **Testovací podpisový klíč v repozitáři** (`build/debug.keystore`), aby šlo APK aktualizovat bez odinstalace. Pro Google Play bude potřeba vlastní tajný klíč.
- **Vlastní postavy a předměty**, žádné postavy ani názvy z Nintenda.
- **Název Škoda Racer + poznámka „neoficiální fanouškovská hra“**: Škoda je ochranná známka, pro Google Play by název mohl být problém.
- **3. úroveň driftu (potvrzeno Jendou):** fialová po 3,5 s nabíjení (oranžová 2,2 s), turbo 1,75 s (oranžová 1,3 s). Platí pro hráče i AI.
- **Efekty se počítají z toho, co už se posílá po síti** (drift, turbo, zásah, cíl, výbuch). Do síťového stavu přibylo jen „brzdí“ (pro stopy smyku), proto hráči potřebují stejnou verzi (teď 1.4.0).
- **Stopy smyku bez per-frame práce:** pevný kruh pásů (MultiMesh), mizení počítá grafická karta. Počet podle kvality v `gfx.gd`.
- **Fyzika s pevným krokem 1/120 s**: stejné chování na rychlém PC i pomalém telefonu.
- **Na mobilu plyn automaticky**: palcem se nedá zároveň držet plyn a driftovat.

## 📁 Stav souborů
- `godot/project.godot` – Godot projekt (otevřít přes Import)
- `godot/scripts/main.gd` – start hry, menu vs. závod, testovací režimy
- `godot/scripts/race.gd` – závod: simulace, AI, předměty, kamery, rozdělená obrazovka, výsledky, síťová synchronizace
- `godot/scripts/kart.gd` – motokára: sestavení modelu, efekty, pérování, jízdní fyzika
- `godot/scripts/mesh_kit.gd` – generátor zaoblených tvarů (jeden model s barvami ve vrcholech)
- `godot/scripts/kart_model.gd` – návrhy 6 motokár a kol
- `godot/scripts/driver_rig.gd` – jezdec: helma, ruce na volantu, animace
- `godot/scripts/showcase.gd` – režim `--showcase` pro screenshoty motokár
- `godot/scripts/track.gd`, `world_builder.gd` – trať a svět kolem ní
- `godot/scripts/atmosphere.gd` – obloha, slunce a stíny, mlha, barvy, záře, mraky, sníh
- `godot/scripts/trackside.gd` – semafor, tribuny s diváky, praporky a vlajky, reklamní panely, balíky a kužely, vítr ve stromech, jezero, dominanty tratí
- `godot/scripts/net.gd` – Wi-Fi multiplayer (hostitel, klient, hledání her, lobby)
- `godot/scripts/menu.gd`, `hud.gd`, `minimap.gd`, `item_icon.gd`, `touch_controls.gd`, `ui.gd` – rozhraní
- `godot/scripts/game.gd`, `sfx.gd` – data (včetně nálady každé trati), nastavení, ovládání, zvuky
- `godot/scripts/gfx.gd` – úrovně kvality grafiky (co která zapíná)
- `godot/scripts/effects.gd` – jednorázové efekty: výbuch, střepy krabic, konfety, hvězdičky po zásahu
- `godot/scripts/skid_marks.gd`, `speed_lines.gd` – stopy smyku a rychlostní čáry
- `godot/export_presets.cfg` – export Android + Windows
- `.github/workflows/build.yml` – testy a sestavení APK + EXE
- `web/` – původní webový prototyp
- `PLAN_GRAFIKA.md` – fázovaný plán vylepšení grafiky
