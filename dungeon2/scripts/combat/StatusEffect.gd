extends Resource
class_name StatusEffect

@export var name: String
@export var duration: int = 3
@export var amount: float = 0.0  # Now treated as percentage for buffs/debuffs
@export var effect_type: String = ""  

var applied := false
var original_values := {}  # Store original stat for revert

func on_apply(target: Battler):
	if applied:
		return

	match effect_type:
		"buff_attack":
			original_values.strength = target.strength
			target.strength = int(target.strength * (1 + amount))
		"buff_defense":
			original_values.defense = target.defense
			target.defense = int(target.defense * (1 + amount))
		"buff_magic":
			original_values.magic = target.magic
			target.magic = int(target.magic * (1 + amount))
		"buff_dexterity":
			original_values.dexterity = target.dexterity
			target.dexterity = int(target.dexterity * (1 + amount))
		"debuff_attack":
			original_values.strength = target.strength
			target.strength = int(target.strength * (1 - amount))
		"debuff_defense":
			original_values.defense = target.defense
			target.defense = int(target.defense * (1 - amount))
		"debuff_magic":
			original_values.magic = target.magic
			target.magic = int(target.magic * (1 - amount))
		"debuff_dexterity":
			original_values.dexterity = target.dexterity
			target.dexterity = int(target.dexterity * (1 - amount))
		"regen", "poison", "burn":
			# No stat change on apply
			pass

	applied = true


func on_turn(target: Battler):
	match effect_type:
		"poison":
			target.hp -= int(target.max_hp * amount)  # damage % of max HP
		"burn":
			target.hp -= int(target.max_hp * amount)
		"regen":
			target.hp += int(target.max_hp * amount)
			target.hp = min(target.hp, target.max_hp)
		"bleed":
			target.hp -= int(target.hp * amount)


func on_end(target: Battler):
	match effect_type:
		"buff_attack":
			target.strength = original_values.strength
		"buff_defense":
			target.defense = original_values.defense
		"buff_magic":
			target.magic = original_values.magic
		"buff_dexterity":
			target.dexterity = original_values.dexterity
		"debuff_attack":
			target.strength = original_values.strength
		"debuff_defense":
			target.defense = original_values.defense
		"debuff_magic":
			target.magic = original_values.magic
		"debuff_dexterity":
			target.dexterity = original_values.dexterity
		# poison, burn, regen have no cleanup
