# Product Requirements Document: Swarm Dominion

**Working Title:** Swarm Dominion  
**Version:** 1.1 Draft  
**Last Updated:** January 2026  
**Author:** John Burbridge, Founder, Spiral House, LLC

-----

## 1. Executive Summary

### 1.1 Vision Statement

Swarm Dominion is a fast-paced real-time strategy game where alien monster factions battle for territorial control. Designed for matches lasting 5-15 minutes, it offers the strategic depth of classic RTS games with a dramatically lower barrier to entry.

### 1.2 Elevator Pitch

"What if StarCraft matches lasted 10 minutes, every unit mattered, you didn't need to memorize 50-unit build orders to compete—and it was completely free?"

Swarm Dominion is a free, open source RTS that eliminates dedicated worker units entirely. Every creature in your swarm can gather resources or fight—the choice is yours, every second. Capture and hold control points to win, or destroy your opponent's Mothers to end the game decisively.

### 1.3 Target Audience

**Primary:** Lapsed RTS players (25-45) who loved StarCraft/Warcraft but no longer have time for 30-45 minute matches or the patience to relearn complex build orders.

**Secondary:** Competitive players seeking a fresh, skill-expressive RTS with ranked matchmaking.

**Tertiary:** Casual strategy gamers looking for quick, satisfying matches during breaks.

### 1.4 Unique Value Proposition

|Traditional RTS                   |Swarm Dominion                              |
|----------------------------------|--------------------------------------------|
|$40-60 price tag                  |Free and open source                        |
|Dedicated workers sit idle at base|All units gather or fight—constant decisions|
|20-45 minute matches              |5-15 minute matches                         |
|Complex build orders required     |Simple start, depth emerges from choices    |
|Many buildings to manage          |No buildings—only mobile Mothers            |
|Army size = resources spent       |Army strength = upgrade investment          |

### 1.5 Platform & Requirements

- **Platforms:** Windows 10/11, macOS 12+
- **Minimum Specs:** Integrated graphics (Intel UHD 620 or equivalent), 4GB RAM, 2GB storage
- **Target Performance:** 60 FPS at 1080p on minimum specs

-----

## 2. Game Design

### 2.1 Core Loop

```
┌─────────────────────────────────────────────────────────────┐
│                        CORE LOOP                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   GATHER ──────► DECIDE ──────► EXECUTE ──────► ADAPT      │
│      │             │               │               │        │
│      │         Upgrade OR      Attack OR        React to    │
│      │         Spawn new       Defend OR        opponent    │
│      │         units           Capture          choices     │
│      │                                                      │
│      └──────────────────────────────────────────────────────┘
│                           │
│                    Every 2-5 seconds
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

The core loop creates constant tension: resources used for upgrades can't spawn new units, units gathering can't fight, units fighting can't gather. There is no "idle time."

### 2.2 Win Conditions

**Primary: Control Point Victory**

Maps contain 3-5 control points. Capture a point by having units in its zone with no enemies present. Capture time varies by strategic value (accessible points take longer).

**Victory Point System: Proportional Control**

VP accumulates based on the *difference* in control points held:

| Your Points | Enemy Points | VP/Second |
|-------------|--------------|-----------|
| 3           | 2            | +1        |
| 4           | 1            | +3        |
| 5           | 0            | +5        |
| 2           | 3            | -1        |
| 1           | 4            | -3        |
| 0           | 5            | -5        |

**Victory Threshold:** 300 VP

**Design Rationale:**

- **Stalemates (2-2-1 split):** One player is always gaining VP, preventing passive play
- **Comeback potential:** Losing player can flip the VP direction by recapturing a single point
- **Snowball prevention:** Even 5-0 control only gains 5 VP/sec, giving ~60 seconds to respond

**Expected Match Length:**

- Close match (trading points): 10-15 minutes
- Dominant performance (4-5 points held): 5-8 minutes
- Complete domination (5-0 from early game): 3-5 minutes

**Alternative System: Threshold Ticks (Reserved for Playtesting)**

If Proportional Control feels too abstract or snowbally during playtesting, consider this alternative:

- Holding majority triggers a "tick" every 30 seconds
- Each tick awards 50 VP
- Victory Threshold: 300 VP (6 ticks to win)
- Creates clear "rounds" of control with tension around tick timing
- More readable for spectators and new players
- Trade-off: Less granular, stalemates feel more punishing

**Secondary: Elimination Victory**

- Destroy all enemy Mother units
- Instant win regardless of control point status
- High-risk, high-reward strategy

### 2.3 Resource System

**Single Resource: Biomass**

- Collected from Biomass Nodes scattered across the map
- All combat units can harvest (not Mothers)
- Harvesting requires standing at a node for a duration
- Units cannot attack while harvesting
- Nodes deplete temporarily, regenerate over time
- Strategic node placement creates map control incentives

**Resource Uses:**

- Spawning new units (from Mothers)
- Upgrading existing units
- Evolving Mothers (to increase supply cap)

### 2.4 Supply System

**Supply Mechanics:**

- Each Mother provides base supply (e.g., 10 supply)
- Mothers can be evolved to provide more supply (costs resources)
- Higher-level units consume more supply:
  - Level 1 unit: 1 supply
  - Level 2 unit: 2 supply
  - Level 3 unit: 3 supply
- Supply cap creates strategic choice: many weak units vs. few elite units

**Mother Units:**

- Spawn at match start (1-2 per player depending on mode)
- Mobile but slow
- Cannot harvest resources
- High HP pool (difficult but not impossible to kill)
- Only unit that can spawn new units
- Can be evolved to increase supply cap
- Destruction = alternate loss condition

### 2.5 Unit System

**Universal Unit Rules:**

- All units spawn as generic Level 1
- Level 1 units are multi-purpose (moderate at everything)
- At Level 2, units specialize into a role
- Level 3 units excel at their specialization
- Upgrading costs progressively more resources
- Death = total investment loss

**Starting Faction: The Swarm (Working Name)**

|Unit |Level 1              |Level 2 Paths                                    |Level 3                   |
|-----|---------------------|-------------------------------------------------|--------------------------|
|Drone|Generic multi-purpose|Hunter (damage) / Guardian (tank) / Scout (speed)|Elite version of L2 choice|

**Level 1 - Drone:**

- Moderate movement speed
- Moderate damage
- Moderate HP
- Can harvest resources
- Cheap to produce

**Level 2 Specializations:**

*Hunter Path (Damage Dealer):*

- Increased damage output
- Slightly reduced HP
- Faster attack speed
- Effective against other units

*Guardian Path (Tank):*

- Significantly increased HP
- Reduced movement speed
- Moderate damage
- Effective at holding positions

*Scout Path (Mobility):*

- Significantly increased movement speed
- Reduced HP
- Moderate damage
- Faster harvest speed
- Excellent for map control and harassment

**Level 3 - Elite:**

- 50% improvement to specialization stats
- Visual distinction (size, effects)
- Same role as Level 2 choice

### 2.6 Control Point Mechanics

**Capture Rules:**

- Unit must be within capture zone
- No enemy units can be in the zone (contested = no capture progress)
- Capture progress shown via UI indicator
- Multiple friendly units do NOT speed up capture
- Capture progress resets if zone becomes contested
- Once captured, point remains yours until enemy captures it

**Strategic Point Values:**

- Central points: Easier to access, longer capture time, higher VP generation
- Edge points: Harder to access, shorter capture time, lower VP generation
- Map-specific variations add replayability

### 2.7 Combat System

**Basic Combat:**

- Units automatically attack enemies in range
- Attack-move and hold-position commands
- No ammunition or cooldown abilities (initially)
- Damage types: Physical (default)
- Simple attack/HP/speed stats determine outcomes

**Combat Priority (AI):**

- Units prioritize nearest enemy by default
- Can be manually targeted
- Mothers are never auto-targeted (must be manually selected)

### 2.8 Fog of War

- Full fog of war system
- Units provide vision radius
- Control points provide small vision radius when captured
- No permanent vision (no static structures)

-----

## 3. Technical Architecture

### 3.1 Engine & Tools

**Game Engine:** Godot 4.x

- GDScript for gameplay logic
- C++ (GDExtension) for performance-critical systems if needed later

**Rationale:**

- Python-like syntax aligns with developer's background
- Excellent 2D support with path to isometric
- Zero royalties or revenue share
- Lightweight, runs on integrated graphics
- Built-in multiplayer networking
- Active community and documentation

### 3.2 Project Structure

```
swarm-dominion/
├── LICENSE                 # MIT License
├── README.md               # Project overview, getting started
├── CONTRIBUTING.md         # Contribution guidelines
├── project.godot
├── assets/
│   ├── sprites/
│   ├── audio/
│   └── ui/
├── scenes/
│   ├── units/
│   ├── maps/
│   ├── ui/
│   └── main/
├── scripts/
│   ├── units/
│   ├── systems/
│   │   ├── resource_system.gd
│   │   ├── supply_system.gd
│   │   ├── control_point_system.gd
│   │   └── combat_system.gd
│   ├── ai/
│   ├── networking/
│   └── utils/
├── server/                 # Dedicated server application
│   ├── README.md           # Server hosting guide
│   └── ...
├── data/
│   ├── unit_stats.json
│   ├── upgrade_costs.json
│   └── map_definitions/
├── docs/                   # Documentation and wiki source
└── tests/
```

**Repository:** Hosted on GitHub under Spiral House organization. Public repository with:

- Issue tracking for bugs and feature requests
- Discussions for community Q&A
- Wiki for game documentation and modding guides
- Project board for development roadmap visibility

### 3.3 Multiplayer Architecture

**Model:** Client-Server with Deterministic Lockstep

**Why Lockstep:**

- Industry standard for competitive RTS
- Minimal bandwidth (only inputs transmitted)
- Guarantees identical game state
- Enables replay system
- Required for anti-cheat in ranked play

**Server Responsibilities:**

- Validate player inputs
- Broadcast inputs to all clients
- Maintain authoritative tick counter
- Handle disconnection/reconnection
- Record match replays

**Client Responsibilities:**

- Simulate game locally
- Send inputs to server
- Render at local framerate
- Handle input prediction (optional later)

**Initial Hosting:**

- Self-hosted dedicated servers on existing hardware
- Migrate to cloud hosting (AWS/Vultr) for beta/launch

### 3.4 Steam Integration

**Required Features:**

- Steamworks authentication
- Achievements
- Cloud saves
- Leaderboards
- Matchmaking (later milestone)
- Workshop support (future: custom maps)

**Library:** GodotSteam (community-maintained Godot plugin)

### 3.5 Data Architecture

**Local Storage:**

- Player preferences (JSON)
- Keybindings (JSON)
- Graphics settings (JSON)
- Replay files (binary)

**Server/Cloud Storage:**

- Player profiles
- Match history
- Leaderboard rankings
- Unlocked cosmetics

**Database:** PostgreSQL for player data, Redis for leaderboard caching

-----

## 4. Development Milestones

### Philosophy

Each milestone produces a **playable, testable build**. Milestones are scoped for 2-4 weeks of part-time development. Early milestones focus on learning Godot while building foundational systems.

### Milestone Overview

|# |Milestone          |Duration|Deliverable                             |
|--|-------------------|--------|----------------------------------------|
|0 |Hello Godot        |2 weeks |Unit moves on screen, responds to clicks|
|1 |Basic Combat       |2 weeks |Two units fight, one dies               |
|2 |Selection & Control|2 weeks |Select multiple units, attack-move      |
|3 |Resource Gathering |3 weeks |Units harvest from nodes                |
|4 |Mothers & Spawning |3 weeks |Mother unit spawns drones               |
|5 |Supply System      |2 weeks |Supply cap limits army size             |
|6 |Unit Upgrades      |3 weeks |Level 1→2→3 progression                 |
|7 |Control Points     |3 weeks |Capture mechanics, victory condition    |
|8 |Fog of War         |2 weeks |Vision system                           |
|9 |Basic AI           |4 weeks |Computer opponent (easy difficulty)     |
|10|Local Multiplayer  |2 weeks |Two players, one machine                |
|11|Network Foundation |4 weeks |Basic client-server connection          |
|12|Networked Gameplay |4 weeks |Full 1v1 over network                   |
|13|Steam Integration  |3 weeks |Auth, achievements, leaderboards        |
|14|Matchmaking        |3 weeks |Ranked queue, ELO system                |
|15|Polish & Balance   |6 weeks |UI, audio, balance tuning               |
|16|Beta Release       |2 weeks |Public beta on Steam                    |

**Total Estimated Time:** ~45 weeks (accounting for learning curve and iteration)

-----

### Milestone 0: Hello Godot

**Goal:** Learn Godot basics, establish project structure  
**Duration:** 2 weeks

**Deliverables:**

- [ ] Godot 4 installed and configured
- [ ] Project created with folder structure
- [ ] Single unit sprite on screen
- [ ] Unit moves to clicked location (pathfinding later)
- [ ] Camera follows unit
- [ ] Basic movement animation (2-4 frames)

**Testable Outcome:** Click anywhere, unit walks there smoothly

**Learning Focus:** Scenes, nodes, GDScript basics, input handling, CharacterBody2D

-----

### Milestone 1: Basic Combat

**Goal:** Two units can fight  
**Duration:** 2 weeks

**Deliverables:**

- [ ] Health system (HP, damage, death)
- [ ] Attack behavior (unit attacks enemy in range)
- [ ] Death animation and removal
- [ ] Health bar UI above units
- [ ] Spawn two opposing units for testing

**Testable Outcome:** Two units approach each other, fight, one dies

**Learning Focus:** Signals, Area2D detection, UI basics, state machines

-----

### Milestone 2: Selection & Control

**Goal:** RTS-style unit selection  
**Duration:** 2 weeks

**Deliverables:**

- [ ] Click to select single unit
- [ ] Drag box to select multiple units
- [ ] Selection highlight visual
- [ ] Right-click to move selected units
- [ ] Attack-move command (A + click)
- [ ] Unit grouping (Ctrl+1 to assign, 1 to recall)
- [ ] Minimap (basic)

**Testable Outcome:** Select 5 units, group them, attack-move across map

**Learning Focus:** Input handling, UI overlays, group management

-----

### Milestone 3: Resource Gathering

**Goal:** Units collect resources  
**Duration:** 3 weeks

**Deliverables:**

- [ ] Biomass Node scene (harvestable object)
- [ ] Harvest command (right-click node while unit selected)
- [ ] Harvest animation and progress bar
- [ ] Resource counter UI
- [ ] Node depletion and regeneration
- [ ] Multiple nodes placed on test map

**Testable Outcome:** Send units to gather, watch resource counter increase, node depletes

**Learning Focus:** Timers, resource management patterns, UI updates

-----

### Milestone 4: Mothers & Spawning

**Goal:** Mother unit spawns new units  
**Duration:** 3 weeks

**Deliverables:**

- [ ] Mother unit scene (large, slow, high HP)
- [ ] Spawn command UI (click Mother, click spawn button)
- [ ] Spawn costs resources
- [ ] Spawn animation (unit emerges from Mother)
- [ ] Rally point (spawned units go to designated location)
- [ ] Mother movement (slow but mobile)

**Testable Outcome:** Gather resources, spawn units from Mother, set rally point

**Learning Focus:** Unit factories, UI panels, more complex state machines

-----

### Milestone 5: Supply System

**Goal:** Army size limited by supply  
**Duration:** 2 weeks

**Deliverables:**

- [ ] Supply counter UI (current/max)
- [ ] Units consume supply when spawned
- [ ] Cannot spawn if supply capped
- [ ] Mother evolution mechanic (spend resources to increase supply cap)
- [ ] Visual feedback when supply blocked

**Testable Outcome:** Hit supply cap, evolve Mother, spawn more units

**Learning Focus:** Resource constraints, upgrade systems

-----

### Milestone 6: Unit Upgrades

**Goal:** Level 1→2→3 progression  
**Duration:** 3 weeks

**Deliverables:**

- [ ] Upgrade command (select unit, click upgrade)
- [ ] Level 2 specialization choice UI (Hunter/Guardian/Scout)
- [ ] Stat changes per level/specialization
- [ ] Visual changes per level (size, color tint, effects)
- [ ] Supply cost increases with level
- [ ] Level 3 upgrade (no choice, enhances L2 path)

**Testable Outcome:** Upgrade drone to L2 Hunter, then L3, observe stat changes

**Learning Focus:** Data-driven design, stat systems, visual feedback

-----

### Milestone 7: Control Points

**Goal:** Capture mechanics and victory condition  
**Duration:** 3 weeks

**Deliverables:**

- [ ] Control Point scene (capturable zone)
- [ ] Capture progress when units in zone
- [ ] Contested state (no progress if enemies present)
- [ ] Ownership indicator (team color)
- [ ] Victory Point accumulation (Proportional Control system)
- [ ] Victory Point UI (showing current VP and rate)
- [ ] Win condition check (300 VP threshold) and victory screen

**Testable Outcome:** Capture points, hold majority, win via VP threshold

**Learning Focus:** Zone detection, game state management, win conditions

-----

### Milestone 8: Fog of War

**Goal:** Vision system  
**Duration:** 2 weeks

**Deliverables:**

- [ ] Fog overlay (unexplored = black, explored = dim, visible = clear)
- [ ] Unit vision radius
- [ ] Control point vision when owned
- [ ] Enemy units hidden in fog
- [ ] Minimap shows fog state

**Testable Outcome:** Move units, reveal map, lose vision when units leave

**Learning Focus:** Shaders or viewport tricks, visibility systems

-----

### Milestone 9: Basic AI

**Goal:** Playable single-player vs computer  
**Duration:** 4 weeks

**Deliverables:**

- [ ] AI controller (replaces player input)
- [ ] Resource gathering behavior
- [ ] Unit spawning decisions
- [ ] Attack behavior (send units to fight)
- [ ] Control point awareness
- [ ] Easy difficulty (predictable, beatable)
- [ ] Skirmish mode: Player vs AI

**Testable Outcome:** Start skirmish, play full match vs AI, win or lose

**Learning Focus:** Behavior trees or state machines for AI, decision-making

**Note:** AI will be iteratively improved throughout development

-----

### Milestone 10: Local Multiplayer

**Goal:** Two players, one machine  
**Duration:** 2 weeks

**Deliverables:**

- [ ] Split controls (Player 1: mouse+WASD, Player 2: controller or alternate keys)
- [ ] Separate fog of war per player
- [ ] Turn-based or simultaneous input handling
- [ ] Local match setup UI

**Testable Outcome:** Two humans play 1v1 on same computer

**Learning Focus:** Multi-input handling, local multiplayer patterns

**Note:** This milestone is optional but useful for testing before networking

-----

### Milestone 11: Network Foundation

**Goal:** Basic client-server communication  
**Duration:** 4 weeks

**Deliverables:**

- [ ] Dedicated server application
- [ ] Client connection flow (connect to IP)
- [ ] Player authentication (basic, pre-Steam)
- [ ] Lobby system (host game, join game)
- [ ] Synchronized game start

**Testable Outcome:** Two clients connect to server, enter lobby, start match

**Learning Focus:** Godot's high-level multiplayer API, networking fundamentals

-----

### Milestone 12: Networked Gameplay

**Goal:** Full 1v1 over network  
**Duration:** 4 weeks

**Deliverables:**

- [ ] Deterministic lockstep implementation
- [ ] Input transmission and synchronization
- [ ] Desync detection
- [ ] Basic reconnection handling
- [ ] Replay recording (inputs + initial state)
- [ ] Network performance monitoring (latency display)

**Testable Outcome:** Complete 1v1 match over internet without desyncs

**Learning Focus:** Deterministic simulation, lockstep networking, state synchronization

-----

### Milestone 13: Steam Integration

**Goal:** Steam features working  
**Duration:** 3 weeks

**Deliverables:**

- [ ] GodotSteam integration
- [ ] Steam authentication
- [ ] Basic achievements (Win first match, etc.)
- [ ] Cloud save for settings
- [ ] Leaderboard posting (win/loss record)
- [ ] Steam overlay working

**Testable Outcome:** Launch via Steam, earn achievement, see leaderboard

**Learning Focus:** Steamworks SDK, GodotSteam plugin

-----

### Milestone 14: Matchmaking

**Goal:** Ranked play system  
**Duration:** 3 weeks

**Deliverables:**

- [ ] ELO/MMR rating system
- [ ] Matchmaking queue
- [ ] Match players of similar skill
- [ ] Ranked leaderboard
- [ ] Match history
- [ ] Basic anti-cheat (server-side validation)

**Testable Outcome:** Queue for ranked, get matched, rating updates after game

**Learning Focus:** Matchmaking algorithms, rating systems, backend services

-----

### Milestone 15: Polish & Balance

**Goal:** Release-quality experience  
**Duration:** 6 weeks

**Deliverables:**

- [ ] Complete UI overhaul (menus, HUD, settings)
- [ ] Sound effects for all actions
- [ ] Background music (AI-generated)
- [ ] Visual effects polish (attacks, deaths, upgrades)
- [ ] Tutorial/How to Play
- [ ] Balance pass (unit stats, costs, timings)
- [ ] Multiple maps (3-5 competitive maps)
- [ ] Accessibility options (colorblind mode, UI scaling)
- [ ] Performance optimization
- [ ] Bug fixing from playtesting

**Testable Outcome:** Full game feels polished, fun, and balanced

-----

### Milestone 16: Beta Release

**Goal:** Public availability on Steam and GitHub  
**Duration:** 2 weeks

**Deliverables:**

- [ ] Steam store page (Free to Play)
- [ ] Trailer video
- [ ] Store assets (screenshots, description)
- [ ] Beta branch deployment on Steam
- [ ] GitHub release with downloadable builds
- [ ] Server deployment documentation
- [ ] Feedback collection system (Discord, GitHub Issues)
- [ ] Patch deployment pipeline

**Testable Outcome:** Players can download and play beta via Steam or GitHub

-----

## 5. Future Milestones (Post-Beta)

These are not part of initial development but inform design decisions:

- **Milestone 17:** Additional Factions (Reptilian, Insectoid)
- **Milestone 18:** Team Modes (2v2, FFA)
- **Milestone 19:** Cosmetic Store
- **Milestone 20:** Ranked Seasons
- **Milestone 21:** Map Editor / Workshop
- **Milestone 22:** 2.5D Isometric Art Upgrade
- **Milestone 23:** Mobile Port (stretch goal)

-----

## 6. Business Model

### 6.1 Open Source Philosophy

**License:** MIT License

Swarm Dominion is fully open source. The complete game client, server software, and all gameplay assets are freely available under the MIT license. Anyone can:

- Play the game for free (offline or online)
- Host private servers for friends or communities
- Modify the game (mods, total conversions)
- Fork the codebase for their own projects
- Contribute bug fixes and improvements

**Why Open Source:**

- Builds trust with the competitive community (no hidden mechanics)
- Encourages community contributions and engagement
- Generates goodwill and word-of-mouth in an underserved genre
- Aligns with the primary goal: make a great game people love

**Repository:** GitHub (public repository with issue tracking, wiki, and discussions)

### 6.2 Access Model

|Play Mode                    |Cost             |
|-----------------------------|-----------------|
|Offline vs AI                |Free             |
|Private servers (self-hosted)|Free             |
|Official ranked servers      |Free             |
|Cosmetics                    |Optional purchase|

**No subscriptions. No pay-to-play. No pay-to-win.**

Players can experience 100% of gameplay without spending money. Cosmetics are the only monetization, and they provide zero competitive advantage.

### 6.3 Cosmetic Monetization

**Cosmetic Types:**

- Unit skins (color schemes, visual variants)
- Mother skins (unique appearances)
- Victory animations
- Player profile icons
- Player banners

**Pricing Tiers:**

- Common: $0.99-1.99
- Rare: $2.99-4.99
- Epic: $4.99-7.99
- Bundles: $9.99-14.99

**Design Rules:**

- Cosmetics are visual only—no gameplay impact
- Clearly communicate "cosmetic only" in store
- No loot boxes—direct purchase only
- No battle pass (initially)
- Skins must not obscure unit type, level, or team color

**Future Consideration:** Optional "Supporter" tier ($5/month) with exclusive cosmetics and profile badge—no gameplay advantages. Only implement if community requests a way to support ongoing development.

### 6.4 Distribution

**Primary Platform:** Steam (Free to Play)

- Largest PC gaming audience
- Built-in matchmaking infrastructure
- Community features (forums, reviews)
- Free-to-play games can still sell cosmetics via Steam

**Source Code:** GitHub

- Public repository
- Community contributions via pull requests
- Issue tracking for bugs and feature requests
- Wiki for documentation and modding guides

**Secondary (Future):**

- itch.io (indie-friendly, pay-what-you-want option)
- Direct download from project website

### 6.5 Server Infrastructure

**Official Servers (Spiral House operated):**

- Free access for all players
- Ranked matchmaking and leaderboards
- Anti-cheat enforcement
- Authoritative match history and replays
- Funded by cosmetic sales

**Private Servers (Community operated):**

- Server software freely available
- Full documentation for self-hosting
- No restrictions on modifications
- Cannot access official leaderboards (by design)

### 6.6 Marketing Strategy

**Pre-Launch:**

- Devlog posts (Reddit, Twitter/X, YouTube)
- Open development—share progress on GitHub
- Playable builds at key milestones (downloadable, not just demos)
- Engage RTS communities (r/RealTimeStrategy, TeamLiquid forums)

**Launch:**

- Steam free-to-play launch
- GitHub repository announcement
- Gaming press outreach (open source angle is unique)
- Streamer outreach (free game = easy for them to try)

**Post-Launch:**

- Regular update cadence (transparent roadmap on GitHub)
- Community tournaments (low prize pools, high engagement)
- Highlight community contributions and mods
- Seasonal cosmetic releases

-----

## 7. Risk Assessment

### 7.1 Technical Risks

|Risk                           |Probability|Impact|Mitigation                                         |
|-------------------------------|-----------|------|---------------------------------------------------|
|Networking desync bugs         |High       |High  |Start deterministic design early, extensive testing|
|Performance on low-end hardware|Medium     |High  |Regular performance profiling, scalable settings   |
|Godot learning curve           |Medium     |Medium|Milestone 0 dedicated to learning                  |
|Steam integration issues       |Low        |Medium|Use well-documented GodotSteam, test early         |

### 7.2 Design Risks

|Risk                       |Probability|Impact  |Mitigation                               |
|---------------------------|-----------|--------|-----------------------------------------|
|Game isn't fun             |Medium     |Critical|Playtest every milestone, iterate early  |
|Snowball/balance problems  |High       |High    |Data-driven balancing, community feedback|
|Matches too short/long     |Medium     |Medium  |Tunable VP threshold, playtesting        |
|Control points feel passive|Medium     |Medium  |Add events/modifiers if needed           |

### 7.3 Business Risks

|Risk                               |Probability|Impact|Mitigation                                           |
|-----------------------------------|-----------|------|-----------------------------------------------------|
|Low cosmetic revenue               |Medium     |Medium|Keep server costs minimal; Patreon as backup         |
|Server costs exceed revenue        |Medium     |Medium|Start self-hosted; scale only with proven demand     |
|Fork competes with official        |Low        |Low   |You control the brand, leaderboard, and community    |
|Free-to-play attracts toxic players|Medium     |Medium|Strong moderation, report system, ranked requirements|
|RTS market is niche                |Medium     |Low   |Free game = low barrier; open source = unique angle  |

### 7.4 Scope Risks

|Risk                    |Probability|Impact|Mitigation                               |
|------------------------|-----------|------|-----------------------------------------|
|Feature creep           |High       |High  |Strict milestone scope, defer to "future"|
|Single developer burnout|Medium     |High  |Sustainable pace, celebrate milestones   |
|Timeline slippage       |High       |Medium|Buffer time built into estimates         |

-----

## 8. Success Metrics

### 8.1 Development Metrics

- Each milestone completed within 150% of estimated time
- Playable build after every milestone
- Zero critical bugs in milestone deliverables

### 8.2 Beta Metrics

- 500+ beta players
- Average match completion rate > 80%
- Average session length > 20 minutes
- Net Promoter Score > 30

### 8.3 Launch Metrics (First 3 Months)

- 10,000+ total downloads
- 1,000+ daily active players (peak)
- Steam review score > 70% positive
- Average playtime > 5 hours per player
- GitHub: 100+ stars, 20+ forks

### 8.4 Long-Term Metrics (Year 1)

- 50,000+ total downloads
- 2,000+ daily active players (sustained)
- Active competitive community with regular tournaments
- Discord community with 2,000+ members
- GitHub: 500+ stars, active contributor community
- Cosmetic revenue covers server hosting costs (break-even goal)

### 8.5 Community Health Metrics

- Average queue time < 2 minutes (1v1 ranked)
- Player retention: 30% of new players return after 7 days
- Community contributions: 10+ merged pull requests from non-core contributors
- Active modding scene (if applicable)

-----

## 9. Open Questions

Items requiring further discussion or playtesting to resolve:

1. **Upgrade costs:** What's the right curve? Linear, exponential, or custom?
2. **Mother count:** Start with 1 or 2 Mothers? Respawn if all die (with penalty) or permanent elimination?
3. **Map size:** How large for 5-15 minute matches? Number of resource nodes?
4. **Unit speeds:** How fast should movement be? RTS games vary widely here.
5. **Matchmaking region:** Global queue or regional servers? Depends on player population.
6. **Faction 2 & 3 timing:** Add before or after launch? Balancing multiple factions is complex.
7. **Replay sharing:** Built-in or rely on file sharing?

-----

## 10. Glossary

|Term               |Definition                                                                              |
|-------------------|----------------------------------------------------------------------------------------|
|Biomass            |The single resource used for spawning, upgrading, and evolving                          |
|Control Point      |A capturable zone on the map that generates Victory Points                              |
|Drone              |The basic Level 1 unit that all units start as                                          |
|Lockstep           |Networking model where all clients simulate the same game state                         |
|Mother             |The only unit that can spawn new units; provides supply                                 |
|Proportional Control|VP system where points accumulate based on the difference in control points held       |
|Supply             |The cap on how many units (weighted by level) you can have                              |
|Threshold Ticks    |Alternative VP system with periodic 50 VP awards for holding majority                   |
|Victory Points (VP)|Accumulated by holding control points; first to 300 VP wins                             |

-----

## Appendix A: Competitive Map Design Principles

1. **Symmetry:** All competitive maps must be rotationally or mirror symmetric
2. **Spawn distance:** Players start far enough apart for 30-60 seconds of setup
3. **Resource accessibility:** Nearby "safe" nodes, contested "rich" nodes in center
4. **Control point distribution:** One central high-value point, 2-4 peripheral lower-value points
5. **Choke points:** Natural defensive positions that can be contested
6. **Size:** Tuned for 5-15 minute matches (requires playtesting to determine)

-----

## Appendix B: AI Difficulty Scaling (Future Reference)

|Difficulty|Behavior                                                            |
|----------|--------------------------------------------------------------------|
|Easy      |Slow reactions, limited multitasking, predictable army composition  |
|Medium    |Faster reactions, basic micro, mixed army composition               |
|Hard      |Near-instant reactions, good micro, adaptive strategies             |
|Brutal    |Optimized gathering/spawning, strong micro, counters player strategy|

-----

## Appendix C: Cosmetic Design Guidelines

1. **Clarity first:** Skins must not obscure unit type or level
2. **Faction identity:** Skins should feel like variants of the faction, not entirely new creatures
3. **Team colors:** Ensure team identification remains clear
4. **No competitive advantage:** Same hitboxes, same visual tells for attacks

-----

*End of Document*
