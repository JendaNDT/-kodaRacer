# Plán vylepšení 2 – naklánění, vibrace a bitva s balónky

Navazuje na verzi 1.16.1 (všechny etapy A–F z `PLAN_VYLEPSENI.md` a oprava grafiky na telefonech).
Tři body rozdělené do **tří etap**. Každá etapa je samostatná verze: projde testy, má screenshoty a je v `main`.
Mezi etapami se dá zastavit, vyzkoušet hru na telefonu a změnit pořadí.

| Etapa | Verze | Velikost | Co přinese |
| --- | --- | --- | --- |
| G | 1.17.0 | malá | zatáčení nakláněním telefonu a vibrace |
| H | 1.18.0 | velká | bitva s balónky v aréně (sám nebo ve dvou na jednom počítači) |
| I | 1.19.0 | střední | bitva s balónky po Wi-Fi |

Pořadí je schválně tohle: G je rychlá a hned je na telefonu znát. H je největší kus práce, I na ni navazuje.

---

## Etapa G – Naklánění a vibrace  ✅ hotovo (verze 1.17.0), čeká na vyzkoušení na telefonu

> **Výsledek:** v menu i v pauze je tlačítko **Vibrace** (i na počítači, kde vibruje herní ovladač) a na telefonu se
> senzorem tlačítka **Ovládání: volant / naklánění** a **Citlivost** (Jemná / Střední / Ostrá), v pauze navíc
> **Vyrovnat**. Při naklánění zmizí dotykový volant a vlevo dole je malý volantík, který ukazuje, jak moc motokára
> zatáčí (při plném rejdu zezlátne). Naklánění měří otočení telefonu jako volantu (kolem osy displeje); když
> telefon držíš skoro naplocho, bere místo toho, jak moc klesá pravý okraj. Vyrovnání proběhne v poslední vteřině
> odpočtu (průměr z 1 s), tlačítko Vyrovnat bere průměr z dalšího půl vteřiny. Vyhlazení s časovou konstantou
> 0,07 s: jeden roztřesený snímek pohne řízením necelou desetinou rejdu, skutečné natočení je za 0,2 s z 93 % hotové.
> **Otočení telefonu:** ve zdrojovém kódu Godotu 4.7.1 jsem ověřil, že Godot osy senzoru otáčí podle displeje sám,
> ale jen když Android ohlásí změnu nastavení, a otočení o 180° (z jedné strany na šířku na druhou) ji neohlásí.
> Hra proto pozná „vzhůru nohama“ podle toho, že gravitace míří k hornímu okraji displeje, a směr si otočí sama.
> Senzor gravitace se musí v Godotu zapnout v nastavení projektu (`input_devices/sensors/enable_gravity`, výchozí je
> vypnuto); kde telefon gravitační senzor nemá, použije se akcelerometr.
> **Vibrace** jdou všechny přes `haptics.gd` (nový autoload `Haptics`), události se poznávají ze stavu motokáry
> stejně jako zvuky, takže fungují i u klienta po Wi-Fi. Síla a délka: náraz 20–60 ms podle síly, zásah 135–160 ms,
> dopad 30–110 ms podle rychlosti pádu (skok z rampy ≈ 13 m/s → 0,66), turbo 35–50 ms, změna jisker 15–30 ms,
> cíl 2× 70 ms. Když přijde další dřív než za 0,1 s, silnější počká na svou chvíli, slabší se zahodí. Po průjezdu
> cílem (jede autopilot) už nic nevibruje. Při zapnutí vibrací telefon jednou zkušebně zavibruje.
> **Test `--tilttest`:** 17 kontrol (rovně, mrtvá zóna, plný rejd přesně na 35° / 25° / 18°, trochu / hodně / přes
> hranu, doleva jako doprava, pořadí citlivostí, skoro naplocho, otočený telefon, vyhlazení, vyrovnání, ovládání)
> a závod s telefonem drženým 12° nakřivo: po odpočtu rovně, po naklonění o 15° zatáčí doprava.
> **Test `--hapticstest`:** celý závod s autopilotem, test sám přidá zásah, blesk, náraz do bariéry, pád ze 6 m
> a drift klávesami. Každá událost zavibruje, mezi dvěma vibracemi je vždy aspoň 0,1 s, v druhém kole jsou vibrace
> vypnuté a nevibruje nic (i když se v něm děje 9–20 událostí). Běží i pro dva hráče (každý cítí jen své).
> Wi-Fi test navíc kontroluje, že hráč u klienta cítí průjezd cílem.
> **Co jde ověřit jen na telefonu:** jestli je naklánění příjemné (citlivost, vyhlazení) a jestli jsou vibrace
> dost silné, ale ne otravné. Některé telefony neumí měnit sílu vibrace, ty rozliší jen délku.

**Cíl:** na telefonu jde zatáčet nakloněním jako s volantem a telefon při nárazech, zásazích a turbu jemně zavibruje.

### Zatáčení nakláněním
- V menu i v pauze nové tlačítko **Ovládání: Volant / Naklánění**. Zobrazí se jen na telefonu, který má senzor
  náklonu. Výchozí zůstává volant (dotykový ovladač vlevo), aby se nic nezměnilo tomu, kdo si nevybere.
- S nakláněním zmizí dotykový volant vlevo. Tlačítka vpravo (drift, předmět, brzda) zůstanou a plyn je dál
  automatický.
- **Citlivost** ve třech stupních (Jemná / Střední / Ostrá). Platí plný rejd při náklonu asi 35° / 25° / 18°.
- **Mrtvá zóna** kolem středu (asi 3°), aby motokára necukala, když telefon držíš skoro rovně. Pohyb se
  vyhlazuje, aby se třes rukou nepřenášel do řízení.
- **Vyrovnání:** při startu závodu (během odpočtu) si hra zapamatuje, jak telefon držíš, a to bere jako „rovně“.
  V pauze je tlačítko **Vyrovnat** pro případ, že si sedneš jinak.
- **Otočení telefonu:** hra se otáčí podle toho, kterým bokem telefon držíš na šířku. Směr náklonu se proto
  musí obracet podle aktuální orientace displeje, jinak by se při otočení zatáčelo obráceně.
- Senzor čte Godot (`Input.get_gravity()`). Kde chybí, volba Naklánění se nenabídne.

### Vibrace
- Krátké zavibrování (`Input.vibrate_handheld`) při:

  | Událost | Síla |
  | --- | --- |
  | náraz do bariéry nebo do soupeře | krátce, podle síly nárazu |
  | zásah raketou, banánem, olejem nebo bleskem | středně |
  | dopad ze skoku | podle výšky pádu |
  | spuštění turba (i z driftu) | jemně |
  | nová úroveň driftu (modrá, oranžová, fialová) | velmi krátce |
  | průjezd cílem | dvakrát krátce |

- Na počítači stejné události rozvibrují připojený ovladač (`Input.start_joy_vibration`). Při dvou hráčích
  vibruje jen ovladač toho hráče, kterého se událost týká.
- V menu i v pauze tlačítko **Vibrace: zapnuté / vypnuté**. Výchozí je zapnuto.
- Android potřebuje k vibracím povolení: v `export_presets.cfg` se zapne `permissions/vibrate`.
- Vibrace se nespouští častěji než asi 10× za sekundu, aby se nesčítaly do jednoho dlouhého bzučení.

### Kde
- `game.gd`: nastavení ovládání, citlivosti a vibrací, čtení náklonu v `read_input`.
- `touch_controls.gd`: bez volantu při naklánění.
- `menu.gd` a `race.gd`: tlačítka v menu a pauze, Vyrovnat.
- Nový malý `haptics.gd`: jedno místo pro všechny vibrace.
- `kart.gd` / `race.gd`: volání při událostech.
- `export_presets.cfg`: povolení.

### Testy a hotovo
- **Test `--tilttest`:** vymyšlené hodnoty senzoru (rovně, mírně, hodně, za hranou, otočený telefon) se musí
  převést na správné zatáčení. Mrtvá zóna, vyhlazení a vyrovnání podle prvních hodnot.
- **Test `--hapticstest`:** celý závod s autopilotem. Vibrace se nezapisují do telefonu, ale do seznamu.
  Kontroluje se, že každá událost vibruje, nic nevibruje častěji než povolený limit a s vypnutými vibracemi
  nevibruje nic.
- **Hotovo, když:** testy projdou v GitHub Actions a Jenda na telefonu potvrdí, že naklánění jde ovládat
  a vibrace jsou příjemné. Obojí se dá ověřit jen na skutečném telefonu, v cloudu senzor ani vibrace nejsou.

---

## Etapa H – Bitva s balónky (sám nebo ve dvou)  ✅ hotovo (verze 1.18.0)

> **Výsledek:** v menu je **Bitva s balónky** (1 hráč, na počítači i 2 hráči s rozdělenou obrazovkou; jezdec, lak,
> aréna, obtížnost). Pravidla podle návrhu: 3 balónky, 3 minuty. **Náměstí** (čtverec 132 m se zaoblenými rohy,
> kašna s vodotryskem, čtyři květináče se stromy, čtyři nízké zídky, čtyři rampy v uličkách u okraje, kolem domy
> s radnicí a diváci) a **Ledový stadion** (kruh o poloměru 70 m, uprostřed kluzký led, šest sněhových valů, tři
> rampy u mantinelu, tribuny s diváky, stožáry světel, sněžení). V každé aréně 14 otazníků rozházených po ploše
> (vždy stejně), 6 startů po obvodu čelem ke středu.
> **Volný pohyb:** všechno pevné v aréně je jedna funkce vzdálenosti `Arena.space`. Motokáry po stěnách
> klouzají jako po bariérách na trati, nízké věci ve vzduchu přeletí, vysoké boky a zadní hrana ramp jsou zeď,
> z rampy se vzlétá jako na trati. Na ledu se zatáčí o polovinu hůř.
> **Bitva:** zásah, který projde (`Race.hit_kart`), stojí balónek; potom aspoň 2 s ochrana (balónky blikají).
> Blesk jen zmenšuje, přejetí zmenšeného stojí balónek. Kdo nemá balónky, zmizí z arény a jeho kamera sleduje
> vedoucího. Konec, když zbyde jeden, nebo po 3 minutách (víc balónků, pak víc prasknutých). Šance na předměty:
> raketa 26, banán 22, štít 10, olej 8, turbo 8, hvězda 7, modrá raketa 5, 3× turbo 3, blesk 2. Raketa letí
> k nejbližšímu soupeři před motokárou a v aréně sleduje jen toho, koho má do 38 m před sebou; modrá k tomu
> s nejvíc balónky. Otazníky se vracejí za 6 s.
> **Počítač:** cíl podle vzdálenosti a balónků (povaha „hunt“), bez předmětu jede pro nejbližší otazník,
> s posledním balónkem (Karel už s dvěma) drží odstup a pokládá banány, střílí, když má soupeře v dosahu
> a před sebou (povaha „aim“, Profesor Píst míří nejlíp), rozhlíží se 13 směry po volném místě, každých 0,08 s.
> Když se zasekne, couvne tak, aby se otočil k volnému místu.
> **HUD a menu:** vlastní balónky vlevo nahoře, zbývající čas (posledních 30 s červeně), soupeři s balónky,
> „Pepa Plyn vypadl!“, „Vypadl jsi · sleduješ: …“, minimapa arény. Výsledky s balónky, prasknutými a časem
> vypadnutí, stupně vítězů za zdí arény. Ve Sbírce **bitevní lak** (tmavý s neonovými doplňky) za vítězství
> na Těžké s daným jezdcem.
> **Test `--battletest`:** 18 kontrol pravidel (raketa vezme balónek, ochrana, poslední balónek, blesk nebere,
> přejetí zmenšeného, hvězda, cíl rakety i modré rakety, konec po 3 minutách se správným pořadím, poslední ve
> hře vyhraje, bitevní lak) a 6 bitev jen s počítačem (obě arény, všechny obtížnosti). Pět opakování po sobě
> (30 bitev): všechny skončily vítězem, nikdo neopustil arénu ani se nezasekl, každý zásah stál právě jeden
> balónek. Bitva šesti počítačů trvá 40–100 s; s hráčem, který se brání, bude delší. Celý test trvá asi minutu.
> **Co jde ověřit jen hraním:** jestli je bitva zábavná (délka, síla soupeřů, velikost arén) a jak běží na
> telefonu.

**Cíl:** nový režim, ve kterém se nezávodí na kola. V aréně se motokáry honí a předměty si navzájem praskají
balónky. Vyhraje, kdo vydrží nejdéle.

### Pravidla
- Každý začíná se **3 balónky**, uvázanými nad motokárou a barevnými podle jezdce.
- Balónek praskne při zásahu raketou, modrou raketou, banánem, olejem nebo nárazem do soupeře s hvězdou.
  Blesk balónek nebere, jen zmenší, a zmenšeného jde přejet: to balónek stojí.
- Po zásahu má motokára 2 s ochranu, aby nepřišla o všechny balónky naráz.
- Kdo přijde o poslední balónek, vypadává. Jeho kamera pak sleduje ostatní.
- Bitva končí, když zbyde jeden, nebo po **3 minutách**. Pak vyhrává, kdo má víc balónků. Při rovnosti rozhodne,
  kdo jich víc praskl ostatním.
- Pořadí ve výsledcích je podle toho, kdo vypadl dřív. Vítěz stojí na stupních vítězů jako po závodě.

### Arény
Dvě nové arény, postavené kódem stejně jako tratě. Hrají se jen v bitvě.
- **Náměstí**: čtvercová plocha s kašnou uprostřed, nízkými zídkami a rampami na okrajích.
- **Ledový stadion**: kulatá aréna, uprostřed kluzká ledová plocha (jako led na zkratce v Ledové laguně) a sněhové
  valy, za které se dá schovat.

Každá aréna má:
- otazníky rozmístěné po celé ploše, ne v řadách,
- 6 startovních míst po obvodu, motokáry na startu míří do středu,
- pevné okraje (zdi), přes které se nedá vyjet.

Motokáry v aréně nejezdí podél středové čáry tratě, ale volně po ploše. To je největší technická změna: okraje
a výška země se v aréně počítají jinak než na trati.

### Předměty v bitvě
- Stejné předměty jako v závodě, ale s jinými šancemi (víc raket a banánů, méně turba).
- Raketa letí k nejbližšímu soupeři před motokárou.
- Modrá raketa letí k tomu, kdo má nejvíc balónků.
- Zkratky ani rampy pro skoky z tratí v aréně nejsou. Arény mají vlastní menší rampy.

### Počítačoví soupeři v bitvě
- Vyberou si cíl: nejbližšího soupeře, raději toho s víc balónky. Pronásledují ho a vystřelí, když je v dosahu
  a před nimi.
- Bez předmětu jedou pro nejbližší otazník.
- S jedním balónkem jsou opatrnější: drží si odstup a banány pokládají za sebe.
- Vyhýbají se zdem, kaši a sněhovým valům a nezaseknou se v rohu.
- Povahy jezdců platí i tady: Zuzka útočí, Karel je opatrný, Profesor Píst míří nejlíp.

### Obrazovka a menu
- V hlavním menu nové tlačítko **Bitva s balónky**. Nastavení: jezdec, lak, aréna, obtížnost, 1 nebo 2 hráči
  (rozdělená obrazovka).
- HUD:
  - vlastní balónky velké vlevo nahoře,
  - malý seznam soupeřů s počtem balónků,
  - zbývající čas,
  - hlášení „Pepa Plyn vypadl!“.
- Minimapa ukazuje arénu a všechny motokáry.
- Do Sbírky přibude odměna za bitvu, třeba **třetí lak** za vítězství v bitvě na Těžké.

### Kde
- `game.gd`: arény a pravidla.
- Nový `arena.gd`: tvar arény, zdi, výška země a otazníky.
- `world_builder.gd` / `trackside.gd`: vzhled arén.
- `kart.gd`: pohyb a okraje v aréně, balónky nad motokárou.
- `race.gd`: režim bitvy, zásahy, vypadávání, konec a výsledky.
- `race.gd`: počítač v bitvě.
- `hud.gd`, `minimap.gd`, `menu.gd`: obrazovky.

### Testy a hotovo
- **Test `--battletest`:** pro obě arény a všechny tři obtížnosti jen počítačoví soupeři. Bitva musí skončit
  vítězem do 3 minut, nikdo nesmí opustit arénu ani se zaseknout a každý zásah musí stát přesně jeden balónek.
- **Kontroly pravidel** v připravených situacích (jako u `--itemtest`):
  - raketa vezme balónek,
  - během ochrany po zásahu se nic nebere,
  - přejetí zmenšeného soupeře stojí balónek,
  - konec po 3 minutách vyhodnotí pořadí správně.
- Všechny dosavadní testy závodů musí projít beze změny.
- **Hotovo, když:** testy projdou, jsou screenshoty obou arén, HUD a výsledků bitvy a bitva se dá odehrát na
  telefonu i ve dvou na počítači.

---

## Etapa I – Bitva po Wi-Fi  ✅ hotovo (verze 1.19.0)

> **Výsledek:** v lobby je vedle **Jeden závod / Mistrovství** režim **Bitva**; hostitel vybírá arénu (stejné
> dlaždice s plánkem jako v menu), ostatní jeho volbu vidí a tlačítko startu má nápis **Do bitvy!**. Hostitel
> počítá celou bitvu. Ke každé motokáře posílá 30× za vteřinu i balónky, kolik jich praskla ostatním, jestli
> vypadla a kde; v hlavičce stav bitvy, čas konce a poslední 4 prasknutí (pořadové číslo, čas, komu, kdo).
> Klient z toho kreslí prasknutí, vypadnutí, HUD i výsledky stejným kódem jako hra na jednom zařízení a pořadí
> bere od hostitele. Svou motokáru si dál předpovídá (i v aréně, s rampami a ledem), při vypadnutí se už
> nedorovnává. Volná místa doplní počítač, kdo odejde, toho převezme počítač (bez balónků zůstane mimo hru),
> výsledky mají u hostitele **Zpět do lobby**, u ostatních „Další hru spouští hostitel“. Nově ve všech bitvách:
> kdo praskne soupeři balónek, uvidí „Trefa!“ a jeho jméno. Bitevní lak za vítězství na Těžké platí i po Wi-Fi.
> **Test:** `--nettest=host --battle --wait-players=3` + klient se zpožděním 120 ms (±20 ms) + druhý klient,
> který po 20 s odejde. Hostitel i klient na konci vypíšou `BATTLE STATE` (balónky, prasknutí a vypadnutí každé
> motokáry, všechna prasknutí, vítěz), CI kontroluje, že jsou stejné, a že odešlého hráče převzal počítač
> (v cloudu ujel ~500 m). Bitvy v testu trvaly asi 1,5 minuty, 17 prasknutí, 5 vypadnutí; předpověď klienta
> p95 0,6 m (limit 1 m). Pak hostitel vrátí všechny do lobby a klient test končí až tam.
> **Oprava z CI:** test bitvy na jednom zařízení jednou našel dvě počítačové motokáry, které se 10 s tlačily
> o sebe (a jinde kroužily kolem blízkého otazníku). Počítač teď u blízkého cíle z boku ubere a případně
> vyjede z kruhu rovně, soupeře, kterému nemůže ublížit, objede a od zaseknutí o motokáru couvá pryč od ní.
> V 48 bitvách (8× obě arény na všech obtížnostech) žádné zaseknutí.
> **Zbývá:** vyzkoušet mezi dvěma skutečnými zařízeními (Jenda + kamarád).

**Cíl:** bitvu jde hrát s kamarády po Wi-Fi stejně jako závod, i mezi telefonem a počítačem.

### Co k tomu patří
- V lobby přibude u volby **Jeden závod / Mistrovství** ještě **Bitva** a hostitel vybere arénu.
- Hostitel počítá celou bitvu: zásahy, balónky, vypadávání, čas a konec. Klientům posílá i počet balónků každé
  motokáry a kdo komu balónek praskl.
- Klient si dál předpovídá svou motokáru (jako od etapy B), takže ovládání nemá zpoždění. Balónky a vypadnutí
  rozhoduje jen hostitel.
- Volná místa doplní počítačoví soupeři. Kdo během bitvy odejde, toho převezme počítač, nebo vypadne, pokud už
  neměl balónky.
- Po bitvě se všichni vrátí do lobby.

### Kde
- `net.gd`: režim bitvy v lobby a startu.
- `race.gd`: balónky a vypadávání ve zprávách hostitele.
- `main.gd`: síťový test bitvy.

### Testy a hotovo
- **Síťový test bitvy** (hostitel + klient na jednom počítači, zpoždění 120 ms každým směrem): bitva dojede do
  konce, klient vidí stejný počet balónků jako hostitel, praskání balónků i vypadnutí. Běží i v GitHub Actions.
- **Hotovo, když:** test projde a bitva po Wi-Fi funguje mezi dvěma zařízeními (Jenda + kamarád).

---

## Společné pro každou etapu
- Před nahráním projdou všechny testy, staré i nové: závod, mistrovství, časovka, zkratky, soupeři, předměty,
  skoky, odemykání, Wi-Fi, hledání her, kontrola verze.
- Na telefonu bez vyhlazování hran (MSAA). Vypnuté je od verze 1.16.1, protože rozbíjelo grafiku.
- Hra nesmí zpomalit víc než o pár procent. Na telefonu se ověří počítadlem FPS.
- Screenshoty novinek, aktualizace `README.md` a `PROJECT_STATUS.md`, nová verze, push na větev, zelená
  kontrola na GitHubu, pak `main`.
- Po každé etapě vyzkoušet hru na telefonu. U etapy G je to nutné, protože senzor náklonu ani vibrace se
  v cloudu vyzkoušet nedají.

## Otevřené otázky (rozhodne Jenda, klidně až u dané etapy)
- Naklánění: má být výchozí ovládání na telefonu, nebo jen volba? Návrh: jen volba, výchozí zůstává volant.
- Bitva: 3 minuty a 3 balónky, nebo jinak? Návrh: 3 a 3 jako v Mario Kartu.
- Arény: Náměstí a Ledový stadion, nebo jiné nápady?
