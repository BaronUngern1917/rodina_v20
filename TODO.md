# TODO
- [x] Переписать прототип в единую играбельную сборку пролога
- [x] Исправить T/R: T перезарядка, R крик
- [x] Реализовать подбор ППШ
- [x] Реализовать туалетную мини-игру
- [x] Реализовать двор, лес, стрельбище и мишени
- [x] Реализовать грузовик и завершение пролога
- [ ] Протестировать v12 в Godot 4.7.2 на Windows
- [ ] Улучшить ППШ и ЗИС-5
- [ ] Позже заменить лицо старшего солдата на предоставленный референс

## v11 additions
- [x] Main menu uses supplied battlefield photograph.
- [x] Add text outline for HUD/menu readability.
- [x] Add user-provided "За Баранова!" audio to R.

## v12 additions
- [x] Restore barracks light with a kerosene-lamp prop and warm light source.
- [x] Remove post-toilet teleport.
- [x] Add locked toilet return door that unlocks after cleaning.
- [x] Add barracks-to-yard exit after returning from the toilet.
- [x] Add separate armory building.
- [x] Add Buryat NPC as the PPSh issuer.
- [x] Enlarge the military base and increase spacing between buildings.
- [x] Move targets farther away from firing line.
- [x] Move ZIS-5 farther from the range.
- [x] Expand safety-floor collision to the new map size.
- [ ] Runtime-test the enlarged map and all door/armory transitions in Godot 4.7.2.

## v13 additions
- [x] Remove the unnecessary second toilet door.
- [x] Make the toilet a single-door room with a clean enter/clean/exit sequence.
- [x] Prevent the player from bypassing the toilet door through a side gap.
- [x] Remove the colliding exterior threshold obstacle at the barracks exit.
- [x] Recheck door paths, collision toggling, and toilet/barracks state transitions.


## v14 additions
- [x] Rebuild toilet and barracks exit doors around hinge pivots.
- [x] Remove doorway side gaps caused by center-pivot doors.
- [x] Close and lock the toilet door only after the player is actually inside.
- [x] Hide the toilet cleaning panel and fork immediately at 100%.
- [x] Change the single toilet door's destination to barracks after cleaning.
- [x] Reset toilet mini-game state on a fresh start.
- [ ] Runtime-test the complete toilet enter/clean/return sequence in Godot 4.7.2.
