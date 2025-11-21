extends Node
class_name EncounterManager

@onready var loader: CharacterLoader = $CharacterLoader

var players_db: Dictionary
var monsters_db: Dictionary
var monster_groups: Dictionary
var current_group_exp: int = 0

var party: Array[Battler] = []
var enemies: Array[Battler] = []

var save_path := "user://save.json"


# ============================================================
# DATABASE LOADING
# ============================================================
func load_databases():
	players_db = loader.load_json("res://json/Players.json")

	var monster_file = loader.load_json("res://json/Monsters.json")
	monsters_db = monster_file.get("monsters", {})
	monster_groups = monster_file.get("groups", {})


# ============================================================
# PARTY FROM MANUAL NAMES (rarely used)
# ============================================================

# ============================================================
# GENERATE ENEMY GROUP
# ============================================================
func setup_enemy_group(group_name: String):
	enemies.clear()
	current_group_exp = 0

	if not monster_groups.has(group_name):
		push_warning("Unknown monster group: %s" % group_name)
		return

	var group = monster_groups[group_name]
	var members = group.get("members", [])

	for monster_name in members:
		if monsters_db.has(monster_name):

			# IMPORTANT: deep copy monster data so each monster is unique
			var data = monsters_db[monster_name].duplicate(true)

			var enemy: Battler = loader.create_enemy_battler(monster_name, data)

			# Give each enemy a completely unique runtime ID
			enemy.instance_id = hash(enemy)  # or Time.get_ticks_usec()

			enemies.append(enemy)
		else:
			push_warning("Unknown monster type: %s" % monster_name)

	current_group_exp = group.get("exp_reward", 0)

# ============================================================
# MAIN PARTY BUILDER — LOADS SAVE OR USES BASE DATA
# ============================================================
func setup_party_from_db() -> Array[Battler]:
	var save_data: Dictionary = load_json(save_path)
	if typeof(save_data) != TYPE_DICTIONARY:
		save_data = {}

	# If party already exists, reuse it; otherwise create empty array
	if party == null:
		party = []

	# Loop through all hero names in database
	for hero_name in players_db.keys():
		var base_data: Dictionary = players_db[hero_name]
		var saved: Dictionary = save_data.get(hero_name, {})

		var unlocked_in_save: bool = saved.get("unlocked", false)
		var unlocked_in_base: bool = base_data.get("unlocked", false)
		if not unlocked_in_save and not unlocked_in_base:
			continue

		# Check if battler already exists
		var existing_battler: Battler = null
		for p in party:
			if p.name == hero_name:
				existing_battler = p
				break

		# Merge data: saved overrides base
		var final_data: Dictionary = base_data.duplicate(true)
		if saved.size() > 0:
			for k in saved.keys():
				final_data[k] = saved[k]

		if existing_battler != null:
			# Update existing Battler with merged data
			existing_battler.max_hp    = final_data.get("max_hp",    existing_battler.max_hp)
			existing_battler.strength  = final_data.get("strength",  existing_battler.strength)
			existing_battler.defense   = final_data.get("defense",   existing_battler.defense)
			existing_battler.magic     = final_data.get("magic",     existing_battler.magic)
			existing_battler.will      = final_data.get("will",      existing_battler.will)
			existing_battler.dexterity = final_data.get("dexterity", existing_battler.dexterity)
			existing_battler.unlocked  = final_data.get("unlocked",  existing_battler.unlocked)
			existing_battler.level     = final_data.get("level",     existing_battler.level)
			existing_battler.exp       = final_data.get("exp",       existing_battler.exp)
			existing_battler.exp_to_next = final_data.get("exp_to_next", existing_battler.exp_to_next)
			# Optionally update icon, equipment, etc. if needed
		else:
			# Create new Battler only if it doesn't exist
			var b: Battler = loader.create_battler(hero_name, final_data, true)
			party.append(b)

	return party

# ============================================================
# GET GROUP FOR FLOOR
# ============================================================
func get_random_group_for_floor(floor: int) -> String:
	var valid: Array[String] = []

	for group_name in monster_groups.keys():
		var group = monster_groups[group_name]
		if group.get("floor", 1) == floor:
			valid.append(group_name)

	if valid.is_empty():
		push_error("No monster groups defined for floor %s!" % floor)
		return ""

	return valid.pick_random()
	


# ============================================================
# JSON LOADING
# ============================================================
func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}  # fallback
	var f = FileAccess.open(path, FileAccess.READ)
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


# ============================================================
# SAVE PLAYER STATS
# ============================================================
func save_player_stats(party: Array[Battler]) -> void:
	var save_data: Dictionary = load_json(save_path)
	if typeof(save_data) != TYPE_DICTIONARY:
		save_data = {}

	for b in party:
		if b.is_player:
			save_data[b.name] = {
				"level": b.level,
				"exp": b.exp,
				"exp_to_next": b.exp_to_next,
				"max_hp": b.base_stats.max_hp,
				"strength": b.base_stats.strength,
				"defense": b.base_stats.defense,
				"magic": b.base_stats.magic,
				"will": b.base_stats.will,
				"dexterity":b.base_stats.dexterity,
				"agility":b.base_stats.agility,
				"luck":b.base_stats.luck,
				"unlocked": b.unlocked,
				"equipment": b.equipment  # <—— NEW
			}

	var json = JSON.stringify(save_data, "\t")
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(json)
	file.close()

func get_battle_drops(enemies: Array[Battler]) -> Dictionary:
	var final_drops: Dictionary = {}	# item_name : quantity

	print("\n=== DROP DEBUG START ===")
	print("Enemies in battle:", enemies.size())

	for e in enemies:
		print("Enemy:", e.name, "Unlocked=", e.unlocked)
		print("  Drops array:", e.drops)

		for drop in e.drops:
			print("    Checking drop:", drop)

			var item = drop.get("item", "")
			var chance = drop.get("chance", 0.0)
			var amount = drop.get("amount", 1)

			if item == "":
				print("    ❌ Drop skipped (no item key)")
				continue

			var roll = randf()
			print("    → Roll =", roll, "Chance =", chance)

			if roll <= chance:
				# Success
				final_drops[item] = final_drops.get(item, 0) + amount
				print("    ✔ Drop SUCCESS:", item, "x", amount)
			else:
				print("    ✖ Drop failed RNG")

	print("Final drops:", final_drops)
	print("=== DROP DEBUG END ===\n")

	return final_drops
