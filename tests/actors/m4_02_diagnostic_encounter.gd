extends "res://scripts/m4/isolated_rescue_clock_encounter.gd"

# Test-only subclass. No production reference and no published-root mutation.
var fault: String = ""
var stale_seal: bool = false
var fail_actor: String = ""


func _publication_fault(candidate: Dictionary) -> String:
	if not fail_actor.is_empty() and candidate.phase == "CLOSED" and candidate.episodes[fail_actor].budget != snapshot().episodes[fail_actor].budget:
		return "M4_INVALID_CANDIDATE"
	return fault


func _sealed_revision_matches(revision: int) -> bool:
	return not stale_seal and super._sealed_revision_matches(revision)
