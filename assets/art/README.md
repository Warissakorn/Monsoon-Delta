# Delta graphic assets

Five original vector illustrations created for Monsoon Delta on 2026-10-24. These SVGs are
drawn from geometric paths for this project; they do not contain stock artwork,
embedded images, external resources, fonts, scripts or generated raster images.
Their source is the editable SVG itself.

`delta_village.png` is a new AI-generated menu illustration made with OpenAI
image generation on 2026-10-24 (1536 × 1024). It depicts a Thai lowland village,
rice fields, a canoe and approaching monsoon clouds in the same teal/ochre
palette. It contains no baked-in UI or lettering. The editable vector claims
above apply to the SVGs, not this raster illustration.

## Art direction

Lagoon teal, rice-paper cream and restrained brass follow `data/palette.json`.
Terracotta timber and soft green plants connect these graphics with the game's
procedural village. A hexagonal frame echoes the board without implying an
additional building or gameplay action. Silhouettes and different tools identify
the four occupations as well as color.

| File | Use | Designed display size |
|---|---|---|
| `delta_village.png` | Full-bleed menu key art; crop centrally to fill, preserve aspect ratio | 540 px wide and above; 1536 × 1024 source |
| `delta_emblem.svg` | River village brand seal: raised house, water and rice | 64–128 px; 256 px source |
| `leaders/farmer.svg` | Farmer: golden rice and harvesting sickle | 64–96 px; 160 px source |
| `leaders/carpenter.svg` | Carpenter: wooden mallet and stacked timber | 64–96 px; 160 px source |
| `leaders/fisher.svg` | Fisher: fish and woven bamboo trap | 64–96 px; 160 px source |
| `leaders/soil_doctor.svg` | Soil doctor: spade, seedling and soil cutaway | 64–96 px; 160 px source |

## Integration

These are **multicolor illustrations**, distinct from the monochrome interface
symbols in `assets/icons/`. Load them into a `TextureRect` with
`STRETCH_KEEP_ASPECT_CENTERED` and leave `modulate` white so the palette remains
intact. Keep translated occupation names and descriptions in ordinary UI text;
the illustrations contain no labels. They are decorative and should ignore
pointer input. A leader illustration does not change the selected leader's rules.

The SVG canvases have transparent space around the hexagon and opaque dark
backgrounds within it. Static artwork needs no additional Reduce motion behavior
and makes no network requests at runtime.

`view/menu_artwork.gd` displays the illustration with a brass journal frame.
`ui/main_menu.gd` uses the seal beside the translated title and the occupation
medallion beside the selected leader's description. `project.godot` also uses
the seal as the application icon. The SVG sources can be recolored or resized
without a separate design application.
