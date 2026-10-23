# Feature status

## Available

| Area | Behavior |
| --- | --- |
| Detection | Automatic Hereditas/Arsenal recognition, scoped by stolen-goods possession |
| Loot | Current bag value out of 500, base maximum, shortfall, bonuses and penalties |
| Remaining sources | Bodies where applicable, combined chests including final chest, safes and total |
| Hereditas estimate | Minimum-source plan using remaining base rewards, partial bodies and boosted-level safe eligibility |
| Overlay | Movable tracker, progress bar, needed source icons, base maximum and saved position |
| Bag total | Current loot on the stolen-goods bag's backpack icon; follows panel moves and slot changes, hidden while dragged; optional |
| Highlights | Bodies, chests, safes, anchors/pylons, doors and controls as applicable |
| Display | 3D wireframe or 2D outer perimeter, source switches and through-wall option |
| Locked loot | Sources behind Agility shortcuts and safes below the Thieving requirement hidden and left out of the estimate, by boosted level; optional |
| Completion | Explicit object states and body exhaustion confirmation; Hide/Grey modes |
| Labels | Optional source names/base rewards and per-body progress; hide on UI overlap using measured text width; disabled by default |
| Lifecycle | Event-driven updates, cached discovery, bounded readiness retries and cleanup on exit/shutdown |

## References

- [Vault of Hereditas strategies](https://runescape.wiki/w/Vault_of_Hereditas/Strategies)
- [Asuran Arsenal strategies](https://runescape.wiki/w/Asuran_Arsenal/Strategies)
- [RuneScape client API](https://developer.runescape.com/rs/)
