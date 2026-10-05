# Škoda Racer – Project Status
*Naposled aktualizováno: 05. 10. 2026*

## 🎯 Co to je
3D motokárové závody ve stylu Mario Kart pro Android a Windows: dva hráči na jednom počítači a crossplay přes Wi-Fi.
Stack: Godot 4.7.1 (GDScript, renderer Compatibility), export APK + EXE přes GitHub Actions. Webový prototyp zůstává ve `web/`.

## ⏭️ Příští krok
**Vyzkoušet verzi 1.2.0 na telefonu a PC (zapnout FPS, projet všechny tři tratě na všech třech kvalitách) a pak fáze 2 z `PLAN_GRAFIKA.md`: efekty při jízdě.**
Až napíšeš, kolik FPS hra na telefonu ukazuje na Střední, rozhodneme, jestli tam stíny nechat, nebo je dát jen na Vysokou (stíny jsou na Střední nejdražší efekt).

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
- **Fáze 0 grafiky (verze 1.1.0):** kvalita grafiky Nízká/Střední/Vysoká v menu i v pauze (rozlišení 3D, vyhlazení hran, počet částic, hustota stromů), počítadlo FPS, kontrola verze u Wi-Fi hry (jiná verze se odmítne s vysvětlením, v seznamu her je vidět verze), měření výkonu `--bench`, hudba se generuje na pozadí (rychlejší start)
- **Fáze 1 grafiky (verze 1.2.0):** stíny od slunce (Střední a Vysoká), záře plamenů, jiskřiček, hvězdy, rakety, krabic a slunce, filmové barvy AgX se sytostí, SSAO na Vysoké, vlastní nálada tratí (údolí odpoledne, kaňon při západu slunce, laguna zatažená se sněžením), sluneční disk a plující mraky. Opravená silnice, na kterou předtím nesvítilo slunce. `--bench` měří skutečný čas snímku.
- Ověřeno lokálně ve vlastnoručně zkompilovaném Godotu 4.7.1 (stejný commit `a13da4f` jako Jendův): import bez chyb, závod do cíle sólo i ve 2 hráčích, síťový závod se shodnými výsledky u hostitele i klienta, screenshoty všech tratí a obrazovek

## 📝 TODO
### Vylepšení grafiky (podrobně v `PLAN_GRAFIKA.md`)
- Fáze 2: stopy smyku, rychlostní čáry, lepší výbuchy a turbo, konfety v cíli
- Fáze 3: 6 různých motokár, živí jezdci (ruce na volantu, naklánění)
- Fáze 4: semafor, tribuny s diváky, vlajky ve větru, dominanty tratí
- Fáze 5: 3D náhled jezdce v menu, stupně vítězů, animovaný HUD
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
- Na softwarovém vykreslování v cloudu je Střední o ~25 % a Vysoká o ~55 % pomalejší než ve verzi 1.1.0 (stíny, záře, SSAO). Na skutečném telefonu zatím neměřeno. Nízká je skoro stejně rychlá jako dřív.
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
- **Crossplay nejdřív přes stejnou Wi-Fi** (bez serveru, zdarma). Hostitel počítá celý závod, ostatní posílají ovládání a dostávají stav 30× za sekundu.
- **Rozdělená obrazovka nahoře/dole** jako v Mario Kartu; každý hráč má vlastní kameru a HUD.
- **Testovací podpisový klíč v repozitáři** (`build/debug.keystore`), aby šlo APK aktualizovat bez odinstalace. Pro Google Play bude potřeba vlastní tajný klíč.
- **Vlastní postavy a předměty**, žádné postavy ani názvy z Nintenda.
- **Název Škoda Racer + poznámka „neoficiální fanouškovská hra“**: Škoda je ochranná známka, pro Google Play by název mohl být problém.
- **Fyzika s pevným krokem 1/120 s**: stejné chování na rychlém PC i pomalém telefonu.
- **Na mobilu plyn automaticky**: palcem se nedá zároveň držet plyn a driftovat.

## 📁 Stav souborů
- `godot/project.godot` – Godot projekt (otevřít přes Import)
- `godot/scripts/main.gd` – start hry, menu vs. závod, testovací režimy
- `godot/scripts/race.gd` – závod: simulace, AI, předměty, kamery, rozdělená obrazovka, výsledky, síťová synchronizace
- `godot/scripts/kart.gd` – motokára: model, efekty, jízdní fyzika
- `godot/scripts/track.gd`, `world_builder.gd` – trať a svět kolem ní
- `godot/scripts/atmosphere.gd` – obloha, slunce a stíny, mlha, barvy, záře, mraky, sníh
- `godot/scripts/net.gd` – Wi-Fi multiplayer (hostitel, klient, hledání her, lobby)
- `godot/scripts/menu.gd`, `hud.gd`, `minimap.gd`, `item_icon.gd`, `touch_controls.gd`, `ui.gd` – rozhraní
- `godot/scripts/game.gd`, `sfx.gd` – data (včetně nálady každé trati), nastavení, ovládání, zvuky
- `godot/scripts/gfx.gd` – úrovně kvality grafiky (co která zapíná)
- `godot/export_presets.cfg` – export Android + Windows
- `.github/workflows/build.yml` – testy a sestavení APK + EXE
- `web/` – původní webový prototyp
- `PLAN_GRAFIKA.md` – fázovaný plán vylepšení grafiky
