extends Node
class_name CombatManager

@onready var turn_manager: TurnManager = $TurnManager
@onready var skill_manager: SkillManager = $SkillManager
@onready var encounter_manager: EncounterManager = $EncounterManager
@onready var ui_manager: CombatUI = $CombatUI
@onready var ui: CombatUI = $CombatUI


signal battle_ended(victory: bool)

var party: Array[Battler] = []
var enemies: Array[Battler] = []
var active_battler: Battler = null
var selected_target: Battler = null
var battle_active: bool = false
var persistent_bars: PersistentPlayerBars



enum PlayerState {
	NONE,
	CHOOSING_ACTION,
	CHOOSING_TARGET_FOR_ATTACK,
	CHOOSING_TARGET_FOR_SKILL
}

var player_state: PlayerState = PlayerState.NONE
var pending_skill: String = ""
var pending_attack: bool = false

func _ready():
	add_to_group("combat_manager")
	print("[CombatManager] Ready. Loading party data...")
	ui_manager.connect_signals(self)
	# Load all player and monster databases (EncounterManager builds its internal DBs)
	encounter_manager.load_databases()

	# Build party inside EncounterManager (it already sets encounter_manager.party)
	encounter_manager.setup_party_from_db()

	# Use the exact party array from the encounter_manager (single source of truth)
	party = encounter_manager.party

	# Assign inventory_manager reference into each battler so equipment bonuses work
	_assign_inventory_manager_to_battlers()

	# Initialize any UI/other references that expect the party to exist
	print("[CombatManager] Party loaded (no combat started).")
	for p in party:
		print(" - Party member:", p.name, "inst_id:", str(p.get_instance_id()))

	# (leave ready() here — start_battle will be called externally)


func start_battle(enemy_group: String = ""):
	reset_battle_state()
	

	# --- Get floor from Main ---
	var main_node = get_tree().root.get_node("Main")
	var floor = main_node.floor

	# --- Choose enemy group if none specified ---
	if enemy_group == "":
		enemy_group = encounter_manager.get_random_group_for_floor(floor)
		if enemy_group == null:
			push_error("No valid enemy group found for floor %s" % floor)
			return
		print("[CombatManager] Random enemy group selected for floor %s: %s" % [floor, enemy_group])

	# --- Load the enemies only ONCE ---
	encounter_manager.setup_enemy_group(enemy_group)
	enemies = encounter_manager.enemies

	# --- Setup UI and systems ---
	ui_manager.setup_ui(party, enemies)
	turn_manager.setup(party, enemies)

	if not turn_manager.is_connected("turn_ready", Callable(self, "_on_turn_ready")):
		turn_manager.connect("turn_ready", Callable(self, "_on_turn_ready"))

	 # this should also check internally

	if not ui_manager.is_connected("target_selected", Callable(self, "_on_target_selected")):
		ui_manager.target_selected.connect(self._on_target_selected)

	if not ui_manager.is_connected("skill_pressed", Callable(self, "_on_skill_selected")):
		ui_manager.skill_pressed.connect(self._on_skill_selected)

	# Persistent bars targeting
	if persistent_bars:
		if not persistent_bars.is_connected("player_target_selected", Callable(self, "_on_target_selected")):
			persistent_bars.connect("player_target_selected", Callable(self, "_on_target_selected"))
	ui_manager.show_enemies()

	# Load skills
	skill_manager.load_skills("res://json/skills.json")

	battle_active = true
	ui_manager.show_message("A battle begins!")
	get_tree().paused = true

func _process(delta):
	if not battle_active:
		return
	turn_manager.process_turns(delta)

# === Turn Handling ===
func _on_turn_ready(battler: Battler):
	active_battler = battler
	
	battler.process_status_effects()
	if battler.has_status("stun"):
	# Skip turn
		ui_manager.show_message("%s is stunned!" % battler.name)
		await get_tree().create_timer(1.0).timeout
		_end_turn()
		return
	if battler.is_player:
		ui_manager.populate_skills_menu(skill_manager, battler)
		ui_manager.show_player_menu(battler)
		ui_manager.set_buttons_enabled(true)
	else:
		await get_tree().create_timer(1.0).timeout
		_enemy_action(battler)
	


# === Player Actions ===
func _on_attack_selected():
	if not active_battler or not active_battler.is_player:
		return
	
	pending_attack = true
	pending_skill = ""
	player_state = PlayerState.CHOOSING_TARGET_FOR_ATTACK

	ui_manager.show_message("Choose a target for Attack.")
	ui_manager.enable_target_selection(enemies, true)


func _on_defend_selected():
	ui_manager.set_buttons_enabled(false)
	active_battler.defending = true
	ui_manager.show_message("%s is defending!" % active_battler.name)
	await get_tree().create_timer(1.0).timeout
	_end_turn()
	

func _on_run_selected():
	ui_manager.set_buttons_enabled(false)
	ui_manager.show_message("%s tries to run away..." % active_battler.name)
	await get_tree().create_timer(1.0).timeout
	if randf() < 0.5:
		ui_manager.show_message("You successfully escaped!")
		await get_tree().create_timer(1.0).timeout
		_end_battle(false)
	else:
		ui_manager.show_message("Couldn't escape!")
		await get_tree().create_timer(1.0).timeout
		_end_turn()

func _on_skill_selected(skill_name: String):
	if not active_battler or not active_battler.is_player:
		return

	var skill = skill_manager.get_skill(skill_name)
	if skill == null:
		ui_manager.show_message("Skill not found.")
		return

	pending_skill = skill_name
	pending_attack = false

	var effects: Array = skill.get("effect", "single").split(",")

	# --- Determine if skill requires target selection ---
	var requires_target := false
	var targets: Array = []

	if "single" in effects:
		requires_target = true
		# Determine target pool based on party vs enemy
		if skill.get("damage", 0) > 0:
			targets = enemies
		else:
			targets = party if active_battler.is_player else enemies

	elif "area" in effects:
		# Auto-targeting skill → targets are all in pool
		targets = enemies if active_battler.is_player else party
		_execute_skill(skill_name, null)
		return

	elif "random" in effects:
		targets = enemies if active_battler.is_player else party
		_execute_skill(skill_name, null)
		return

	elif "party" in effects:
		# Affects party members, but may still require target selection if "single" is present
		if not "single" in effects:
			_execute_skill(skill_name, null)
			return
		targets = party if active_battler.is_player else enemies

	# --- Handle target selection if needed ---
	if requires_target:
		if targets.is_empty():
			# No valid targets → auto execute
			_execute_skill(skill_name, null)
			return

		player_state = PlayerState.CHOOSING_TARGET_FOR_SKILL
		ui_manager.enable_target_selection(targets, true)
		ui_manager.show_message("Choose a target for %s." % skill_name)


func _on_target_selected(target: Battler):
	if not active_battler or not active_battler.is_player:
		return

	selected_target = target  # ← make sure this is set

	match player_state:
		PlayerState.CHOOSING_TARGET_FOR_ATTACK:
			_execute_attack()
		PlayerState.CHOOSING_TARGET_FOR_SKILL:
			_execute_skill(pending_skill, selected_target)
		_:
			ui_manager.show_message("Choose an action first.")



# === Enemy Actions ===
func _enemy_action(enemy: Battler):
	var targets = party.filter(func(p): return p.unlocked and p.hp > 0)
	if targets.is_empty():
		return
	var target = targets.pick_random()
	var dmg = _calculate_damage(enemy, target)
	target.hp -= dmg
	ui_manager.show_message("%s hits %s for %d!" % [enemy.name, target.name, dmg])
	await get_tree().create_timer(0.5).timeout
	_check_battle_state()


# === Damage Calculation ===
func _calculate_damage(attacker: Battler, target: Battler, use_magic := false) -> int:
	var stat_name: String = "strength"
	if use_magic:
		stat_name = "magic"
	
	var base_stat = attacker.get_after_stat(stat_name)
	var target_def = target.will if use_magic else target.defense

	var dmg = max(1, base_stat - target_def)  # minimum 1 damage

	# --- Weakness / Resistance ---
	var attack_type: String = "physical"  # all basic attacks are physical
	if attack_type in target.weak:
		dmg = int(dmg * 1.5)
		ui_manager.show_message("It's super effective!")
	elif attack_type in target.resist:
		dmg = int(dmg * 0.5)
		ui_manager.show_message("It's not very effective...")

	# --- Defending halves damage ---
	if target.defending:
		dmg = int(dmg / 2)
		target.defending = false

	# --- Critical hit ---
	if randf() < attacker.luck:
		dmg = int(dmg * 2)
		ui_manager.show_message("Critical hit!")

	return dmg


# === PLAYER ATTACK ===
func _execute_attack():
	print("Active battler:", active_battler, "name:", active_battler.name)
	if selected_target == null:
		ui_manager.show_message("No target selected for attack.")
		return

	var dmg = _calculate_damage(active_battler, selected_target)
	selected_target.hp = max(0, selected_target.hp - dmg)
	ui_manager.show_message("%s attacks %s for %d!" % [active_battler.name, selected_target.name, dmg])
	_cleanup_after_action()

func _execute_skill(skill_name: String, selected_target: Battler):
	var skill = skill_manager.get_skill(skill_name)
	if skill == null:
		ui_manager.show_message("Skill not found.")
		_cleanup_after_action()
		return

	print("\n=== EXECUTING SKILL: %s ===" % skill_name)

	var effects: Array = skill.get("effect", "single").split(",")
	var hits: int = skill.get("hits", 1)
	var base_power: int = skill.get("damage", 0)
	var heal: int = skill.get("heal", 0)
	var crit_chance: float = skill.get("crit_chance", 0.0)
	var crit_mult: float = skill.get("on_crit", 2.0)
	var stat: String = skill.get("stat", "")
	var status_name: String = skill.get("status", "")
	var skill_type: String = skill.get("type", "")

	var targets: Array = []
	var is_random := false

	# ---- SELECT TARGETS ----
	if "single" in effects:
		if selected_target == null:
			ui_manager.show_message("No target selected.")
			_cleanup_after_action()
			return
		targets = [selected_target]

	elif "party" in effects:
		targets = party if active_battler.is_player else enemies

	elif "area" in effects:
		targets = enemies if active_battler.is_player else party

	elif "random" in effects:
		var pool = (enemies if active_battler.is_player else party).filter(
			func(x): return x != null and x.hp > 0
		)

		if pool.is_empty():
			ui_manager.show_message("No valid targets.")
			_cleanup_after_action()
			return

		targets = pool
		is_random = true

	# Remove dead/null
	targets = targets.filter(func(t): return t != null and t.hp > 0)

	if targets.is_empty():
		ui_manager.show_message("No valid targets.")
		_cleanup_after_action()
		return

	# ---- APPLY EFFECTS ----
	for hit_i in range(hits):

		var chosen_targets: Array = []

		if is_random:
			# NEW random target every hit
			chosen_targets = [targets[randi() % targets.size()]]
		else:
			chosen_targets = targets

		for t in chosen_targets:
			var dmg := 0

			# ---- DAMAGE ----
			if base_power > 0 and stat != "":
				var caster_stat = active_battler.get_after_stat(stat)
				dmg = int(base_power * caster_stat / 10)

				# Weakness / resistance
				if skill_type != "":
					if skill_type in t.weak:
						dmg = int(dmg * 1.5)
						ui_manager.show_message("It's super effective!")
					elif skill_type in t.resist:
						dmg = int(dmg * 0.5)
						ui_manager.show_message("It's not very effective...")

				# Critical
				if randf() < crit_chance:
					dmg = int(dmg * crit_mult)
					ui_manager.show_message("%s suffered a CRITICAL hit!" % t.name)

				t.hp = max(0, t.hp - dmg)
				ui_manager.show_message("%s took %d damage!" % [t.name, dmg])

			# ---- HEAL ----
			if heal > 0 and stat != "":
				var caster_stat = active_battler.get_after_stat(stat)
				var healing = int(heal * caster_stat / 10)
				t.hp = min(t.max_hp, t.hp + healing)
				ui_manager.show_message("%s recovered %d HP!" % [t.name, healing])

			# ---- STATUS ----
			if status_name != "":
				_apply_status_effect(t, status_name)

			# ---- BUFF / DEBUFF ----
			if "buff" in effects and stat != "":
				_apply_buff(t, stat, base_power)
			if "debuff" in effects and stat != "":
				_apply_debuff(t, stat, base_power)

	_cleanup_after_action()


func _apply_status_effect(target: Battler, effect_name: String):
	if effect_name == "" or effect_name == null:
		return

	var path = "res://tres/%s.tres" % effect_name
	var effect_res = load(path)

	if effect_res == null:
		push_error("StatusEffect NOT FOUND: %s" % path)
		return

	target.add_status(effect_res)
	ui_manager.show_message("%s is now affected by %s!" %
		[target.name, effect_name])


func _apply_buff(target: Battler, stat: String, amount: int):
	if target == null:
		return
	target.add_buff(stat, amount)
	ui_manager.log_action("%s's %s increased by %d!" % [target.name, stat, amount])

func _apply_debuff(target: Battler, stat: String, amount: int):
	if target == null:
		return
	target.add_debuff(stat, amount)
	ui_manager.log_action("%s's %s decreased by %d!" % [target.name, stat, amount])

func _cleanup_after_action():
	ui_manager.enable_target_selection([], false)
	player_state = PlayerState.NONE
	pending_attack = false
	pending_skill = ""
	selected_target = null
	
	await get_tree().create_timer(0.5).timeout
	_check_battle_state()


# === Battle State ===
func _check_battle_state():
	var alive_enemies = enemies.filter(func(e): return e.hp > 0)
	var alive_players = party.filter(func(p): return p.unlocked and p.hp > 0)
	
	ui_manager.update_bars()
	
	if alive_enemies.is_empty():
		_end_battle(true)
	elif alive_players.is_empty():
		_end_battle(false)
	else:
		_end_turn()


func _end_turn():
	active_battler = null
	selected_target = null
	turn_manager.resume()


func _end_battle(victory: bool):
	battle_active = false
	

	if victory:
		ui_manager.show_message("You won the battle!")

		# === EXP ===
		var total_exp = encounter_manager.current_group_exp
		var living_players = party.filter(func(p): return p.unlocked and p.hp > 0)

		if living_players.size() > 0:
			var exp_each = int(total_exp / living_players.size())

			for p in living_players:
				p.gain_exp(exp_each)

			encounter_manager.save_player_stats(party)

			ui_manager.show_message("Each living member gains %d EXP!" % exp_each)

		# === DROPS ===
		var drops = encounter_manager.get_battle_drops(enemies)
		var item_manager = get_node("/root/Main/inventoryManager")

		if drops.size() > 0:
			for item_name in drops.keys():
				var qty = drops[item_name]
				item_manager.add_item(item_name, qty)
				ui_manager.show_message("Obtained %d × %s!" % [qty, item_name])
			var equipment_ui = get_node("/root/Main/EquipmentPanel")
			equipment_ui._refresh_inventory()
		else:
			ui_manager.show_message("No items found.")

	else:
		ui_manager.show_message("You were defeated or fled...")

	await get_tree().create_timer(1.0).timeout
	ui_manager.hide_all_menus()
	get_tree().paused = false
	emit_signal("battle_ended", victory)


# Helper: find the project's main node and copy its inventory_manager into battlers.
func _assign_inventory_manager_to_battlers():
	# Try to get the main node where you keep the inventory_manager
	var main_node = null
	if get_tree().root.has_node("Main"):
		main_node = get_tree().root.get_node("Main")
	elif get_tree().has_current_scene():
		# fallback: current_scene might be Main
		main_node = get_tree().current_scene
	else:
		main_node = null

	var inv_ref = null
	if main_node != null and main_node.has_method("get") and main_node.has_node("inventoryManager"):
		# if your Main scene node exposes a child named inventoryManager
		inv_ref = main_node.get_node("inventoryManager")
	# fallback: try direct property (some of your scripts used `onready var inventory_manager`)
	if inv_ref == null and main_node != null and main_node.has_variable("inventory_manager"):
		inv_ref = main_node.inventory_manager

	# Last resort: search root for a node of type inventoryManager (expensive, but okay for init)
	if inv_ref == null:
		for child in get_tree().root.get_children():
			if str(child.get_class()).to_lower().find("inventory") != -1:
				inv_ref = child
				break

	if inv_ref == null:
		print("[CombatManager] WARNING: inventory_manager not found. Equipment bonuses will not apply.")
	else:
		print("[CombatManager] Found inventory_manager:", inv_ref)
		for b in party:
			# set a reference on each battler so get_after_stat() can query item data
			b.inventory_manager = inv_ref
			# ensure base stats are initialized (if your loader doesn't do that)
			if b.base_stats.size() == 0:
				if b.has_method("initialize_base_stats"):
					b.initialize_base_stats()
			print("Assigned inventory_manager to", b.name, "inst_id:", str(b.get_instance_id()))

func reset_battle_state():
	# Completely clear all battle state
	enemies.clear()
	turn_manager.reset()
	ui_manager.clear_targets()

	active_battler = null
	selected_target = null

	pending_skill = ""
	pending_attack = false
	player_state = PlayerState.NONE
