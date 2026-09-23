# PROJECT STATE — Родина 3D / Студин: За Баранова

## Версия
Build v14 — расширенная играбельная сборка пролога с увеличенной военной частью, казармой с керосиновой лампой, Бурятом и отдельной оружейной, пользовательским фоном меню, обводкой интерфейса и озвучкой «За Баранова!». Godot 4.7.2, Compatibility renderer.

## Концепция
3D FPS-пародия на шаблонные фильмы о Второй мировой. Намеренный абсурд — часть дизайна.

## Пролог
1. Казарма: койки, советские цвета, плакаты и тёплый свет керосиновой лампы.
2. Старший солдат выдаёт абсурдное задание: почистить унитаз вилкой.
3. Простая мини-игра очистки без телепорта наружу.
4. После очистки открывается отдельная дверь из туалета обратно в казарму.
5. После возвращения открывается выход из казармы во двор.
6. Увеличенная военная часть с расстоянием между зданиями.
7. Отдельная оружейная: Бурят выдаёт ППШ.
8. Дальнее стрельбище: 5 мишеней.
9. После стрельбы нужно реально дойти до удалённого ЗИС-5; посадка завершает пролог.

## Управление
WASD движение; Shift бег; ЛКМ стрельба; ПКМ прицел; F взаимодействие; T перезарядка; R крик «За Баранова!»; Esc отпустить мышь.

## Реализовано
- процедурная low-poly 3D локация без внешних 3D-ассетов;
- FPS-камера и движение;
- спринт + выносливость;
- взаимодействия, несколько дверей и блокировка этапов;
- мини-игра туалета с вилкой;
- выдача ППШ через персонажа Бурята в отдельной оружейной;
- стрельба и перезарядка;
- прицеливание;
- 5 мишеней и переход к грузовику;
- упрощённый ЗИС-5 и посадка;
- русское HUD и меню управления;
- сохранена абсурдная стилистика.

## Ограничения
Модели пока процедурные и намеренно простые. В меню используется пользовательская фотография с КВ-1 и Сталиным. Озвучка «За Баранова!» добавлена из пользовательского файла.

## Следующий этап
Проверить запуск в Godot 4, затем при необходимости исправить коллизии/переходы. После теста можно заменить процедурные модели на более выразительные low-poly ассеты, добавить звуки, а позже — референс лица старшего солдата.


## Compatibility note
- First build is targeted at Godot 4.7.2.
- Fixed strict GDScript type-inference errors in Game.gd (`crown`, `from`, `to`) and explicitly typed player/camera references.


## 2026-09-20 — First build v2
- Fixed player spawn height and added dedicated safety floor collision in Main.tscn.
- Reset player velocity when teleporting between prologue stages.
- Replaced menu KV-1 text placeholder with a simple 3D low-poly KV-1 model rendered in a SubViewport.
- Target engine: Godot 4.7.2.


## Build v4 fixes
- Barracks changed from solid block to floor/walls/roof so player can stand inside correctly.
- Player spawn and transition positions set to y=1.05 (floor-level capsule center).
- Toilet exterior-facing wall added so toilet/urinal cannot be seen from outside.


## Build v5 fix
- Reworked barracks front wall to contain a real doorway to the toilet beside the senior soldier.
- Door is centered in the wall opening at x=4.5, z=3.0 and uses a horizontal 2m x 3m panel.
- Toilet room moved/aligned behind this doorway; its side/rear walls remain closed so the toilet is not visible from outside.


## Build v6
- Rebuilt front wall with a real 2m doorway opening.
- Door mesh/collision is aligned with the opening instead of being rotated across the wall.
- Toilet was moved behind the doorway and its walls aligned to the entrance.
- Priority: correctness and testing over speed.

- v6 correction: front wall opening widened and wall segments moved so no wall overlaps the doorway; door mesh/collision is horizontal across the opening; toilet fixture aligned inside toilet room.


## Build v7
- Fixed toilet door interaction: robust F prompt and interaction detection.
- Door moved slightly toward the player side of the wall so it cannot visually/physically sit behind the wall.
- Door collision is disabled after opening so the doorway is actually passable.
- Interaction ray extended to 4.5 m and doorway fallback added to avoid missed prompts when grazing the frame.
- Menu KV-1 intentionally unchanged.
- Additional static code review performed; runtime validation in Godot 4.7.2 is still required on the user machine because Godot is not installed in this environment.

## Build v9 — PPSh/yard correction
- Found a concrete v8 runtime fault in PPShPickup.gd: interaction used `$CollisionShape3D.set_deferred(...)` without checking that the child reference existed. Replaced it with a cached, null-safe CollisionShape3D reference.
- PPSh is now placed farther into the yard at z=-7 instead of directly beside the post-toilet teleport.
- Post-toilet teleport moved to z=-4.5 to prevent spawning on top of the PPSh.
- Yard-to-range trigger moved to z<-20 so the player has an actual yard section to traverse.
- Interaction code now stores the hit node in a safe local reference before calling interact().
- PPSh is hidden using set_deferred after the collision is disabled, avoiding direct tree/physics mutation during ray processing.

## Build v11 — menu, HUD readability, shout audio
- Added the user-provided battlefield photograph as `assets/menu_background.jpg` and made it the full-screen main-menu background.
- Removed the procedural KV-1 menu viewport from the active menu; the supplied photograph already contains the intended KV-1/Stalin composition.
- Added a subtle dark overlay over the menu image so UI remains readable.
- Added a dark outline to all current Label/Button text in the HUD and menu; this includes the ammo counter, objectives, interaction prompts, messages, crosshair, menu buttons, and controls dialog.
- Added the user-provided `гс.mp3` as `assets/za_baranova.mp3` and connected it to the R shout action.
- The text message `СТУДИН: «ЗА БАРАНОВА!»` remains synchronized with the audio playback.
- No changes were made to the gameplay route that was working in v10.

## Build v14 — expanded military unit and revised prologue flow
- Expanded the playable base to roughly 86 x 190 m, with significantly more distance between buildings and gameplay areas.
- Restored barracks lighting using a visible low-poly kerosene-lamp prop with warm local OmniLight3D.
- Removed the post-toilet teleport: cleaning now leaves the player inside the toilet room.
- Added a separate toilet return door that remains locked until cleaning reaches 100%; opening it returns the player to the barracks state without teleporting.
- Added a main barracks exit door to the yard, unlocked after the player returns from the toilet.
- Replaced the loose PPSh-in-the-yard flow with a dedicated armory building and the NPC Buryat, who issues the PPSh through interaction.
- The PPSh remains visually displayed on the armory counter but is not directly interactable; Buryat is the issuer.
- Moved the firing range substantially farther away. Five targets remain, but they are now placed at approximately 28 m from the firing line.
- Moved the ZIS-5 much farther beyond the range so the end of the prologue requires a real walk to the truck.
- Added wider ground/safety-floor coverage to match the enlarged map.
- Added `scripts/Buryat.gd`.
- Performed an additional static review of node paths, null-sensitive `visible`/`set_deferred` calls, resource references, map bounds, and progression transitions.


## Build v13 — toilet doorway and barracks exit collision correction
- Removed the second toilet door entirely. The toilet now has one physical doorway, matching a normal small toilet room.
- The single `Barracks/ToiletDoor` is used to enter and later leave the toilet.
- After the player enters, the same door closes and locks until cleaning reaches 100%; after cleaning it unlocks and can be used to return to the barracks.
- Rebuilt the toilet rear wall as solid geometry so there is no hidden second exit.
- Kept the front opening exactly matched to the single door width to prevent walking through a side gap.
- Removed the colliding threshold block at the barracks exterior exit; it was the rectangular obstacle that could remain in the doorway after the door opened.
- Kept the threshold only as a non-colliding visual detail.
- Rechecked door node paths, door collision toggling, toilet state transitions, barracks exit transition, and null-sensitive calls.


## Build v14 — doorway and toilet-state correction
- Reworked both relevant doors as true hinge doors: the door origin is on the jamb and the panel spans the doorway, instead of rotating around its center.
- Tightened the barracks exterior opening to match the door, eliminating a side gap.
- Aligned the toilet doorway exactly between its two jambs; the toilet door hinge is on the right jamb.
- The toilet has one physical door and one stateful route: entry -> close/lock after the player is inside -> clean -> unlock -> return to barracks.
- Removed the blind timer-based close; the door now closes only after the player has actually moved into the toilet room.
- After cleaning, the cleaning panel is hidden, the fork is hidden, and the same door's target state changes from `toilet` to `barracks`.
- Reset toilet progress/UI/fork state when starting a new game.
- Rechecked door node paths, collision enable/disable, state transitions, and null-sensitive UI/mesh/collision references.


## v15
- Оружейная Бурята полностью закрыта стенами, оставлен один вход.
- Добавлена настоящая дверь оружейной с петлёй у правого косяка.
- Изображение `assets/armory_wall.webp` размещено только на внутренней стороне задней стены; снаружи оно скрыто глухой стеной.
- Бурят выдаёт ППШ с репликой: «Вот, твоё оружие. Идти стрелять мишень тренировка.»

## v16 changes
- Moved the armory arsenal image clearly inside the rear wall and changed it to an interior-facing PlaneMesh so the image cannot protrude outside.
- Added a kerosene lamp and warm OmniLight to the armory, matching the barracks lamp style.
- Added the user-provided `menu_music.mp3` (`deti-online.com_-_zhuravli.mp3`) to the main menu with looping playback; music stops when the game starts.


## v17 — Arsenal backdrop position correction
- Moved the interior arsenal photograph panel from z=-6.78 to z=-7.02, placing it on the room-facing side immediately inside the rear wall.
- Kept it as a one-sided PlaneMesh facing into the armory so the image should not be visible from outside.


## v18 — исправление арсенального фона оружейной
- Фото арсенала перемещено на внутреннюю сторону задней стены оружейной, в сторону Бурята.
- Задняя стена имеет центр z=-7.1 и толщину 0.2 м; внутренняя поверхность находится на z=-7.0. Панель установлена на z=-6.85, то есть на 0.15 м внутри помещения.
- Размер панели 10.8 x 3.1 м.
- Сохранено одностороннее отображение материала, чтобы изображение не было видно снаружи.
- Освещение оружейной, музыка меню, дверь, Бурят и остальной v17 без изменений.


## v20 — окончательное исправление фотографии оружейной
- Проверена сама текстура `assets/armory_wall.webp`: это реальная фотография оружейной с оружием, файл присутствует в проекте и не заменён белым полотном.
- Найдена ошибка координат предыдущей версии: задняя стена имеет центр `z=-7.1` и толщину `0.2`, поэтому помещение находится в сторону отрицательного Z. Координата `z=-6.50` была снаружи здания.
- Фото переведено с `PlaneMesh` на `QuadMesh` с ориентацией по умолчанию `FACE_Z`, то есть оно смотрит внутрь оружейной по направлению `+Z`.
- Панель растянута до `11.5 x 3.2 м`, почти на всю ширину и высоту помещения.
- Панель поставлена на `z=-10.5`: это гарантированно внутри комнаты и ближе к Буряту (`z=-13.0`), чем к задней стене (`z=-7.1`).
- Материал сделан `unshaded` и двусторонним (`cull_disabled`), чтобы фотография не превращалась в белое/тёмное пятно из-за освещения или направления поверхности.
- Остальная логика оружейной, дверь, Бурят, выдача ППШ и звук не менялись.
- Статически проверены структура проекта, наличие текстуры, ссылки `res://assets/armory_wall.webp` и целостность ZIP. Runtime-проверка в Godot 4.7.2 в текущей среде недоступна.
