# Pepple Survivor · Space arsenal

Image Gen concepts (generated before implementation):
- Primary: `exec-07bd111a-eaa0-4823-a9c8-ad89a92320fe.png` (1536 × 1024).
- Upgrade state: `exec-ef49e03e-4411-4587-82e7-4ddb5d00db3a.png`.
- Local originals: `C:/Users/Flori/.codex/generated_images/01a13ead-15b6-78f1-bc15-d0fb38b4edf7/`.

## Visual system

Navy surfaces #091322/#0a1426, cyan #69e7f8, violet #c6a0fc, warm score amber #ffd384, danger pink #f5476b. Segoe UI/Inter, 40px desktop game title, 20px stats, 12–13px controls, 10–11px secondary labels. Thin luminous arena frame, 12px corners, 14px arena/aside gap. Lucide outline icons, minimum 44px primary touch targets. The native header shows Score, Level, Welle, Kills and Zeit. Native life/XP bars stay above the canvas. The right rail contains the actual unlocked arsenal, boss timer, movement energy and real highscores. Three color-coded upgrade choices pause simulation. Mobile stacks choices and sidebar and adds a captured touch joystick.

## Assets and mechanics

New generated transparent 4×3 weapon atlas and uninterrupted nebula background. Preserve the existing personal astronaut face, enemies, props and cinematic title illustration. Canvas slices the atlas directly; UI remains React. Existing scrolling world, obstacle collision, XP, potions, waves, bosses, bleeding, ten weapons, six passives and four music tracks remain. Railgun pierces visible aligned enemies; homing comets explode once with area damage. Weapons evolve at levels 4/8. Web Audio layers and cached noise distinguish shots, beams, explosions and rewards. Particle counts remain capped and respect reduced motion.

## Fidelity ledger and intentional adaptations

Both concept images and final Playwright screenshots were opened using view_image. Browser plugin not available; real Edge via Playwright used at 1536×1024, 1440×1000 and touch 390×844.

| Comparison | Render / resolution |
| --- | --- |
| Primary hierarchy | Title, five counters, controls above the arena; arsenal and leaderboard right. Kept inside existing Aviary navigation, so available width is smaller than the concept. |
| Palette and borders | Navy/cyan/violet/amber matched. Removed inherited old orbit/diagonal decoration that crossed the new chrome. |
| Typography and spacing | Explicit title, stat, button and caption scales; minimum touch targets; consistent native panels. |
| Background and assets | New unwashed nebula and weapon atlas match space direction. Existing mascot/enemy art preserves identity. Real animated combat replaces the concept's densely illustrated static battle. |
| Upgrade anatomy | Three art/name/level/description/action cards with paused-state notice; mobile all three visible in a taller arena. |
| Copy and actual state | Title, tagline, stat labels, arsenal, boss, highscores, movement/pause/finish and upgrade instructions retained. Demo numbers/names replaced by actual API/game values; boss appears at the real 3-minute threshold. |
| Functional additions | Movement energy/bleeding warning is necessary for the existing idle-death mechanic. Loading/retry, menu/options/pause/result panels, single score-save action and guest explanation are native operational states. |
| Responsive behavior | Sidebar moves below the arena; touch stick replaces keyboard reliance; stacked upgrade cards fit without horizontal overflow. |

Above-fold copy audit: no new marketing sections or decorative eyebrow labels. Operational menu copy explains starting, saving, loading and retry. Final comparison preserves the concept's hierarchy, color system, illustrated identity and functional card anatomy; gameplay density varies with the actual wave/build rather than invented visual enemies.

