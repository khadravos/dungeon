extends Node
class_name CharacterLoader

var inventory_manager: inventoryManager

# Cache of already-created Battlers
var battler_cache: Dictionary = {}

var growth_data := {
	"Hero": {
		"max_hp": 12,
		"strength": 3,
		"defense": 2,
		"magic": 1,
		"will": 2,
		"dexterity": 2
	},
	"Mage": {
		"max_hp": 6,
		"strength": 1,
		"defense": 1,
		"magic": 4,
		"will": 3,
		"dexterity": 2
	},
	"Rogue": {
		"max_hp": 8,
		"strength": 2,
		"defense": 1,
		"magic": 1,
		"will": 1,
		"dexterity": 4
	},
	"Paladin": {
		"max_hp": 14,
		"strength": 3,
		"defense": 3,
		"magic": 1,
		"will": 2,
		"dexterity": 1
	},
	"Archer": {
		"max_hp": 7,
		"strength": 2,
		"defense": 1,
		"magic": 1,
		"will": 1,
		"dexterity": 5
	},
	"Cleric": {
		"max_hp": 7,
		"strength": 1,
		"defense": 2,
		"magic": 3,
		"will": 3,
		"dexterity": 1
	}
}

var save_data = load_json("user://save.json")
var save_path := "user://save.json"

func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("JSON not found: %s" % path)
		return {}
	var f = FileAccess.open(path, FileAccess.READ)
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func create_battler(name: String, data: Dictionary, is_player := false) -> Battler:
	# ✔ Reuse battler if one with the same name already exists
	if battler_cache.has(name):
		return battler_cache[name]

	var b = Battler.new()

	# --- Base stats ---
	b.name = name
	b.max_hp = data.get("max_hp", 1)
	b.hp = b.max_hp
	b.strength = data.get("strength", 1)
	b.defense = data.get("defense", 1)
	b.magic = data.get("magic", 1)
	b.will = data.get("will", 1)
	b.dexterity = data.get("dexterity", 1)
	b.agility = data.get("agility", 1.0)
	b.luck = data.get("luck", 0.0)
	b.is_player = is_player
	b.unlocked = data.get("unlocked", true)
	b.weak = data.get("weak", [])
	b.resist = data.get("resist", [])
	b.instance_id = hash(b)

	# --- Icon ---
	var icon_path = data.get("icon", "")
	b.icon = load(icon_path) if icon_path != "" else null

	# --- Player-specific stats ---
	if is_player:
		var s = save_data.get(name, {})
		b.level = s.get("level", 1)
		b.exp = s.get("exp", 0)
		b.exp_to_next = s.get("exp_to_next", 50)

		if growth_data.has(name):
			b.growth = growth_data[name]

		b.initialize_base_stats()
		b.set_inventory_manager(get_node("/root/Main/inventoryManager"))

	# ✔ Store in cache so any future calls return the same instance
	battler_cache[name] = b
	if is_player:
		var s = save_data.get(name, {})
		var saved_eq: Dictionary = s.get("equipment", {})

		if saved_eq.size() > 0:
			var inv = get_node("/root/Main/inventoryManager")

			for slot in saved_eq.keys():
				var item_name = saved_eq[slot]
				if item_name != null and item_name != "":
				# Do NOT remove items from inventory if loading from save!
					b.equipment[slot] = item_name

		# Recalculate stats after applying equipment
			b.recalculate_stats(inv)

	return b

func create_enemy_battler(name: String, data: Dictionary) -> Battler:
	# ❌ Do NOT use cache for enemies
	# Always create a FRESH Battler instance
	var b = Battler.new()

	# --- Base stats ---
	b.name = name
	b.max_hp = data.get("max_hp", 1)
	b.hp = b.max_hp
	b.strength = data.get("strength", 1)
	b.defense = data.get("defense", 1)
	b.magic = data.get("magic", 1)
	b.will = data.get("will", 1)
	b.dexterity = data.get("dexterity", 1)
	b.agility = data.get("agility", 1.0)
	b.luck = data.get("luck", 0.0)
	b.is_player = false
	b.unlocked = true
	b.weak = data.get("weak", [])
	b.resist = data.get("resist", [])
	b.drops = data.get("drops", [])


	b.instance_id = hash(Time.get_ticks_usec() + randi())

	# Icon
	var icon_path = data.get("icon", "")
	b.icon = load(icon_path) if icon_path != "" else null
	b.initialize_base_stats()
	return b
