# Art Direction v2: "Painted Temple" (binding for all art agents)

> Owner feedback on alpha 2 (2026-11-26): "The graphics do not look good." The owner wants a large step up. The
> art stays **generated in code** (owner decision), built by Fable agents. This document replaces DESIGN §6 for
> look and feel. The palette (§6.1) still applies.

## Target
A **stylised, painterly 3D** look, in the spirit of high-end indie action games on Indian mythology (e.g. *Raji:
An Ancient Epic*): rich light, atmosphere and colour. It is not photoreal and not "low-poly". Test for every
screenshot: **would it look at home on a Steam store page next to a well-reviewed indie game?** If it reads as
"programmer art", it fails.

Five qualities every frame must have:
1. **Light that tells the time of day.** A warm key light, a cool fill, a rim, coloured shadows (shifted toward
   indigo or violet, never grey), bloom on gold and fire, and soft ambient occlusion in the corners.
2. **Atmosphere.** Depth fog, volumetric light shafts at dawn and dusk, particles in the air (dust, embers,
   fireflies, petals), and a real sky with clouds and a sun disc.
3. **Surface richness.** No flat single-colour faces. Every material has subtle colour variation (noise), a
   proper shading response (cloth, fur, stone, gold metal, foliage, skin), and smooth normals on organic
   shapes. Architecture has bevelled edges and carved detail.
4. **Silhouette and detail at three scales:** a strong overall shape; secondary forms (mouldings, armour plates,
   muscle masses, drapery); and tertiary detail (ornaments, trims, patterns).
5. **Motion.** Nothing in the world is perfectly still: cloth and foliage sway in the wind, water moves, fire
   flickers, and characters breathe when idle. Animation has anticipation and follow-through.

## Rendering
- Forward+ renderer. **ACES tonemapping**, glow (bloom) with a threshold so that only gold, fire and magic bloom, SSAO, and
  SSIL on High. SDFGI on High. **Volumetric fog** on Medium and High.
- Mood presets in `core/look.gd`: `dawn`, `day`, `dusk`, `night`, `inferno` (for the burning of Lanka) and `divine`
  (for the shloka cards and the epilogue). Each sets the environment, the sun and moon light, the fog colour and density,
  and a colour-grading adjustment (saturation, contrast, brightness). Levels pick a mood.
- Graphics presets (DESIGN §8): **Low** = no SDFGI, SSIL, SSAO or volumetrics, 0.75 render scale, and simple fog. It
  must still look intentional, never broken.

## Materials (`gen/materials.gd`, shared)
A single painterly spatial shader with material **kinds**: `stone`, `cloth`, `fur`, `skin`, `gold`, `wood`,
`foliage`, `water_edge` and `lacquer` (painted surfaces). Each kind has its own settings:
- the base colour from vertex colour, with a world-space triplanar **noise variation** of ±6–12% in value and a slight
  hue shift;
- **soft banded diffuse** (2–3 soft bands, not hard toon steps) with shadows hue-shifted toward `NIGHT_INDIGO`;
- **gold**: metallic, a bright specular, and it catches the bloom;
- **cloth and foliage**: wrap lighting (light bleeding through), and wind sway in the vertex shader controlled by
  vertex colour alpha (0 = rigid, 1 = free);
- **stone**: cavity darkening from AO and edge highlights on bevels;
- **fur**: a soft sheen at grazing angles.
The material kind is chosen per surface. Meshes can have several surfaces (one per kind). MeshKit must let a
mesh be built with several surfaces and with smooth or flat normals.

## Geometry
- Organic shapes (characters, rocks, trees, the mountain) use **smooth normals** and enough segments to be
  round at gameplay zoom. Characters are about 3–6k triangles, hero props about 2–4k.
- Architecture: bevelled edges, layered cornices, carved bands (repeated relief motifs), pillars with
  bases, flutes and capitals, kalasha finials, and doorway arches. Lanka is **opulent**: gold leaf, red lacquer and
  white stone.
- Terrain: ground tiles get gentle height noise and blended edges between tile types. No visible grid.

## Characters
- **Hanuman** is the hero and must look heroic and divine: a powerful, sculpted body (chest, shoulders and arms
  built from blended smooth forms), an expressive face (brow, eyes, the gentle smile of a devotee), a richly
  detailed gold mukuta, earrings, necklace, armlets, a flowing saffron dhoti that sways in the wind, and a
  long tail with spring motion. He has a soft golden aura (rim plus faint particles) when his Smarana is high.
- **Rakshasas** look menacing through their silhouettes (horns, spiked armour, heavy jaws) and colour (dark violet, crimson,
  bronze). No gore.
- **Sita and Rama** must look dignified and serene, with refined faces, graceful drapery and soft divine light. Read
  DESIGN §2.
- **Animation**: an idle with breathing, a walk and run with hip sway and arm swing, attacks with anticipation,
  a smear or arc trail on swings, impact and recovery, a hit reaction, and a meditate pose with a gentle float.

## Environment
- **Sky**: a procedural sky shader with a gradient, layered clouds that drift slowly, a sun or moon disc, and stars at
  night.
- **Ocean**: Gerstner waves, a fresnel reflection of the sky colour, depth colour, shoreline foam, and sparkles.
- **Foliage**: trees with leaf clusters built from leaf cards, so the canopy has a lacy silhouette instead of blobs; grass
  fields as wind-swaying MultiMesh blades; flowers; falling Ashoka petals.
- **Set dressing**: every level is dressed with lamps, banners, pots, rugs, statues and carved stones, so that
  nothing looks empty.

## VFX (`gen/vfx.gd`)
Hit sparks, dust puffs on landing and footsteps, gada swing trails, fire with smoke and embers, golden
Smarana motes, size-change bursts, a shockwave ring for the surge, dissolve-into-embers for defeated
rakshasas, fireflies, petals, and sea spray.

## Process
Every art module must use the **visual acceptance loop**: render with `dev/preview/*.gd`, look at the PNG, and
compare it against this document's test ("next to a well-reviewed indie game"). Iterate at least three times. Attach
the final screenshot path in the report.
