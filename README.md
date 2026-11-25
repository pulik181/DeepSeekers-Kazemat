# Kazemat Framework — Dark Fantasy Action-Detective RPG

> **In-game language:** Russian (UI, dialogues, and voiceovers).

A top-down / isometric dark fantasy Action-Detective RPG framework built with **Godot Engine 4.7.2**. The project combines atmospheric dungeon exploration, dynamic 2D shadow-casting lighting, and fast-paced elemental combat with interactive suspect interrogations powered by a hybrid Large Language Model (LLM) and deterministic offline dialogue engine.

---

## 1. Core Gameplay Mechanics

### Movement, Lighting & Combat
- **Mobility & Evasion:** Responsive 8-directional character movement paired with a high-speed dash featuring invulnerability frames (`i-frames`) and afterimage trails.
- **Melee & Elemental Magic:** Wide-arc sword slashes with line-of-sight wall raycast checks (`PhysicsRayQueryParameters2D` to prevent hitting through walls) and 4 distinct magic elements (*Fire, Frost, Lightning, Dark*), each supporting two switchable casting modes:
  - *Delayed Runic Seal* — high-damage area-of-effect rune detonation after a short charge delay.
  - *Arcane Bolt* — fast directional elemental projectile with elemental status effects (frost slow, lightning stun, dark life-drain).
- **Stamina & Loadout Customization:** Stamina consumption on melee swings, spells, and dashes, quick-use healing potions and stamina tonics, plus selectable character armor skins and lantern light colors.
- **Dynamic 2D Lighting & Interactive Environment:** Cursor-tracking directional lantern cone, soft radial ambient glow, shadow-casting stone pillars and walls (`LightOccluder2D` + `CanvasModulate`), breakable supply barrels, locked iron gates, and treasure chests.

### Investigation System
- **Evidence Discovery & Case Journal:** Collectible physical clues scattered across the environment and tracked in an interactive investigation dossier (`TAB`).
- **Event & Trigger Chains:** Discovering evidence automatically unlocks new interrogation topics, lifts seals on locked iron gates, and activates ritual objects.
- **Modular Ritual Keywords (`RITUAL_KEYWORDS`):** Symbolic runic motifs linking discovered clues, suspect dialogue prompts, and the final verdict at the Ritual Altar.

### AI Suspect Interrogations
- **Hybrid Dialogue Engine:** Supports live HTTP requests to external OpenAI-compatible / Gemini LLM APIs (dynamically assembling system prompts with suspect personality, presented evidence, and active `RITUAL_KEYWORDS`) alongside an instant **autonomous offline fallback mode** (deterministic local response logic when running without an internet connection or API key).
- **Evidence Presentation & Stress Meter:** Present collected clues directly to suspects to trigger specific reactions, shift their panic/stress gauge, and ask either quick-select or free-form typed questions.

### Audio & User Interface
- **Dark-Fantasy HUD:** Real-time health and stamina bars, active element/spell mode indicator, gold/potion/evidence counters, contextual interaction prompts, and a scrollable case dossier.
- **Three-Channel Audio Architecture:** Independent volume sliders for background music, combat/UI sound effects, and character voiceovers, featuring automatic background music ducking during speech playback and real-time neural TTS synthesis support.

---

## 2. Controls

| Key / Input | Action |
| --- | --- |
| `W`, `A`, `S`, `D` / `Arrow Keys` | Character movement |
| `Mouse Cursor` | Aiming direction and lantern beam orientation |
| `LMB` (Left Mouse Button) | Melee sword slash |
| `RMB` (Right Mouse Button) | Cast elemental spell |
| `Q` | Toggle spell mode (*Delayed Runic Seal* / *Arcane Bolt*) |
| `Space` | Dash / dodge roll (with invulnerability frames) |
| `E` | Interact (collect clue, interrogate suspect, open chest, use altar) |
| `1` | Drink healing potion (`+60 HP`) |
| `2` | Drink stamina tonic (`+100% Stamina`) |
| `TAB` | Open / close Case Dossier & Ritual Keywords |
| `ESC` | Close active dialogue or modal window |

---

## 3. Project Structure & Modules

```text
KazematFramework/
├── autoload/                   # Global Singletons (Autoload)
│   ├── case_manager.gd         # Hero stats, clue inventory, progression flags, and RITUAL_KEYWORDS
│   ├── ai_interrogator.gd      # Dialogue engine: LLM HTTP client and deterministic offline fallback
│   └── audio_manager.gd        # Music, SFX pool, voice bus ducking, and live TTS worker integration
├── entities/                   # Gameplay Entities & Combat Systems
│   ├── player/                 # Player controller and scene (inquisitor.gd / .tscn)
│   ├── enemies/                # Universal enemy controller and scene (dungeon_fiend.gd / .tscn)
│   └── combat/                 # Projectiles, delayed runic seals, floating damage text, loot barrels
├── scenes/                     # Game Scenes
│   ├── main_menu.gd / .tscn    # Title screen, character creator, and audio/keyword settings
│   └── framework_sandbox.gd / .tscn # Core playable chamber with lighting, combat, clues, and interrogation
├── ui/                         # User Interface
│   ├── ui_theme.gd             # Procedural dark-fantasy UI styling factory (StyleBoxFlat)
│   ├── hud.gd / .tscn          # In-game HUD, case dossier modal, and ritual completion screen
│   └── interrogation_ui.gd / .tscn # Suspect interrogation window, voice waveform, and verdict altar UI
├── assets/                     # Visual & Audio Assets
│   ├── sprites/                # Floor/wall tiles, character skins, environment props, and light masks
│   ├── portraits/              # Character and suspect portraits for dialogue interfaces
│   ├── ui/                     # Menu background artwork
│   ├── audio/                  # Combat, movement, environment, and UI sound effects (.wav)
│   └── voice/                  # Pre-rendered Russian voiceover clips (.mp3)
└── tools/                      # Python Content Generation Utilities
    ├── sprite_generator.py     # Procedural 2x-supersampled (LANCZOS) sprite and icon generator
    ├── voice_generator.py      # Batch neural Russian voiceover synthesizer
    └── live_tts_worker.py      # Background worker for real-time dynamic dialogue speech generation
```

---

## 4. Tools & Custom Assets

All code, visual assets, and audio resources in this repository were created in-house without relying on third-party proprietary asset packs:
- **Graphics (`assets/sprites/`, `assets/portraits/`, `assets/ui/`):** Stone and earth tiles, male and female character sprites across three armor sets, enemy sprites, interactive props (chests, breakable barrels, iron gates, ritual altar, runic evidence), and smooth radial/cone light textures (`light_cone.png`, `light_radial.png`). Custom sprites are generated via `tools/sprite_generator.py` using Python `Pillow` with 2x supersampling (`LANCZOS`).
- **Audio & Voiceovers (`assets/audio/`, `assets/voice/`):** Procedurally synthesized `.wav` sound effects for sword slashes, elemental spells, dashes, locks, and UI interactions, paired with batch and real-time Russian neural speech generation scripts (`tools/voice_generator.py`, `tools/live_tts_worker.py`).

---

## 5. Running the Project & Requirements

- **Engine:** Godot Engine **4.7.2 Standard** (GDScript).

- **Renderer:** `GL Compatibility` (ensures stable performance across desktop GPUs and integrated graphics).
- **Quick Start on Windows:**
  - Run **`PLAY_GAME.bat`** in the project root to launch the game directly (automatically initializes imported resources on first run if `.godot/` is absent).
  - Run **`OPEN_EDITOR.bat`** to open the project in the Godot 4.7.2 Editor (press `F5` to play).
  - The project can be exported to a standalone Windows executable (`.exe`) via `Project -> Export` in the Godot Editor.


  ## 6. License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.
