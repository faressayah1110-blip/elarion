# Elarion Phase 1: Multiplayer Core Slice Implementation Plan

> **For agentic workers:** implement this plan task-by-task, in order, checking off each step as it lands. Steps use checkbox (`- [ ]`) syntax for tracking. Dispatch a fresh subagent per task where the tasks are independent (see dispatching-parallel-agents), otherwise execute inline with a review checkpoint after each task.

**Goal:** A playable Summer Engine (Godot 4.6) slice where 2-8 players join one host's session, move/fight together as a melee Warrior in a small zone, and complete simple quests — no backend, no persistence.

**Architecture:** Host-authoritative multiplayer over Godot's high-level ENet API. The host runs the authoritative simulation (positions, health, combat, quest state); clients send input and render locally. Game logic (health, cooldowns, quest state) is written as plain GDScript classes with GUT unit tests; scene/engine-dependent work (nodes, networking spawn, camera, UI) is built live through Summer's `summer_*` MCP tools and verified with screenshots/playtests, per `using-summer` and `verifying-scenes`.

**Tech Stack:** Summer Engine / Godot 4.6, GDScript, GUT (Godot Unit Test addon) for logic unit tests, Godot high-level multiplayer (ENetMultiplayerPeer).

---

## Task 0: Engine bring-up (cloud/headless environment)

**Files:** none (environment setup only)

- [ ] **Step 1: Check engine status**

Run: `summer doctor`
Expected: reports `engine: not installed` (as seen at setup time).

- [ ] **Step 2: Install the engine per the running-in-the-cloud skill**

Invoke the `running-in-the-cloud` skill and follow it to install and launch Summer Engine headless in this container (it covers `summer install`, `xvfb-run`/software GL requirements, and `SUMMER_ENGINE_BINARY`/`SUMMER_TOKEN` when no display is present).

- [ ] **Step 3: Verify MCP tools are live**

Run: `summer doctor`
Expected: `Engine` and `Local API` rows both show OK (no longer warnings).

- [ ] **Step 4: Commit nothing (environment-only task)**

No commit — this task only prepares the environment for Task 1 onward.

---

## Task 1: Project scaffold + test harness

**Files:**
- Create: `project.godot` (via `summer new-project`, not hand-written)
- Create: `addons/gut/` (GUT addon, installed not hand-written)
- Create: `tests/unit/test_sanity.gd`
- Create: `scripts/` (empty dir for gameplay scripts, created as files land)

- [ ] **Step 1: Create the Summer project**

Run: `summer new-project --name Elarion --path /home/user/elarion` (or the equivalent `new-project` skill/tool flow — confirm exact invocation with `summer --help` since this is the first project created in this environment)
Expected: `project.godot` exists at `/home/user/elarion/project.godot`.

- [ ] **Step 2: Install GUT via the Godot AssetLib or manual copy into `addons/gut/`, then enable it**

In Project Settings → Plugins, enable GUT (or set it via `summer_ui_actions` per `driving-the-editor-ui`).
Expected: `addons/gut/plugin.cfg` present and GUT enabled in `project.godot`.

- [ ] **Step 3: Write a sanity test**

```gdscript
# tests/unit/test_sanity.gd
extends GutTest

func test_sanity():
    assert_eq(1 + 1, 2)
```

- [ ] **Step 4: Run the test suite headless**

Run: `summer_engine_binary --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: 1 test, 1 pass.

- [ ] **Step 5: Commit**

```bash
git add project.godot addons/gut tests/unit/test_sanity.gd
git commit -m "Scaffold Elarion project with GUT test harness"
```

---

## Task 2: Health component (host-authoritative damage logic)

**Files:**
- Create: `scripts/health.gd`
- Test: `tests/unit/test_health.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/unit/test_health.gd
extends GutTest

func test_damage_reduces_current_health():
    var health := Health.new()
    health.max_health = 100
    health.current = 100
    health.apply_damage(30)
    assert_eq(health.current, 70)

func test_health_does_not_go_below_zero():
    var health := Health.new()
    health.max_health = 100
    health.current = 10
    health.apply_damage(999)
    assert_eq(health.current, 0)

func test_is_dead_when_zero():
    var health := Health.new()
    health.max_health = 100
    health.current = 5
    health.apply_damage(5)
    assert_true(health.is_dead())
```

- [ ] **Step 2: Run test to verify it fails**

Run: `summer_engine_binary --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_health.gd -gexit`
Expected: FAIL — `Health` class does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```gdscript
# scripts/health.gd
class_name Health
extends RefCounted

var max_health: int = 100
var current: int = 100

func apply_damage(amount: int) -> void:
    current = max(0, current - amount)

func is_dead() -> bool:
    return current <= 0
```

- [ ] **Step 4: Run test to verify it passes**

Run: `summer_engine_binary --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_health.gd -gexit`
Expected: 3 tests, 3 pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/health.gd tests/unit/test_health.gd
git commit -m "Add Health component with unit tests"
```

---

## Task 3: Ability cooldown component

**Files:**
- Create: `scripts/ability_cooldown.gd`
- Test: `tests/unit/test_ability_cooldown.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/unit/test_ability_cooldown.gd
extends GutTest

func test_starts_ready():
    var cd := AbilityCooldown.new(5.0)
    assert_true(cd.is_ready())

func test_not_ready_after_use():
    var cd := AbilityCooldown.new(5.0)
    cd.use()
    assert_false(cd.is_ready())

func test_ready_again_after_duration_elapses():
    var cd := AbilityCooldown.new(5.0)
    cd.use()
    cd.tick(5.0)
    assert_true(cd.is_ready())

func test_not_ready_before_duration_elapses():
    var cd := AbilityCooldown.new(5.0)
    cd.use()
    cd.tick(4.9)
    assert_false(cd.is_ready())
```

- [ ] **Step 2: Run test to verify it fails**

Run: `summer_engine_binary --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_ability_cooldown.gd -gexit`
Expected: FAIL — `AbilityCooldown` class does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```gdscript
# scripts/ability_cooldown.gd
class_name AbilityCooldown
extends RefCounted

var duration: float
var _remaining: float = 0.0

func _init(cooldown_duration: float) -> void:
    duration = cooldown_duration

func is_ready() -> bool:
    return _remaining <= 0.0

func use() -> void:
    _remaining = duration

func tick(delta: float) -> void:
    _remaining = max(0.0, _remaining - delta)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `summer_engine_binary --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_ability_cooldown.gd -gexit`
Expected: 4 tests, 4 pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/ability_cooldown.gd tests/unit/test_ability_cooldown.gd
git commit -m "Add AbilityCooldown component with unit tests"
```

---

## Task 4: Quest state logic (kill-N and reach-location quests)

**Files:**
- Create: `scripts/quest_state.gd`
- Test: `tests/unit/test_quest_state.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/unit/test_quest_state.gd
extends GutTest

func test_kill_quest_not_complete_until_target_reached():
    var quest := QuestState.new_kill_quest("kill_wolves", 3)
    quest.record_kill("kill_wolves")
    quest.record_kill("kill_wolves")
    assert_false(quest.is_complete())

func test_kill_quest_complete_at_target():
    var quest := QuestState.new_kill_quest("kill_wolves", 3)
    quest.record_kill("kill_wolves")
    quest.record_kill("kill_wolves")
    quest.record_kill("kill_wolves")
    assert_true(quest.is_complete())

func test_kill_quest_ignores_other_ids():
    var quest := QuestState.new_kill_quest("kill_wolves", 1)
    quest.record_kill("kill_bandits")
    assert_false(quest.is_complete())

func test_reach_location_quest_completes_on_arrival():
    var quest := QuestState.new_reach_quest("find_shrine")
    assert_false(quest.is_complete())
    quest.record_arrival("find_shrine")
    assert_true(quest.is_complete())
```

- [ ] **Step 2: Run test to verify it fails**

Run: `summer_engine_binary --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_quest_state.gd -gexit`
Expected: FAIL — `QuestState` class does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```gdscript
# scripts/quest_state.gd
class_name QuestState
extends RefCounted

enum Kind { KILL, REACH }

var id: String
var kind: Kind
var kill_target_id: String = ""
var kill_count_needed: int = 0
var _kill_count: int = 0
var _arrived: bool = false

static func new_kill_quest(quest_id: String, count_needed: int) -> QuestState:
    var q := QuestState.new()
    q.id = quest_id
    q.kind = Kind.KILL
    q.kill_target_id = quest_id
    q.kill_count_needed = count_needed
    return q

static func new_reach_quest(quest_id: String) -> QuestState:
    var q := QuestState.new()
    q.id = quest_id
    q.kind = Kind.REACH
    return q

func record_kill(killed_id: String) -> void:
    if kind == Kind.KILL and killed_id == kill_target_id:
        _kill_count += 1

func record_arrival(location_id: String) -> void:
    if kind == Kind.REACH and location_id == id:
        _arrived = true

func is_complete() -> bool:
    if kind == Kind.KILL:
        return _kill_count >= kill_count_needed
    return _arrived
```

- [ ] **Step 4: Run test to verify it passes**

Run: `summer_engine_binary --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_quest_state.gd -gexit`
Expected: 4 tests, 4 pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/quest_state.gd tests/unit/test_quest_state.gd
git commit -m "Add QuestState logic with unit tests"
```

---

## Task 5: Networking foundation — host/join and player spawn

**Files:**
- Create: `scripts/network_manager.gd`
- Modify (scene, via MCP tools, not hand-edited): `scenes/world.tscn`

- [ ] **Step 1: Write `NetworkManager` as a plain script (host/join logic is engine-integration code, verified live rather than via GUT since it depends on `multiplayer` singleton networking)**

```gdscript
# scripts/network_manager.gd
class_name NetworkManager
extends Node

const PORT := 7777
const MAX_PLAYERS := 8

signal player_joined(peer_id: int)
signal player_left(peer_id: int)

func host_session() -> void:
    var peer := ENetMultiplayerPeer.new()
    var err := peer.create_server(PORT, MAX_PLAYERS)
    if err != OK:
        push_error("Failed to host session: %s" % err)
        return
    multiplayer.multiplayer_peer = peer
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func join_session(address: String) -> void:
    var peer := ENetMultiplayerPeer.new()
    var err := peer.create_client(address, PORT)
    if err != OK:
        push_error("Failed to join session: %s" % err)
        return
    multiplayer.multiplayer_peer = peer

func _on_peer_connected(peer_id: int) -> void:
    player_joined.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
    player_left.emit(peer_id)
```

- [ ] **Step 2: Use `summer_run_script` to add `NetworkManager` as an autoload named `Net`, and add a `PlayerSpawner` (MultiplayerSpawner) to `scenes/world.tscn` pointed at a `Character` scene path (built in Task 6), following `scene-scripting` for the mutation and `verifying-scenes` for before/after checks**

Run the mutation via `summer_run_script`, then `summer_snapshot_diff` to confirm the autoload and `MultiplayerSpawner` node were added, and `summer_screenshot` to visually confirm the world scene loads without errors.

- [ ] **Step 3: Manually verify host+join with two local engine instances (per `agent-playtesting`)**

Launch two `summer_runtime_*` instances: one calls `Net.host_session()`, the other `Net.join_session("127.0.0.1")`. Use `summer_game_probe` before/after to confirm both `peer_connected` fires on the host and a second player entry exists in the multiplayer peer list.
Expected: host log shows `player_joined` signal fired once; both instances report 2 connected peers.

- [ ] **Step 4: Commit**

```bash
git add scripts/network_manager.gd scenes/world.tscn
git commit -m "Add host-authoritative NetworkManager and world spawner"
```

---

## Task 6: Character scene — movement, camera, and network sync

**Files:**
- Create: `scripts/character.gd`
- Create (via MCP tools): `scenes/character.tscn`

- [ ] **Step 1: Write the character controller script**

```gdscript
# scripts/character.gd
class_name Character
extends CharacterBody3D

@export var move_speed: float = 6.0
@export var health: Health = Health.new()

@onready var camera_pivot: Node3D = $CameraPivot
var multiplayer_authority_id: int = 1

func _physics_process(delta: float) -> void:
    if not is_multiplayer_authority():
        return
    var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    var cam_basis := camera_pivot.global_transform.basis
    var direction := (cam_basis.x * input_dir.x + cam_basis.z * input_dir.y).normalized()
    velocity.x = direction.x * move_speed
    velocity.z = direction.z * move_speed
    move_and_slide()
```

- [ ] **Step 2: Build `scenes/character.tscn` via `summer_run_script`/`summer_add_node`**

Create a `CharacterBody3D` root named `Character` with `character.gd` attached, a `CollisionShape3D`, a visible mesh (placeholder capsule until art lands), a `CameraPivot` (`Node3D`) child holding a `Camera3D` positioned behind/above, and a `MultiplayerSynchronizer` node replicating `position` and `rotation`. Follow `scene-scripting` for the script-driven build and `verifying-scenes` (`summer_world_snapshot` → mutate → `summer_snapshot_diff` + `summer_screenshot`) to confirm the hierarchy landed correctly.

- [ ] **Step 3: Wire `Character` as the `PlayerSpawner`'s spawnable scene from Task 5, and set each spawned instance's `multiplayer_authority_id` to the joining peer's id**

Verify with two instances (per `agent-playtesting`): host moves via joystick input, `summer_game_probe` on the second instance confirms the host's character position updates within one sync interval.

- [ ] **Step 4: Commit**

```bash
git add scripts/character.gd scenes/character.tscn
git commit -m "Add networked Character scene with movement and camera"
```

---

## Task 7: Combat — basic attack and abilities

**Files:**
- Create: `scripts/combat_component.gd`
- Modify: `scenes/character.tscn` (attach `CombatComponent`)

- [ ] **Step 1: Write the combat component using `Health` (Task 2) and `AbilityCooldown` (Task 3)**

```gdscript
# scripts/combat_component.gd
class_name CombatComponent
extends Node

@export var attack_range: float = 2.0
@export var attack_damage: int = 10
@export var heavy_strike_damage: int = 25

@export var charge_distance: float = 5.0
@export var charge_speed: float = 20.0

var basic_attack_cd := AbilityCooldown.new(0.8)
var charge_cd := AbilityCooldown.new(6.0)
var heavy_strike_cd := AbilityCooldown.new(8.0)
var block_cd := AbilityCooldown.new(4.0)
var is_blocking: bool = false

func _process(delta: float) -> void:
    basic_attack_cd.tick(delta)
    charge_cd.tick(delta)
    heavy_strike_cd.tick(delta)
    block_cd.tick(delta)

func try_basic_attack(target: Node) -> bool:
    if not basic_attack_cd.is_ready():
        return false
    basic_attack_cd.use()
    _deal_damage(target, attack_damage)
    return true

func try_charge(character: CharacterBody3D, facing_direction: Vector3) -> bool:
    if not charge_cd.is_ready():
        return false
    charge_cd.use()
    var travel_time := charge_distance / charge_speed
    var tween := character.create_tween()
    tween.tween_property(
        character, "position",
        character.position + facing_direction.normalized() * charge_distance,
        travel_time
    )
    return true

func try_heavy_strike(target: Node) -> bool:
    if not heavy_strike_cd.is_ready():
        return false
    heavy_strike_cd.use()
    _deal_damage(target, heavy_strike_damage)
    return true

func try_block() -> bool:
    if not block_cd.is_ready():
        return false
    block_cd.use()
    is_blocking = true
    return true

func _deal_damage(target: Node, amount: int) -> void:
    if target.has_method("get_health") and not is_blocking:
        var target_health: Health = target.get_health()
        target_health.apply_damage(amount)
```

- [ ] **Step 2: Add unit tests for the damage-routing logic (cooldown behavior already covered in Task 3)**

```gdscript
# tests/unit/test_combat_component.gd
extends GutTest

class FakeTarget:
    extends RefCounted
    var health := Health.new()
    func get_health() -> Health:
        return health

func test_basic_attack_deals_damage_and_respects_cooldown():
    var combat := CombatComponent.new()
    var target := FakeTarget.new()
    assert_true(combat.try_basic_attack(target))
    assert_eq(target.health.current, 90)
    assert_false(combat.try_basic_attack(target))

func test_blocking_prevents_damage():
    var combat := CombatComponent.new()
    var target := FakeTarget.new()
    combat.try_block()
    combat.is_blocking = true
    combat.try_basic_attack(target)
    assert_eq(target.health.current, 100)

func test_charge_respects_cooldown():
    var combat := CombatComponent.new()
    assert_true(combat.charge_cd.is_ready())
    combat.charge_cd.use()
    assert_false(combat.charge_cd.is_ready())
```

- [ ] **Step 3: Run tests to verify they pass**

Run: `summer_engine_binary --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_combat_component.gd -gexit`
Expected: 3 tests, 3 pass.

- [ ] **Step 4: Attach `CombatComponent` to `scenes/character.tscn` and wire host-side RPC: attack input on a client calls an RPC to the host, host resolves damage via `CombatComponent`, then replicates the target's new `Health.current` back to all clients**

Verify via `agent-playtesting` with two instances: client presses attack, host log shows damage applied, both clients' health bars (once UI lands in Task 9) reflect the new value — for now, confirm via `summer_inspect_runtime_node` reading the target's `Health.current`.

- [ ] **Step 5: Commit**

```bash
git add scripts/combat_component.gd tests/unit/test_combat_component.gd scenes/character.tscn
git commit -m "Add CombatComponent with basic attack, heavy strike, and block"
```

---

## Task 8: Enemy AI

**Files:**
- Create: `scripts/enemy_ai.gd`
- Test: `tests/unit/test_enemy_ai_state.gd`
- Create (via MCP tools): `scenes/enemy.tscn`

- [ ] **Step 1: Write the failing test for the state-transition logic (pure function, testable without the engine loop)**

```gdscript
# tests/unit/test_enemy_ai_state.gd
extends GutTest

func test_idle_to_chase_when_target_in_range():
    var state := EnemyAI.next_state(EnemyAI.State.IDLE, 5.0, 8.0, 2.0)
    assert_eq(state, EnemyAI.State.CHASE)

func test_stays_idle_when_target_out_of_range():
    var state := EnemyAI.next_state(EnemyAI.State.IDLE, 15.0, 8.0, 2.0)
    assert_eq(state, EnemyAI.State.IDLE)

func test_chase_to_attack_when_in_attack_range():
    var state := EnemyAI.next_state(EnemyAI.State.CHASE, 1.5, 8.0, 2.0)
    assert_eq(state, EnemyAI.State.ATTACK)

func test_chase_resets_to_idle_when_target_leaves_aggro_range():
    var state := EnemyAI.next_state(EnemyAI.State.CHASE, 20.0, 8.0, 2.0)
    assert_eq(state, EnemyAI.State.IDLE)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `summer_engine_binary --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_enemy_ai_state.gd -gexit`
Expected: FAIL — `EnemyAI` class does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```gdscript
# scripts/enemy_ai.gd
class_name EnemyAI
extends CharacterBody3D

enum State { IDLE, CHASE, ATTACK }

@export var aggro_range: float = 8.0
@export var attack_range: float = 2.0
@export var move_speed: float = 4.0
@export var combat: CombatComponent = CombatComponent.new()

var state: State = State.IDLE
var target: Node3D = null

static func next_state(current: State, distance_to_target: float, aggro: float, attack: float) -> State:
    if current == State.IDLE:
        return State.CHASE if distance_to_target <= aggro else State.IDLE
    # CHASE or ATTACK
    if distance_to_target > aggro:
        return State.IDLE
    if distance_to_target <= attack:
        return State.ATTACK
    return State.CHASE

func _physics_process(_delta: float) -> void:
    if not is_multiplayer_authority() or target == null:
        return
    var distance := global_position.distance_to(target.global_position)
    state = next_state(state, distance, aggro_range, attack_range)
    if state == State.CHASE:
        var direction := (target.global_position - global_position).normalized()
        velocity.x = direction.x * move_speed
        velocity.z = direction.z * move_speed
        move_and_slide()
    elif state == State.ATTACK:
        velocity = Vector3.ZERO
        combat.try_basic_attack(target)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `summer_engine_binary --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_enemy_ai_state.gd -gexit`
Expected: 4 tests, 4 pass.

- [ ] **Step 5: Build `scenes/enemy.tscn` via MCP tools (CharacterBody3D + CollisionShape3D + mesh + `enemy_ai.gd`), add an `EnemySpawner` to `scenes/world.tscn` placing 1-2 enemies, and verify live with `summer_screenshot` + `summer_game_probe`**

Expected: enemy stays put until a player enters `aggro_range`, then chases and attacks.

- [ ] **Step 6: Commit**

```bash
git add scripts/enemy_ai.gd tests/unit/test_enemy_ai_state.gd scenes/enemy.tscn scenes/world.tscn
git commit -m "Add EnemyAI with aggro/chase/attack state machine"
```

---

## Task 9: Quest wiring (kill quest + reach-location quest, host-authoritative)

**Files:**
- Create: `scripts/quest_manager.gd` (autoload, host-owned, replicates via RPC)
- Modify: `scenes/world.tscn` (add `QuestManager` autoload wiring, a `ReachLocationArea` trigger)

- [ ] **Step 1: Write `QuestManager`, wrapping `QuestState` (Task 4) with host-authoritative RPC replication**

```gdscript
# scripts/quest_manager.gd
class_name QuestManager
extends Node

var kill_quest := QuestState.new_kill_quest("kill_wolves", 3)
var reach_quest := QuestState.new_reach_quest("find_shrine")

signal quest_updated(quest_id: String, complete: bool)

func report_kill(killed_id: String) -> void:
    if not multiplayer.is_server():
        return
    kill_quest.record_kill(killed_id)
    _sync_quest.rpc(kill_quest.id, kill_quest.is_complete())

func report_arrival(location_id: String) -> void:
    if not multiplayer.is_server():
        return
    reach_quest.record_arrival(location_id)
    _sync_quest.rpc(reach_quest.id, reach_quest.is_complete())

@rpc("authority", "call_local", "reliable")
func _sync_quest(quest_id: String, complete: bool) -> void:
    quest_updated.emit(quest_id, complete)
```

- [ ] **Step 2: Wire `EnemyAI` (Task 8) to call `QuestManager.report_kill("kill_wolves")` on death, and add a Task-5-style `Area3D` trigger (`ReachLocationArea`) in `scenes/world.tscn` that calls `QuestManager.report_arrival("find_shrine")` on player entry**

Add `QuestManager` as an autoload named `Quests` via the editor/`summer_run_script`, then verify with `summer_snapshot_diff`.

- [ ] **Step 3: Verify live with two instances (per `agent-playtesting`)**

One player kills 3 wolves, the other confirms (via `summer_inspect_runtime_node` on `Quests.kill_quest` or a logged `quest_updated` signal) that `is_complete()` becomes true on both clients. Repeat for the reach-location quest by walking a player into the trigger area.

- [ ] **Step 4: Commit**

```bash
git add scripts/quest_manager.gd scenes/world.tscn
git commit -m "Wire host-authoritative QuestManager to enemy kills and location trigger"
```

---

## Task 10: Mobile UI/HUD

**Files:**
- Create (via MCP tools): `scenes/hud.tscn`
- Create: `scripts/hud.gd`

- [ ] **Step 1: Write the HUD script binding to the local player's `Health` and `Quests` autoload**

```gdscript
# scripts/hud.gd
class_name HUD
extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar
@onready var quest_label: Label = $QuestTracker

var tracked_health: Health

func _ready() -> void:
    Quests.quest_updated.connect(_on_quest_updated)

func bind_health(health: Health) -> void:
    tracked_health = health

func _process(_delta: float) -> void:
    if tracked_health:
        health_bar.max_value = tracked_health.max_health
        health_bar.value = tracked_health.current

func _on_quest_updated(quest_id: String, complete: bool) -> void:
    var status := "Complete" if complete else "In Progress"
    quest_label.text = "%s: %s" % [quest_id, status]
```

- [ ] **Step 2: Build `scenes/hud.tscn` via MCP tools: `CanvasLayer` root with a `ProgressBar` (`HealthBar`), a `Label` (`QuestTracker`), a virtual joystick control (left side, touch-safe area), and 4 `TouchScreenButton`/`Button` nodes for basic attack, charge, heavy strike, and block, following `ui-basics`**

Verify with `summer_screenshot` on a phone-aspect-ratio viewport that all elements are within touch-safe margins and don't overlap.

- [ ] **Step 3: Wire joystick output to `Character`'s movement input, and the 4 buttons to `CombatComponent`'s existing `try_basic_attack(target)`, `try_charge(character, facing_direction)`, `try_heavy_strike(target)`, and `try_block()` calls (all defined in Task 7 — no new component code needed here, only scene/input wiring via `summer_run_script`)**

Verify live: tapping each button on one instance triggers the corresponding action, observed via `summer_screenshot` and `summer_inspect_runtime_node` on the character's position (after charge) and cooldown state.

- [ ] **Step 4: Commit**

```bash
git add scripts/hud.gd scenes/hud.tscn
git commit -m "Add mobile touch HUD: joystick, ability buttons, health bar, quest tracker"
```

---

## Task 11: End-to-end multiplayer playtest

**Files:** none (verification task)

- [ ] **Step 1: Launch 3 local engine instances per `agent-playtesting` (1 host, 2 clients)**

Use `summer_runtime_launch` (or the project's equivalent) with `fixed_fps` and a shared seed for determinism.

- [ ] **Step 2: Run the full loop: all 3 players join, move around, see each other's positions update, fight the 2 enemies together, complete both quests**

Use `summer_game_probe` before/after each action (join, move, attack, quest completion) and `summer_screenshot` to visually confirm all 3 characters and enemies render correctly for every instance.

- [ ] **Step 3: Record and fix any desyncs found (e.g. a client's view of another player's health lagging or not updating) as follow-up commits against the relevant task's files above — do not proceed to sign-off until 0 desyncs remain across 2 consecutive full runs**

- [ ] **Step 4: Commit the final verification note**

```bash
git add .summer/plans/2026-09-18-phase1-multiplayer-slice.md
git commit -m "Complete Phase 1 end-to-end multiplayer playtest verification"
```
