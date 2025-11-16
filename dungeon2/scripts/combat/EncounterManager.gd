extends Node
class_name EncounterManager

@onready var loader: CharacterLoader = $CharacterLoader

var players_db: Dictionary
var monsters_db: Dictionary
var monster_groups: Dictionary
var current_group_exp: int = 0


var party: Array[Battler] = []
var enemies: Array[Battler] = []

func load_databases():
	players_db = loader.load_json("res://json/Players.json")
	
	var monster_file = loader.load_json("res://json/Monsters.json")
	monsters_db = monster_file.get("monsters", {})
	monster_groups = monster_file.get("groups", {})
	

func setup_party(names: Array[String]):
	party.clear()
	for name in names:
		if players_db.has(name):
			var data = players_db[name]
			party.append(loader.create_battler(name, data, true))
		else:
			push_warning("Unknown player: %s" % name)

func setup_enemy_group(group_name: String):
	enemies.clear()
	current_group_exp = 0  # Reset!

	if not monster_groups.has(group_name):
		push_warning("Unknown monster group: %s" % group_name)
		return

	var group = monster_groups[group_name]
	var members = group.get("members", [])

	# === Load enemies ===
	for monster_name in members:
		if monsters_db.has(monster_name):
			var data = monsters_db[monster_name]
			enemies.append(loader.create_battler(monster_name, data, false))
		else:
			push_warning("Unknown monster type: %s" % monster_name)

	# === Load EXP for reward ===
	current_group_exp = group.get("exp_reward", 0)


func setup_party_from_db() -> Array[Battler]:
	var party: Array[Battler] = [] 
	
	for hero_name in players_db.keys():
		var h = players_db[hero_name]
		if h.get("unlocked", false):
			# ← Use create_battler instead of Battler.new()
			var b := loader.create_battler(hero_name, h, true)
			party.append(b)
	
	return party

func get_random_group_for_floor(floor: int) -> String:
	var valid: Array[String] = []

	for group_name in monster_groups.keys():   # ← MUST BE THIS
		var group = monster_groups[group_name]
		if group.get("floor", 1) == floor:
			valid.append(group_name)

	if valid.is_empty():
		push_error("No monster groups defined for floor %s!" % floor)
		return ""

	return valid.pick_random()

func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("JSON not found: %s" % path)
		return {}
	var f = FileAccess.open(path, FileAccess.READ)
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

var save_path := "user://save.json"

func save_player_stats(party: Array[Battler]) -> void:
	# Load existing save
	var save_data: Dictionary = load_json(save_path)
	if save_data == null or save_data.size() == 0:
		save_data = {}  # make sure we have a dictionary

	for b in party:
		if b.is_player:
			# Update only this player's data, preserving other players
			var existing = save_data.get(b.name, {})
			
			save_data[b.name] = {
				"level": b.level,
				"exp": b.exp,  # cumulative EXP is already tracked in Battler
				"exp_to_next": b.exp_to_next,
				"max_hp": b.max_hp,
				"strength": b.strength,
				"defense": b.defense,
				"magic": b.magic,
				"will": b.will,
				"dexterity": b.dexterity,
				"unlocked": b.unlocked
			}

	# Write updated save_data back to file
	var json = JSON.stringify(save_data, "\t")
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(json)
	file.close()
