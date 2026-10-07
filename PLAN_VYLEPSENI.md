# Plán vylepšení hry – 7 bodů

Navazuje na verzi 1.10.0 (všech šest fází grafiky, šest tratí, mistrovství i po Wi-Fi, časovka).
Body jsou rozdělené do **šesti etap**. Každá etapa je samostatná verze: projde testy, má screenshoty
a je v `main`. Mezi etapami se dá zastavit, vyzkoušet hru na telefonu a změnit pořadí.

| Etapa | Body | Verze | Velikost | Co přinese |
| --- | --- | --- | --- | --- |
| A ✅ | 1, 4 | 1.11.0 | malá | čisté menu, žádné náhodné poskoky |
| B ✅ | 2 | 1.12.0 | střední | ovládání po Wi-Fi bez zpoždění |
| C ✅ | 5 | 1.13.0 | střední | čtyři nové předměty |
| D ✅ | 7 | 1.14.0 | střední | chytřejší soupeři s vlastní povahou |
| E ✅ | 8 | 1.15.0 | velká | zkratka na každé trati |
| F | 6 | 1.16.0 | střední | poháry, odemykání barev, tajný jezdec, zrcadlové tratě |

Odemykání (F) je schválně na konci: může pak odemykat i věci z etap C–E.

---

## Etapa A – Doladění (body 1 a 4)  ✅ hotovo (verze 1.11.0)

> **Výsledek:** vybraná volba má zlatou výplň a tmavý text. Kurzor je tenký bílý pulzující rámeček kousek vně
> tlačítka (`focus_ring.gd`), objeví se jen po šipkách nebo ovladači. Na začátku obrazovky stojí na vybrané volbě,
> po výběru zůstává na místě (i posunutí stránky). Kliknutí na už vybranou volbu ji nezruší. Vzlétnout jde jen při
> propadu silnice o 25 cm a víc najednou (rampa a její boky), na hřebeni se motokára jen zhoupne v pérování.
> Nejostřejší hřebeny jsou zaoblené (nejvíc se to dotklo Pouštního kaňonu). Nový test `--jumptest`: na původní verzi
> našel 18 vzletů mimo rampu (hlavně odskok po dopadu z rampy), teď žádný.


### 1. Zvýraznění tlačítek v menu
**Problém:** vybrané tlačítko i tlačítko pod kurzorem ovladače mají stejný zlatý rámeček, takže u přepínačů (režim,
jezdec, trať, obtížnost) svítí dvě věci najednou.

**Řešení:**
- **Vybrané** = zlatá výplň a tmavý text (jasně „zapnuto“).
- **Kurzor** (ovladač nebo klávesnice) = tenký bílý pulzující rámeček, který se vybraného tlačítka nijak nedotkne.
- Myší a dotykem se kurzorový rámeček vůbec nekreslí, objeví se až po stisku šipky nebo ovladače.
- Kurzor po otevření obrazovky začne na vybrané volbě, ne na první.

**Kde:** `ui.gd` (styly tlačítek), `menu.gd` (počáteční kurzor).
**Hotovo, když:** na screenshotech menu, nastavení závodu a lobby svítí v každé skupině jen jedna volba a kurzor je
poznat zvlášť.

### 4. Náhodné poskoky na hrbolech
**Problém:** s turbem nebo hvězdou motokára na ostrém hřebeni občas krátce vzlétne i mimo rampu.

**Řešení:**
- Vzlétnout jde jen **z rampy** nebo z opravdového schodu (propad o víc než ~25 cm najednou). Na obyčejném hřebeni
  motokára vždy zůstane na zemi a jen se zhoupne v pérování.
- Pro jistotu se na hřebenech trochu uhladí výškový profil tratí (ostré zlomy kopců se zaoblí).

**Kde:** `kart.gd` (`_vertical`), `track.gd` (vyhlazení profilu).
**Hotovo, když:** test se záznamem vzletů (jako při fázi 6) ukáže vzlety jen na rampách na všech šesti tratích,
i s turbem a hvězdou.

**Testy etapy A:** všechny dosavadní (závody na 6 tratích, 2 hráči, mistrovství, časovka, Wi-Fi), screenshoty menu.

---

## Etapa B – Ovládání po Wi-Fi bez zpoždění (bod 2)  ✅ hotovo (verze 1.12.0)

> **Výsledek:** klient počítá svou motokáru sám, hned ve stejném snímku, kdy zmáčkneš ovládání. Každá zpráva od
> hostitele nese číslo posledního ovládání, které hostitel použil (`ack`). Klient vezme stav od hostitele, znovu
> přepočítá novější ovládání a rozdíl dorovná během zlomku sekundy (víc než 4 m = přesun hned). Zpráva o motokáře má
> 8 čísel navíc (svislá rychlost, nabití driftu, síla turba, doba ve vzduchu, ochrana po zásahu…), aby přepočet
> seděl. `--fake-lag=120 --fake-jitter=20` zpozdí každou zprávu tam i zpátky o 120–140 ms (ping kolem 250 ms).
> Naměřeno s tímto zpožděním: předpověď je od hostitele v průměru 0,26 m, v 95 % případů do 0,62 m (závod
> i mistrovství po Wi-Fi). Bez zpoždění 0,11 m a 0,60 m.


**Problém:** hostitel počítá celý závod. Druhý hráč pošle ovládání, hostitel ho použije a stav pošle zpátky. Hráč
tak vidí svoji motokáru se zpožděním Wi-Fi (obvykle 30–100 ms), zatáčení působí „gumově“.

**Řešení – předpověď vlastní motokáry (client-side prediction):**
1. Telefon druhého hráče **počítá svoji motokáru sám** podle svého ovládání, okamžitě, stejným kódem jako hostitel
   (zatáčení, drift, turbo, kopce, skoky, bariéry).
2. Hostitel dál rozhoduje o všem, co se týká víc hráčů: srážky, předměty, zásahy, pořadí, cíl.
3. Když přijde stav od hostitele, telefon porovná, kde motokára podle hostitele je, s tím, kde si ji myslí.
   - Malý rozdíl (běžný) se **neznatelně dorovná** během zlomku sekundy.
   - Velký rozdíl (zásah raketou, srážka, banán) = motokára se přesune tam, kde je podle hostitele.
4. Zásah, smyk po banánu nebo raketa přijdou od hostitele a hned se projeví (motokára se roztočí jako dnes).
5. Hostitel dostane kromě ovládání i pořadové číslo, takže ví, které ovládání už použil.

**Testování bez dvou telefonů:** nový přepínač `--fake-lag=120` uměle zpozdí síťové zprávy o 120 ms. Test pak změří,
jak daleko je předpověď od hostitele (má být do ~1 m) a jestli se motokára netrhá.

**Kde:** `kart.gd`, `race.gd` (smyčka klienta), `net.gd` (pořadová čísla ovládání).
**Riziko:** střední. Předpověď a hostitel se můžou rozcházet v kopcích nebo při srážkách. Proto se dorovnává
plynule a jen vlastní motokára, ostatní zůstávají jako dnes.
**Hotovo, když:** se zpožděním 120 ms klient zatáčí okamžitě, předpověď drží do ~1 m od hostitele, síťový test
a mistrovství po Wi-Fi projdou.

---

## Etapa C – Nové předměty (bod 5)  ✅ hotovo (verze 1.13.0)

> **Výsledek:** všechny čtyři předměty jsou ve hře včetně ikon, zvuků a efektů. Modrá raketa letí 4 m nad tratí
> rychlostí 85 m/s, za vedoucím se snese dolů a výbuch zasáhne vše do 7 m. Louže zasahuje do 2,4 m, majitel má 1 s
> na odjetí, po 20 s zaschne. Blesk zmenší ostatní na 55 % a zpomalí je na 78 % (6 s), zmenšené motokáry se dají
> přejet. Štít je skleněná bublina na 10 s, posledních 2 s bliká. Šance podle pořadí (6 motokár): 1. místo banán 44 %,
> olej 20 %, turbo 24 %, raketa 9 %, štít 3 %; 6. místo raketa 23 %, 3× turbo 21 %, turbo 19 %, hvězda 14 %,
> modrá raketa 9 %, blesk 4 %. Test `--itemtest` prošel 22 kontrolami, síťový test v GitHub Actions rozdává předměty
> postupně dokola a ověřuje, že klient vidí louže, modré rakety, štít i zmenšení.


| Předmět | Co dělá | Kdo ho dostane |
| --- | --- | --- |
| **Modrá raketa** | letí po trati až k vedoucímu, výbuch shodí jeho i motokáry těsně u něj | vzácná, jen na posledních místech |
| **Olejová skvrna** | položíš za sebe velkou louži, kdo do ní vjede, dostane dlouhý smyk; zmizí po 20 s | spíš vepředu (obranná) |
| **Blesk** | všichni ostatní se na 6 s zmenší, jsou pomalejší a dají se přejet; hvězda a štít chrání | velmi vzácný, jen poslední dva |
| **Štít** | bublina kolem motokáry pohltí jeden zásah (banán, olej, raketa), vydrží 10 s | střed pole |

**Co k tomu patří:**
- ikony pro losování (hrací automat) a HUD, zvuky, efekty (louže, bublina, záblesk blesku, zmenšené motokáry),
- nová tabulka šancí podle pořadí (vzadu silnější předměty), aby hra zůstala férová,
- počítačoví soupeři je umějí použít (modrou raketu hned, olej když je někdo těsně za nimi, štít před raketou),
- přenos po Wi-Fi: louže a modré rakety jako banány a rakety dnes, zmenšení a štít jako stav motokáry,
- časovka zůstává jen se třemi turby.

**Kde:** `game.gd` (seznam předmětů), `race.gd` (použití, šance, zásahy), `kart.gd` (štít, zmenšení),
`item_icon.gd`, `effects.gd`, `sfx.gd`, `net.gd` (snímky).
**Nový test:** `--itemtest` postupně rozdá každý předmět a ověří, že funguje (zásah, štít pohltí ránu, blesk zmenší
ostatní, louže zmizí).
**Hotovo, když:** všechny předměty projdou testem, jsou na screenshotech a fungují i po Wi-Fi.

---

## Etapa D – Chytřejší soupeři (bod 7)  ✅ hotovo (verze 1.14.0)

> **Výsledek:** ideální stopa se pro každou trať spočítá na pozadí (tuhý drát položený do silnice: v zatáčkách má
> větší poloměr než střed silnice, např. les 30 m místo 27 m). Soupeři po ní jedou, rychlost volí podle zatáček před
> sebou a brzdí včas, předjíždějí z té strany, kde je víc místa, a uhýbají banánům i louži. Povahy jsou v
> `Game.PERSONA`. **Změna pravidel pro všechny (Jendovo rozhodnutí):** turbo z driftu dřív potřebovalo asi 110°
> zatočení v driftu, což se na Těžké do dlouhých oblouků nevešlo ani hráči. Hranice jsou teď na 60 %
> (0,6 / 1,3 / 2,1 místo 1,0 / 2,2 / 3,5). Soupeři si před dlouhou zatáčkou najedou k vnějšímu okraji a driftují do
> vnitřního. Sopečný ostrov nemá žádnou dost dlouhou zatáčku, tam nedriftují.
> **Naměřeno (`--aitest`, průměrné kolo všech šesti tratí):** Těžká bez otazníků 34,63 s → 33,0 s (o 4,8 % rychleji,
> nejlepší kola o 2 s), s otazníky 36,1 s → 35,5 s (soupeři se teď předměty víc trefují). Střední s otazníky
> 44,0 s → 42,7 s, Lehká 56,2 s → 56,0 s (schválně skoro beze změny). Dohánění na Těžké na 15 %, na Střední na 55 %.
> Nikdo se nezasekl, všichni dojeli.


**Dnes:** počítač jede po náhodném pruhu, přibrzdí před zatáčkou, nedriftuje, předměty používá jednoduše.

**Nově:**
1. **Ideální stopa:** pro každou trať se dopředu spočítá závodní stopa (do zatáčky z vnější strany, vrchol u vnitřní,
   ven zase vně). Soupeři se jí drží a jen se od ní odchylují, když předjíždějí nebo uhýbají.
2. **Drift:** v delších zatáčkách soupeři driftují a na výjezdu dostanou turbo. Na Lehké skoro ne, na Těžké dobře.
3. **Povahy jezdců** (každý jezdec jiná, sedí k jeho popisu v menu):
   - *Turbo Tonda:* vyrovnaný, nic nepřehání.
   - *Zuzka Zběsilá:* agresivní, vráží do soupeřů, předměty hned.
   - *Pepa Plyn:* pozdě brzdí, rychlý na rovinkách.
   - *Máňa Motor:* skvělé starty, raketový start skoro vždy.
   - *Karel Kolo:* opatrný, drží stopu, předměty si šetří.
   - *Bára Brzda:* královna zatáček, nejlepší drift.
4. **Taktika s předměty:** banán nebo olej podrží za sebou jako ochranu, raketu pošle, až je soupeř blízko, hvězdu
   použije, když ztrácí, turbo na rovince nebo přes trávu.
5. **Dohánění (rubber band) jemněji:** na Těžké skoro žádné, aby výhra něco znamenala.

**Kde:** `race.gd` (`_ai_input`), `track.gd` (ideální stopa), `game.gd` (povahy).
**Hotovo, když:** na všech tratích soupeři driftují a dojedou bez zaseknutí, na Těžké jsou znatelně rychlejší než
dnes (měřeno časy kol v testech) a mistrovství i Wi-Fi projdou.

---

## Etapa E – Zkratky (bod 8)  ✅ hotovo (verze 1.15.0)

> **Výsledek:** každá trať má jednu zkratku. Místo pro ni najde nástroj `--trackinfo --findcuts`: úsek silnice
> 180 m až skoro půl kola, ne přes start a cíl, rampu ani otazníky, cesta 45–72 % délky úseku, aspoň 3 m od cizích
> bariér, bez zatáček ostřejších než poloměr 15 m. Výsledek je uložený v `Game.TRACKS` (`cut`), hra ho jen postaví.
> Zpomalení na každé zkratce změřil `--cutcal` pro každou obtížnost zvlášť tak, aby bez turba prohrála asi o 6 %
> (na Lehké jezdí motokáry pomaleji, zatáčky silnice je tolik nebrzdí, a zkratka proto musí brzdit víc). Motokára na zkratce má
> vlastní stav (`on_cut`), její místo v kole se přepočítá na přeskočený úsek, takže pořadí i kola sedí. U silnice
> leží zkratka na povrchu silnice, takže najetí ani sjetí nevyhodí motokáru do vzduchu. Počítač zkratku vezme jen
> s turbem nebo hvězdou (Lehká 25 %, Střední 60 %, Těžká 90 %) a turbo pustí, až je na ní srovnaný.
> **Test `--cuttest` (úsek se zkratkou, Turbo Tonda, všechny tři obtížnosti):** bez turba 5–7 % pomaleji než silnice,
> s turbem o 4–20 % rychleji, s hvězdou o 15–53 % rychleji. Na žádné zkratce plnou rychlostí s hvězdou motokára
> nevyletí. Závod se zkratkou každé kolo počítá kola správně na všech tratích, po Wi-Fi klient zkratku vidí.


**Nápad:** na každé trati jedna zkratka. Mezera v bariéře, za ní prašná cesta přes trávu, písek nebo sníh a dál zpátky
na trať. Je kratší, ale terén zpomaluje. **S turbem, hvězdou nebo po driftu se vyplatí**, bez nich spíš ne. Riziko proti
odměně jako v Mario Kartu.

| Trať | Zkratka |
| --- | --- |
| Zelené údolí | lesní cesta kolem mlýna |
| Pouštní kaňon | pod skalním obloukem přes vyschlé koryto |
| Ledová laguna | přes okraj zamrzlého jezera (klouže) |
| Podzimní les | úvozová cesta pod rozhlednou |
| Noční město | průjezd podchodem mezi domy |
| Sopečný ostrov | po pláži kolem lávového jezera |

**Jak se to postaví:**
- Trať dostane kromě hlavní osy i **vedlejší cestu** (krátkou křivku) s vlastní šířkou.
- Motokára smí jet po hlavní trati **nebo** po vedlejší cestě. Bariéry v místě odbočení a napojení se vynechají.
- Terén pod cestou se srovná s její výškou, cesta má vlastní texturu a značky (šipky, kužely).
- Počítání kol a pořadí se na zkratce nesmí splést (zkratka je kratší než půl kola) a ukazatel „špatný směr“ se tam
  nespustí.
- Počítač zkratku vezme, když má turbo nebo hvězdu (na Těžké častěji).
- Minimapa zkratku ukáže čárkovaně.
- Kontrola `--trackinfo` ověří, že se zkratka nekříží s jinou částí trati.

**Kde:** `track.gd` (vedlejší cesta, omezení pohybu), `world_builder.gd` (cesta, terén, bariéry), `kart.gd`, `race.gd`
(AI, pořadí), `minimap.gd`, `game.gd` (body cest pro každou trať).
**Riziko:** velké, je to nejsložitější bod. Dotýká se fyziky, počítání kol, AI i terénu. Proto má vlastní etapu
a vlastní test.
**Nový test:** `--cuttest` projede s autopilotem kolo přes zkratku na každé trati a ověří, že se kolo počítá správně
a čas je s turbem kratší než bez zkratky.
**Hotovo, když:** zkratky jsou na screenshotech všech tratí, test projde a závody, mistrovství i Wi-Fi fungují.

---

## Etapa F – Odemykání (bod 6)

**Cíl:** aby mělo smysl vyhrávat poháry a jezdit časovky znovu.

**Co se odemyká:**
| Odměna | Jak ji získat |
| --- | --- |
| Druhý lak motokáry (každý jezdec) | jakýkoli pohár v mistrovství s tímto jezdcem |
| Zlatý lak motokáry (každý jezdec) | zlatý pohár na Těžké s tímto jezdcem |
| **Zrcadlové tratě** (všech šest otočených zrcadlově) | zlatý pohár na Střední |
| **Tajný 7. jezdec** s vlastní motokárou | zlatý pohár na Těžké |
| Duch „vývojáře“ v časovce (rychlý soupeř na každé trati) | časovka pod daným limitem na všech tratích |

**Co k tomu patří:**
- nová obrazovka **Sbírka** v menu: poháry (bronz/stříbro/zlato pro každou obtížnost) a odemčené i zamčené odměny
  s tím, jak je získat,
- oznámení po závodě „Odemčeno: …“ s efektem,
- výběr laku u jezdce v menu i v lobby,
- tajný jezdec: nový model motokáry a postava, vlastní jízdní vlastnosti a povaha. Ve hře je pak 7 jezdců a do závodu
  jich jede 6,
- zrcadlové tratě: celá trať se otočí zrcadlově (všechno se generuje z bodů, takže je to levné). Záznamy a duchové
  se ukládají zvlášť,
- po Wi-Fi: lak a tajný jezdec se posílají v lobby. Kdo jezdce nemá odemčeného, uvidí ho, ale nemůže si ho vybrat.

**Kde:** `game.gd` (odemčené věci v nastavení), `menu.gd` (Sbírka, výběr laku), `kart_model.gd` (laky, 7. motokára),
`driver_rig.gd`, `track.gd` (zrcadlení), `race.gd` (oznámení).
**Hotovo, když:** odemykání funguje v testu (simulované poháry), screenshoty Sbírky, laků, tajného jezdce
a zrcadlové trati, všechny testy projdou.

---

## Společné pro každou etapu
- Před nahráním projdou všechny testy (6 tratí, 2 hráči, mistrovství, časovka, Wi-Fi, hledání her, kontrola verze)
  a nové testy etapy.
- Měření výkonu na všech kvalitách. Žádná etapa nesmí hru zpomalit o víc než pár procent.
- Screenshoty novinek, aktualizace `README.md` a `PROJECT_STATUS.md`, nová verze, push na větev, zelená kontrola na
  GitHubu, pak `main`.
- Po každé etapě je dobré hru zkusit na telefonu. Hlavně po etapě B (Wi-Fi mezi dvěma zařízeními), protože tu se
  v cloudu dá jen simulovat.

## Odhad
Výkon Podzimního lesa (původně bod 3) z plánu vypadl, les zůstává tak, jak je.
Etapy A, C, D a F jsou střední až menší práce. B a hlavně E jsou nejnáročnější. Doporučené tempo je jedna etapa
najednou, v pořadí A → B → C → D → E → F. Pořadí se dá kdykoli změnit, třeba nové předměty (C) dřív než Wi-Fi (B).
