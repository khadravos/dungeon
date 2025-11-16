extends Node
class_name SkillManager

var skills_data: Dictionary = {}

func load_skills(path: String):
	if not FileAccess.file_exists(path):
		push_warning("No skills file found at %s" % path)
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var text = file.get_as_text()
	file.close()

	var result = JSON.parse_string(text)

	if result == null:
		push_warning("Error parsing skills file: invalid JSON")
		return

	if typeof(result) != TYPE_DICTIONARY:
		push_warning("Error: skills JSON root must be a dictionary")
		return

	skills_data = result
	print("Skills loaded:", skills_data.keys())


func get_skill(name: String) -> Dictionary:
	if not skills_data.has(name):
		push_warning("Skill '%s' not found in JSON!" % name)
		return {}
	return skills_data[name]


# ============================================================
#   FINAL DAMAGE FORMULA (Stat Scaling + Weakness/Resistance)
# ============================================================
func compute_skill_damage(skill_name: String, user: Battler, target: Battler) -> int:
	if not skills_data.has(skill_name):
		push_warning("Skill not found: %s" % skill_name)
		return 0

	var skill: Dictionary = skills_data[skill_name]
	var base: int = skill.get("damage", 0)
	var stat: String = skill.get("stat", "")
	var element: String = skill.get("type", "")
	var hits: int = skill.get("hits", 1)

	var total_damage = 0

	for i in range(hits):
		var dmg = base
		# Stat scaling
		if stat != "":
			if user.has_method("get") and stat in user:
				dmg += user.get(stat) * 0.5
			elif user.has(stat):
				dmg += user.get(stat) * 0.5
			else:
				push_warning("User does not have stat '%s'" % stat)
		# Elemental weakness/resistance
		if element != "":
			if element in target.weak:
				dmg *= 1.5
			if element in target.resist:
				dmg *= 0.6
		total_damage += dmg

	return round(total_damage)


func can_user_use(skill_name: String, user: Battler) -> bool:
	var skill = skills_data[skill_name]

	if not skill.has("allowed_users"):
		return true
	
	return user.name in skill.allowed_users

func get_skills_for_battler(battler: Battler) -> Array[String]:
	var list: Array[String] = []
	
	for skill_name in skills_data.keys():
		var skill = skills_data[skill_name]

		if not skill.has("allowed_users"):
			continue

		# If the battler's name is inside allowed_users, add the skill
		if battler.name in skill["allowed_users"]:
			list.append(skill_name)

	return list
