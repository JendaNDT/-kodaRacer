# Škoda Racer — kompletní plán webové verze

**Autor projektu:** Jan Svatoš  
**Datum plánu:** 27. října 2026  
**Stav:** návrh připravený k realizaci; jednotlivé etapy zatím nejsou implementované  
**Cíl:** otevřít odkaz, načíst hru a hrát v prohlížeči na počítači, telefonu nebo tabletu.

## 1. Výsledná podoba

Webová verze bude vycházet ze současného projektu v Godotu. Zachová jeho tratě, motokáry, fyziku, předměty, hudbu i herní režimy. Doplníme sestavení pro prohlížeč, přizpůsobení zařízení a nový způsob síťového spojení.

Navržená hlavní adresa je **https://jenda.cool/skoda-racer/**. Jde o plánovanou adresu; tímto dokumentem se hra nezveřejňuje.

Hráč uvidí načítání, stiskne **Hrát** a pokračuje do známého menu. Na telefonu bude mít dotykové ovládání, na počítači klávesnici nebo připojený ovladač. Nabídka se přizpůsobí skutečně dostupným možnostem zařízení. Rozšíření o hraní bez internetu přijde po ověření základní verze. Online hra nabídne místnosti s kódem a pozvánkou.

Podporu budeme deklarovat podle reálných testů. Cílem jsou současné prohlížeče na Windows, macOS, Linuxu, Androidu a iOS/iPadOS. Staré telefony, televizory, konzole a prohlížeče uvnitř jiných aplikací nemají předem zaručenou podporu. Zařízení bez potřebné grafické podpory dostane srozumitelné vysvětlení.

## 2. Z čeho plán vychází

Kontrola zahrnovala zdrojové soubory hry, nastavení exportu, automatické sestavení, poslední vydání a konfiguraci webu JendaWeb. Šlo o čtení kódu a dokumentace; v této fázi se hra nesestavovala ani neměřila v prohlížeči.

| Ověřená oblast | Zjištění | Důsledek pro realizaci |
| --- | --- | --- |
| Poslední vydání | `testovaci-build` ukazuje na `870ba46e85eb0ae5fad1875bee585dd55752e7e9`; projekt má verzi 1.19.1 | Výchozím bodem bude tato verze na větvi `main`, po novém ověření při zahájení |
| Výchozí větev repozitáře | `ccr-05c4e7fe-qo3pmx`, commit `c3880dd…`, je proti `main` o 38 commitů pozadu | Při pokračování nespoléhat na automaticky zvolenou výchozí větev |
| Engine | Projekt a sestavení uvádějí Godot 4.7.1, GDScript a grafický režim Compatibility | Ověřit odpovídající editor i webové exportní šablony; začít se stejnou verzí |
| Současné exporty | Android a Windows | Doplnit samostatný export Web a jeho automatické sestavení |
| Obsah | Šest základních tratí, zrcadlené varianty, mistrovství, časovka s duchem, sbírka odměn a dvě arény pro bitvu | Převod ověřovat na celé vydané hře, včetně odemykaného obsahu |
| Soupeři | `Track.prepare_line()` používá `WorkerThreadPool`; `line_now()` obsahuje čekací smyčku | Pro web bez vláken připravit jízdní stopy před sestavením; nezablokovat stránku čekáním |
| Zvuk | Vlastní skladby `menu.ogg` a `race.ogg`; efekty vznikají při startu, motor používá `AudioStreamGenerator` | Zachovat skladby, pro web upravit spouštění a generování zvuku |
| Ukládání | `user://settings.cfg` a vlastní soubory duchů | Zajistit trvalé uložení v prohlížeči a zachování dat při aktualizacích |
| Síťová hra | ENet, UDP vyhledávání na Wi-Fi, hostitel počítá závod, klient předpovídá svůj pohyb | Web potřebuje jiný přenos; zachovat herní pravidla a předpovídání pohybu |
| Mobilní grafika | MSAA je vypnuté kvůli dřívějšímu mizení 3D obrazu po prvním závodě | Tuto opravu zachovat i při detekci mobilního prohlížeče |
| Web jenda.cool | JendaWeb obsahuje `vercel.json`, vlastní sestavení webu a kořenový `sw.js`; už má oddělenou cestu pro Lost Signal | Přidat cestu hry, předávání souborů a výjimku z cache hlavního webu |

Původní `web/index.html` je starší samostatný prototyp. Při realizaci ho označíme jako historický, aby se nezaměňoval s novou webovou verzí současné hry.

## 3. Zvolený technický směr

### Společný základ hry

Jeden projekt Godotu bude obsluhovat Windows, Android a Web. Rozdíly soustředíme do malé vrstvy pro zjištění možností zařízení a spolupráci s prohlížečem. Nové pomocné soubory uvedené v plánu jsou navržené názvy, nikoli už existující části projektu.

Pro první webovou verzi zvolíme **export bez více vláken**. Godot pro Web používá WebAssembly a WebGL 2.0; běžný jednovláknový export má menší požadavky na nastavení hostingu. Tato volba vyžaduje vyřešit současný výpočet jízdní stopy soupeřů. Vícevláknový export zůstane případným pozdějším výkonovým experimentem, bude-li pro něj doložený přínos. [D1]

### Online hra

Navržený přenos závodu je **WebRTC**. Ve hře zůstane jeden hostitel, který rozhoduje o průběhu závodu, a ostatní budou klienti. Přenos rychle se měnícího stavu oddělíme od spolehlivých zpráv lobby a výsledků. Pro založení a propojení místnosti poslouží malá služba přes zabezpečený WebSocket, označovaný WSS. WebRTC je v Godotu pro web dostupné přímo; nativní Windows a Android potřebují odpovídající doplněk. [D2, D3]

Pro spojení přes různé internetové přípojky počítáme se STUN a **TURN**: TURN přenese data v situaci, kdy přímé propojení zařízení neprojde. Přenos musí být odzkoušený i s vynuceným TURN, aby funkčnost nestála jen na příznivé domácí Wi-Fi. WebSocket doporučujeme pro správu místností; u rychlé závodní hry nebudeme jeho použití jako jediného herního přenosu považovat za automaticky rovnocenné. [D2, D3]

Před dokončením síťové části musí projít malý ověřovací projekt: web ↔ web a web ↔ nativní klient s přesnou verzí Godotu. Pokud nebude dostupný spolehlivý doplněk pro některou stávající architekturu, zaznamenáme konkrétní překážku a porovnáme sestavení doplňku s variantou samostatného herního serveru. Ta by znamenala další oddělení simulace od grafiky; nemá být skrytým předpokladem tohoto plánu.

První online vydání má jednoho hostitele bez automatického předávání jeho role. Hostitel musí během hry udržet stránku aktivní. Při jeho odchodu nebo dlouhém přerušení se spojení ukončí s vysvětlením. Samostatný trvale běžící autoritativní herní server je samostatné budoucí rozšíření, pokud budeme chtít odstranit tuto závislost na hostiteli.

## 4. Milníky a pořadí

| Milník | Etapy | Výsledek |
| --- | --- | --- |
| M0 — první ověřitelný převod | W00–W04 | Skutečná současná hra jde spustit v prohlížeči a ovládat na počítači i mobilu |
| M1 — kompletní hra na jednom zařízení | W05–W09, po M0 | Všechny místní režimy, ukládání, výkon, offline obsah a stabilní adresa na webu |
| M2 — online hra v prohlížeči | W10–W12 | Místnosti pro až šest hráčů, závod, mistrovství i bitva, ověřené výpadky |
| M3 — společné hraní a finální vydání | W13–W14 | Aktualizované Windows a Android se připojí do stejných online místností; závěrečné ověření |

Základní návaznost je W00 → W01 → W02 → W03 → W04 → W05 → W06 → W07 → W08 → W09 → W10 → W11 → W12 → W13 → W14. Předběžné ověření dostupnosti WebRTC doplňku patří už do W00. Základ automatických kontrol založíme ve W01 a rozšiřujeme v dalších etapách; W09 dokončuje vydávání a publikaci.

Každá etapa přinese samostatnou změnu v Gitu, stručný zápis výsledků a uvedení zbývajících problémů. Při dokončení etapy nabídneme další nejvhodnější krok. Etapu označíme jako hotovou až po splnění jejích uvedených podmínek.

## 5. Jednotlivé etapy

### W00 — pevný výchozí bod a měření současné hry

**Účel:** navázat na skutečně vydanou hru a zachovat její dosavadní vlastnosti.

- Znovu načíst stav větve `main`, posledního vydání a případných otevřených změn. Při novější verzi aktualizovat tento plán podle rozdílů.
- Založit pracovní větev, například `codex/web-version`, z ověřeného commitu. Zapsat celý commit a číslo enginu do pracovního záznamu.
- Ověřit dostupnost editoru 4.7.1 i odpovídajících webových šablon. Verzi enginu měnit jen z konkrétního zjištěného důvodu.
- Spustit existující kontroly závodu, mistrovství, časovky, odměn, skoků, zkratek, soupeřů, předmětů, naklánění, vibrací, hudby a bitvy; síťové kontroly podle současného workflow.
- Zaznamenat známé chyby výchozí verze a oddělit je od pozdějších regresí převodu.
- Připravit stejné zkušební scény a nastavení pro porovnání výkonu: menu, závod na Podzimním lese a Nočním městě, bitva a přechod do další tratě.
- Předběžně ověřit WebRTC doplněk pro Windows x86_64 a Android arm64 i armeabi-v7a v přesné používané verzi Godotu. Samotný nález knihovny není doklad funkčního propojení.

**Hotovo, když:** známe správnou verzi, výchozí kontroly a omezení; máme pracovní větev a seznam dostupných cílových zařízení. Nevznikne další sestavení omylem ze staré výchozí větve.

### W01 — první Web export a rozhraní pro možnosti zařízení

**Soubory:** `project.godot`, `export_presets.cfg`, `game.gd`, `main.gd`, `menu.gd`; nové `platform_caps.gd`, `web_bridge.gd` a složka `godot/web/`.

- Přidat export `Web`, jednovláknovou šablonu a první českou spouštěcí stránku. Zachovat zahrnutí `ghosts/*.dat` i potřebných hudebních souborů a fontů.
- Rozlišit „běží v prohlížeči“, „má dotyk“, „má ovladač“, „je dostupné trvalé ukládání“ a „umí celou obrazovku“. Velikost displeje nebude jediným ukazatelem telefonu.
- Zachytit neúspěšný start, nepodporovanou grafiku a chybějící herní soubor. Zobrazit českou chybu s možností zkusit načtení znovu.
- Při prvním převodu použít konzervativní grafiku a potřebné dočasné přepínače pro dosud nepřipravené subsystémy. Výjimky budou zapsané a odstraněné v následujících etapách.
- Zabránit volání UDP a ENet z webové nabídky. Do dokončení online části bude nabídka síťové hry srozumitelně označená jako připravovaná.
- Doplnit sestavení webového artefaktu bez jeho automatického zveřejnění a první kontrolu spuštění v opravdovém prohlížeči.

**Hotovo, když:** export načte herní menu a 3D scénu bez pádu; při nepodporovaném prostředí stránka vysvětlí problém. Toto je technický prototyp, ještě ne vydání pro hráče.

### W02 — soupeři a načítání bez blokování stránky

**Soubory:** `track.gd`, `race.gd`, `main.gd`, případně stavitelé prostředí; nový nástroj pro předvýpočet a datová složka jízdních stop.

- Doplnit nástroj, který ze stejných definic tratí a stejného algoritmu předem vytvoří ideální jízdní stopy a jejich křivost.
- Pro web načítat předpočítaná data; zachovat číselné výsledky současného algoritmu. Zahrnout běžné i zrcadlené varianty, nebo doložit přesnou transformaci mezi nimi.
- Soubor propojit s kontrolním součtem definice tratě a verzí algoritmu. Při změně tratě musí sestavení rozpoznat zastaralá data a znovu je vytvořit.
- Vyřadit z webové cesty `WorkerThreadPool.add_task()` a čekací smyčku v `line_now()`. Dočasná středová stopa nemá tiše zůstat konečným řešením slabších soupeřů.
- Změřit tvorbu terénu, motokár a prostředí. Dlouhé práce rozdělit mezi snímky s postupem načítání; předpočítávat jen tam, kde měření doloží přínos.
- Kontrolovat opuštění načítání a zrušení rozpracované scény. Zahájení závodu nesmí ponechat dva aktivní světy.

**Hotovo, když:** projdou kontroly soupeřů a tratí, nejsou nutná vlákna a příprava závodu nezablokuje ovládání celé stránky. Chybějící předvýpočet se zjistí při sestavení.

### W03 — hudba, efekty a motorový zvuk

**Soubory:** `sfx.gd`, `project.godot`, spouštěcí stránka; nová webová zvuková data podle měření.

- Zachovat obě Jendovy skladby, smyčku, přechod menu → závod, pauzu a zrychlení hudby na konci závodu či bitvy.
- Zvuk spustit po vědomém stisku tlačítka **Hrát**. Ověřit obnovu po návratu do stránky, zamčení telefonu i přerušení jiným zvukem. [D1]
- Pro první webové vydání nahradit generování motoru za běhu předem připravenou plynulou smyčkou či několika smyčkami. Otáčky řídit výškou tónu a hlasitostí podle stejného vstupu jako dosud.
- Krátké syntetizované efekty vytvořit při sestavení a přibalit; ověřit všechny klíče `Sfx.play()`, aby nechyběl některý nový předmět.
- Změřit latenci a paměť pro hudbu i efekty. Zvolit webový způsob přehrávání podle výsledku, nikoli hromadným přepnutím všech zvuků na náročnější režim.
- Udržet samostatné motory pro rozdělenou obrazovku, ztlumení a bezpečný návrat bez dvojí hudby.

**Hotovo, když:** hrají obě skladby, všechny efekty a oba lokální motory; po přerušení jde zvuk obnovit. Dvě desítky změn menu/závod nevytvářejí další zvukové přehrávače bez uvolnění.

### W04 — ovládání a chování prohlížeče

**Soubory:** `game.gd`, `touch_controls.gd`, `hud.gd`, `menu.gd`, `main.gd`, `tilt.gd`, `haptics.gd`, webová vrstva.

- Zprovoznit současnou klávesnici, dotykové ovládání a herní ovladače včetně připojení až po startu stránky. Přidat ruční volbu dotykových tlačítek pro neobvyklá zařízení.
- Na herní ploše zabránit nechtěnému posouvání a zvětšování stránky při řízení. Běžné prvky menu, zadávání jména a připojovacího kódu musí zůstat použitelné.
- Podporovat současné stisky zatáčení, driftu, předmětu a brzdy. Po zrušeném dotyku, odpojení ovladače nebo ztrátě zaměření vyčistit celý stav vstupů.
- Přidat tlačítko pro celou obrazovku. Klávesu F11, Esc a tlačítko Zpět přizpůsobit možnostem prohlížeče; zachovat jeho bezpečnostní omezení.
- Rozvržení přepočítat při rotaci, změně velikosti, vysunutí mobilní lišty a otevření klávesnice. Ošetřit výřezy displeje a bezpečné okraje; na výšku nabídnout otočení zařízení.
- Naklánění napojit přes webové události pohybu/orientace do současného vyhlazování a kalibrace. Oprávnění vyžádat tlačítkem, pokud ho prohlížeč potřebuje; při odmítnutí nebo absenci dat zůstane volant. Ověřit oba směry otočení na šířku. [D4, D5]
- Vibrace a vibrace ovladače nabídnout podle skutečné podpory. Nepodporované vibrace nesmějí bránit hraní. [D6]
- Sólo při skrytí stránky pozastavit a obnovit až vědomým pokračováním; po návratu nepřepočítávat dlouhý výpadek jako jeden herní krok.

**Hotovo, když:** celý závod lze dohrát na klávesnici, dotykem a dostupným ovladačem. Změna orientace, odmítnutý senzor ani návrat ze zamčeného telefonu nezanechají zaseklé řízení. Tím končí M0.

### W05 — uložený postup, rekordy a duchové

**Soubory:** `game.gd`, webová spouštěcí vrstva; nový modul pro stav ukládání a zálohy.

- Zajistit, aby se persistentní úložiště připravilo před načtením nastavení a aby se zápisy dokončovaly průběžně, zejména po výsledku závodu. Nespoléhat na poslední zápis při zavření karty.
- Určit stabilní vlastní prostor dat Škoda Racer. Jeho identita nesmí záviset na adresáři konkrétního vydání ani sdílet názvy s Lost Signal či jinou aplikací na jenda.cool. Chování ověřit v reálně použitém exportovaném runtime.
- Zachovat jméno, zvolenou postavu, grafiku, zvuk, odměny, laky, poháry, rekordy, běžné i zrcadlené časovky a soubory duchů.
- Kontrolovat výsledek zápisu, zaplněné úložiště a nedostupné trvalé uložení. Hra může pokračovat v paměti, ale upozorní, že postup nelze spolehlivě zachovat. Data prohlížeče nejsou náhradou zálohy. [D7]
- Verzi dat ukládat odděleně od verze hry. Před migrací uchovat předchozí použitelná data a ověřit obnovu při chybě.
- Přidat **Export postupu** a **Import postupu** přes běžný výběr souboru. Použít omezený validovaný formát se schématem; neprovádět kód ani nenačítat libovolné objekty ze souboru.
- Zamezit přepsání postupu současně otevřenými kartami; druhá karta dostane zřejmou volbu, jak pokračovat.

**Hotovo, když:** rekord, odemčená odměna a duch zůstanou po zavření, znovuotevření a přechodu na nové webové vydání. Selhání zápisu a neplatný import nesmažou platný postup. Export/import skutečně obnoví zkušební uloženou hru.

### W06 — grafika, plynulost a spotřeba paměti

**Soubory:** `gfx.gd`, `race.gd`, `atmosphere.gd`, `kart_stage.gd`, `world_builder.gd`, `arena_world.gd`, `trackside.gd`, efekty a webová vrstva.

- Zavést webové výchozí hodnoty a ruční úrovně Nízká/Střední/Vysoká. Na mobilním webu zachovat vypnuté MSAA v závodě i náhledech motokár.
- Omezit vnitřní 3D rozlišení podle výkonu; neodvozovat ho bez omezení od vysoké hustoty pixelů displeje. Text a ovládání musí zůstat čitelné.
- Prověřit podporu používaných shaderů, průhlednosti, stínů, záře a dalších efektů v cílových prohlížečích. Neúčinné či nepodporované efekty přiznat a nabídnout přiměřený vzhled.
- Změřit menu s živým závodem, rotující náhled i souběh více 3D pohledů. Na slabém zařízení omezit náročnost menu podle zjištění.
- Postupně ladit hustotu okolí, diváky, částice, vzdálené modely, stíny a přebytečné pohledy. Herní kolize a pravidla se nesmějí měnit s grafickou kvalitou.
- Při přechodech hlídat uvolňování světů, náhledů, částic a zvuků. Ošetřit ztrátu grafického kontextu s nabídkou bezpečného obnovení.
- Zaznamenat čas prvního stažení, čas zahřátého startu, FPS, dobu snímku a vývoj paměti. Výsledky vždy spojit se zařízením, prohlížečem, tratí a kvalitou.

**Hotovo, když:** jsou splněné cíle měření v oddílu 7 nebo je zdokumentováno konkrétní omezení zařízení a odpovídající doporučená kvalita. Po prvním závodě nezmizí grafika a opakované přechody neukazují rostoucí únik paměti.


### W07 — úplnost všech místních režimů

**Účel:** ověřit obsah současné hry po převodu, nejen jeden ukázkový závod.

- Projít všech šest tratí, zkratky, skoky a zrcadlené varianty; stejné počítání kol a pořadí.
- Dokončit mistrovství od prvního závodu po konečné stupně vítězů. Ověřit body, restart aktuálního závodu a přechody mezi tratěmi.
- Projet časovku, uložit lepšího ducha a v dalším běhu ho zobrazit; prověřit i odměnu a ducha autora.
- Odehrát obě bitevní arény na všech obtížnostech; eliminaci, sledování soupeřů, konec času a výsledky.
- Prověřit všechny předměty, ochrany, odemčené postavy, laky a sbírku.
- Zprovoznit dva hráče na jednom počítači. Na mobilu zůstane standardem jeden lokální hráč; dva hráči jsou cílem pro dostatečně velký displej s klávesnicí/ovladači.
- Upravit tlačítko Konec na webově smysluplný návrat. Menu, výsledky a texty nemají vybízet k operaci, kterou prohlížeč neumí.

**Hotovo, když:** existuje zápis úspěšných scénářů pro všechny režimy a projdou stávající věcné kontroly. Převod nevynechává obsah vydání 1.19.1.

### W08 — hraní bez internetu a bezpečné aktualizace

**Soubory:** webový manifest, ikony, spouštěcí stránka, service worker hry; později výjimka v `JendaWeb/sw.js`.

- Přidat možnost **Připravit pro hraní bez internetu**, viditelný průběh a potvrzení až po kompletním uložení všech požadovaných souborů.
- Offline ověřit všechny místní režimy, obě skladby, fonty a data duchů. Online místnosti budou při chybějícím připojení jasně nedostupné.
- Doplnit přidání na plochu tam, kde je podporované. Samotné přidání ikony nebude zaměňované s dokončeným stažením obsahu.
- Použít vlastní rozsah service workeru `/skoda-racer/` a vlastní názvy cache. Zabraňovat zásahům do ostatních aplikací téhož webu.
- Každé vydání držet jako soudržný celek: HTML/JS, WebAssembly a herní balík musí patřit k téže verzi. Rozpracovaný update nesmí nahradit funkční offline kopii.
- Aktualizaci nabídnout v menu po dokončení závodu. Žádné nucené znovunačtení uprostřed jízdy nebo online místnosti.
- Ověřit přerušené stahování, plné úložiště, novou verzi ve druhé kartě a opětovný start po chybě aktualizace. [D7, D8]

**Hotovo, když:** potvrzeně připravená hra jde znovu spustit bez internetu a dohrát; vadné či přerušené nové vydání nepoškodí předchozí dostupnou verzi ani postup.

### W09 — automatické sestavení, web a první vydání

**Soubory hry:** `.github/workflows/build.yml` nebo oddělená workflow, nástroje balení, soupis verzí a kontrolních součtů.  
**Soubory webu:** `JendaWeb/vercel.json`, `sw.js`, `build_site.cjs` a odpovídající záznam aplikace v katalogu.

- Sestavovat Windows, Android a Web z téhož ověřeného zdroje. Ukládat samostatné artefakty a identifikaci commitu, enginu, dat a protokolu.
- Přidat kontroly webové stránky v opravdovém prohlížeči: načtení, zvuk po stisku, dohraný závod, ukládání a opakovaný start. Text „soubor existuje“ nestačí.
- Automatické publikování omezit na určenou vydávací větev nebo tag. Současný krok maže a znovu vytváří `testovaci-build`; pracovní větev nesmí přepsat veřejné vydání.
- Doplnit stabilní spouštěcí cestu `/skoda-racer/` a samostatné adresáře neměnných souborů jednotlivých verzí. Před přepnutím hlavní adresy ověřit úplnost nové verze.
- V `vercel.json` nastavit odpovídající typy souborů a cache. U případné předkomprimované WebAssembly ověřit `Content-Encoding`, typ `application/wasm` a chování bez dvojí komprese. Chybějící herní soubor nesmí vrátit HTML hlavního webu.
- Zajistit, aby `build_site.cjs` zahrnul nové soubory do výstupu. Do `sw.js` hlavního webu doplnit výjimku pro `/skoda-racer` a celý podadresář, stejně důsledně jako pro ostatní oddělené aplikace.
- Nejprve zveřejnit testovací cestu a ověřit start z čistého prohlížeče i z již nainstalovaného portfolia. Potom přepnout cílovou adresu a přidat tlačítko **Hrát v prohlížeči** vedle stažení APK/EXE.
- Připravit návrat na předchozí vydání a ověřit zachování uloženého postupu. Poznamenat případnou nevratnou změnu formátu dat ještě před vydáním.

**Hotovo, když:** je dosažen M1 — kompletní místní hra funguje na cílové adrese; projdou kontrolní scénáře nového i vracejícího se hráče, instalované ikony, offline obsahu a návratu předchozí verze.

### W10 — ověření internetového spojení a místností

**Nové části:** například `net_transport.gd`, `net_webrtc.gd`, `room_client.gd` a složka `server/` pro propojovací službu. Současný ENet se oddělí do vlastní implementace.

- Dokončit malý WebRTC prototyp ve stejné verzi Godotu. Prokázat spolehlivé i průběžné zprávy, přiřazení hostitele a kompatibilitu používaných vzdálených volání.
- Navrhnout jednoduchou službu: založit místnost, připojit se kódem/odkazem, předat nabídku spojení, odpověď a ICE informace, opustit místnost a odstranit neaktivní místnost.
- Použít zabezpečenou propojovací službu WSS. Výsledný hosting pro ni musí podporovat potřebné dlouhotrvající spojení; statický web a tato služba jsou dvě různé části provozu.
- Připravit STUN a TURN, dočasné přihlašovací údaje pro TURN a potřebné varianty přenosu pro omezené sítě. Dlouhodobá serverová tajemství nepřibalovat do hry.
- Prokázat spojení na stejné Wi-Fi, přes dvě různé přípojky a s vynuceným relé TURN. Změřit přenos dat, dobu připojení a zpoždění.
- Zvolit provozní řešení až podle naměřené zátěže a ověřené aktuální ceny. Oddělit spotřebu statických souborů, propojovací služby a případně výraznější datový přenos přes TURN.

**Hotovo, když:** dva webové klienty lze propojit na odlišných sítích a vynuceně přes TURN. Protokol, závislosti a provozní návrh jsou zapsané. Bez tohoto výsledku se plné online režimy neoznačí za funkční.

### W11 — lobby a všechny online režimy

**Soubory:** `net.gd`, nové přenosové moduly, `menu.gd`, `main.gd`, `race.gd`, případně `battle.gd`.

- Přidat **Online hra → Založit místnost / Připojit se**. Pozvánka předvyplní místnost, jméno zůstane místní volbou. Limit je šest hráčů; volná místa doplní počítač.
- Oddělit volbu přenosu od herních pravidel. Nativní nabídka může dále používat původní režim Wi-Fi; web používá online místnosti.
- Zachovat kontrolu verze, doplnit explicitní verzi síťového protokolu a identitu herních dat. Grafická kvalita nesmí být důvodem nekompatibility.
- Zavést potvrzení připravenosti po načtení tratě. Hostitel nespustí odpočet pouze podle toho, že sám už má prostředí připravené.
- Zachovat předpovídání klientovy motokáry, potvrzování vstupů a plynulé dorovnávání. Rozhodování o předmětech, kolech, bodech a cíli zůstane hostiteli.
- Ověřit rozdělení zpráv na spolehlivé události a průběžný stav; definovat jejich kanály, pořadí, omezenou velikost a zacházení se starými zprávami.
- Dokončit jeden závod, celé mistrovství, zrcadlené tratě a obě bitvy. Ověřit výsledky, přidělení odměn, návrat do lobby a další hru bez nového načtení stránky.

**Hotovo, když:** nejprve dva a pak šest webových klientů dokončí společné scénáře; všichni mají shodné pořadí, body a výsledky bitvy. Pomalé načtení jednoho hráče nezpůsobí nesynchronní start.

### W12 — výpadky, latence a veřejný provoz

- V lobby odmítnout chybný nebo prošlý kód, plnou místnost a nekompatibilní verzi s českým vysvětlením.
- U odchozího klienta zachovat převzetí počítačem. Návrat po dlouhém výpadku v první verzi znamená návrat do lobby po skončení rozehrané hry; neslibuje se obnovení vlastního sedadla uprostřed závodu.
- Při odchodu nebo dlouhém uspání hostitele ukončit relaci po definovaném limitu a vrátit ostatní bezpečně do nabídky. Prohlížeč může skrytou stránku omezit; není to vlastnost, kterou lze obejít pouhým přepínačem hry. [D1]
- Pro krátký výpadek nastavit omezený čas čekání; po obnovení provést synchronizaci, po vypršení časového limitu jednoznačně ukončit staré spojení.
- Změřit latenci, rozptyl zpoždění, ztráty zpráv, objem dat a délku front. Zahazovat zastaralý průběžný stav; nepřenášet nekonečnou historii po obnovení spojení.
- Omezit veřejnou službu: počet místností a účastníků, počet požadavků, velikosti zpráv, životnost místnosti a pokusy o kód. Ověřovat příslušnost odesílatele a oprávnění měnit lobby.
- V herních zprávách kontrolovat typy, rozsahy, délky polí, platné odesílatele a číslování. Zpracování neplatného vstupu nesmí shodit hostitele. Hostitelský model sám o sobě nezaručuje férovost vůči podvádějícímu hostiteli.
- Provozní záznamy omezit na spojení, chyby a nutné metriky; připravit obnovu služby po restartu a stručný postup řešení výpadku.

**Hotovo, když:** jsou dokončené síťové scénáře v oddílu 7, nikdo nezůstává neomezeně ve stavu připojování a restart propojovací služby nezpůsobí pád hry. Tím končí M2.

### W13 — společné hraní Web + Android + Windows

**Soubory:** přenosové moduly, nativní WebRTC doplněk, `export_presets.cfg`, automatické sestavení a nativní nabídky.

- Zahrnout ověřený doplněk pro Windows x86_64 a obě současné architektury Androidu. Pokud některá architektura vyžaduje vlastní sestavení, připravit ho reprodukovatelně; podporu neodstraňovat potichu.
- Pro webový export vyloučit nepotřebné nativní knihovny. Nativní balíčky musejí mít správnou architekturu, verzi a potřebná oprávnění.
- Nabídnout v nových APK/EXE stejné online místnosti. Staré instalace založené pouze na ENet se do nich samy připojit neumějí; hráč bude potřebovat odpovídající novou verzi.
- Původní hraní na Wi-Fi a jeho vyhledávání ověřit jako samostatný regresní scénář.
- V každé kombinaci vyzkoušet založení místnosti i připojení: Web ↔ Web, Web ↔ Android, Web ↔ Windows a smíšená skupina až šesti zařízení.
- Prověřit rozdíly nativního a webového pohybu, zvuku, časování, ukládání odměn a odpojení hostitele.

**Hotovo, když:** smíšená skupina dohraje závod, mistrovství a bitvu; nové nativní verze zachovají původní místní a Wi-Fi režimy. Dostupnost doplňku je prokázaná testem, ne pouze úspěšným exportem.

### W14 — finální ověření, vydání a předání

- Dokončit matici zařízení a prohlížečů; rozlišit skutečně ověřené kombinace a neověřené cíle.
- Zopakovat paměťový test, přechody mezi režimy, aktualizaci z M1 na finální verzi a zachování postupu.
- Z čistého zařízení ověřit celý postup: otevření odkazu → načtení → ovládání → závod → uložený výsledek → nový start. Dále offline start a připojení do místnosti.
- Vydat vzájemně kompatibilní Web/APK/EXE s identifikací zdrojového commitu a popisem změn. Hotové soubory a webová adresa musejí odpovídat stejnému vydání.
- Doplnit český návod pro hraní, přidání na plochu, offline obsah, zálohu postupu a založení místnosti.
- Zapsat skutečně naměřené provozní náklady, dostupné limity, verze služeb a postup návratu. Nezaručovat neomezený online provoz podle malé zkoušky.
- Uzavřít seznam změn, nevyřešených chyb a doporučeného dalšího kroku. Kritická chyba znamená návrat do odpovídající etapy, nikoli označení celého projektu za hotový.

**Hotovo, když:** je dosažen M3 a jsou splněné společné podmínky vydání v oddílu 8.

## 6. Přehled zásahů do projektu

| Oblast | Stávající části | Plánovaný zásah |
| --- | --- | --- |
| Spuštění a export | `godot/project.godot`, `godot/export_presets.cfg` | Webový export a nastavení platformy |
| Možnosti zařízení | `game.gd`, `main.gd` | Nový adaptér schopností a webová propojení |
| Načítání soupeřů | `track.gd`, `race.gd` | Předvýpočet stopy, kontrola platnosti, zrušení čekání na vlákno |
| Hudba a motor | `sfx.gd`, `godot/music/` | Spuštění po stisku, předem připravené efekty a smyčka motoru pro web |
| Vstupy | `game.gd`, `touch_controls.gd`, `tilt.gd`, `haptics.gd`, `hud.gd` | Dotyk v prohlížeči, oprávnění senzorů, reset vstupů, volitelné vibrace |
| Menu a životní cyklus | `menu.gd`, `main.gd`, `race.gd` | Webové volby, pauza, rotace, návrat do aktivní stránky |
| Grafika | `gfx.gd`, `atmosphere.gd`, `kart_stage.gd`, stavitelé světa a efekty | Webové úrovně kvality a opravy podle měření |
| Postup | `game.gd`, soubory duchů | Trvalé ukládání, vlastní prostor dat, migrace a záloha |
| Spojení | `net.gd`, `menu.gd`, `race.gd` | Oddělené ENet/WebRTC přenosy, místnosti a synchronizace startu |
| Webové soubory | Nová `godot/web/` a výstup sestavení | Spouštěcí stránka, manifest, worker a offline aktualizace |
| Propojovací služba | Nová `server/` a provozní konfigurace | WSS signalizace, přidělení místností, krátkodobé TURN údaje |
| Ověření a vydávání | `.github/workflows/build.yml`, nové nástroje a scénáře pro prohlížeč | Export tří platforem, věcné kontroly, omezené zveřejňování |
| Web jenda.cool | `JendaWeb/vercel.json`, `sw.js`, `build_site.cjs`, katalog aplikací | Cesta hry, komprese, cache, příslušné soubory ve výstupu, tlačítko Hrát |
| Dokumentace | Nové `docs/PLAN_WEB.md`, `docs/WEB_TESTY.md`, `docs/WEB_PROVOZ.md` | Plán, výsledky testů, provoz a pokračování práce |

## 7. Ověření a měřitelné cíle

Následující čísla jsou **navržené cíle**, nikoli dnešní naměřené výsledky. Po W00–W02 doplníme referenční měření. Cíl lze změnit jen s uvedeným důvodem a výsledkem, aby se nízký výkon pouze nepřejmenoval na úspěch.

### Výkon a stabilita

| Zkouška | Navržená podmínka |
| --- | --- |
| MacBook Air M4, jeden hráč | Cíl 60 FPS při rozumné kvalitě; orientačně 95 % snímků do 25 ms mimo načítání |
| Samsung S24 Ultra a Lenovo IdeaTab | Minimum pro podporovanou kvalitu: průměr alespoň 30 FPS a 95 % snímků do 50 ms ve zvolené srovnávací jízdě; cíl 60 FPS tam, kde je to dosažitelné |
| První spuštění | Zaznamenat velikost přenosu a čas při definované rychlosti sítě; předběžný cíl ovladatelné menu do 15 s při 50 Mbit/s. Po prvním exportu cíl potvrdit nebo doložit nutnou optimalizaci |
| Zahřátý start | Předběžný cíl ovladatelné menu do 5 s na referenčním počítači; mobilní výsledky zaznamenat zvlášť |
| Dlouhé načítání | Viditelný postup, žádné neomezené čekání, možnost bezpečného zotavení při selhání |
| Opakované hraní | Alespoň 20 cyklů menu → závod → výsledky → menu, plus celé mistrovství; bez černého 3D obrazu a trvalého růstu počtu živých objektů či paměti po zahřátí cache |
| Delší mobilní hraní | Alespoň 30 minut; zaznamenat případný pokles výkonu při zahřívání a funkčnost dotyku/zvuku |

Měření snímků musí vycházet ze skutečného času. Výpis FPS v menu nestačí. U testů vždy uvést scénu, kvalitu, počet hráčů, verzi prohlížeče a zda byl připojený diagnostický nástroj. Paměť měřit dostupnými prostředky každého prohlížeče, bez předpokladu jedné univerzální přesné hodnoty.

### Zařízení a prohlížeče

| Kombinace | Co ověřit |
| --- | --- |
| MacBook Air M4: Safari a Chrome, doplňkově Firefox | Hraní, zvuk, ukládání, celá obrazovka, dva hráči a online spojení |
| Samsung S24 Ultra: Chrome a Samsung Internet | Vícedotyk, rotace, zvuk, senzory, návrat ze zamčení, výkon |
| Lenovo IdeaTab: Chrome | Vícedotyk, větší obrazovka, případná klávesnice/ovladač, senzory podle skutečné dostupnosti, výkon |
| Windows: Edge a Chrome, doplňkově Firefox | Hraní, rozdělená obrazovka, ovladače a online spojení |
| Linux: Chrome/Chromium a Firefox | Základní závod, ukládání, zvuk a online připojení |
| iPhone a iPad: Safari na dostupných fyzických zařízeních | Dotyk, senzorová oprávnění, zvuk po přerušení, offline start a paměť; simulace mobilního rozměru ani desktopový WebKit tento test nenahrazují |

Chybějící fyzické zařízení nezablokuje ověření ostatních systémů. V přehledu ale zůstane označené jako neověřené; jeho podporu veřejně nepotvrdíme jen podle emulace.

### Scénáře webu a dat

1. Čisté načtení bez cache a následný start s cache.
2. Chybějící WebAssembly, herní balík nebo zvuk; přerušené stahování a opakování.
3. Uložení výsledku, zavření stránky a znovunačtení po dokončení zápisu; samostatně rychlé zavření a kontrola zotavení.
4. Aktualizace hry se starým postupem; úspěšná migrace, neplatná data a návrat předchozího vydání.
5. Zakázané či plné úložiště, soukromé okno, dvě karty, import neplatné zálohy.
6. Vlastní offline kopie hry i návštěva z již nainstalovaného hlavního webu; žádná záměna HTML a herních souborů.
7. Otáčení displeje, systémová klávesnice, ztráta dotyku, odpojený ovladač a odmítnutý senzor.
8. Všechny místní režimy včetně odemčeného obsahu a opakovaných přechodů.

### Scénáře online hry

1. Dva hráči na stejné Wi-Fi, dva na různých přípojkách a zvlášť vynucený TURN.
2. Dva, tři a šest hráčů; různé prohlížeče a následně smíšená nativní skupina.
3. Jeden závod, celé mistrovství a obě bitevní arény; shodné výsledky u všech.
4. Pomalu načítající klient, odmítnutá verze, plná místnost, chybný/prošlý kód.
5. Zpoždění odpovídající 120 ms každým směrem a kolísání 20 ms jako návaznost na současné testy; navíc ztráty paketů na úrovni skutečné testovací sítě. Záznam falešného zpoždění uvnitř hry se nesmí vydávat za test všech vlastností sítě.
6. Změřit chybu předpovědi na stejném scénáři před a po převodu. Předběžný cíl 95. percentil do 1 m při popsaném zpoždění; porovnávat stavy stejného potvrzeného kroku.
7. Odchod klienta, odchod hostitele, skrytí stránky, ztráta internetu, restart propojovací služby a vypršení TURN údajů.
8. Připojení cizího/neplatného odesílatele, nadměrná zpráva a neplatná herní hodnota; bez pádu hostitele a bez změny oprávnění.

Automatizace pokryje opakovatelné herní scénáře a kontroly v prohlížeči. Zvuk, kvalita dotykového řízení, zahřívání a část omezení iOS vyžadují ověření na skutečném zařízení. Při realizaci nejdříve provedeme vlastní dostupné kontroly a Jendovi předáme konkrétní krátký seznam zbývajících zkoušek na jeho zařízeních.

## 8. Společné podmínky vydání

- Žádná nevyřešená chyba, která brání startu, dohrání podporovaného režimu, správnému výsledku nebo ohrožuje platný uložený postup.
- Přesně známý zdrojový commit a vzájemně odpovídající soubory webového vydání.
- Ověřené místní režimy a všechny online režimy, které dané vydání nabízí.
- Srozumitelné chování při nepodporovaném prohlížeči, nefunkčním ukládání a neúspěšném připojení.
- Ověřená aktualizace, zachování postupu a návrat na předchozí použitelnou verzi.
- Přehled skutečně otestovaných zařízení a známých omezení.
- Pro online vydání běžící propojovací služba, funkční TURN a zapsané provozní limity i náklady.
- Nové APK a EXE prošly příslušnými dosavadními kontrolami; místní režimy zůstanou použitelné i bez dostupné online služby.

## 9. Náklady, hranice a rozhodnutí před další prací

Místní webová hra potřebuje hosting souborů; při hraní na jednom zařízení nemusí běžet herní server. Online místnosti přidají propojovací službu a TURN, který může tvořit hlavní datovou položku. Cenový odhad připravíme podle vybraného provozního řešení, počtu současně připojených hráčů a změřené spotřeby. Předem zde není tvrzený konkrétní měsíční poplatek ani neomezený bezplatný provoz.

Pro první úplné vydání navrhujeme hraní bez uživatelského účtu, místní postup se zálohou, soukromé místnosti s pozvánkou a až šest závodníků. Globální žebříčky, chat, veřejné vyhledávání soupeřů, synchronizace postupu mezi zařízeními, automatická migrace hostitele, diváci a velký dedikovaný herní server nejsou podmínkou tohoto převodu. Mohou později dostat vlastní plán.

Největší nejistoty k ověření jsou skutečný mobilní výkon v prohlížeči, délka načítání procedurálně stavěného světa, chování zvuku v Safari, stabilita uložených dat přes aktualizaci a kompatibilita nativního WebRTC doplňku. V plánu mají samostatné kroky a měřitelné výstupy.

Odhad času pro celý projekt by před prvním exportem a síťovým prototypem nebyl podložený. Po W02 lze zpřesnit zbývající práci pro M1; po W10 pro M2 a M3. Nejnáročnější očekávanou částí je síťová hra a ověření napříč systémy.

## 10. Jak navázat při realizaci

1. Otevřít tento plán a znovu ověřit aktuální `main` a poslední vydání.
2. Začít **W00**, potom bez změny cíle pokračovat W01 a W02 k prvnímu spustitelnému webovému převodu.
3. Do `docs/WEB_TESTY.md` zapisovat commit, ověřený scénář, výsledek a případná omezení. Záznam má obsahovat jen doložené výsledky.
4. Po každé etapě uvést: co hráč nově může, co bylo ověřeno, co ještě brání dalšímu milníku a jaký je další nejvhodnější krok.
5. Milník M1 lze zpřístupnit pro běžné hraní, zatímco síťové etapy pokračují. Úplnost online části se vyhodnotí samostatně.

## 11. Zdroje a ověřené podklady

### Projektové podklady

- [Zdrojový stav posledního vydání Škoda Racer](https://github.com/JendaNDT/-kodaRacer/tree/870ba46e85eb0ae5fad1875bee585dd55752e7e9).
- [Nastavení projektu 1.19.1](https://github.com/JendaNDT/-kodaRacer/blob/870ba46e85eb0ae5fad1875bee585dd55752e7e9/godot/project.godot).
- [Exportní nastavení](https://github.com/JendaNDT/-kodaRacer/blob/870ba46e85eb0ae5fad1875bee585dd55752e7e9/godot/export_presets.cfg).
- [Výpočet tratě a jízdní stopy](https://github.com/JendaNDT/-kodaRacer/blob/870ba46e85eb0ae5fad1875bee585dd55752e7e9/godot/scripts/track.gd).
- [Hudba, zvukové efekty a motor](https://github.com/JendaNDT/-kodaRacer/blob/870ba46e85eb0ae5fad1875bee585dd55752e7e9/godot/scripts/sfx.gd).
- [Nastavení, ovládání a ukládání](https://github.com/JendaNDT/-kodaRacer/blob/870ba46e85eb0ae5fad1875bee585dd55752e7e9/godot/scripts/game.gd).
- [Současná síťová hra](https://github.com/JendaNDT/-kodaRacer/blob/870ba46e85eb0ae5fad1875bee585dd55752e7e9/godot/scripts/net.gd).
- [Současné automatické kontroly a sestavení](https://github.com/JendaNDT/-kodaRacer/blob/870ba46e85eb0ae5fad1875bee585dd55752e7e9/.github/workflows/build.yml).
- [Vydání pro Android a Windows](https://github.com/JendaNDT/-kodaRacer/releases/tag/testovaci-build).
- [Konfigurace hostingu JendaWeb](https://github.com/JendaNDT/JendaWeb/blob/main/vercel.json) a [service worker hlavního webu](https://github.com/JendaNDT/JendaWeb/blob/main/sw.js); ověřené při přípravě plánu, před úpravou znovu načíst aktuální verzi.

### Dokumentace použitá při návrhu

- **D1:** [Godot — Exporting for the Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html): požadavky exportu, vlákna, zvuk, omezení prohlížeče.
- **D2:** [Godot — WebRTC](https://docs.godotengine.org/en/stable/tutorials/networking/webrtc.html) a [WebRTCMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_webrtcmultiplayerpeer.html): propojení klientů a rozdíly webové/nativní implementace.
- **D3:** [Godot — Using WebSockets](https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html): vhodnost a omezení WebSocket přenosu.
- **D4:** [MDN — DeviceOrientationEvent.requestPermission](https://developer.mozilla.org/en-US/docs/Web/API/DeviceOrientationEvent/requestPermission_static): dostupnost a vyžádání oprávnění po stisku.
- **D5:** [Godot — Input](https://docs.godotengine.org/en/latest/classes/class_input.html) a [MDN — Detecting device orientation](https://developer.mozilla.org/en-US/docs/Web/API/Device_orientation_events/Detecting_device_orientation): nativní čtení senzoru a webové události. Podpisy a chování API při realizaci ověřit proti přesně používané verzi enginu.
- **D6:** [MDN — Vibration API](https://developer.mozilla.org/en-US/docs/Web/API/Vibration_API): vibrace jako možnost závislá na prohlížeči.
- **D7:** [MDN — Storage quotas and eviction criteria](https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria): limity a životnost uložených dat.
- **D8:** [MDN — Using Service Workers](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API/Using_Service_Workers): rozsah, ukládání souborů a aktualizace offline obsahu.

Dokumentace popisuje obecné možnosti. Konkrétní návrhy etap, architektura, cílové hodnoty a pořadí jsou návrhem pro tento projekt a vyžadují uvedené ověření.
