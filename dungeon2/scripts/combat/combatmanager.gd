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

	# AUTO EXECUTE SKILLS WITHOUT TARGET SELECTION
	if "area" in effects or "party" in effects or "random" in effects:
		player_state = PlayerState.NONE
		_execute_skill(skill_name, null)
		return

	# SINGLE TARGET LOGIC
	var targets: Array = []

	if "single" in effects:
		if skill.get("damage", 0) > 0:
			targets = enemies
		else:
			targets = party

	if targets.is_empty():
		player_state = PlayerState.NONE
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

func _execute_skill(skill_name: String, selected_target: Battler):
	var skill = skill_manager.get_skill(skill_name)
	if skill == null:
		print("[ERROR] Skill '%s' not found!" % skill_name)
		ui_manager.show_message("Skill not found.")
		_cleanup_after_action()
		return

	print("\n=== EXECUTING SKILL: %s ===" % skill_name)

	# Effects & skill properties
	var effects: Array = skill.get("effect", "single").split(",")
	var hits: int = skill.get("hits", 1)
	var power: int = skill.get("damage", 0)  # Damage value
	var heal: int = skill.get("heal", 0)
	var crit_chance: float = skill.get("crit_chance", 0.0)
	var crit_mult: float = skill.get("on_crit", 2.0)
	var stat: String = skill.get("stat", "")
	var status_name: String = skill.get("status_name", "")

	print("Effects: ", effects)
	print("Hits: ", hits)
	print("Power/Damage: ", power)
	print("Heal: ", heal)

	# 1) DETERMINE TARGETS
	var targets: Array = []

	if "single" in effects:
		if selected_target == null:
			print("[ERROR] No selected target for single-target skill!")
			ui_manager.show_message("No target selected.")
			_cleanup_after_action()
			return
		targets = [selected_target]
		print("Single-target skill → Target: %s" % selected_target.name)

	elif "party" in effects:
		targets = party if active_battler.is_player else enemies
		print("Party skill → %d targets" % targets.size())

	elif "area" in effects:
		targets = enemies if active_battler.is_player else party
		print("Area skill → %d targets" % targets.size())

	elif "random" in effects:
		var pool = enemies if active_battler.is_player else party
		if pool.is_empty():
			print("[ERROR] No enemies/allies to randomly target!")
			ui_manager.show_message("No valid targets.")
			_cleanup_after_action()
			return
		targets = [pool[randi() % pool.size()]]
		print("Random skill → Target: %s" % targets[0].name)

	# 2) FILTER NULL + DEAD TARGETS
	targets = targets.filter(func(t):
		return t != null and t.hp > 0
	)

	print("Valid targets after filtering: %d" % targets.size())

	if targets.is_empty():
		print("[WARN] No valid targets after filtering.")
		ui_manager.show_message("No valid targets.")
		_cleanup_after_action()
		return

	# 3) APPLY DAMAGE / HEALING / EFFECTS
	for hit_i in range(hits):
		print("--- HIT %d/%d ---" % [hit_i + 1, hits])

		for t in targets:
			print(" → Applying skill to %s" % t.name)

			# --- DAMAGE ---
			if power > 0:
				var dmg: int = power
				if randf() < crit_chance:
					dmg = int(dmg * crit_mult)
					print("   Critical hit! Damage: %d" % dmg)
					ui_manager.show_message("%s suffered a CRITICAL hit!" % t.name)
				t.hp = max(0, t.hp - dmg)
				print("   Damage: -%d (HP now %d)" % [dmg, t.hp])
				ui_manager.show_message("%s took %d damage!" % [t.name, dmg])

			# --- HEAL ---
			if heal > 0:
				t.hp = min(t.max_hp, t.hp + heal)
				print("   Heal: +%d (HP now %d)" % [heal, t.hp])
				ui_manager.show_message("%s recovered %d HP!" % [t.name, heal])

			# --- STATUS EFFECTS ---
			if status_name != "":
				print("   Applying status effect: %s" % status_name)
				_apply_status_effect(t, status_name)

			# --- BUFF / DEBUFF ---
			if "buff" in effects and stat != "":
				print("   Buffing %s: %s by %d" % [t.name, stat, power])
				_apply_buff(t, stat, power)

			if "debuff" in effects and stat != "":
				print("   Debuffing %s: %s by %d" % [t.name, stat, power])
				_apply_debuff(t, stat, power)

	# 4) AFTER ACTION
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
