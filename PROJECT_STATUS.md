# Škoda Racer – Project Status
*Naposled aktualizováno: 06. 10. 2026 (verze 1.13.0)*

## 🎯 Co to je
3D motokárové závody ve stylu Mario Kart pro Android a Windows: dva hráči na jednom počítači a crossplay přes Wi-Fi.
Stack: Godot 4.7.1 (GDScript, renderer Compatibility), export APK + EXE přes GitHub Actions. Webový prototyp zůstává ve `web/`.

## ⏭️ Příští krok
**Vyzkoušet verzi 1.13.0 (nové předměty, i po Wi-Fi), pak etapa D z `PLAN_VYLEPSENI.md`: chytřejší soupeři s vlastní povahou (verze 1.14.0).** Etapy A, B a C jsou hotové. Zbývají D–F: chytřejší soupeři, zkratky a odemykání.

## ✅ Hotovo
- Přepis celé hry do Godotu 4.7.1: 3 tratě, 6 jezdců, 3 obtížnosti, drift s mini-turbem, raketový start, předměty (turbo, 3× turbo, banán, naváděná raketa, hvězda), 5 AI soupeřů, 3 kola, pořadí, časy kol, rekordy
- Low-poly svět generovaný kódem: obloha, mlha, silnice, obrubníky, bariéry z pneumatik, startovní brána s nápisem ŠKODA RACER, stromy / kaktusy / smrky, sněhuláci, hory, stolové hory, mraky, jezero
- Zvuky, hudba a zvuk motoru syntetizované v Godotu (žádné zvukové soubory)
- **2 hráči na jednom počítači**: rozdělená obrazovka nahoře/dole, vlastní HUD, klávesy WASD vs. šipky, podpora 2 ovladačů
- **Crossplay přes Wi-Fi**: hostitel/klient přes ENet, automatické hledání her v síti, ruční zadání adresy, lobby (výběr jezdce, trati, obtížnosti), až 6 hráčů, volná místa doplní AI. Když někdo odejde, jeho motokáru převezme AI.
- Menu s živou ukázkou závodu v pozadí, pauza, výsledková tabulka
- Dotykové ovládání pro Android (volant, drift, předmět, brzda, automatický plyn), tlačítko Zpět = pauza
- Ikona aplikace a úvodní obrazovka
- GitHub Actions: import projektu, test celého závodu, test celého mistrovství, test časovky s duchem, test Wi-Fi hry (hostitel + klient), export **APK** a **EXE**, zveřejnění v Releases jako „testovací build“
- **Fáze 0 grafiky:** kvalita grafiky Nízká/Střední/Vysoká v menu i v pauze, počítadlo FPS, kontrola verze u Wi-Fi hry, měření výkonu `--bench`, hudba se generuje na pozadí
- **Fáze 1 grafiky:** stíny od slunce (Střední a Vysoká), záře plamenů, jiskřiček, hvězdy, rakety, krabic a slunce, filmové barvy AgX se sytostí, SSAO na Vysoké, vlastní nálada tratí (údolí odpoledne, kaňon při západu slunce, laguna zatažená se sněžením), sluneční disk a plující mraky
- **Fáze 2 grafiky:** stopy smyku, rychlostní čáry, 3. úroveň driftu (fialové jiskry, nejdelší turbo), plamen turba se zábleskem, výbuch rakety s tlakovou vlnou, hvězdičky nad hlavou po zásahu, lesk a střepy krabic, konfety v cíli, vlající vlajky, prach / písek / sníh od kol podle trati
- **Fáze 3 grafiky:** 6 různých motokár z generátoru zaoblených tvarů (formule, bublina, sporťák, buggy, traktůrek, střela), živý jezdec (ruce na volantu, hlava do zatáčky, náklon, radost v cíli, motání hlavy po zásahu), helma s pruhy, startovní čísla na bocích, kola s ráfkem a vzorkem, pérování podvozku, zjednodušené modely pro vzdálené motokáry, režim `--showcase` na screenshoty
- **Spojení fází 1, 2 a 3 do verze 1.4.0** (větev `claude/amazing-faraday-a6w7aw`): plameny, záblesk turba, stopy smyku, prach od kol a hvězdičky po zásahu sedí na výfuky a kola každé motokáry. Do stínu se kreslí zjednodušené motokáry, ruce a volant stín nevrhají. Zářící krabice (fáze 1) a lesk krabic (fáze 2) jsou spojené v jednom shaderu.
- **Fáze 4 grafiky (verze 1.5.0):** semafor s pěti světly synchronizovaný s odpočtem, tribuny s mávajícími diváky, praporky a vlajky ve větru, reklamní panely vymyšlených sponzorů, balíky slámy a kužely v zatáčkách, stromy a kaktusy ve větru, vlnící se a třpytivé jezero. Dominanty: větrný mlýn a dřevěný most přes trať (údolí), skalní oblouk přes trať (kaňon), iglú, ledové krystaly a zamrzlé jezero (laguna). Hustota diváků podle kvality.
- **Fáze 5 grafiky (verze 1.6.0):** výběr jezdce s motokárou na otáčejícím se podstavci (menu, 2 hráči i Wi-Fi lobby) a 3D obrázky na tlačítkách jezdců, stupně vítězů u startovní rovinky (první tři motokáry, mávající jezdci, konfety, houpající se kamera, tabulka dole) i na rozdělené obrazovce a po Wi-Fi, losování předmětu jako hrací automat, „+1“ / „−1“ při změně pořadí, pás „KOLO 2/3“ / „POSLEDNÍ KOLO“ s časem kola, zatmívačka mezi menu a závodem
- **Fáze 6 grafiky (verze 1.7.0):** kopce a sjezdy na všech tratích (údolí ±8 m, kaňon ±11 m, laguna až 7 m), klopené zatáčky, kopec se žlutočernou rampou a skokem přes 20 m, trik ve vzduchu tlačítkem driftu (otočka, nápis „Trik!“, turbo po dopadu), do kopce pomaleji, z kopce rychleji, dopad s pérováním a zvukem, motokára se naklání podle svahu, terén kolem trati navazuje na silnici, všechno okolí stojí na zemi, předměty jezdí po kopcích, kamera sleduje výšku a nezajede do kopce, výška a skoky jdou i přes Wi-Fi
- **Tři nové tratě (verze 1.8.0), celkem jich je šest:** Podzimní les (barevné stromy a jedle, padající listí, dřevěná rozhledna s vlajkou, rybník), Noční město (domy s rozsvícenými okny, lampy se světlem na silnici, hvězdy a měsíc, televizní věž, neonová brána přes trať, panorama města na obzoru), Sopečný ostrov (palmy, pláže a moře kolem, kouřící sopka s lávovými proudy, lávové jezero). Každá má vlastní kopce a skok.
- **Mistrovství (verze 1.9.0):** všech šest tratí za sebou se stejnými soupeři, body 10/8/6/4/2/1, po každém závodě dvě tabulky (tento závod s přičtenými body a celkové pořadí), vedoucí startuje příště ze zadu, na startu každého závodu pás „ZÁVOD 2/6“, na konci tři nejlepší z celého mistrovství na stupních vítězů a uložený nejlepší pohár pro každou obtížnost. Funguje pro jednoho i dva hráče. Restart v pauze zopakuje jen aktuální závod. Hra teď drží v paměti jen trať, která je na obrazovce (šest tratí by telefon zahltilo).
- **Mistrovství po Wi-Fi a časovka (verze 1.10.0):** v lobby přepínač Jeden závod / Mistrovství. Body počítá hostitel a posílá je všem, další závod spouští hostitel, až dojedou všichni hráči. Kdo mezi závody odejde, za toho jede dál počítač. Časovka: sám na trati, bez otazníků, se třemi turby, proti průhlednému duchovi nejlepší jízdy (uložený zvlášť pro každou trať a obtížnost). Po každém kole rozdíl proti duchovi, ve výsledcích časy kol s rozdíly, nejlepší čas časovky u tratí v menu.
- **Etapa A (verze 1.11.0):** v menu svítí zlatě jen vybraná volba, kurzor ovladače a klávesnice je zvlášť (bílý pulzující rámeček, myší a dotykem se neukazuje), začíná na vybrané volbě a po výběru zůstává na místě. Motokára vzlétne jen z rampy, na hřebenech se jen zhoupne v pérování, nejostřejší hřebeny jsou zaoblené. Nový test vzletů `--jumptest` (i v GitHub Actions).
- **Etapa B (verze 1.12.0):** po Wi-Fi reaguje vlastní motokára hned: zařízení ji počítá samo a hostitel ji jen dorovnává. Test se zpožděním 120 ms každým směrem (`--fake-lag`) ukazuje odchylku od hostitele v průměru 26 cm, v 95 % případů do 62 cm. GitHub Actions teď síťový závod testují s tímto zpožděním.
- **Etapa C (verze 1.13.0):** čtyři nové předměty: modrá raketa (letí k vedoucímu), olej (louže na 20 s), blesk (ostatní se na 6 s zmenší a dají se přejet) a štít (bublina pohltí jeden zásah). Nové ikony v hracím automatu, zvuky a efekty, nová tabulka šancí podle pořadí, počítačoví soupeři je používají a vyhýbají se louži. Fungují i po Wi-Fi. Test `--itemtest`.
- Ověřeno v oficiálním Godotu 4.7.1: import bez chyb, závod do cíle sólo i ve 2 hráčích, síťový závod (hostitel + klient), hledání her, odmítnutí jiné verze, screenshoty všech tratí a efektů, měření výkonu

## 📝 TODO
### Vylepšení grafiky (podrobně v `PLAN_GRAFIKA.md`)
- Všech šest fází je hotových. Volitelně zbývá Forward+ jen pro PC nebo hotové modely CC0.

### Backlog (později)
- Hra přes internet (ne jen stejná Wi-Fi): server nebo relay
- Rozdělená obrazovka i v síťové hře (2 hráči na jednom zařízení + další přes Wi-Fi)
- Vlastní podpisový klíč a verze pro Google Play

## 🐛 Známé bugy
- Zatím žádné známé. Na skutečném telefonu a na Windows zatím netestováno, stejně jako Wi-Fi mezi dvěma reálnými zařízeními (otestováno jen hostitel + klient na jednom počítači).
- Na softwarovém vykreslování v cloudu je verze 1.5.0 proti 1.1.0 na Nízké asi o 14 %, na Střední o ~35 % a na Vysoké o ~58 % pomalejší (Nízká 27,8 → 24,0, Střední 10,4 → 6,7, Vysoká 10,0 → 4,2 FPS). Většinu dělají stíny, záře a SSAO z fáze 1. Verze 1.6.0 je stejně rychlá jako 1.5.0 (měřeno vedle sebe). Verze 1.7.0 je kvůli terénu na Střední asi o 11 % a na Vysoké o 12 % pomalejší, na Nízké stejná. Telefon ukazoval s verzí 1.6.0 na Střední 120 FPS.
- Kdo do rampy vjede skoro stojící (pod 3 m/s), nevyletí, jen se na konci rampy sveze dolů. A kdo jede pozpátku, na rampu „vyskočí“ zezadu. V závodě se to skoro nestane.
- Podzimní les je v cloudu nejnáročnější trať (Střední 5,6 FPS proti 6,3 v údolí): je nejdelší, má nejvíc stromů a pneumatik. Noční město a ostrov jsou na tom jako údolí.
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
- **Výška trati se počítá z oblouku podél kola, ne z mapy výšek:** silnice má výšku a klopení v každém bodě osy (po 2 m), fyzika z toho jen interpoluje, takže je přesná a levná. Terén kolem je zvláštní síť po 6 m, která u silnice pokračuje jejím povrchem. Rampa je samostatný kus, terén ji neřeší. Motokára zůstává v rovině „2D + výška“: zatáčení, srážky, AI i síť fungují jako dřív, výška se k tomu jen přidává.
- **Nové tratě jsou jen data a pár stavebnic:** tvar (body křivky), barvy, nálada oblohy a kopce jsou v `game.gd`, okolí podle typu (`deco`: autumn, city, palms) ve `world_builder.gd`, dominanta podle id v `trackside.gd`. Hra, AI, síť, minimapa i menu pracují s libovolným počtem tratí. Nová trať musí projít `--trackinfo`: části trati, které jsou daleko od sebe po trati, musí být v prostoru aspoň ~85 m od sebe a nejostřejší zatáčka mít poloměr kolem 28 m a víc.
- **Duch v časovce je záznam, ne simulace:** desetkrát za sekundu se uloží poloha, výška a natočení motokáry. Duch se mezi záznamy jen dopočítá a natočí podle povrchu, takže sedí na trati přesně tak, jak se jelo. Soubor má pro tři kola jen pár desítek kilobajtů (`user://ghost_<trať>_<obtížnost>.dat`).
- **Mistrovství po Wi-Fi vede hostitel:** body počítá jen on (u klientů by se odhad pořadí nedojetých motokár mohl lišit) a posílá je ostatním. Test `--nettest=host --cup --cup-start=4` projede poslední dva závody mistrovství po síti. V GitHub Actions neběží, protože síťové závody jedou ve skutečném čase a test by trval přes 5 minut.
- **Stíny motokár ze zjednodušeného modelu:** detailní model stín nevrhá, místo něj ho vrhá neviditelná jednodušší kopie (stín se kreslí pro každé pásmo stínů zvlášť).
- **Vzlet jen ze schodu, ne z hřebene:** motokára vyletí, jen když silnice pod ní najednou spadne o 25 cm a víc (konec rampy, její boky). Dřív stačilo, aby silnice klesala rychleji než gravitace, a to se s turbem stávalo i na hřebenech a hlavně těsně po dopadu z rampy. Kopec teď pocítíš jen v pérování.
- **Kurzor menu se kreslí zvlášť (`focus_ring.gd`), ne stylem tlačítka:** styl tlačítka by se musel měnit každý snímek kvůli blikání, a to by Godot přepočítával celé menu. Samostatná vrstva navíc pozná, jestli hraješ myší, dotykem, nebo ovladačem.
- **Nové předměty jsou stav, ne událost (od verze 1.13.0):** štít a zmenšení jsou časovače v motokáře, louže a modré rakety seznamy jako banány. Klient po Wi-Fi tak efekty (záblesk blesku, prasknutí bubliny, zvuky) pozná sám ze změny stavu a nic se nemusí posílat zvlášť. Výbuch nese druh (raketa, nebo modrá raketa).
- **Blesk netrefí hvězdu a štít:** hvězda ochrání úplně, štít se místo zmenšení spotřebuje. Zmenšená motokára se při srážce s normální roztočí („přejetí“).
- **Crossplay nejdřív přes stejnou Wi-Fi** (bez serveru, zdarma). Hostitel počítá celý závod, ostatní posílají ovládání a dostávají stav 30× za sekundu.
- **Předpověď jen pro vlastní motokáru (od verze 1.12.0):** klient si svou motokáru počítá sám stejným kódem jako hostitel, hostitel ale zůstává pánem všeho. Ve zprávě posílá číslo posledního použitého ovládání, klient od toho místa přepočítá novější ovládání a rozdíl plynule dorovná. Ostatní motokáry se dál jen plynule posouvají podle hostitele. Předměty, zásahy, srážky s ostatními, kola a cíl předpověď neřeší, rozhodne je hostitel a projeví se se zpožděním Wi-Fi.
- **Síťový test jezdí jako skutečný hráč:** od verze 1.12.0 v testu řídí motokáru klienta počítačový řidič na straně klienta a jeho ovládání jde přes síť. Dřív ji řídil hostitel sám, takže se předávání ovládání netestovalo.
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
- `godot/scripts/focus_ring.gd` – kurzor v menu pro klávesnici a ovladač
- `godot/scripts/gfx.gd` – úrovně kvality grafiky (co která zapíná)
- `godot/scripts/effects.gd` – jednorázové efekty: výbuch, střepy krabic, konfety, hvězdičky po zásahu
- `godot/scripts/skid_marks.gd`, `speed_lines.gd` – stopy smyku a rychlostní čáry
- `godot/export_presets.cfg` – export Android + Windows
- `.github/workflows/build.yml` – testy a sestavení APK + EXE
- `web/` – původní webový prototyp
- `PLAN_GRAFIKA.md` – fázovaný plán vylepšení grafiky
