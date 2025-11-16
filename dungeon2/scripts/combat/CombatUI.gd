extends Control
class_name CombatUI

# === SIGNALS ===
signal attack_pressed()
signal defend_pressed()
signal run_pressed()
signal skill_pressed(skill_name: String)
signal target_selected(target: Battler)

# === NODES ===
@onready var action_log: VBoxContainer = $CanvasLayer/Control/VBoxContainer/actionscroll/actionlog
@onready var action_scroll: ScrollContainer = $CanvasLayer/Control/VBoxContainer/actionscroll

@onready var menu_container: VBoxContainer = $CanvasLayer/Control/Menu
@onready var skills_menu: VBoxContainer = $CanvasLayer/Control/SkillsMenu
@onready var enemy_bars_container: HBoxContainer = $CanvasLayer/Control/TurnBars/EnemyBars

@onready var attack_button: Button = menu_container.get_node("attackbutton")
@onready var defend_button: Button = menu_container.get_node("defendbutton")
@onready var run_button: Button = menu_container.get_node("runbutton")
@onready var skills_button: Button = menu_container.get_node("skillsbutton")

# === STATE ===
var target_selection_enabled: bool = false
var current_target_group: Array = []


# =========================================
# SIGNAL CONNECTIONS
# =========================================
func connect_signals(manager: Node):
	attack_button.pressed.connect(manager._on_attack_selected)
	defend_button.pressed.connect(manager._on_defend_selected)
	run_button.pressed.connect(manager._on_run_selected)
	skills_button.pressed.connect(func(): show_skills_menu())

# =========================================
# UI SETUP
# =========================================
func _ready():
	hide_all_menus()

func setup_ui(party: Array[Battler], enemies: Array[Battler]):
	_create_enemy_bars(enemies)
	_create_player_bars(party)  # <— we need to instantiate PlayerBars here
	hide_all_menus()

func _create_player_bars(party: Array[Battler]):
	var persistent = get_tree().current_scene.get_node("persistentplayerbars")
	if persistent:
		persistent.setup(party)
	else:
		print("[CombatUI] PersistentPlayerBars node not found!")
	persistent.setup(party)  # Pass the same Battler objects TurnManager is using

# =========================================
# INTERNAL HELPERS
# =========================================
func _clear_container(container: Node):
	for child in container.get_children():
		child.queue_free()

# =========================================
# ENEMY BARS
# =========================================
func _create_enemy_bars(enemies: Array):
	_clear_container(enemy_bars_container)

	for e in enemies:
		var container := VBoxContainer.new()
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.alignment = BoxContainer.ALIGNMENT_CENTER
		container.add_theme_constant_override("separation", 4)

		# === ICON ===
		var icon := TextureRect.new()
		icon.texture = e.icon
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		icon.custom_minimum_size = Vector2(64, 64)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		# Click handling for icons
		icon.gui_input.connect(func(event):
			if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
				if target_selection_enabled and e in current_target_group:
					emit_signal("target_selected", e)
		)

		# === NAME LABEL ===
		var name_label := Label.new()
		name_label.text = e.name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		# === HP BAR ===
		var hp_bar := ProgressBar.new()
		hp_bar.max_value = e.max_hp
		hp_bar.value = e.hp
		hp_bar.custom_minimum_size = Vector2(100, 14)

		# === Add elements ===
		container.add_child(icon)
		container.add_child(name_label)
		container.add_child(hp_bar)

		enemy_bars_container.add_child(container)

		# store references
		e.hp_bar = hp_bar
		e.button = icon   # replaced button with icon for targeting

# =========================================
# TARGET SELECTION
# =========================================
func enable_target_selection(targets: Array, enabled: bool):
	target_selection_enabled = enabled
	current_target_group = targets if enabled else []

	# Enemy buttons
	for container in enemy_bars_container.get_children():
		for child in container.get_children():
			if child is Button:
				var battler_meta = child.get_meta("battler")
				child.disabled = not (enabled and battler_meta in targets)

	update_target_availability()

	# Tell persistent bars they are selectable
	var persistent = get_tree().current_scene.get_node("persistentplayerbars")
	if persistent:
		persistent.enable_player_targeting(targets, enabled)

# =========================================
# PLAYER MENU
# =========================================
func show_player_menu(battler: Battler):
	menu_container.visible = true
	skills_menu.visible = false
	action_log.visible = true
	action_scroll.visible = true
	show_message("%s's turn! Choose an action." % battler.name)

func show_skills_menu():
	menu_container.visible = false
	skills_menu.visible = true
	show_message("Select a skill to use!")

func populate_skills_menu(skill_manager: SkillManager, battler: Battler):
	skills_menu.visible = true
	_clear_container(skills_menu)

	var skills = skill_manager.get_skills_for_battler(battler)

	for skill_name in skills:
		var skill = skill_manager.get_skill(skill_name)
		if not skill:
			continue

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(140, 32)

		var effect = skill.get("effect", "")
		var hits = skill.get("hits", 1)
		var extra_hits = " x%d" % hits if hits > 1 else ""
		btn.text = "%s [%s%s]" % [skill_name, effect, extra_hits]

		btn.pressed.connect(func():
			emit_signal("skill_pressed", skill_name)
			skills_menu.visible = false
		)

		skills_menu.add_child(btn)

# =========================================
# LOG
# =========================================
func show_message(text: String):
	_add_log_line(text)

func append_text(extra: String):
	_add_log_line(extra)

func _add_log_line(text: String):
	var label = Label.new()
	label.text = text
	action_log.add_child(label)
	await get_tree().process_frame
	action_scroll.scroll_vertical = action_scroll.get_v_scroll_bar().max_value

# =========================================
# GENERAL UI
# =========================================
func hide_all_menus():
	menu_container.visible = false
	skills_menu.visible = false
	action_log.visible = false
	action_scroll.visible = false
	
func update_bars():
	# Enemy only now
	for e in get_parent().enemies:
		if e.hp_bar:
			e.hp_bar.value = e.hp

func update_target_availability():
	for container in enemy_bars_container.get_children():
		for child in container.get_children():
			if child is Button:
				var battler = child.get_meta("battler")
				child.disabled = battler.hp <= 0 or (target_selection_enabled and not battler in current_target_group)
func set_buttons_enabled(enabled: bool):
	attack_button.disabled = not enabled
	defend_button.disabled = not enabled
	run_button.disabled = not enabled
	skills_button.disabled = not enabled
