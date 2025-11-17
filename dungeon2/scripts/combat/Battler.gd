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
