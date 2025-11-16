extends Control
class_name PlayerBars

signal bar_clicked(battler: Battler)

var battler: Battler

func _ready():
	# Ensure ClickArea fires its own signal
	if $ClickArea:
		$ClickArea.pressed.connect(_on_ClickArea_pressed)

	# Make sure ClickArea receives mouse input
	$ClickArea.mouse_filter = Control.MOUSE_FILTER_STOP

	# Prevent labels/bars from blocking clicks
	for node in $VBoxContainer.get_children():
		if node is Control:
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(b: Battler):
	battler = b
	
	_update_name_label()
	$VBoxContainer/name_label.text = b.name
	$VBoxContainer/hp_bar.max_value = b.max_hp
	$VBoxContainer/hp_bar.value = b.hp
	$VBoxContainer/atb_bar.max_value = 100
	$VBoxContainer/atb_bar.value = b.charge

	# Link UI bars to battler
	b.hp_bar = $VBoxContainer/hp_bar
	b.atb_bar = $VBoxContainer/atb_bar

	set_clickable(false)


func set_clickable(active: bool):
	$ClickArea.disabled = not active
	$ClickArea.mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	


func _on_ClickArea_pressed():
	if battler:
		
		emit_signal("bar_clicked", battler)


# === Auto-update bars every frame ===
func _process(delta):
	if battler:
		# Clamp values just in case
		battler.hp = clamp(battler.hp, 0, battler.max_hp)
		battler.charge = clamp(battler.charge, 0, 100)

		$VBoxContainer/hp_bar.value = battler.hp
		$VBoxContainer/atb_bar.value = battler.charge
		_update_name_label()
		
func _update_name_label():
	if battler:
		var lvl_text := " (Lv " + str(battler.level) + ")"
		$VBoxContainer/name_label.text = battler.name + lvl_text
