class_name ActorDefinition
extends RefCounted

# Baseline data only. No scene nodes, current HP or mutable nested containers.
const FIELDS: Array[String] = ["actor_id", "display_name", "role", "base_max_hp"]
const ROLES: Array[String] = ["PLAYER", "NPC", "ENEMY"]
var _data: Dictionary = {}


static func create(data: Variant) -> ActorDefinition:
	if typeof(data) != TYPE_DICTIONARY or data.size() != FIELDS.size():
		return null
	for field in FIELDS:
		if not data.has(field):
			return null
	if typeof(data.actor_id) != TYPE_STRING or not valid_actor_id(data.actor_id):
		return null
	if typeof(data.display_name) != TYPE_STRING or data.display_name.strip_edges().is_empty():
		return null
	if typeof(data.role) != TYPE_STRING or data.role not in ROLES:
		return null
	if typeof(data.base_max_hp) != TYPE_INT or data.base_max_hp <= 0:
		return null
	var definition := ActorDefinition.new()
	definition._data = data.duplicate(true)
	definition._data.make_read_only()
	return definition


static func valid_actor_id(actor_id: String) -> bool:
	# Stable lowercase snake_case IDs, starting with a letter.
	if actor_id.is_empty() or actor_id[0] < "a" or actor_id[0] > "z":
		return false
	for character in actor_id:
		if not (character >= "a" and character <= "z") \
			and not (character >= "0" and character <= "9") and character != "_":
			return false
	return true


func snapshot() -> Dictionary:
	return _data.duplicate(true)
