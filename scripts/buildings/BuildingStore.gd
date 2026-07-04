extends RefCounted

static func add(b: Dictionary, kind: String, amount: int) -> void:
	b.store[kind] = b.store.get(kind, 0) + amount

static func take(b: Dictionary, kind: String, amount: int) -> void:
	b.store[kind] = max(0, b.store.get(kind, 0) - amount)

static func count(b: Dictionary, kind: String) -> int:
	return int(b.store.get(kind, 0))
