# Aviary design assets

## Chicken Snake / Nachtgarten

New game art generated with the built-in Image Gen tool using the Chicken Snake
concept as a style reference. Sprite alpha is preserved. Sprite source cells are
selected natively by Canvas; no bitmap editing or screenshot-based UI.

Arena: `public/assets/snake/night-garden.png`

> Use case: stylized-concept. Input image is style reference for a real game asset, NOT edit target. Generate ONLY a standalone top-down midnight magical garden arena background matching the reference Chicken Snake artwork. Landscape 1792x1024 (1.75:1) orthographic view no perspective. Frame of rich illustrated dark teal glossy leaves, lush jade foliage, small violet bell flowers, stone border, glowing pale golden lotus flowers in lower corners and one small warm stone lantern upper right. EXACT functional safe composition: decorated border restricted to outer 8% on all sides; entire central rectangle from x8% to92% and y12%to88% is empty quiet deep dark teal #07262b ground, very faint texture, NO checker grid because grid drawn in code, no large props anywhere in central playfield. Foreground foliage lighter mint edges and soft warm accents. Rich premium indie hand-painted polished 3D stylized game aesthetic, gently lit magical night garden, subtle depth and smooth textural detail. No snake, no eggs, no characters, no text, no UI, no buttons, no icons, no frame line, no watermark. Need clean unobstructed gameplay center.

Atlas: `public/assets/snake/jade-sprites.png` (transparent background enabled)

> Use case: stylized-concept. Image is STYLE REFERENCE only. Generate transparent production sprite atlas for the cute jade crowned serpent and golden egg in this Chicken Snake design. 1024x1024 PNG actual transparent alpha background. EXACT 2x2 equal 512x512 cells with generous padding, isolated objects never crossing cell boundaries. TOP LEFT CELL centered at256,256: one round cute mint jade serpent HEAD, orthographic top down facing RIGHT, charming two big glossy dark eyes along top/bottom facing right, small golden crown atop head near rear, tiny nostrils, no neck or body, warm pale yellow underside, polished jade scales. TOP RIGHT CELL centered768,256: one single circular chunky jade-green snake BODY SEGMENT with detailed overlapping emerald scales, broad soft mint highlight on top-left and dark green edge, orthographic top down, rounded disk silhouette suitable overlapping continuous snake body. BOTTOM LEFT CELL centered256,768: one golden magical EGG collectible, warm golden shell with delicate flecks, bright pale golden highlight, sharp clean silhouette, orthographic top-down stylized egg slightly elongated vertically, no big outside glow. BOTTOM RIGHT CELL centered768,768: one tapered jade snake TAIL TIP pointing LEFT, curved taper, matching scale texture, no body attached. Each object fills about70% of own cell, same beautifully polished premium game art as reference. Actual transparent background required across all empty space and cell margins, no ground, no shadows extending across cell edges, no checkerboards, no text, no labels, no separators, no multiple heads, no scenery.

Generated using the built-in Image Gen tool. UI labels, navigation, scores and controls remain native React elements. User avatars come from the existing API, with initials as the fallback.

## Game banners

File: `public/assets/aviary-game-banners.png`

Prompt:

> Use case: stylized-concept. Production image asset, one seamless game banner atlas for Aviary dark premium gaming dashboard. 1536x1024 landscape, exactly FOUR equal 256-pixel high horizontal banner scenes stacked vertically, no gaps or borders. Each scene spans entire width and is suitable for an approximately 700x66 game launch UI strip, maintain all subject matter readable when reduced to 66px height. Native backdrop dark charcoal purple #19171f. TOP QUARTER: a charming small golden round chicken jumping across amber cavern platforms, amber orange softly lit environment. SECOND QUARTER: a cute teal curved segmented snake and small floating teal orb in dark teal stone cave. THIRD QUARTER: shiny lavender pinball orb and two purple flippers in dark violet miniature arcade, accurate pinball imagery. BOTTOM QUARTER: charming small pink round bird running through dark magenta floating stone platforms. Subjects on LEFT THIRD of each scene, right half fades gently into near-black matching #19171f to place code text. High-quality polished stylized 3D illustration, restrained glow, cohesive across all 4 strips, very clean. Absolutely no text, no logos, no buttons, no letters, no UI, no watermark.

The four regions are displayed using CSS background positioning. Aspect ratio is preserved; the art is not stretched to the button width.

## Welcome mascot

File: `public/assets/aviary-mascot.png`

Prompt (transparent background enabled):

> Use case: stylized-concept. Standalone transparent-background production illustration for Aviary premium dark gaming community dashboard. One charming small plump lavender purple bird with tiny warm golden crown and orange beak and feet, perched inside an elegant dark lavender domed birdcage. Tasteful polished stylized 3D game art, delicate matte metal cage bars, gentle soft studio lighting. A few small lavender leaves beside cage base. Entire cage fully visible, centered, isolated with actual transparent background, compact square composition, no background, no mist, no scenery, no text, no logo, no UI. This is the welcoming mascot in a charcoal-purple dashboard, subtly illuminated, classy friendly magical aesthetic, very clean silhouette.
