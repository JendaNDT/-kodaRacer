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
- **Mistrovství**: všech šest tratí za sebou se stejnými soupeři. Za 1.–6. místo dostaneš 10, 8, 6, 4, 2 a 1 bod. Po každém závodě uvidíš průběžné pořadí, kdo vede, startuje příště ze zadu. Na konci stojí tři nejlepší z celého mistrovství na stupních vítězů a hra si pamatuje tvůj nejlepší pohár pro každou obtížnost. Jde hrát sám, ve dvou na jednom počítači i po Wi-Fi (hostitel v lobby přepne na Mistrovství, další závod spouští on, až dojedou všichni hráči).
- **Časovka proti rekordu**: jedeš sám, bez soupeřů a otazníků, se třemi turby. Proti tobě jede průhledný duch tvé nejlepší jízdy na téhle trati a obtížnosti. Po každém kole uvidíš, o kolik jsi před ním (zeleně) nebo za ním (červeně), a když ho porazíš, stane se z tvé jízdy nový duch.
- **Bitva s balónky**: nezávodí se na kola, ale v aréně si navzájem praskáte balónky. Sám proti pěti počítačovým soupeřům, na počítači i ve dvou (rozdělená obrazovka) a po Wi-Fi (hostitel v lobby přepne na Bitva). Víc níže.
- **2 hráči na jednom počítači**: obrazovka se rozdělí na horní a dolní půlku.
- **Hra po Wi-Fi (crossplay)**: až 6 hráčů na stejné Wi-Fi, telefony i počítače dohromady. Volná místa doplní počítač.

## Jezdci a motokáry

Každý jezdec má vlastní motokáru. Liší se jen vzhledem, jízdní vlastnosti určuje jezdec. Při výběru se zvolená motokára otáčí na podstavci a jezdec ti zamává.

| Číslo | Jezdec | Motokára | Typ (jako v menu) |
| --- | --- | --- | --- |
| 1 | Turbo Tonda | formule s křídly | Vyvážený |
| 2 | Zuzka Zběsilá | zaoblená bublina | Hbitá |
| 3 | Pepa Plyn | dlouhý sporťák s velkým křídlem | Rychlík |
| 4 | Máňa Motor | buggy s velkými koly a rámem | Akcelerace |
| 5 | Karel Kolo | traktůrek s komínem | Tahoun |
| 6 | Bára Brzda | nízká futuristická střela | Zatáčky |
| 7 | Profesor Píst *(tajný)* | retro roadster z 30. let s chromovanou maskou | Tajný |

Profesor Píst je zamčený, dokud nevyhraješ zlatý pohár na Těžké. Pak je jezdců sedm a do závodu jich jede šest (počítač si vybírá i jeho).

Když jezdce řídí počítač, má každý svou povahu: **Turbo Tonda** jede vyrovnaně, **Zuzka Zběsilá** vráží do soupeřů a předměty použije hned, **Pepa Plyn** brzdí pozdě a na rovinkách je nejrychlejší, **Máňa Motor** má skoro vždy raketový start, **Karel Kolo** jezdí opatrně a předměty si šetří, **Bára Brzda** nejlíp driftuje. Počítač jezdí po ideální stopě (do zatáčky zvenku, vrchol u vnitřní strany, ven zase vně), v dlouhých zatáčkách driftuje pro turbo a předměty používá s rozmyslem: banán a olej si nechá jako ochranu, raketu pošle, až je soupeř blízko. Na Těžké skoro nedohání ani nečeká, výhra tam něco znamená.

## Sbírka a odměny

V hlavním menu je obrazovka **Sbírka**. Ukazuje poháry z mistrovství (bronz, stříbro, zlato) pro každou obtížnost a všechny odměny: co už máš a co je ještě zamčené, i s tím, jak to získat. Když odměnu získáš, ukáže se po závodě zlatý rámeček **ODEMČENO!** s fanfárou.

| Odměna | Jak ji získat |
| --- | --- |
| Druhý lak motokáry (pro každého jezdce zvlášť) | jakýkoli pohár v mistrovství s tímto jezdcem |
| Zlatý lak motokáry (pro každého jezdce zvlášť) | zlatý pohár na Těžké s tímto jezdcem |
| **Zrcadlové tratě** (všech šest otočených zrcadlově) | zlatý pohár na Střední nebo Těžké |
| **Tajný jezdec Profesor Píst** | zlatý pohár na Těžké |
| Bitevní lak motokáry (pro každého jezdce zvlášť) | vítězství v bitvě s balónky na Těžké s tímto jezdcem (platí i po Wi-Fi) |
| **Duch vývojáře** v časovce (zlatý průhledný soupeř) | časovka pod limitem na všech šesti tratích (limit je o 10 % pomalejší než duch, najdeš ho ve Sbírce) |

- **Lak** si vybereš pod jezdci při nastavení závodu i v lobby po Wi-Fi. Ostatní hráči tvůj lak uvidí.
- **Zrcadlové tratě** zapneš přepínačem *Tratě: Normální / Zrcadlové* u výběru trati. Platí pro závod, mistrovství i časovku a po Wi-Fi je zapíná hostitel. Rekordy a duchové se pro zrcadlové tratě ukládají zvlášť.
- **Tajného jezdce** vidí v lobby i hráči, kteří ho ještě nemají, ale vybrat si ho nemůžou.

## Bitva s balónky

V menu **Bitva s balónky** vybereš jezdce, lak, arénu a obtížnost. Na počítači můžete hrát i dva (rozdělená obrazovka). Po Wi-Fi přepne hostitel v lobby režim na **Bitva** a vybere arénu (víc v části Hra po Wi-Fi).

- Každý začíná se **3 balónky** nad motokárou v barvě jezdce.
- Balónek praskne, když tě zasáhne raketa, modrá raketa, banán nebo olej, když do tebe narazí soupeř s hvězdou, nebo když tě přejede soupeř, zatímco jsi zmenšený bleskem. Samotný blesk balónek nebere.
- Po zásahu máš aspoň **2 s ochranu**: balónky blikají a další zásah nic nebere, takže nepřijdeš o všechny naráz.
- Kdo přijde o poslední balónek, **vypadává**. Jeho kamera pak sleduje ostatní.
- Bitva končí, když zbyde jeden, nebo po **3 minutách**. Pak vyhraje, kdo má víc balónků; při rovnosti ten, kdo jich víc praskl ostatním. Pořadí ostatních je podle toho, kdo vypadl později.
- Předměty jsou stejné jako v závodě, jen častěji padají rakety a banány a méně turbo. Raketa letí k nejbližšímu soupeři před tebou, modrá raketa k tomu, kdo má nejvíc balónků.
- Vlevo nahoře máš své balónky, zbývající čas a seznam soupeřů s jejich balónky. Minimapa ukazuje arénu. Když někomu praskneš balónek, uvidíš „Trefa!“ a jeho jméno.

| Aréna | Co v ní je |
| --- | --- |
| **Náměstí** | čtvercové náměstí s kašnou uprostřed, čtyři květináče se stromy, nízké zídky a na okrajích čtyři rampy; kolem domy s radnicí |
| **Ledový stadion** | kulatý stadion, uprostřed kluzký led, kolem sněhové valy, za které se dá schovat, tři rampy u mantinelu; tribuny s diváky a sněžení |

## Tratě

| Trať | Nálada | Poznávací znamení |
| --- | --- | --- |
| Zelené údolí | slunečné odpoledne | větrný mlýn u jezera, dřevěný most přes trať, kopce do 8 m |
| Pouštní kaňon | západ slunce | skalní oblouk přes trať, nejvyšší kopce (až 11 m) |
| Ledová laguna | zataženo, sněží | iglú, svítící ledové krystaly, zamrzlé jezero |
| Podzimní les | zlaté podzimní ráno, padá listí | barevné stromy, dřevěná rozhledna s vlajkou, rybník |
| Noční město | noc, měsíc a hvězdy | domy s rozsvícenými okny, lampy se světlem na silnici, televizní věž, neonová brána přes trať |
| Sopečný ostrov | tropické poledne | palmy, pláže a moře kolem, kouřící sopka s lávovými proudy, lávové jezero |

**Zkratky:** každá trať má jednu zkratku přes vnitřek tratě. Před odbočkou stojí žlutá cedule ZKRATKA se šipkou a na minimapě je zkratka žlutě čárkovaná. Je zhruba o polovinu kratší než silnice, kterou přeskakuje, ale povrch zpomaluje: bez turba je o pár procent pomalejší. **S turbem nebo hvězdou se vyplatí.** Turbo je nejlepší pustit, až je motokára na zkratce srovnaná.

| Trať | Zkratka |
| --- | --- |
| Zelené údolí | hliněná cesta |
| Pouštní kaňon | písečná cesta |
| Ledová laguna | led přes okraj zamrzlého jezera, klouže |
| Podzimní les | lesní cesta |
| Noční město | štěrková cesta mezi domy, nejpomalejší povrch |
| Sopečný ostrov | písečná pláž obloukem kolem lávového jezera, ušetří nejméně |

Každá trať má kopce, sjezdy, klopené zatáčky a jeden skok: žlutočernou rampu za vrcholem kopce. Vzlétnout jde jen z rampy. Na hřebeni kopce zůstane motokára i s turbem nebo hvězdou na zemi a jen se zhoupne v pérování.

Na startu se při odpočtu rozsvěcuje semafor, u startovní rovinky fandí diváci na tribunách. Po závodě stojí první tři motokáry na stupních vítězů u startovní rovinky, létají konfety a pod nimi je výsledková tabulka.

## Ovládání

| | Jeden hráč | Hráč 1 (2 hráči) | Hráč 2 (2 hráči) |
| --- | --- | --- | --- |
| Zatáčení | ← → nebo A D | A D | ← → |
| Plyn | ↑ nebo W | W | ↑ |
| Brzda / couvání | ↓ nebo S | S | ↓ |
| Drift | mezerník nebo Shift | mezerník nebo levý Shift | pravý Shift nebo Num 0 |
| Předmět | X, E nebo Enter | E nebo Q | Enter |

Další klávesy: **Esc** pauza, **F11** celá obrazovka.

**V menu**: vybraná volba (režim, jezdec, trať, obtížnost) svítí zlatě. Když se po menu pohybuješ šipkami nebo ovladačem, kurzor je bílý blikající rámeček. Myší a dotykem se kurzor neukazuje.

**Herní ovladač**: A plyn, B brzda, RB/RT drift, LB/LT nebo X předmět, Start pauza. U dvou hráčů patří první ovladač hráči 1 a druhý hráči 2. Když je připojený jen jeden, ovládá hráče 2 a hráč 1 jede na klávesnici.

**Mobil**: plyn běží sám. Vlevo je volant (táhni palcem), vpravo **DRIFT**, **PŘEDMĚT** a **BRZDA**. Tlačítko Zpět hru pozastaví.

**Naklánění telefonu** (jen telefon se senzorem náklonu): v menu nebo v pauze přepni **Ovládání** z *volant* na *naklánění*. Zatáčíš pak jako volantem: nakloň telefon doprava (pravý okraj dolů) a motokára jede doprava. Volant vlevo zmizí, místo něj je tam malý volantík, který ukazuje, jak moc zatáčíš (při plném rejdu zezlátne). Tlačítka vpravo zůstávají.

- **Citlivost**: Jemná / Střední / Ostrá. Plný rejd je při náklonu asi 35° / 25° / 18°. Do 3° se nic neděje, aby motokára necukala.
- **Vyrovnání**: na konci odpočtu si hra zapamatuje, jak telefon držíš, a to bere jako „rovně“. Když si sedneš jinak, dej v pauze **Vyrovnat** a půl vteřiny drž telefon tak, jak chceš jezdit rovně.
- Telefon můžeš otočit na druhou stranu na šířku, směr řízení zůstane správný.

### Tipy

- **Drift**: v zatáčce drž drift a zatáčej. Jiskry se mění z modrých na oranžové a nakonec na fialové. Když drift pustíš, dostaneš turbo: čím dál jsi došel, tím delší. Modré jiskry (první turbo) naskočí zhruba po 0,7 s driftu, takže se drift vyplatí v každé delší zatáčce. Nejvíc času dá, když do zatáčky vjedeš od vnějšího okraje.
- **Raketový start**: šlápni na plyn, až se při odpočtu objeví „1“.
- **Trik**: když letíš z rampy, zmáčkni ve vzduchu drift. Motokára se otočí a po dopadu dostaneš turbo.
- **Otazníky**: čím víc jsi vzadu, tím lepší předmět dostaneš. Vepředu padají hlavně banány, olej a turbo, uprostřed štít, vzadu rakety, hvězda a modrá raketa. Předmět se losuje jako na hracím automatu: obrázky se protáčejí, zpomalí a vyhraný zacvakne.

| Předmět | Co dělá |
| --- | --- |
| Turbo (i 3×) | krátké zrychlení |
| Banán | položíš ho za sebe, kdo do něj najede, dostane smyk |
| Raketa | letí za soupeřem před tebou a vyhodí ho |
| Hvězda | 7 s nesmrtelnosti a vyšší rychlosti, srážkou shodíš soupeře |
| Modrá raketa | letí vysoko nad tratí až k vedoucímu a vybuchne nad ním; výbuch shodí i motokáry těsně u něj. Padá jen na posledních místech |
| Olej | položíš za sebe velkou louži, kdo do ní vjede, dostane dlouhý smyk. Po 20 s zaschne |
| Blesk | všichni ostatní se na 6 s zmenší, jsou pomalejší a dá se přes ně přejet. Chrání hvězda a štít. Velmi vzácný, jen pro poslední dva |
| Štít | bublina kolem motokáry na 10 s, pohltí jeden zásah (banán, olej, raketa, blesk) |

## Grafika, vibrace a výkon

V hlavním menu i v pauze jsou čtyři tlačítka:

- **Zvuk**: zapnout nebo vypnout.
- **Grafika**: Nízká / Střední / Vysoká. Telefon začíná na Střední, počítač na Vysoké. Když se hra na telefonu trhá, přepni na Nízkou.
  - **Nízká**: pod motokárami jen tmavé skvrny, bez záře, méně stromů, částic, stop smyku a diváků, vzdálené motokáry zjednodušené už od 10 m.
  - **Střední**: stíny od slunce, záře plamenů, jiskřiček a hvězdy, sněžení na Ledové laguně.
  - **Vysoká**: navíc měkčí a delší stíny, jemné stínování v rozích (SSAO), hustší sníh a detailní motokáry až do 32 m.
  - Na telefonu je vyhlazování hran (MSAA) vždy vypnuté, místo něj se 3D obraz kreslí ve vyšším rozlišení (Střední 85 %, Vysoká 100 % displeje). S vyhlazováním se na telefonech po prvním závodě rozbila grafika.
  - Barvy a nálada tratí jsou na všech kvalitách stejné: odpoledne v údolí, západ slunce v kaňonu, zatažená obloha na laguně.
  - Ostrost obrazu, vyhlazení hran, stíny a záře se změní hned. Hustota stromů a diváků, počet částic a stop smyku, sníh a zjednodušení vzdálených motokár se změní od dalšího závodu.
- **FPS**: ukáže dole uprostřed, kolik snímků za sekundu hra kreslí (60 = plynulé, pod 30 = trhání). Hodí se, když chceš napsat, jak hra běží.
- **Vibrace**: zapnuté / vypnuté (výchozí zapnuté). Telefon krátce zavibruje při nárazu do bariéry nebo soupeře (podle síly), při zásahu raketou, banánem, olejem nebo bleskem, při dopadu ze skoku (podle výšky), při turbu, když jiskry driftu změní barvu, a dvakrát v cíli. Na počítači to samé dělá herní ovladač, u dvou hráčů vibruje jen ovladač toho, koho se to týká. Vibrace nikdy nepřijdou častěji než 10× za vteřinu. Když telefon nevibruje, zkontroluj, jestli nemá vibrace vypnuté v nastavení nebo režim Nerušit.

## Hra po Wi-Fi

1. Všichni musí být připojení ke **stejné Wi-Fi**.
2. Jeden hráč dá **Hra po Wi-Fi → Založit hru**. Na obrazovce uvidí svou adresu, třeba `192.168.1.23`.
3. Ostatní dají **Hra po Wi-Fi** a hru buď uvidí v seznamu, nebo zadají adresu ručně.
4. Hostitel vybere režim **Jeden závod**, **Mistrovství** nebo **Bitva**, k tomu trať (u bitvy arénu) a obtížnost (a jestli jsou tratě zrcadlové, když je má odemčené) a spustí hru.

**Bitva po Wi-Fi**: celou bitvu počítá hostitel, tedy kdo koho zasáhl, kolik má kdo balónků, kdo vypadl, čas i konec. Ostatní dostávají jeho výsledek, takže všichni vidí stejné balónky, stejná prasknutí i stejného vítěze. Volná místa doplní počítač. Když hráč uprostřed bitvy odejde, jeho motokáru převezme počítač; pokud už neměl žádný balónek, zůstane mimo hru. Po bitvě hostitel všechny vrátí do lobby tlačítkem **Zpět do lobby**.

Svou motokáru máš pod kontrolou okamžitě, i když je Wi-Fi pomalejší: tvoje zařízení ji počítá samo a hostitel ji jen průběžně neznatelně dorovnává. Srážky, předměty, zásahy, pořadí a cíl dál rozhoduje hostitel, takže po zásahu raketou nebo po banánu se motokára může kousek přesunout.

Všichni musí mít **stejnou verzi hry** (je napsaná dole v hlavním menu). Hra s jinou verzí se v seznamu ukáže jako „jiná verze hry“ a připojení se odmítne s vysvětlením.

Na Windows se při prvním založení hry objeví dotaz brány firewall. Povol přístup pro **soukromé sítě**, jinak se ostatní nepřipojí. Hra používá porty UDP 24680 a 24681.

## Složky

- `godot/` – hra v Godotu (skripty v `godot/scripts/`, nastavení exportu v `godot/export_presets.cfg`)
- `godot/ghosts/` – nahrané jízdy ducha vývojáře pro časovku (vyrobí je `--devghosts`)
- `web/` – původní webový prototyp (`web/index.html`), dá se otevřít v prohlížeči
- `build/debug.keystore` – testovací podpisový klíč pro APK (heslo `android`). Pro Google Play je potřeba vlastní tajný klíč.
- `.github/workflows/build.yml` – automatické testy a sestavení APK + EXE

## Licence přibalených souborů

- Hudba „Škoda Racer – Menu“ a „Škoda Racer – Závod“: dodal autor hry Jenda pro tuto hru (`godot/music/`)
- Písma Bungee a Barlow Semi Condensed: SIL Open Font License (`godot/fonts/`, `web/fonts/`)
- Three.js r128 (jen webový prototyp): MIT (`web/vendor/three-LICENSE.txt`)
