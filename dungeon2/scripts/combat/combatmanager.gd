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

	# Load all player and monster databases
	encounter_manager.load_databases()

	# Automatically get all unlocked heroes
	party = encounter_manager.setup_party_from_db()

	print("[CombatManager] Party loaded (no combat started).")
	print(party)
	
	

func start_battle(enemy_group: String = ""):
	persistent_bars.connect("player_target_selected", Callable(self, "_on_target_selected"))
	print("[CombatManager] Battle initializing...")

	ui_manager.connect_signals(self)
	skill_manager.load_skills("res://json/skills.json")

	# === If no group provided, choose a random one for the current floor ===
	if enemy_group == "":
		var main_node = get_tree().root.get_node("Main")
		var floor = main_node.floor

		var result = encounter_manager.get_random_group_for_floor(floor)
		if result == null:
			push_error("No valid enemy group found for floor %s" % floor)
			return

		enemy_group = result
		print("[CombatManager] Random enemy group selected for floor %s: %s" % [floor, enemy_group])

	# === Load enemies ===
	encounter_manager.setup_enemy_group(enemy_group)
	enemies = encounter_manager.enemies

	# Party was loaded earlier in _ready()
	ui_manager.setup_ui(party, enemies)
	turn_manager.setup(party, enemies)

	turn_manager.connect("turn_ready", Callable(self, "_on_turn_ready"))
	ui_manager.skill_pressed.connect(self._on_skill_selected)
	ui_manager.target_selected.connect(self._on_target_selected)

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
	
	if battler.is_player:
		ui_manager.populate_skills_menu(skill_manager, battler)
		ui_manager.show_player_menu(battler)
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
	ui_manager.set_buttons_enabled(true)

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
		ui_manager.set_buttons_enabled(true)

func _on_skill_selected(skill_name: String):
	if not active_battler or not active_battler.is_player:
		return
	
	pending_skill = skill_name
	pending_attack = false
	player_state = PlayerState.CHOOSING_TARGET_FOR_SKILL

	var skill = skill_manager.get_skill(skill_name)
	var effects = (skill.get("effect", "single") if skill else "single").split(",")

	var targets_to_select = []

	# === Determine selectable targets ===
	if "party" in effects:
		targets_to_select = party  # allies
	elif "single" in effects:
		targets_to_select = enemies  # enemies
	# random/area skills do not need selection
	else:
		targets_to_select = []

	if targets_to_select.size() > 0:
		ui_manager.enable_target_selection(targets_to_select, true)
		ui_manager.show_message("Choose a target for %s." % skill_name)
	else:
		# No selection needed
		_execute_skill(skill_name)
		player_state = PlayerState.NONE


func _on_target_selected(target: Battler):
	if not active_battler or not active_battler.is_player:
		return

	selected_target = target  # ← make sure this is set

	match player_state:
		PlayerState.CHOOSING_TARGET_FOR_ATTACK:
			_execute_attack()
		PlayerState.CHOOSING_TARGET_FOR_SKILL:
			_execute_skill(pending_skill)
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
	var base: int
	if use_magic:
		base = max(1, attacker.magic - target.will)
	else:
		base = max(1, attacker.strength - target.defense)
	if target.defending:
		base = int(base / 2)
		target.defending = false
	if randf() < attacker.luck:
		base *= 2
		ui_manager.append_text(" Critical!")
	return base


# === Actions Execution ===
func _execute_attack():
	var dmg = _calculate_damage(active_battler, selected_target)
	selected_target.hp -= dmg
	ui_manager.show_message("%s attacks %s for %d!" %
		[active_battler.name, selected_target.name, dmg])
	_cleanup_after_action()


func _execute_skill(skill_name: String):
	var skill = skill_manager.get_skill(skill_name)
	if not skill:
		ui_manager.show_message("Skill not found.")
		return

	var effect_string: String = skill.get("effect", "single")
	var effects: Array = effect_string.split(",")  # ["single", "multi-hit", "party", "area", "random", etc.]
	var hits: int = skill.get("hits", 1)

	# === Determine targets ===
	var targets: Array = []

	if "single" in effects:
		targets = [selected_target]
	if "party" in effects:
		if "area" in effects:
			targets = party  # heal all allies
		else:
			targets = [selected_target]  # heal single ally  # heal single ally
	elif "area" in effects:
		targets = enemies  # area damage hits all enemies
	elif "random" in effects:
		targets = enemies  # will pick randomly later

	# === Execute skill ===
	if "random" in effects and "multi-hit" in effects:
		# Random multi-hit
		for i in range(hits):
			var target = enemies.pick_random()
			if target.hp <= 0:
				continue
			var dmg = skill_manager.compute_skill_damage(skill_name, active_battler, target)
			target.hp -= dmg
			ui_manager.show_message("%s hits %s for %d with %s!" %
				[active_battler.name, target.name, dmg, skill_name])
	elif "multi-hit" in effects:
		# Multi-hit on single target or area target list
		for t in targets:
			var total_dmg = 0
			for i in range(hits):
				var dmg = skill_manager.compute_skill_damage(skill_name, active_battler, t)
				total_dmg += dmg
			t.hp -= total_dmg
			ui_manager.show_message("%s hits %s %d times with %s for %d total!" %
				[active_battler.name, t.name, hits, skill_name, total_dmg])
	else:
		# Single hit or area
		for t in targets:
			if t.hp <= 0:
				continue
			var dmg = skill_manager.compute_skill_damage(skill_name, active_battler, t)

			if "party" in effects:
				# Healing skill
				t.hp += abs(skill.get("damage", 0))
				ui_manager.show_message("%s uses %s to heal %s for %d!" %
					[active_battler.name, skill_name, t.name, abs(skill.get("damage", 0))])
			else:
				# Regular damage
				t.hp -= dmg
				if "area" in effects:
					ui_manager.show_message("%s uses %s on all enemies!" %
						[active_battler.name, skill_name])
				else:
					ui_manager.show_message("%s uses %s on %s for %d!" %
						[active_battler.name, skill_name, t.name, dmg])

	_cleanup_after_action()


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
	ui_manager.hide_all_menus()

	if victory:
		ui_manager.show_message("You won the battle!")

		# === Award EXP ===
		var total_exp = encounter_manager.current_group_exp
		var living_players = party.filter(func(p): return p.unlocked and p.hp > 0)

		if living_players.size() > 0:
			var exp_each = int(total_exp / living_players.size())
			
			for p in living_players:
				p.gain_exp(exp_each)  # This properly handles level ups

			# === Save updated party ===
			encounter_manager.save_player_stats(party)

			ui_manager.show_message("Each living member gains %d EXP!" % exp_each)
	else:
		ui_manager.show_message("You were defeated or fled...")

	await get_tree().create_timer(1.0).timeout
	get_tree().paused = false
	emit_signal("battle_ended", victory)
	queue_free()
