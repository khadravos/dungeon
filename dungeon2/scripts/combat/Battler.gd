extends Resource
class_name Battler

var name: String = ""
var hp: int = 1
var max_hp: int = 1
var strength: int = 1
var defense: int = 1
var magic: int = 1
var will: int = 1
var dexterity: int = 1
var agility: float = 1.0
var luck: float = 0.0

var is_player: bool = false
var charge := 0.0
var defending := false
var unlocked := true
var weak: Array = []
var resist: Array = []
var icon: Texture2D

# --- NEW ---
var level: int = 1
var exp: int = 0
var exp_to_next: int = 50

# UI references
var hp_bar = null
var atb_bar = null
var button = null

var growth := {
	"max_hp": 0,
	"strength": 0,
	"defense": 0,
	"magic": 0,
	"will": 0,
	"dexterity": 0
}

var status_effects: Array = []
var inventory_manager: inventoryManager = null

var instance_id: int = 0
var drops: Array = []


func gain_exp(amount: int):
	exp += amount
	print(amount)
	print(exp_to_next)
	while exp >= exp_to_next:
		exp -= exp_to_next
		level += 1
		_on_level_up()
		
func _on_level_up():
	max_hp += growth.max_hp
	hp = max_hp

	strength += growth.strength
	defense += growth.defense
	magic += growth.magic
	will += growth.will
	dexterity += growth.dexterity

	exp_to_next = int(exp_to_next * 1.25)

func add_status(effect: StatusEffect):
	status_effects.append(effect)
	effect.on_apply(self)

func remove_status(effect_name: String):
	status_effects = status_effects.filter(func(e): return e.name != effect_name)

func process_status_effects():
	# Must iterate using copy to safely erase inside loop
	for effect in status_effects.duplicate():
		
		# --- Call "on_turn" if it exists ---
		if effect.has_method("on_turn"):
			effect.on_turn(self)

		# --- Reduce duration ---
		effect.duration -= 1

		# --- Remove if expired ---
		if effect.duration <= 0:
			if effect.has_method("on_end"):
				effect.on_end(self)
			status_effects.erase(effect)

			
func has_status(name: String) -> bool:
	for e in status_effects:
		if e.name == name:
			return true
	return false
	
# --- Buff & Debuff Storage ---
var buffs := {}
var debuffs := {}

func get_modified_stat(stat: String) -> int:
	var base: int = get(stat) as int
	var buff: int = buffs.get(stat, 0) as int
	var debuff: int = debuffs.get(stat, 0) as int
	return max(0, base + buff + debuff)

func add_buff(stat: String, amount: int) -> void:
	var prev: int = buffs.get(stat, 0) as int
	buffs[stat] = prev + amount

func add_debuff(stat: String, amount: int) -> void:
	var prev: int = debuffs.get(stat, 0) as int
	debuffs[stat] = prev - amount

func remove_buff(stat: String) -> void:
	buffs.erase(stat)

func remove_debuff(stat: String) -> void:
	debuffs.erase(stat)
	
var equipment := {
	"right_hand": null,
	"left_hand": null,
	"armor": null,
	"accessory1": null,
	"accessory2": null
}

var base_stats := {
	"strength": 0,
	"defense": 0,
	"magic": 0,
	"will": 0,
	"dexterity": 0,
	"agility": 0.0,
	"luck": 0.0,
	"max_hp": 0
}

func initialize_base_stats():
	base_stats.strength = strength
	base_stats.defense = defense
	base_stats.magic = magic
	base_stats.will = will
	base_stats.dexterity = dexterity
	base_stats.agility = agility
	base_stats.luck = luck
	base_stats.max_hp = max_hp


func get_after_stat(stat_name: String) -> float:
	# Start with base stat
	var value = base_stats.get(stat_name, 0)

	print("\n=== GET AFTER STAT: %s for %s ===" % [stat_name, name])
	print("Base %s = %s" % [stat_name, value])

	if inventory_manager == null:
		print("WARNING: inventory_manager is NULL, returning base stat only.")
		return value

	# Check each slot
	for slot in equipment.keys():
		var item = equipment[slot]

		if item == null:
			print("Slot %s: EMPTY" % slot)
			continue

		print("Slot %s: has item %s" % [slot, item])

		var item_data = inventory_manager.get_item_data(item)
		if item_data.is_empty():
			print("  ERROR: No data found for item '%s'!" % item)
			continue

		var bonus = item_data.get("stat_bonus", {})

		if stat_name in bonus:
			print("  Applying bonus from %s: +%s %s" %
				[item, bonus[stat_name], stat_name])
			value += bonus[stat_name]
		else:
			print("  No '%s' bonus in this item." % stat_name)

	print("Final %s = %s" % [stat_name, value])
	print("=== END ===\n")

	return value

	
func recalculate_stats(inv_manager: inventoryManager) -> void:
	# Reset base stats
	for key in base_stats.keys():
		self.set(key, base_stats[key])

	# Apply equipment bonuses
	for slot in equipment.keys():
		var item = equipment[slot]
		if item != null:
			var data = inv_manager.get_item_data(item)
			var bonus = data.get("stat_bonus", {})
			for stat_name in bonus.keys():
				var old_value = self.get(stat_name)
				self.set(stat_name, old_value + bonus[stat_name])
				print("%s equipped in %s: %s changed from %d to %d" %
					[item, slot, stat_name, old_value, self.get(stat_name)])

	# Clamp HP
	hp = min(hp, max_hp)
	print("Current HP:", hp)
	
func set_inventory_manager(inv):
	inventory_manager = inv
	print("Inventory manager set for %s" % name)
