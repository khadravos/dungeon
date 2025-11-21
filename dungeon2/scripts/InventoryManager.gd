extends Node

var items_data: Dictionary = {}
var inventory: Dictionary = {}	# key=item_name, value=quantity
const SAVE_PATH := "user://inventory.json"


func _ready():
	_load_items()
	load_inventory()       # load previous data
	#_add_test_items()    # only use this for debugging

func _load_items():
	var file = FileAccess.open("res://json/items.json", FileAccess.READ)
	if file:
		items_data = JSON.parse_string(file.get_as_text())
		file.close()

func save_inventory():
	print("[Inventory] Saving... ", inventory)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(inventory))
		file.close()

func load_inventory():
	if not FileAccess.file_exists(SAVE_PATH):
		return  # no save yet

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var parsed = JSON.parse_string(content)

		if typeof(parsed) == TYPE_DICTIONARY:
			inventory = parsed
		file.close()


func add_item(item_name: String, amount := 1):
	inventory[item_name] = inventory.get(item_name, 0) + amount
	save_inventory()

func remove_item(item_name: String, amount := 1):
	if not inventory.has(item_name):
		return
	inventory[item_name] -= amount
	if inventory[item_name] <= 0:
		inventory.erase(item_name)
	save_inventory()  # <—— add this


func get_item_data(item_name: String) -> Dictionary:
	return items_data.get(item_name, {})

func equip_item(battler: Battler, item_name: String) -> bool:
	var data = get_item_data(item_name)
	if data.is_empty():
		return false

	var slot = data.get("slot", "")
	if slot == "":
		return false

	# Restriction: allowed users
	var allowed = data.get("allowed_users", [])
	if not battler.name in allowed:
		return false

	# Unequip previous item
	if battler.equipment[slot] != null:
		var old_item = battler.equipment[slot]
		add_item(old_item)

	# Equip new item
	battler.equipment[slot] = item_name
	remove_item(item_name)
	
	# Update stats
	battler.recalculate_stats(self)
	print("Equipping", item_name, "to battler", battler, "named", battler.name)


	return true
	
func _add_test_items():
	# Add whatever items exist in your items.json
	add_item("SwordBasic", 1)
	add_item("WoodenShield", 1)
	add_item("LeatherArmor", 1)
	add_item("SilverRing", 2)
