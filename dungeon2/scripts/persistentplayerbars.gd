extends Control
class_name PersistentPlayerBars

var player_bar_scene := preload("res://scenes/playerbars.tscn")
signal player_target_selected(battler: Battler)

var target_group: Array = []
var targeting_enabled := false

func _ready():
	load_party_from_combat_manager()


func load_party_from_combat_manager():
	var cm = get_tree().get_first_node_in_group("combat_manager")
	if cm:
		setup(cm.party)
	else:
		push_warning("CombatManager not found in group 'combat_manager'")

func setup(party: Array):
	var container := $BarsContainer
	for child in container.get_children():
		child.queue_free()

	for battler in party:
		if not battler.unlocked:
			continue

		var bar: PlayerBars = player_bar_scene.instantiate()
		bar.setup(battler)
		bar.connect("bar_clicked", Callable(self, "_on_bar_clicked"))
		container.add_child(bar)

func enable_player_targeting(targets: Array, enabled: bool):
	targeting_enabled = enabled
	target_group = targets if enabled else []

	for bar in $BarsContainer.get_children():
		if not bar.battler:
			continue

		# Check if this battler's name is in targets
		var in_targets = false
		for t in targets:
			if t.name == bar.battler.name:
				in_targets = true
				break

		var active = enabled and in_targets and bar.battler.hp > 0
		
		bar.set_clickable(active)


func _on_bar_clicked(clicked_battler: Battler):
	if not targeting_enabled:
		return

	# Match by name (or another unique property) instead of object identity
	for target in target_group:
		if target.name == clicked_battler.name:
			
			emit_signal("player_target_selected", target)
			return
