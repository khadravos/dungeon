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
