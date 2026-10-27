# Webová verze — provozní záznam

## Výchozí stav W00

Pracovní větev `codex/web-version` vychází z vydané hry 1.19.1 na `main`. Výchozí větev repozitáře zůstává starší `ccr-05c4e7fe-qo3pmx`; pro další práci používat výslovně pracovní větev nebo `main`.

Automatický krok přepisující veřejný `testovaci-build` je omezen podmínkou `github.ref == 'refs/heads/main'`. Sestavení z pracovní větve může projít kontrolami, ale nesmí smazat ani přepsat veřejné APK a EXE.

W00 nevytvořilo webový export hry, webovou adresu ani propojovací službu.

## První export W01

Samostatné workflow `.github/workflows/web.yml` sestavuje skutečnou hru pro Web bez více vláken, ověřuje její start v Chromium a ukládá artefakt `SkodaRacer-Web-W01`. Artefakt obsahuje webové soubory, jejich kontrolní součty, výsledek šesti browser scénářů a snímky. Nic se automaticky nezveřejňuje. Podrobnosti, postup místního exportu a dočasné přepínače jsou v [záznamu W01](WEB_W01.md).

Výstup `dist/web/` se obsluhuje přes HTTP. Před publikací se musí pokračovat podle [plánu](PLAN_WEB.md); veřejná adresa a napojení na JendaWeb patří do W09. Tento prototyp ještě nezajišťuje zvuk, úplné webové ovládání, bezpečné ukládání postupu ani online místnosti.
