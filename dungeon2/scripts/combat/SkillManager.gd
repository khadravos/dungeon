extends Node
class_name SkillManager

var skills_data: Dictionary = {}

func load_skills(path: String):
	if not FileAccess.file_exists(path):
		push_warning("No skills file found at %s" % path)
		return

	# Read file
	var file := FileAccess.open(path, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()

	# Parse JSON
	var result: Variant = JSON.parse_string(text)

	if result == null:
		push_warning("Error parsing skills file: invalid JSON")
		return

	if typeof(result) != TYPE_DICTIONARY:
		push_warning("Error: skills JSON root must be a dictionary")
		return

	# Save loaded data
	skills_data = result

	print("Skills loaded:", skills_data.keys())


func get_skill(name: String) -> Dictionary:
	if not skills_data.has(name):
		push_warning("Skill '%s' not found in JSON!" % name)
		return {}
	return skills_data[name]


# ============================================================
#   DAMAGE COMPUTATION WITH CRITS
# ============================================================
func compute_skill_damage(skill_name: String, user: Battler, target: Battler) -> Dictionary:
	if not skills_data.has(skill_name):
		push_warning("Skill not found: %s" % skill_name)
		return {"damage": 0, "crits": []}

	# --- Explicit typed variables ---
	var skill: Dictionary = skills_data[skill_name]
	var base: float = float(skill.get("damage", 0))
	var stat_name: String = str(skill.get("stat", ""))
	var element: String = str(skill.get("type", ""))
	var hits: int = int(skill.get("hits", 1))

	var crit_chance: float = float(skill.get("crit_chance", 0.0))
	var crit_mult: float = float(skill.get("on_crit", 1.0))
	var crit_effect: String = str(skill.get("on_crit_effect", ""))

	var result := {
		"damage": 0.0,
		"crits": [],
		"crit_effects": []
	}

	for i in range(hits):

		var dmg: float = base

		# --- Stat scaling ---
		if stat_name != "":
			if stat_name in user:
				dmg += float(user.get(stat_name)) * 0.5
			else:
				push_warning("User missing stat: %s" % stat_name)

		# --- Elemental mods ---
		if element != "":
			if element in target.weak:
				dmg *= 1.5
			if element in target.resist:
				dmg *= 0.6

		# --- Critics ---
		var did_crit: bool = randf() <= crit_chance
		if did_crit:
			dmg *= crit_mult
			result["crit_effects"].append(crit_effect)
		else:
			result["crit_effects"].append(null)

		result["crits"].append(did_crit)
		result["damage"] += dmg

	result["damage"] = int(round(result["damage"]))
	return result


func can_user_use(skill_name: String, user: Battler) -> bool:
	var skill: Dictionary = skills_data[skill_name]
	if not skill.has("allowed_users"):
		return true
	return user.name in skill["allowed_users"]


func get_skills_for_battler(battler: Battler) -> Array[String]:
	var list: Array[String] = []
	
	for skill_name in skills_data.keys():
		var skill: Dictionary = skills_data[skill_name]

		if not skill.has("allowed_users"):
			continue

		if battler.name in skill["allowed_users"]:
			list.append(skill_name)

	return list
