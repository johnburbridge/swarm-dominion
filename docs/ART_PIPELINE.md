# Visual Art Pipeline: Swarm Dominion

**Working Title:** Swarm Dominion
**Document:** Art Production Pipeline (AI-Generated Assets)
**Version:** 1.0 Draft
**Last Updated:** July 2026
**Author:** John Burbridge, Founder, Spiral House, LLC

---

## 1. Executive Summary

Swarm Dominion has no dedicated art team; all visual assets must be AI-generated and
maintained by a solo developer. This document proposes a production pipeline that treats
**consistency** and **animation** — not asset volume — as the hard problems, because the
game's actual asset count is small.

The core strategy: establish a small **art bible**, train a **style model** on it, and
generate every asset through that model so the whole set shares one visual DNA. Team colors
are handled at runtime in Godot with a **palette-swap shader** rather than by generating
per-color art, and animation is minimized by exploiting the top-down RTS camera.

## 2. Design Constraints (What Makes Swarm Dominion Specific)

- **Small cast.** The starting faction (The Swarm) is a single creature line: Drone (L1) →
  Hunter / Guardian / Scout (L2) → Elite forms (L3), plus the Mother. That is ~8 creature
  designs. The full art bible is those creatures plus a handful of props (biomass nodes,
  control points), terrain tiles, UI, and VFX. This is not a thousand-asset pipeline.
- **Monster aesthetic is an advantage.** Organic, blobby alien forms hide the minor
  inconsistencies AI generation produces, and there are no faces, hands, or text — the
  three subjects generators still handle poorly.
- **Progression must read as evolution.** Drone → Hunter is the *same creature* evolving,
  not a new unit. Visual lineage matters more than novelty.
- **Team color is mandatory.** Every unit must render in the owning player's color. This is
  a runtime concern, not an art-generation concern (see §6).
- **Cosmetic skins are a business-model pillar.** The pipeline must support reskinning and
  variant generation cheaply. Style models are well suited to this.
- **2D now, isometric later.** Per the PRD, an isometric art upgrade is explicitly deferred
  (Milestone 22). Early perspective choices should stay simple and cheap.

## 3. Decision 1: Style and Perspective

This decision is upstream of everything else and should be locked first.

### Art style

For an RTS, stylized beats realistic — and not as a matter of taste. At RTS zoom, excessive
realism turns units into visual noise, while simplified forms and strong value separation
stay readable. Target bold silhouettes, high value contrast between unit and ground, and
emissive/glowing accents (a natural fit for alien biomass: glowing sacs, spines, veins).
Those accents also double as the team-color carrier. This is also the output AI generates
most reliably.

### Perspective

The classic RTS answer is a tilted 3/4 or isometric view because it reveals more of each
unit. A near-top-down view has a practical payoff for a solo developer, though: a straight-
down camera eliminates unit occlusion entirely, sidestepping an age-old RTS problem.

**Recommendation:** Start with a **slightly-tilted top-down 3/4 view** — enough angle to read
each creature's form, flat enough to avoid occlusion and to allow rotating a single sprite
for facing instead of drawing eight directions. This defers the harder isometric look to
Milestone 22 while keeping assets cheap now.

## 4. Recommended Pipeline

The central principle, on which every credible source converges: **do not prompt each asset
from scratch.** Train one style model on a small art bible and generate everything through
it. Piecemeal prompting is how a project ends up with assets that look like clip art pulled
from five different websites — different perspective, lighting, and detail on every one.

1. **Establish the look (a few hours).** Generate concept variations of the Drone in a
   general model (e.g. Flux 2, Midjourney, Nano Banana) until 10–20 images nail the
   aesthetic — consistent palette, lighting logic, and 3/4 angle. This set is the art bible.
   A small, well-curated set (5–15 images) outperforms 30–50 that lack variety.

2. **Train a style model.** Feed the bible to a game-focused platform (Scenario is the
   reference option). Training runs on ~15–50 images and completes in roughly 20–40 minutes,
   producing a LoRA that applies the style to every generation automatically. A short prompt
   ("guardian form, hunched, heavy chitin plates") then comes out on-model.

3. **Generate the unit line as evolutions, not separate creatures.** Take the finished Drone
   and use a reference-based editing model (Flux Kontext, Nano Banana) to evolve it into
   Hunter, Guardian, and Scout — the same creature made more specialized — then into the
   Elite (L3) forms. This preserves visual lineage far better than generating each unit
   independently.

4. **Bake in the team-color region deliberately.** Design each creature so one clear area
   (glowing sacs, a carapace stripe) is the team color, generated as a flat, isolated hue.
   Godot then recolors per-player at runtime via a palette-swap shader — one sprite, N player
   colors, zero duplicated art. (See §6.)

5. **Animate by sidestepping AI's weakest area.** One-shot sprite sheets are still not
   production-ready as of early 2026; frame-to-frame consistency is unreliable, so the
   working method is generating key poses individually and assembling them. For a top-down
   RTS, most of the problem can be avoided:
   - **Movement:** rotate a single rigid sprite toward its heading. Zero animation frames.
   - **Idle / attack / harvest:** Godot cutout/skeletal 2D animation — generate the creature,
     split it into parts (limbs, sacs), rig with bones, animate procedurally. Squash-stretch
     plus a lunge covers most RTS needs.
   - **Death / spawn / upgrade:** particle VFX (goo splatter, emergence shimmer) rather than
     drawn frames.
   - Only if frame animation is wanted later: PixelLab (skeleton rigging, 4/8-direction
     rotation) or AutoSprite (image-to-spritesheet) are held in reserve.

6. **Post-process — always budget for it.** The consistent reality is that AI yields ~80% of
   a game asset in seconds and the last 20% is done by hand: background cleanup to clean
   alpha, edge tidying, palette snapping. GIMP / Krita / Aseprite, a few minutes per asset.

## 5. Alternatives

### Alternative A — Lighter-weight, no training (reference-based only)

Skip the LoRA. Design the Drone, then drive the entire set through an editing model
(Nano Banana, Flux Kontext) using the Drone as a reference each time. Consistency is not as
tight as a trained model, but for a small cast it is often sufficient.

- **Pro:** no training step, lower cost, faster start.
- **Con:** more drift across the set; more manual correction.
- **Use:** ideal for validating the look before committing to a trained model.

### Alternative B — Heavier, more control (local + ComfyUI)

Run open models (Flux, SDXL + a style/pixel LoRA) locally via ComfyUI on your own GPU.

- **Pro:** free per image, full control, private, fits a home-lab setup.
- **Con:** real setup time and GPU dependency; this is where AI *slows you down* if the
  tooling fights you, and where engineering time is arguably better spent on the game.
- **Use:** only if the pipeline-building itself is enjoyable.

### Recommended path

Run the **main pipeline with Scenario**, using **Alternative A** first as the cheap way to
lock the style before paying for training.

## 6. RTS-Specific Leverage

### Team color via palette-swap shader

Generate units once, with the team-color region as a flat isolated hue, then recolor at
runtime with a Godot 4 palette-swap shader. KoBeWi's Godot Palette Swap Shader is the
standard free option: it reads and writes `COLOR` directly with no texture lookups and ships
with a palette-generator tool. This turns "one sprite → every player color" into a shader
parameter instead of duplicated art.

### Animation avoidance

The top-down camera lets rigid-sprite rotation replace directional animation, and Godot's
2D skeleton plus particle VFX cover idle/attack/death without AI needing to produce
consistent frames. Keeping AI out of the frame-animation loop removes its least reliable
task from the critical path.

## 7. Cost

Generation is cheap: a few dollars up to ~$50 in generation for a typical indie asset set,
versus $2,000–$10,000+ for outsourced art. Scenario runs ~$15/month. The real cost is
developer time on curation and post-processing, not compute.

## 8. Licensing and Community Considerations

For an open-source, competitive game, be deliberate about:

- **Commercial-licensing terms** of whichever tool is chosen. Scenario and the major sprite
  tools grant commercial ownership of outputs; keep a clean paper trail given the MIT repo.
- **Community perception** of AI-generated assets. The competitive/open-source audience can
  be opinionated; decide up front how to represent the art's provenance.

## 9. Next Steps and Open Questions

- [ ] Lock style + perspective (§3) via a Drone concept pass (Alternative A).
- [ ] Decide Scenario vs. local ComfyUI for the trained-model step.
- [ ] Define the team-color region convention before generating any final unit art.
- [ ] Prototype the palette-swap shader on a placeholder sprite in Godot.
- [ ] Establish the post-processing checklist (alpha cleanup, palette snap, edge tidy).
- [ ] Open question: skeletal/cutout rig vs. reserved sprite-sheet tools for L2/L3 attacks.
- [ ] Open question: how (and whether) to disclose AI provenance in-repo and on the store page.

## 10. References

- Apatero — *AI Game Art Generator: Sprites, Textures & More* (2026):
  https://www.apatero.com/blog/ai-game-art-generator-sprites-textures-2026
- Scenario — *Train a Style Model* (Knowledge Base):
  https://help.scenario.com/en/articles/train-a-style-model/
- Scenario — *Custom Model Training for Brands*:
  https://www.scenario.com/features/train
- KoBeWi — *Godot Palette Swap Shader*:
  https://github.com/KoBeWi/Godot-Palette-Swap-Shader
- Godot Shaders — *Palette Swap (no recolor / recolor)*:
  https://godotshaders.com/shader/palette-swap-no-recolor-recolor/
- Strike Tactics — *3D vs. 2D Visuals in RTS Games* (top-down vs. isometric, occlusion):
  https://striketactics.net/devblog/3d-vs-2d-visuals-rts-games
- Sunstrike Studios — *Realism vs Stylization in Game Art* (readability at RTS scale):
  https://sunstrikestudios.com/en/blog/game_art_visual_direction/
- TECHSY — *7 Best AI Game Asset Generators (2026, Tested)*:
  https://techsy.io/en/blog/best-ai-game-asset-generators

---

*End of Document*
