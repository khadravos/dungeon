extends Control
class_name EquipmentPanel

@onready var character_select: OptionButton = $PanelContainer/VBoxContainer/CharacterSelect
@onready var slots_container: VBoxContainer = $PanelContainer/VBoxContainer/Slots
@onready var inventory_container: VBoxContainer = $PanelContainer/VBoxContainer/InventoryList

var inventory_manager: inventoryManager
var current_battler: Battler

var slot_order := [
	"right_hand",
	"left_hand",
	"armor",
	"accessory1",
	"accessory2"
]

func setup(party: Array[Battler], inventory_manager):
	self.inventory_manager = inventory_manager
	
	if party.is_empty():
		print("EquipmentPanel: party is empty, nothing to display.")
		return
	
	character_select.clear()
	for i in party.size():
		character_select.add_item(party[i].name, i)

	character_select.connect("item_selected", Callable(self, "_on_character_selected").bind(party))
	
	# Pick first character by default
	if party.size() > 0:
		_on_character_selected(0, party)
	print("EquipmentPanel party refs:", party)
	for p in party:
		print("  ", p.name, p)

func _on_character_selected(index: int, party: Array[Battler]):
	current_battler = party[index]
	_refresh_slots()
	_refresh_inventory()


# --------------------------------------------------
#	SLOTS UI
# --------------------------------------------------
func _refresh_slots():
	for child in slots_container.get_children():
		child.queue_free()

	for slot_name in slot_order:
		var row = HBoxContainer.new()
		slots_container.add_child(row)

		var label = Label.new()
		label.text = _slot_display_name(slot_name)
		row.add_child(label)

		var unequip_btn = Button.new()
		unequip_btn.text = "X"
		unequip_btn.custom_minimum_size.x = 24
		unequip_btn.connect("pressed", Callable(self, "_on_unequip_pressed").bind(slot_name))
		row.add_child(unequip_btn)

		var equipped_label = Label.new()
		var item = current_battler.equipment.get(slot_name)
		equipped_label.text = item if item != null else "-"
		row.add_child(equipped_label)

func _slot_display_name(slot: String) -> String:
	match slot:
		"right_hand":
			return "Right Hand"
		"left_hand":
			return "Left Hand"
		"armor":
			return "Armor"
		"accessory1":
			return "Accessory 1"
		"accessory2":
			return "Accessory 2"
		_:
			return slot.capitalize()

func _on_unequip_pressed(slot_name: String):
	var item = current_battler.equipment.get(slot_name)
	if item == null:
		return

	# Return to inventory
	inventory_manager.add_item(item)
	current_battler.equipment[slot_name] = null
	current_battler.recalculate_stats(inventory_manager)

	_refresh_slots()
	_refresh_inventory()


# --------------------------------------------------
#	INVENTORY LIST
# --------------------------------------------------
func _refresh_inventory():
	for child in inventory_container.get_children():
		child.queue_free()

	for item_name in inventory_manager.inventory.keys():
		var quantity = inventory_manager.inventory[item_name]
		
		var btn = Button.new()
		btn.text = "%s (x%d)" % [item_name, quantity]
		btn.connect("pressed", Callable(self, "_on_inventory_item_pressed").bind(item_name))
		inventory_container.add_child(btn)

func _on_inventory_item_pressed(item_name: String):
	if current_battler == null:
		print("No current battler selected.")
		return

	var data = inventory_manager.get_item_data(item_name)
	if data.is_empty():
		print("Item data not found for:", item_name)
		return

	var slot = data.get("slot", "")
	if slot == "":
		print("Item has no slot:", item_name)
		return

	# Check class restriction
	var allowed = data.get("allowed_users", [])
	if not current_battler.name in allowed:
		print("%s cannot equip %s (not allowed)" % [current_battler.name, item_name])
		return

	print("Attempting to equip", item_name, "to", current_battler.name, "in slot", slot)

	# Real equip logic
	var success = inventory_manager.equip_item(current_battler, item_name)
	if success:
		print(item_name, "equipped successfully on", current_battler.name)
		_refresh_slots()
		_refresh_inventory()
	else:
		print("Failed to equip", item_name, "on", current_battler.name)
