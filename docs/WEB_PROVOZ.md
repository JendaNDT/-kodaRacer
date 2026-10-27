# Webová verze — provozní záznam

## Výchozí stav W00

Pracovní větev `codex/web-version` vychází z vydané hry 1.19.1 na `main`. Výchozí větev repozitáře zůstává starší `ccr-05c4e7fe-qo3pmx`; pro další práci používat výslovně pracovní větev nebo `main`.

Automatický krok přepisující veřejný `testovaci-build` je omezen podmínkou `github.ref == 'refs/heads/main'`. Sestavení z pracovní větve může projít kontrolami, ale nesmí smazat ani přepsat veřejné APK a EXE.

W00 nevytváří webový export hry, webovou adresu ani propojovací službu. Další krok je W01 podle [plánu](PLAN_WEB.md).
