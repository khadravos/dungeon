extends Node
class_name CharacterLoader

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

func create_battler(name: String, data: Dictionary, is_player := false) -> Battler:
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

	# --- Icon ---
	var icon_path = data.get("icon", "")
	b.icon = load(icon_path) if icon_path != "" else null

	# --- Player-specific stats ---
	if is_player:
		# Load saved data if available
		var s = save_data.get(name, {})
		b.level = s.get("level", 1)
		b.exp = s.get("exp", 0)
		b.exp_to_next = s.get("exp_to_next", 50)

		# Load growth data if available
		if growth_data.has(name):
			b.growth = growth_data[name]

	return b
