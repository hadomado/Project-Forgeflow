extends RefCounted

# Chunked procedural map generator + expanding-world support.
#
# The world is an expanding set of chunks. Each chunk owns an ORGANIC blob of
# tiles (not a square) carved out with a weighted, domain-warped Voronoi test,
# so chunk borders and the explored frontier are naturally wiggly. Only the
# tiles a chunk owns are written; everything else defaults to "rock" and reads
# as impassable void until an adjacent chunk is opened and fills it in.
#
# All generation is a pure function of (world_seed, chunk coord, tile position),
# so opening a chunk is deterministic and independent of the order chunks open
# in -- neighbouring blobs always tile together seamlessly.
#
# Ownership (see PROJECT_CONTEXT.md `map/`): this file owns terrain, ores,
# natural walls, geodes, liquids/sand/magma placement, per-chunk spawn seeding,
# and the spiral expansion order. Main owns *when* to expand and feeds wave
# lifecycle events in; the generator decides *how* a chunk looks.

const DIRS4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIRS8 := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

# Ore kinds by tier used for the distance bias. sand/water/magma are terrain.
const ORE_KINDS := ["copper", "coal", "lead", "titanium", "thorium"]

# --- Organic-generation tuning ----------------------------------------------
const REVEAL_R := 16.0          # how far a chunk blob reaches from its site
const SPAWN_BONUS := 10.0       # extra reach for the home chunk (bigger spawn)
const WARP_AMP := 7.0           # domain-warp strength -> wiggle of the borders
const SEA_LEVEL := -0.18        # elevation below this -> water
const BEACH_BAND := 0.10        # elevation band above sea level -> sand (beach)
const STONE_LEVEL := 0.55       # elevation above this -> stone accent
const CA_PASSES := 4            # cellular-automata cave smoothing iterations
const ORE_T := 0.66            # ore-noise above this -> ore
const GEODE_T := 0.82           # ore-noise above this -> geode core (in ore)
const MAGMA_T := 0.80           # magma-noise above this -> magma (outer only)
const MAGMA_MIN_RINGF := 1.3    # magma only this many chunks out from the core
const WALL_BASE := 0.30         # cave wall seed density at the core...
const WALL_PER_RING := 0.09     # ...rising this much per chunk of distance...
const WALL_MAX := 0.60          # ...capped here (more choke points further out).
const CORE_CLEAR := 11          # ground disc kept clear around the home core

# Cached noise fields per world seed so repeated open_chunk calls are cheap.
static var _fields_cache := {}

# --- Natural walls -----------------------------------------------------------

# Terrain kinds that block movement and building like a wall.
static func is_natural_wall(t: String) -> bool:
	return t == "rock" or t == "geode"

static func _is_land(t: String) -> bool:
	return t == "ground" or t == "stone" or t == "sand"

# Remove any ore that ended up under a natural wall (e.g. a geode carved into a
# deposit). Kept as a named entry point because Main and the tests call it.
static func cleanup_ore_in_natural_walls(terrain: Dictionary, ore: Dictionary) -> void:
	var to_remove: Array[Vector2i] = []
	for p in ore.keys():
		if is_natural_wall(String(terrain.get(p, "rock"))):
			to_remove.append(p)
	for p in to_remove:
		ore.erase(p)

# --- World lifecycle ---------------------------------------------------------

# Fresh world: nothing generated except the spawn chunk. Returns the
# terrain/ore dictionaries, chunk metadata, spiral order, and the resolved seed.
#   opts = { chunk, max_ring, core_pos, core_size, seed }
static func new_world(opts: Dictionary) -> Dictionary:
	var max_ring: int = int(opts.get("max_ring", 5))
	var world_seed: int = int(opts.get("seed", 0))
	if world_seed == 0:
		world_seed = randi() | 1
	var spawn_chunk := Vector2i(max_ring, max_ring)
	var terrain := {}
	var ore := {}
	var order := spiral_order(max_ring, spawn_chunk)
	var chunks := {}
	var sub := opts.duplicate()
	sub["seed"] = world_seed
	var meta := open_chunk(terrain, ore, spawn_chunk, 0, sub)
	chunks[spawn_chunk] = meta
	return {
		"terrain": terrain,
		"ore": ore,
		"chunks": chunks,
		"order": order,
		"spawn_chunk": spawn_chunk,
		"seed": world_seed,
	}

# Deterministic spiral of chunk coords, spawn chunk first, expanding ring by
# ring outward. All coords land in [0, 2*max_ring].
static func spiral_order(max_ring: int, sc: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [sc]
	for r in range(1, max_ring + 1):
		var minx := sc.x - r
		var maxx := sc.x + r
		var miny := sc.y - r
		var maxy := sc.y + r
		for x in range(minx, maxx + 1):
			out.append(Vector2i(x, miny))
		for y in range(miny + 1, maxy + 1):
			out.append(Vector2i(maxx, y))
		for x in range(maxx - 1, minx - 1, -1):
			out.append(Vector2i(x, maxy))
		for y in range(maxy - 1, miny, -1):
			out.append(Vector2i(minx, y))
	return out

static func chunk_ring(cc: Vector2i, max_ring: int) -> int:
	return maxi(absi(cc.x - max_ring), absi(cc.y - max_ring))

# Generate one chunk's organic blob into `terrain`/`ore` in place. Returns:
#   { coord, ring, index, origin (tile), spawn (tile), tiles (Array[Vector2i]) }
static func open_chunk(terrain: Dictionary, ore: Dictionary, cc: Vector2i, index: int, opts: Dictionary) -> Dictionary:
	var chunk: int = int(opts.get("chunk", 24))
	var max_ring: int = int(opts.get("max_ring", 5))
	var core_pos: Vector2i = opts.get("core_pos", Vector2i.ZERO)
	var world_seed: int = int(opts.get("seed", 1337))
	var map_w := (2 * max_ring + 1) * chunk
	var map_h := map_w
	var fld := _get_fields(world_seed)
	var n_elev: FastNoiseLite = fld["elev"]
	var n_ore: FastNoiseLite = fld["ore"]
	var n_magma: FastNoiseLite = fld["magma"]
	var spawn_chunk := Vector2i(max_ring, max_ring)
	var ring := chunk_ring(cc, max_ring)
	var sc := _site_center(cc, chunk)
	var bonus := (SPAWN_BONUS if cc == spawn_chunk else 0.0)

	# Neighbouring sites (5x5) so the Voronoi border with adjacent chunks is exact.
	var neigh: Array = []
	for ny in range(-2, 3):
		for nx in range(-2, 3):
			var ncc := cc + Vector2i(nx, ny)
			neigh.append({
				"pos": _site_center(ncc, chunk),
				"bonus": (SPAWN_BONUS if ncc == spawn_chunk else 0.0),
			})

	# 1) Owned tiles: warped nearest-site test, clipped to a reveal radius.
	var pad := int(ceil(REVEAL_R + bonus + WARP_AMP)) + 2
	var owned: Array[Vector2i] = []
	var owned_set := {}
	var amin := Vector2i(map_w, map_h)
	var amax := Vector2i(-1, -1)
	for ty in range(maxi(0, int(sc.y) - pad), mini(map_h, int(sc.y) + pad + 1)):
		for tx in range(maxi(0, int(sc.x) - pad), mini(map_w, int(sc.x) + pad + 1)):
			var p := Vector2i(tx, ty)
			var wp := _warp(fld, p)
			var eff := wp.distance_to(sc) - bonus
			if eff > REVEAL_R:
				continue
			var mine := true
			for s in neigh:
				var sp: Vector2 = s["pos"]
				var sb: float = s["bonus"]
				if wp.distance_to(sp) - sb < eff - 0.0001:
					mine = false
					break
			if not mine:
				continue
			owned.append(p)
			owned_set[p] = true
			amin.x = mini(amin.x, tx)
			amin.y = mini(amin.y, ty)
			amax.x = maxi(amax.x, tx)
			amax.y = maxi(amax.y, ty)

	if owned.is_empty():
		return {"coord": cc, "ring": ring, "index": index, "origin": cc * chunk, "spawn": sc as Vector2i, "tiles": owned}

	# 2) Cave walls via cellular automata over the blob's AABB (+skirt so the
	#    result matches a global CA exactly on owned tiles). Denser further out.
	var wall := _carve_walls(fld, amin, amax, core_pos, chunk)

	# 3) Base terrain: elevation -> water / beach sand / ground / stone, magma in
	#    the outer field, then CA rock over land.
	for p in owned:
		var ev := n_elev.get_noise_2d(p.x, p.y)
		var t := "ground"
		if ev < SEA_LEVEL:
			t = "water"
		elif ev < SEA_LEVEL + BEACH_BAND:
			t = "sand"
		elif ev > STONE_LEVEL:
			t = "stone"
		if t != "water":
			var df := Vector2(p).distance_to(Vector2(core_pos)) / float(chunk)
			if df >= MAGMA_MIN_RINGF and _n01(n_magma.get_noise_2d(p.x, p.y)) > MAGMA_T:
				t = "magma"
		if _is_land(t) and wall.has(p):
			t = "rock"
		terrain[p] = t

	# 4) Ore + geode cores on land. Ring-weighted tiers, coherent clusters.
	var has_copper := false
	var has_coal := false
	for p in owned:
		if not _is_land(String(terrain[p])):
			continue
		var nn := _n01(n_ore.get_noise_2d(p.x, p.y))
		if nn > GEODE_T:
			var kind := _ore_kind_for(fld, p, ring, max_ring)
			terrain[p] = "geode"                      # natural-wall core...
			for d in DIRS4:                           # ...ringed by its ore.
				var q: Vector2i = p + d
				if owned_set.has(q) and _is_land(String(terrain.get(q, "rock"))) and not ore.has(q):
					ore[q] = kind
					has_copper = has_copper or kind == "copper"
					has_coal = has_coal or kind == "coal"
		elif nn > ORE_T:
			var kind2 := _ore_kind_for(fld, p, ring, max_ring)
			ore[p] = kind2
			has_copper = has_copper or kind2 == "copper"
			has_coal = has_coal or kind2 == "coal"

	# Floor guarantee: no chunk is ever void of the basics, no matter how far out.
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed ^ (cc.x * 73856093) ^ (cc.y * 19349663)
	if not has_copper:
		_force_seed(terrain, ore, owned, owned_set, "copper", rng)
	if not has_coal:
		_force_seed(terrain, ore, owned, owned_set, "coal", rng)

	# 5) Connectivity: keep the home core clear, place the frontier spawn tile,
	#    and carve a corridor from that spawn tile back toward the core.
	if ring == 0:
		for p in owned:
			if Vector2(p).distance_to(Vector2(core_pos)) <= float(CORE_CLEAR):
				terrain[p] = "ground"
				ore.erase(p)

	var spawn := _pick_spawn_tile(owned, owned_set, sc, cc, spawn_chunk)
	_carve_line(terrain, ore, owned_set, spawn, core_pos)
	terrain[spawn] = "spawn"
	ore.erase(spawn)

	# Ore never survives under a natural wall.
	for p in owned:
		if is_natural_wall(String(terrain.get(p, "rock"))):
			ore.erase(p)

	return {"coord": cc, "ring": ring, "index": index, "origin": cc * chunk, "spawn": spawn, "tiles": owned}

# --- Cellular-automata caves -------------------------------------------------

static func _carve_walls(fld: Dictionary, amin: Vector2i, amax: Vector2i, core_pos: Vector2i, chunk: int) -> Dictionary:
	var n_elev: FastNoiseLite = fld["elev"]
	var n_wall: FastNoiseLite = fld["wall"]
	var skirt := CA_PASSES + 2
	var wmin := amin - Vector2i(skirt, skirt)
	var wmax := amax + Vector2i(skirt, skirt)
	var wall := {}
	for ty in range(wmin.y, wmax.y + 1):
		for tx in range(wmin.x, wmax.x + 1):
			if n_elev.get_noise_2d(tx, ty) < SEA_LEVEL:
				continue                              # never wall water
			var df := Vector2(tx, ty).distance_to(Vector2(core_pos)) / float(chunk)
			var density := clampf(WALL_BASE + WALL_PER_RING * df, WALL_BASE, WALL_MAX)
			if _n01(n_wall.get_noise_2d(tx, ty)) < density:
				wall[Vector2i(tx, ty)] = true
	for _pass in CA_PASSES:
		var nxt := {}
		for ty in range(wmin.y + 1, wmax.y):
			for tx in range(wmin.x + 1, wmax.x):
				if n_elev.get_noise_2d(tx, ty) < SEA_LEVEL:
					continue
				var p := Vector2i(tx, ty)
				var c := 0
				for d in DIRS8:
					if wall.has(p + d):
						c += 1
				if c >= 5:
					nxt[p] = true
		wall = nxt
	return wall

# --- Ore tier bias -----------------------------------------------------------

# Weighted ore pick that shifts toward higher tiers the further out the chunk
# is. Driven by a smooth "kind" noise so a deposit reads as one coherent kind.
static func _ore_kind_for(fld: Dictionary, p: Vector2i, ring: int, max_ring: int) -> String:
	var t := float(ring) / float(maxi(max_ring, 1))
	var weights := {
		"copper": maxf(0.18, 1.2 - t * 1.4),
		"coal": maxf(0.15, 1.0 - t * 1.1),
		"lead": 0.25 + t * 0.7,
		"titanium": maxf(0.0, t - 0.2) * 1.6,
		"thorium": maxf(0.0, t - 0.45) * 2.4,
	}
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var n_kind: FastNoiseLite = fld["kind"]
	var roll := _n01(n_kind.get_noise_2d(p.x, p.y)) * total
	for k in ORE_KINDS:
		roll -= float(weights[k])
		if roll <= 0.0:
			return k
	return "copper"

static func _force_seed(terrain: Dictionary, ore: Dictionary, owned: Array[Vector2i], owned_set: Dictionary, kind: String, rng: RandomNumberGenerator) -> void:
	var land: Array[Vector2i] = []
	for p in owned:
		if _is_land(String(terrain.get(p, "rock"))):
			land.append(p)
	if land.is_empty():
		return
	var t: Vector2i = land[rng.randi_range(0, land.size() - 1)]
	ore[t] = kind
	for d in DIRS4:
		var q: Vector2i = t + d
		if owned_set.has(q) and _is_land(String(terrain.get(q, "rock"))):
			ore[q] = kind

# --- Geometry helpers --------------------------------------------------------

static func _site_center(cc: Vector2i, chunk: int) -> Vector2:
	return Vector2(float(cc.x) * chunk + chunk * 0.5, float(cc.y) * chunk + chunk * 0.5)

static func _warp(fld: Dictionary, p: Vector2i) -> Vector2:
	var n_wx: FastNoiseLite = fld["warpx"]
	var n_wy: FastNoiseLite = fld["warpy"]
	return Vector2(p) + Vector2(n_wx.get_noise_2d(p.x, p.y), n_wy.get_noise_2d(p.x, p.y)) * WARP_AMP

static func _n01(v: float) -> float:
	return (v + 1.0) * 0.5

# Frontier spawn tile: the owned tile furthest along the outward (away-from-core)
# direction, so enemies march inward from the edge of the blob.
static func _pick_spawn_tile(owned: Array[Vector2i], owned_set: Dictionary, sc: Vector2, cc: Vector2i, spawn_chunk: Vector2i) -> Vector2i:
	var dir := Vector2(signf(float(cc.x - spawn_chunk.x)), signf(float(cc.y - spawn_chunk.y)))
	if dir == Vector2.ZERO:
		dir = Vector2(0, 1)
	dir = dir.normalized()
	var target := sc + dir * (REVEAL_R * 0.7)
	var best: Vector2i = owned[0]
	var best_d := INF
	for p in owned:
		var d := Vector2(p).distance_squared_to(target)
		if d < best_d:
			best_d = d
			best = p
	return best

# Clear a 1-wide corridor of natural walls / water to ground between two tiles,
# but only through tiles this chunk owns (so we never punch into void).
static func _carve_line(terrain: Dictionary, ore: Dictionary, owned_set: Dictionary, a: Vector2i, b: Vector2i) -> void:
	var x0 := a.x
	var y0 := a.y
	var dx := absi(b.x - x0)
	var dy := -absi(b.y - y0)
	var stepx := 1 if x0 < b.x else -1
	var stepy := 1 if y0 < b.y else -1
	var err := dx + dy
	while true:
		var p := Vector2i(x0, y0)
		if owned_set.has(p):
			var t := String(terrain.get(p, "rock"))
			if is_natural_wall(t) or t == "water":
				terrain[p] = "ground"
				ore.erase(p)
		if x0 == b.x and y0 == b.y:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += stepx
		if e2 <= dx:
			err += dx
			y0 += stepy

# --- Noise fields ------------------------------------------------------------

static func _get_fields(world_seed: int) -> Dictionary:
	if _fields_cache.has(world_seed):
		return _fields_cache[world_seed]
	var f := {
		"elev": _mk(world_seed + 11, 0.045, FastNoiseLite.TYPE_SIMPLEX_SMOOTH),
		"wall": _mk(world_seed + 23, 0.110, FastNoiseLite.TYPE_SIMPLEX),
		"ore": _mk(world_seed + 37, 0.160, FastNoiseLite.TYPE_SIMPLEX_SMOOTH),
		"kind": _mk(world_seed + 41, 0.030, FastNoiseLite.TYPE_SIMPLEX_SMOOTH),
		"magma": _mk(world_seed + 43, 0.060, FastNoiseLite.TYPE_SIMPLEX),
		"warpx": _mk(world_seed + 51, 0.050, FastNoiseLite.TYPE_SIMPLEX),
		"warpy": _mk(world_seed + 67, 0.050, FastNoiseLite.TYPE_SIMPLEX),
	}
	_fields_cache[world_seed] = f
	return f

static func _mk(s: int, freq: float, kind: FastNoiseLite.NoiseType) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = s
	n.frequency = freq
	n.noise_type = kind
	return n
