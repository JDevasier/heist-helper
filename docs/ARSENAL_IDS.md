# Asuran Arsenal definition reference

The runtime registry is `data/arsenal_entities.lua`. NPC and scenery namespaces are distinct. Each entry defines its role, reward type and completion state where applicable.

## Loot and activation objects

| Source | Namespace | Available/inactive | Looted/active |
| --- | --- | --- | --- |
| [Ordinary chest](https://runescape.wiki/w/Chest_(Asuran_Arsenal)) | Scenery | 84214 | 84215 |
| [Ornate chest](https://runescape.wiki/w/Ornate_Chest) | Scenery | 86429 | 86430 |
| [Rare chest](https://runescape.wiki/w/Rare_chest_(Asuran_Arsenal)) | Scenery | 84176 | 84177 |
| [Safe](https://runescape.wiki/w/Safe_(Asuran_Arsenal)) | Scenery | 134525 | 134526 |
| [Dragonkin pylon](https://runescape.wiki/w/Dragonkin_pylon_(Asuran_Arsenal)) | Scenery | 84183, 84187 | 84193 |
| [Strange conduit](https://runescape.wiki/w/Strange_conduit) | Scenery | 84196 | 84197 |

Loot objects honor Hide/Grey completion. Active pylons/conduits disappear. Native custom click bounds take precedence over approximate footprint boxes.

## Other registered definitions

| Definition | Namespace | IDs |
| --- | --- | --- |
| [Siege engine](https://runescape.wiki/w/Siege_engine_(Asuran_Arsenal)) | NPC | 7891 |
| [Siege cannon](https://runescape.wiki/w/Siege_cannon_(Asuran_Arsenal)) | NPC | 14934 |
| Keeper / Projection | NPC | 651 / 652 |
| [Security projector](https://runescape.wiki/w/Security_projector_(Asuran_Arsenal)) | Scenery | 134554 |
| [System controls](https://runescape.wiki/w/System_controls) | Scenery | 84181 |
| [Tablet](https://runescape.wiki/w/Tablet_(Asuran_Arsenal)) / [Lectern](https://runescape.wiki/w/Lectern_(Asuran_Arsenal)) | Scenery | 84191 / 84192 |
| [Locked/unlocked door](https://runescape.wiki/w/Locked_door_(Asuran_Arsenal)) | Scenery | 134532 / 134533; parents 134527, 134528 |
| [Barrier](https://runescape.wiki/w/Barrier_(Asuran_Arsenal)) | Scenery | 84178, 84179, 84180; parent 84182 |
| [Rubble](https://runescape.wiki/w/Rubble_(Asuran_Arsenal)) | Scenery | 134548, 134550, 134549, 134551, 134546 |
| [Crevice](https://runescape.wiki/w/Crevice_(Asuran_Arsenal)) | Scenery | 134534–134538 |
| [Railing](https://runescape.wiki/w/Railing_(Asuran_Arsenal)) | Scenery | 134545 |
| [Handholds](https://runescape.wiki/w/Handholds_(Asuran_Arsenal)) | Scenery | 134539, 134541, 134543 |
| [Dropdown](https://runescape.wiki/w/Dropdown_(Asuran_Arsenal)) | Scenery | 134540, 134542, 134544 |
| [Low wall](https://runescape.wiki/w/Low_wall_(Asuran_Arsenal)) | Scenery | 134547 |
| Entrances / exit | Scenery | 84171–84174 |

Doors remain marked when unlocked; repeatable system controls remain marked after use. Guards, barriers and other objectives are registered for discovery and have no guard/vision overlay. Entrances and exits do not establish that a run is active.

## Unresolved details

- Instance 500 identifies Arsenal; this is separate from scenery definition IDs.
- Chest counts use fourteen shared state slots plus the separate final flag. Definition names alone do not establish ordinary/ornate reward ordering.
- Barrier 84179 is closed. No completion state is assigned to 84180.
- Door/control fallback heights are approximate; native bounds should be checked in-game.
- Complete trap geometry, guard vision and movement prediction are not implemented.
