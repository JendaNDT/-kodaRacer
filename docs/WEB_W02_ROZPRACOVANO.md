# W02–W04 — rozpracováno

W02: připraveny stopy pro všech šest tratí a šest zrcadlených variant původním algoritmem. Kontrola `res://check_lines.tscn` porovnala hodnoty s novým výpočtem a prošla pro všech 12 variant. Export ověřuje kontrolní součty zdrojů a odmítne zastaralá data. Webový balík s daty byl sestaven.

W02 není dokončeno: zbývá ověřit a podle měření rozdělit dlouhé načítání a prověřit rušení načítané scény. Browser test závodu s novými daty a celé CI musí projít.

W03 zvuk a W04 ovládání zůstávají k provedení podle `PLAN_WEB.md`.

Předvýpočet: `godot --headless --path godot res://bake_lines.tscn`; ověření: `godot --headless --path godot res://check_lines.tscn`. Po každé změně `scripts/track.gd` nebo `scripts/game.gd` se data musí přegenerovat.
