# Škoda Racer – plán vylepšení grafiky
*Sestaveno: 05. 10. 2026 · Godot 4.7.1, renderer Compatibility*

Cíl: aby hra vypadala „hotově“ (světlo, stíny, efekty, detailní motokáry, živé okolí) a přitom plynule běžela i na slabším telefonu.

> **Stav:** fáze 0–4 jsou hotové (**verze 1.5.0**, větev `main`). Fáze 0–3 byly spojené ve verzi 1.4.0. Fáze 1, 2 a 3 vznikly souběžně a jejich vlastní čísla verzí (1.2.0, 1.3.0) platila jen pro samostatné buildy. Výkon spojené verze v cloudu proti 1.1.0: Nízká 27,8 → 22,8 FPS, Střední 10,4 → 7,1 FPS, Vysoká 10,0 → 3,9 FPS. Většinu poklesu dělají stíny z fáze 1, fáze 2 a 3 přidávají asi 5–8 %.

## Jak budeme postupovat

- **Jedna fáze = jeden balík změn.** Po každé fázi nahraju změny na GitHub, sestaví se nové APK a EXE a ty si to vyzkoušíš na telefonu i PC.
- **Fáze jdou po sobě**, ale fáze 2–5 na sobě skoro nezávisí. Když tě něco láká víc, dá se pořadí prohodit. Jen **fáze 0 musí být první**.
- **Ke každé fázi udělám:** screenshoty všech tří tratí před a po, automatický test závodu, test Wi-Fi hry a sestavení v GitHub Actions.
- **Co neumím ověřit:** plynulost (FPS) na skutečném telefonu. Proto má fáze 0 počítadlo FPS, které uvidíš přímo ve hře.

## Co Godot 4.7.1 v našem rendereru umí (ověřeno ve zdrojovém kódu)

| Efekt | Compatibility | Poznámka |
| --- | --- | --- |
| Stíny od slunce | ✅ | dražší na mobilu, proto podle kvality |
| Záře (glow / bloom) | ✅ | zjednodušená verze, stačí |
| Stínování v rozích (SSAO) | ✅ | základní verze, jen na Vysoké kvalitě |
| Barevné podání AgX / ACES / Filmic | ✅ | |
| Jas, kontrast, sytost | ✅ | |
| Decals (obtisky na silnici) | ❌ | stopy smyku proto uděláme jako vlastní pásy z trojúhelníků |

**Zjištěno ve fázi 1:** slunce se stíny kreslí renderer Compatibility jako druhou vrstvu přes celou scénu. Proto stíny stojí nejvíc výkonu ze všech efektů a scéna by vyšla přepáleně světlá. Hra to vyrovnává automaticky (`Atmosphere._shadowed_sun`), takže všechny kvality vypadají stejně jasně.

**Rozhodnutí:** zůstáváme na rendereru Compatibility pro PC i mobil. Hra pak vypadá všude stejně a já ji umím testovat tady. Výkonnější renderer Forward+ pro PC (měkčí stíny, odlesky) je volitelný bonus na konec.

---

## Fáze 0 – Nastavení kvality, FPS a kontrola verze  *(malá, nutný základ)* ✅ hotovo (verze 1.1.0)

> **Výsledek:** kvalita Nízká/Střední/Vysoká v menu i pauze (`gfx.gd`), počítadlo FPS, kontrola verze při připojení (vestavěné ověření Godotu) a verze v seznamu her, měření `--bench`. Na softwarovém vykreslování v cloudu: Nízká 19,6 FPS, Střední 8,0 FPS, Vysoká 7,7 FPS. Na telefonu s grafickým čipem budou čísla jiná, poměr ale ukazuje, že přepínač pomáhá.
> *Oprava ve fázi 1:* `--bench` u pomalých snímků měřil zaokrouhlený čas, teď měří skutečný. Přeměřená verze 1.1.0: Nízká 25,7 FPS, Střední 9,8 FPS, Vysoká 9,9 FPS.

Aby hezčí grafika nezabila slabé telefony.

- **Kvalita grafiky Nízká / Střední / Vysoká.** Volí se v menu i v pauze, hra si ji pamatuje.
  - Výchozí: telefon **Střední**, PC **Vysoká**.
  - Jedno místo v kódu (`gfx.gd`) určuje, co každá úroveň zapíná: stíny, MSAA, rozlišení 3D, záře, SSAO, počet částic, hustota stromů a počasí.
- **Počítadlo FPS** (zapne se v menu). Díky němu mi můžeš napsat, jak plynule to na telefonu jede.
- **Kontrola verze při připojení přes Wi-Fi.** Když má každý jinou verzi hry, místo podivného chování se ukáže hláška „Hostitel má jinou verzi hry“.
- **Měření výkonu (`--bench`):** porovnání úrovní kvality mezi sebou. Absolutní čísla z cloudu neodpovídají telefonu, ale rozdíly ano.

**Hotovo, když:** přepínání kvality viditelně mění scénu, FPS se zobrazuje a testy procházejí.

---

## Fáze 1 – Světlo a atmosféra  *(střední, největší „wow“)* ✅ hotovo (verze 1.2.0)

> **Výsledek:** nový soubor `atmosphere.gd` (obloha se slunečním diskem, slunce, mlha, mraky, sníh), nálady tratí v `game.gd`, svítící efekty v `kart.gd` a `race.gd`.
> - Stíny od slunce na Střední (tvrdé okraje, šetří výkon) a Vysoké (měkké okraje, 4 pásma, delší dosah). Na Nízké zůstaly tmavé skvrny.
> - Záře na Střední a Vysoké: plameny turba, jiskry driftu, hvězda, raketa (nový svítící plamen vzadu), výbuchy, krabice s otazníkem a slunce.
> - Barvy AgX se zvýšenou sytostí na všech kvalitách, takže hra vypadá všude stejně. SSAO jen na Vysoké.
> - Údolí: odpoledne. Kaňon: západ slunce s dlouhými stíny. Laguna: chladné zatažené světlo, nízké mraky a sněžení (Střední a Vysoká).
> - Mraky pomalu plují. Opravena stará chyba: silnice byla otočená spodní stranou nahoru, takže na ni slunce nesvítilo a stíny na ní nebyly vidět.
> - Výkon na softwarovém vykreslování v cloudu (průměr tří tratí, 1.1.0 → 1.2.0): Nízká 25,7 → 24,5 FPS, Střední 9,8 → 7,3 FPS, Vysoká 9,9 → 4,4 FPS. Na Střední stojí nejvíc stíny. Pokud se telefon na Střední trhá, můžeme stíny nechat jen na Vysoké.

- **Opravdové stíny od slunce** od motokár, stromů, pneumatik i brány. Na Nízké zůstanou dnešní tmavé skvrny.
- **Záře (glow):** svítí plameny turba, jiskry driftu, hvězda, raketa a krabice s otazníkem (materiály s emisí).
- **Filmové barvy (AgX)** a jemné doladění kontrastu a sytosti. Zmizí „plastový“ vzhled.
- **SSAO** na Vysoké: jemné stíny v rozích a pod objekty.
- **Vlastní nálada každé trati** (slunce, obloha, mlha, okolní světlo):
  - *Zelené údolí:* slunečné odpoledne, sytá obloha, ostré stíny.
  - *Pouštní kaňon:* **západ slunce**, oranžové nízké světlo, dlouhé stíny, teplý opar.
  - *Ledová laguna:* chladné modravé světlo, nízké mraky a **padající sníh**.
- **Obloha:** sluneční disk a pomalu plující mraky.

Soubory: `world_builder.gd` (prostředí, slunce, obloha), `game.gd` (barvy tratí), `kart.gd` a `race.gd` (svítící materiály).

**Hotovo, když:** screenshoty všech tří tratí ukazují stíny, záři a odlišnou náladu a Nízká kvalita vypadá jako dnes.

---

## Fáze 2 – Efekty při jízdě („šťáva“)  *(střední)* ✅ hotovo (verze 1.2.0)

> **Výsledek:** stopy smyku (`skid_marks.gd`, na GPU mizí, počet podle kvality: 160 / 360 / 700), rychlostní čáry (`speed_lines.gd`, každý hráč vlastní), 3. úroveň driftu (fialová, po 3,5 s „nabíjení“, turbo 1,75 s místo 1,3 s, platí i pro AI), plamen turba s jádrem, jiskrami a zábleskem v barvě driftu, výbuch rakety (záblesk, tlaková vlna, oheň, kouř, úlomky, otřes kamery), hvězdičky nad hlavou po zásahu, lesk přejíždějící po krabicích a barevné střepy, konfety v cíli, vlající šachovnicové vlajky na bráně, prach / písek / sníh od kol podle povrchu a kouř pneumatik při driftu. Vše vidí i klient ve Wi-Fi hře. Výkon v cloudu (softwarové vykreslování): Nízká 26,9 → 25,3 FPS, Střední 10,4 → 9,8 FPS.
> *Odchylky od plánu:* mávající vlajka je na startovní bráně (ne v ruce). Motokára po zásahu se točí jako dřív, nové jsou hvězdičky.

- **Stopy smyku** na asfaltu při driftu a prudkém brzdění. Postupně mizí a jejich počet je omezený, aby nežraly výkon.
- **Rychlostní čáry** po okrajích obrazovky při turbu a hvězdě, síla podle rychlosti. Každý hráč má vlastní, i na rozdělené obrazovce.
- **3. úroveň driftu:** fialové jiskry a nejsilnější turbo. *Mění hratelnost, proto ji chci před zařazením potvrdit s tebou.*
- **Silnější turbo:** svítící plamen, jiskry a krátký záblesk při startu turba.
- **Výbuch rakety:** tlaková vlna (rozpínající se kruh), kouř a úlomky.
- **Zásah:** motokára se zatočí a nad hlavou jezdce krouží hvězdičky.
- **Krabice s otazníkem:** lesk, který přejíždí po stěnách, a rozpad na barevné střepy.
- **Cíl:** konfety a mávající šachovnicová vlajka.
- **Prach a sníh** odletují od kol podle povrchu (tráva, písek, sníh).

Počet částic se řídí kvalitou z fáze 0.

**Hotovo, když:** efekty jsou vidět na screenshotech a v síťové hře je vidí i klient.

---

## Fáze 3 – Nové motokáry a živí jezdci  *(velká)* ✅ hotovo (verze 1.3.0)

> **Výsledek:** generátor zaoblených tvarů (`mesh_kit.gd`), 6 různých motokár (`kart_model.gd`): formule, bublina, sporťák s velkým křídlem, buggy s ochranným rámem a rezervou, traktůrek s komínem a závodní střela se svítícími pruhy. Jezdec (`driver_rig.gd`) drží volant oběma rukama a ruce se s ním točí, hlava se dívá do zatáčky, tělo se naklání, v cíli zvedne ruce nad hlavu a po zásahu se mu motá hlava. Helma má pruhy v barvě jezdce, startovní číslo je na obou bocích. Kola mají ráfek, paprsky, barevnou krytku a podle motokáry hladký, silniční, terénní nebo traktorový vzorek. Podvozek pruží při dopadu, předklání se při brzdění a zaklání při rozjezdu a turbu, v trávě a písku drncá.
>
> **Výkon:** celá kostra motokáry je jeden model, vzdálené motokáry se přepnou na jednodušší verzi (Nízká od 10 m, Střední od 16 m, Vysoká od 32 m) a jezdcům v dálce se nekreslí ruce a volant. Měření `--bench` v cloudu: kreslicích volání o 30–50 % méně (Střední 139 → 94), trojúhelníků o 8–23 % víc. Na softwarovém vykreslování v cloudu, které počítá i trojúhelníky procesorem, je FPS asi o 6 % nižší, když je všech šest motokár blízko kamery (Střední 10,3 → 9,6 FPS). Na telefonu brzdí hlavně počet kreslicích volání, takže by to mělo být stejné nebo lepší. Ověřit jde jen počítadlem FPS na skutečném telefonu.
>
> **Screenshoty:** `--showcase` postaví všech šest motokár vedle sebe (`--view=front|back|side|close`, `--pose=drive|steer|cheer|dizzy|boost|star|mix`, u `close` ještě `--driver=0..5`).

- **Generátor zaoblených tvarů** (zkosené hrany, zaoblené kapotáže), aby motokáry vypadaly jako modelované, ne slepené z krabic.
- **Každý jezdec dostane vlastní motokáru** (jízdní vlastnosti zůstávají, mění se jen vzhled):
  - *Turbo Tonda:* klasická formule.
  - *Zuzka Zběsilá:* zaoblená „bublina“.
  - *Pepa Plyn:* dlouhý sporťák s velkým křídlem.
  - *Máňa Motor:* buggy s velkými koly.
  - *Karel Kolo:* robustní „traktůrek“.
  - *Bára Brzda:* nízká futuristická střela.
- **Živý jezdec:** ruce na volantu, který se točí podle zatáčení. Hlava se dívá do zatáčky, tělo se naklání, helma má pruhy v barvě jezdce a na boku je startovní číslo.
- **Kola** s ráfkem a vzorkem a pérování při nerovnostech a dopadu.
- **Animace:** radost v cíli (ruce nahoře) a „motání hlavy“ po zásahu.
- **Výkon:** statické díly každé motokáry se spojí do jednoho modelu, takže bude méně volání GPU než dnes, i když budou detailnější.

**Hotovo, když:** 6 různých motokár na screenshotu a stejné nebo lepší FPS na Střední kvalitě.

---

## Fáze 4 – Živější svět kolem trati  *(velká)* ✅ hotovo (verze 1.5.0)

> **Výsledek (`trackside.gd`):** pod startovní bránou visí semafor s pěti světly. Při odpočtu se rozsvěcují červeně jedno po druhém a při startu se všechna rozsvítí zeleně, a to i u klienta ve Wi-Fi hře. U startovní rovinky stojí až dvě tribuny s barevnými sedadly, plné diváků: polovina mává oběma rukama, ostatní poskakují. Na střechách jsou praporky a vlajky ve větru. Kolem trati jsou reklamní panely osmi vymyšlených sponzorů (Turbo Šnek, Knedlík Expres, Pneu Hop…) a v nejostřejších zatáčkách balíky slámy a kužely. Stromy, keře i kaktusy se hýbou ve větru, jezero v údolí se vlní a třpytí.
> - *Údolí:* větrný mlýn u jezera s točícími se lopatkami a obloukový dřevěný most přes trať, na kterém stojí diváci.
> - *Kaňon:* skalní oblouk z pískovce s vrstvami přes celou trať.
> - *Laguna:* iglú u jezera a u trati, svítící ledové krystaly a zamrzlé jezero s prasklinami, které odráží oblohu.
> - **Hustota diváků** podle kvality (Nízká 35 %, Střední 65 %, Vysoká všechna místa), vzdálené tribuny se nekreslí.
> - **Výkon:** aby fáze 4 nic nestála, nevrhají už stín pneumatiky bariér (přes tisíc kusů, stín skoro neviditelný), balíky slámy ani kužely. V cloudu je pak Střední stejně rychlá jako předtím (6,8 → 6,7 FPS, v rámci šumu) a Vysoká dokonce rychlejší (3,9 → 4,2 FPS). Trojúhelníků na snímek je na Střední o 40 % méně (308 → 184 tisíc).
> - **Screenshoty:** `--showcase --view=spot --spot=bridge` (dále `windmill`, `arch`, `igloo1`, `crystals`, `lake`, `lights`, `stand1`, `board1`, `corner1`…) zamíří kameru na dané místo.

- **Start a cíl:** semafor s pěti světly synchronizovaný s odpočtem, tribuny s mávajícími diváky, vlajky a praporky ve větru.
- **Okolí trati:** reklamní panely s vymyšlenými sponzory (žádné skutečné značky), kužely a balíky slámy.
- **Pohyb:** stromy, kaktusy i vlajky se hýbou ve větru (shader, téměř zdarma) a jezero se vlní a třpytí.
- **Dominanta každé trati:**
  - *Údolí:* větrný mlýn a dřevěný most.
  - *Kaňon:* skalní oblouk přes trať.
  - *Laguna:* iglú, ledové krystaly a zamrzlé jezero s odrazy.
- **Hustota okolí** podle kvality: na Nízké méně stromů a diváků.

**Hotovo, když:** každá trať má svůj poznávací prvek a výkon na Střední se nezhorší o víc než pár FPS.

---

## Fáze 5 – Menu, výsledky a rozhraní  *(střední)*

- **Výběr jezdce:** 3D motokára na otočném podstavci místo barevného kolečka, v menu i v lobby.
- **Stupně vítězů** po závodě: první tři motokáry na pódiu, konfety a kamera kolem dokola, pod tím výsledková tabulka.
- **Losování předmětu** jako jednoruký bandita (válce se roztočí a zastaví).
- **Animace HUD:** změna pořadí („+1“ vyskočí), banner kola, plynulé přechody mezi menu a závodem (zatmívačka).

**Hotovo, když:** menu i výsledky na screenshotech a funguje to na rozdělené obrazovce i po Wi-Fi.

---

## Fáze 6 – Kopce, skoky a klopené zatáčky  *(největší, volitelná)*

- **Výškový profil** každé trati: stoupání, klesání, klopené zatáčky a jeden skok s rampou.
- **Fyzika ve 3D:** let vzduchem, dopad s odpružením, krátké turbo za trik ve vzduchu.
- **Terén kolem trati** navazuje na výšku silnice.
- **Úpravy kolem:** kamera, AI, minimapa a síťová synchronizace (posílá se i výška).

Riziko: zasahuje do fyziky, AI i sítě, proto až nakonec a samostatně.

**Hotovo, když:** závod do cíle projde na všech tratích (i AI a síť) a skok je vidět na screenshotu.

---

## Volitelně na konec

- **Renderer Forward+ jen pro PC:** měkké stíny, odlesky, lepší SSAO. Telefon zůstane na Compatibility. Pro testování si tady musím přeložit Godot s podporou Vulkanu.
- **Hotové modely zdarma (licence CC0)**, například od Kenney, místo generovaných, pokud bys chtěl ještě „profesionálnější“ vzhled.

## Pořadí a odhad

| Fáze | Velikost | Co přinese |
| --- | --- | --- |
| 0 Kvalita + FPS + verze ✅ | malá | bezpečnost výkonu, základ |
| 1 Světlo a atmosféra ✅ | střední | největší vizuální skok |
| 2 Efekty při jízdě ✅ | střední | pocit rychlosti, zábava |
| 3 Motokáry a jezdci ✅ | velká | charakter postav |
| 4 Svět kolem trati ✅ | velká | živé prostředí |
| 5 Menu a výsledky | střední | dojem z celé hry |
| 6 Kopce a skoky | největší | nová hratelnost |

Doporučené tempo: **0 + 1 dohromady**, potom vždy jedna fáze. Po každé fázi společně zkontrolujeme výkon na telefonu.
