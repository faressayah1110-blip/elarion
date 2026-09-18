# Elarion — Phase 1: Multiplayer Core Slice

## Vision

Elarion is a long-term goal to build a WoW-like mobile MMORPG: a persistent
fantasy world, class-based combat, quests, dungeons, and eventually guilds
and an economy at MMO scale (dozens/hundreds of concurrent players).

That full scope is a multi-phase effort. A true persistent MMO backend
(dedicated server, database, matchmaking) is a separate, large engineering
project outside what Summer Engine's built-in multiplayer tooling provides.
This spec covers only **Phase 1**: a small shared-session slice that proves
the core gameplay feels good and works in real-time multiplayer, before any
backend/persistence work begins.

## Phase 1 Goal

2-8 players join a single host's session, explore one small zone together,
fight enemies, and complete a couple of simple quests — all playing the same
melee Warrior class, in third-person action combat, on mobile touch controls.

## Explicitly Out of Scope (Phase 1)

- Multiple classes (Warrior only)
- Dungeons/instances
- Persistence (no save/load; progress resets each session)
- Dedicated server / backend / database
- Guilds, economy, auction house
- Character creation beyond entering a name
- Host migration (if the host leaves, the session ends)

## Architecture

- **Engine:** Summer Engine (Godot 4.6 technical base), GDScript.
- **Networking:** Host-authoritative multiplayer using Godot's high-level
  multiplayer API (ENet). One player's device is the host and runs the
  authoritative simulation (positions, health, combat resolution, quest
  state). Clients send input and render locally, per Summer's
  `host-authoritative-state` and `peer-to-peer-multiplayer` skill guidance.
- **Scene structure:**
  - `World` scene: the zone, holds environment, `EnemySpawner`, and quest
    triggers/locations.
  - `Character` scene: spawned per player on join (host-owned authority),
    with movement, camera rig, combat, and ability components.
  - `QuestState`: an autoload/singleton, host-owned, replicated to clients
    via RPC as state changes.
- **Camera:** Third-person, follows behind the Warrior.

## Core Systems

- **Movement & camera:** Virtual joystick (left thumb) for movement,
  relative to camera facing. Camera auto-follows behind the character, with
  drag-to-orbit.
- **Combat:** Basic melee attack (forward arc, on a button), plus 2-3
  ability buttons on cooldown: a gap-closer charge, a heavy strike, and a
  defensive block/parry. All damage/health resolution happens on the host
  and is replicated to clients via RPC.
- **Enemies:** Simple AI loop (aggro radius → chase → attack → reset).
  1-2 enemy types. Host-authoritative, same as players.
- **Quests:** 2-3 simple quests (e.g. kill N enemies, reach a location),
  tracked in `QuestState`. Host validates completion and broadcasts updates
  to all clients.
- **UI/HUD:** Health bar, ability buttons, virtual joystick, minimal quest
  tracker. Designed for phone screens/touch safe areas.
- **Art style:** Semi-realistic, WoW-inspired character and environment
  style (not stylized low-poly).

## Error Handling

- Player disconnect: despawn their character on the host, notify remaining
  clients.
- Player reconnect: not supported in Phase 1 (rejoin as a fresh spawn if
  they reconnect before the session ends).
- Host disconnect: session ends for all clients (no host migration in
  Phase 1 — an accepted limitation).

## Testing / Verification

- Multiplayer correctness verified by running 2+ local engine instances
  side by side (per Summer's `agent-playtesting` / `playtesting-a-feature`
  skills): confirm players see each other move and fight, combat damage/
  cooldowns resolve correctly and consistently across clients, and quest
  progress/completion replicates to all connected players.
- Manual playtesting of mobile controls (joystick, camera drag, ability
  buttons) for feel, on top of the automated verification above.

## Future Phases (not in this spec)

- **Phase 2:** Dedicated authoritative server + database for persistence,
  replacing the host-authoritative model.
- **Phase 3:** Scale out — sharding/zones, more concurrent players, guilds,
  economy.
