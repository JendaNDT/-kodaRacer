# Škoda Racer – plán vylepšení grafiky
*Sestaveno: 05. 10. 2026 · Godot 4.7.1, renderer Compatibility*

Cíl: aby hra vypadala „hotově“ (světlo, stíny, efekty, detailní motokáry, živé okolí) a přitom plynule běžela i na slabším telefonu.

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

**Rozhodnutí:** zůstáváme na rendereru Compatibility pro PC i mobil. Hra pak vypadá všude stejně a já ji umím testovat tady. Výkonnější renderer Forward+ pro PC (měkčí stíny, odlesky) je volitelný bonus na konec.

---

## Fáze 0 – Nastavení kvality, FPS a kontrola verze  *(malá, nutný základ)* ✅ hotovo (verze 1.1.0)

> **Výsledek:** kvalita Nízká/Střední/Vysoká v menu i pauze (`gfx.gd`), počítadlo FPS, kontrola verze při připojení (vestavěné ověření Godotu) a verze v seznamu her, měření `--bench`. Na softwarovém vykreslování v cloudu: Nízká 19,6 FPS, Střední 8,0 FPS, Vysoká 7,7 FPS. Na telefonu s grafickým čipem budou čísla jiná, poměr ale ukazuje, že přepínač pomáhá.

Aby hezčí grafika nezabila slabé telefony.

- **Kvalita grafiky Nízká / Střední / Vysoká.** Volí se v menu i v pauze, hra si ji pamatuje.
  - Výchozí: telefon **Střední**, PC **Vysoká**.
  - Jedno místo v kódu (`gfx.gd`) určuje, co každá úroveň zapíná: stíny, MSAA, rozlišení 3D, záře, SSAO, počet částic, hustota stromů a počasí.
- **Počítadlo FPS** (zapne se v menu). Díky němu mi můžeš napsat, jak plynule to na telefonu jede.
- **Kontrola verze při připojení přes Wi-Fi.** Když má každý jinou verzi hry, místo podivného chování se ukáže hláška „Hostitel má jinou verzi hry“.
- **Měření výkonu (`--bench`):** porovnání úrovní kvality mezi sebou. Absolutní čísla z cloudu neodpovídají telefonu, ale rozdíly ano.

**Hotovo, když:** přepínání kvality viditelně mění scénu, FPS se zobrazuje a testy procházejí.

---

## Fáze 1 – Světlo a atmosféra  *(střední, největší „wow“)*

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

## Fáze 2 – Efekty při jízdě („šťáva“)  *(střední)*

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

## Fáze 4 – Živější svět kolem trati  *(velká)*

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
| 0 Kvalita + FPS + verze | malá | bezpečnost výkonu, základ |
| 1 Světlo a atmosféra | střední | největší vizuální skok |
| 2 Efekty při jízdě | střední | pocit rychlosti, zábava |
| 3 Motokáry a jezdci ✅ | velká | charakter postav |
| 4 Svět kolem trati | velká | živé prostředí |
| 5 Menu a výsledky | střední | dojem z celé hry |
| 6 Kopce a skoky | největší | nová hratelnost |

Doporučené tempo: **0 + 1 dohromady**, potom vždy jedna fáze. Po každé fázi společně zkontrolujeme výkon na telefonu.
