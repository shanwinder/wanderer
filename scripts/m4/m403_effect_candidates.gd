extends "res://scripts/m4/isolated_queue_outcome_encounter.gd"

# Opt-in B facade. This is the SAME inherited Encounter/root, not a wrapped live
# aggregate or second owner. Keeps the unchanged A proof's absent-B-API contract.
# Pure candidate calculations remain in m403_queue_adapter.gd.
func lock_self_retreat(request: Variant, capability: Variant) -> Dictionary:
	return _lock_retreat(request, capability)


func impact(token: Variant) -> Dictionary:
	return _settle_retreat(token, "IMPACT")


func complete(token: Variant) -> Dictionary:
	return _settle_retreat(token, "COMPLETE")


func cancel(token: Variant) -> Dictionary:
	return _settle_retreat(token, "CANCEL")
