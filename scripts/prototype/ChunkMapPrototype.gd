extends Node2D

# ============================================================================
# ORGANIC CHUNK-MAP PROTOTYPE  (throwaway / not the real game loop)
#
# Reveals up to N_CHUNKS chunks at once and draws their organic borders so we
# can eyeball the generation techniques before wiring any of it into Main.gd:
#
#   * Weighted, domain-warped Voronoi  -> organic chunk regions & seams
#   * Spawn site distance-bonus         -> a visibly larger home chunk
#   * Elevation noise + beach band      -> sand always hugging water
#   * Cellular-automata caves by ring   -> more walls / choke points further out
#   * Ring-weighted ore + copper/coal floor -> rarer ore out, basics never gone
#
# Press SPACE to reroll the seed, R to redraw. It is intentionally not playable.
# ============================================================================

const SEED_BASE := 1337

# --- Layout ------------------------------------------------------------------
const N_CHUNKS := 20            # hard cap on revealed chunks
const MAX_RING := 5             # spiral rings available (>= enough for 20)
const SITE_SPACING := 22        # tile distance between neighbouring chunk sites
const REVEAL_R := 15.0          # how far a chunk blob reaches from its site
const SPAWN_BONUS := 10.0       # extra reach for the spawn chunk (bigger home)
const WARP_AMP := 7.0           # domain-warp strength -> wiggle of the borders
const TILE := 8                 # px per tile in the reveal view

# --- Terrain thresholds ------------------------------------------------------
const SEA_LEVEL := -0.18        # elevation below this -> water
const BEACH_BAND := 0.10        # elevation band above sea level -> sand
const CA_PASSES := 4            # cellular-automata smoothing iterations

const ORE_KINDS := ["copper", "coal", "lead", "titanium", "thorium"]

const DIRS8 := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

# --- Generated state ---------------------------------------------------------
var _sites: Array = []              # [{coord, ring, pos(Vector2 tile), bonus}]
var _owner: Dictionary = {}         # Vector2i tile -> site index (revealed only)
var _terrain: Dictionary = {}       # Vector2i tile -> String
var _ore: Dictionary = {}           # Vector2i tile -> String
var _core_tile := Vector2i.ZERO
var _seed := SEED_BASE

# Noise fields (rebuilt per seed).
var _elev: FastNoiseLite
var _walls: FastNoiseLite
var _oren: FastNoiseLite
var _warp_x: FastNoiseLite
var _warp_y: FastNoiseLite

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#16181c"))
	_generate()
	_fit_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_seed += 1
			_generate()
			_fit_camera()
			queue_redraw()
		elif event.keycode == KEY_R:
			_generate()
			_fit_camera()
			queue_redraw()


# ============================================================================
# GENERATION
# ============================================================================

func _generate() -> void:
	_owner.clear()
	_terrain.clear()
	_ore.clear()
	_sites.clear()
	_rng.seed = _seed
	_build_noise()

	_build_sites()
	_assign_voronoi()          # organic regions + reveal mask
	_paint_base_terrain()      # water / sand / ground from elevation
	_carve_caves()             # cellular-automata walls, denser by ring
	_place_ore()               # ring-weighted, with copper/coal floor
	_clear_spawn_core()


func _build_noise() -> void:
	_elev = _make_noise(_seed + 11, 0.045, FastNoiseLite.TYPE_SIMPLEX_SMOOTH)
	_walls = _make_noise(_seed + 23, 0.11, FastNoiseLite.TYPE_SIMPLEX)
	_oren = _make_noise(_seed + 37, 0.16, FastNoiseLite.TYPE_SIMPLEX_SMOOTH)
	_warp_x = _make_noise(_seed + 51, 0.05, FastNoiseLite.TYPE_SIMPLEX)
	_warp_y = _make_noise(_seed + 67, 0.05, FastNoiseLite.TYPE_SIMPLEX)


func _make_noise(s: int, freq: float, kind: FastNoiseLite.NoiseType) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = s
	n.frequency = freq
	n.noise_type = kind
	return n


# --- Sites: spiral of chunk coords, first N_CHUNKS kept --------------------

func _build_sites() -> void:
	var spawn := Vector2i(MAX_RING, MAX_RING)
	var order := _spiral_order(MAX_RING, spawn)
	var count: int = mini(N_CHUNKS, order.size())
	for i in count:
		var cc: Vector2i = order[i]
		var ring: int = maxi(absi(cc.x - MAX_RING), absi(cc.y - MAX_RING))
		var center := Vector2(
			float(cc.x * SITE_SPACING) + SITE_SPACING * 0.5,
			float(cc.y * SITE_SPACING) + SITE_SPACING * 0.5
		)
		var bonus := (SPAWN_BONUS if cc == spawn else 0.0)
		_sites.append({"coord": cc, "ring": ring, "pos": center, "bonus": bonus})
		if cc == spawn:
			_core_tile = Vector2i(int(center.x), int(center.y))


func _spiral_order(max_ring: int, sc: Vector2i) -> Array:
	var out: Array = [sc]
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


# --- Weighted domain-warped Voronoi ----------------------------------------

func _assign_voronoi() -> void:
	# Bounding box of all sites, padded so organic blobs can spill outward.
	var minp := Vector2(INF, INF)
	var maxp := Vector2(-INF, -INF)
	for s in _sites:
		minp = minp.min(s.pos)
		maxp = maxp.max(s.pos)
	var pad := int(REVEAL_R + SPAWN_BONUS + WARP_AMP) + 3
	var x0 := int(minp.x) - pad
	var x1 := int(maxp.x) + pad
	var y0 := int(minp.y) - pad
	var y1 := int(maxp.y) + pad

	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			# Warp the sample position so the nearest-site seams wiggle.
			var wx := float(tx) + _warp_x.get_noise_2d(tx, ty) * WARP_AMP
			var wy := float(ty) + _warp_y.get_noise_2d(tx, ty) * WARP_AMP
			var wpos := Vector2(wx, wy)
			var best := INF
			var best_i := -1
			for i in _sites.size():
				var s = _sites[i]
				var eff: float = wpos.distance_to(s.pos) - s.bonus
				if eff < best:
					best = eff
					best_i = i
			# Revealed only inside a blob radius -> organic outer coastline.
			if best_i >= 0 and best <= REVEAL_R:
				_owner[Vector2i(tx, ty)] = best_i


# --- Base terrain: elevation -> water, beach band -> sand -------------------

func _paint_base_terrain() -> void:
	for t in _owner.keys():
		var e := _elev.get_noise_2d(t.x, t.y)
		if e < SEA_LEVEL:
			_terrain[t] = "water"
		elif e < SEA_LEVEL + BEACH_BAND:
			_terrain[t] = "sand"
		else:
			_terrain[t] = "ground" if e < 0.55 else "stone"


# --- Cellular-automata caves, wall density rising with ring ----------------

func _carve_caves() -> void:
	# Seed: land tiles roll a wall based on noise, thresholded per ring so the
	# frontier is rockier (more choke points) than home.
	var wall: Dictionary = {}
	for t in _owner.keys():
		if _terrain[t] == "water":
			continue
		var ring: int = _sites[_owner[t]].ring
		var density: float = minf(0.62, 0.30 + 0.09 * float(ring))
		# noise in [-1,1] -> [0,1]; below density becomes seed wall.
		var v := (_walls.get_noise_2d(t.x, t.y) + 1.0) * 0.5
		if v < density:
			wall[t] = true

	# Smooth: classic 4-5 rule. A cell is rock if it has >= 5 rock neighbours
	# (missing/void neighbours count as rock so blobs close near the edges).
	for _pass in CA_PASSES:
		var next: Dictionary = {}
		for t in _owner.keys():
			if _terrain[t] == "water":
				continue
			var n := 0
			for d in DIRS8:
				var nb: Vector2i = t + d
				if not _owner.has(nb) or wall.has(nb):
					n += 1
			if n >= 5:
				next[t] = true
		wall = next

	for t in wall.keys():
		_terrain[t] = "rock"


# --- Ore: ring-weighted tiers, with a copper + coal floor per chunk ---------

func _place_ore() -> void:
	# Group revealed, mineable tiles by chunk.
	var by_chunk: Dictionary = {}
	for t in _owner.keys():
		var terr: String = _terrain[t]
		if terr == "water" or terr == "rock":
			continue
		var ci: int = _owner[t]
		if not by_chunk.has(ci):
			by_chunk[ci] = []
		by_chunk[ci].append(t)

	for ci in by_chunk.keys():
		var ring: int = _sites[ci].ring
		var tiles: Array = by_chunk[ci]
		var has_copper := false
		var has_coal := false
		# Ore clusters: threshold a mid-frequency noise into blobs, kind by ring.
		for t in tiles:
			var v := (_oren.get_noise_2d(t.x, t.y) + 1.0) * 0.5
			if v > 0.72:
				var kind := _roll_ore_kind(ring)
				_ore[t] = kind
				if kind == "copper":
					has_copper = true
				elif kind == "coal":
					has_coal = true
		# Floor guarantee: every chunk keeps at least one copper and one coal
		# seed so the basics are never absent no matter how far out.
		if not has_copper:
			_force_seed(tiles, "copper")
		if not has_coal:
			_force_seed(tiles, "coal")


func _force_seed(tiles: Array, kind: String) -> void:
	if tiles.is_empty():
		return
	var t: Vector2i = tiles[_rng.randi_range(0, tiles.size() - 1)]
	# Little 4-neighbour blob so the floor reads as a cluster, not a speck.
	_ore[t] = kind
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		var nb: Vector2i = t + d
		var terr := String(_terrain.get(nb, "rock"))
		if _owner.has(nb) and terr != "water" and terr != "rock":
			_ore[nb] = kind


func _roll_ore_kind(ring: int) -> String:
	var f := float(ring) / float(maxi(MAX_RING, 1))
	var weights := {
		"copper": maxf(0.18, 1.2 - f * 1.4),
		"coal": maxf(0.15, 1.0 - f * 1.1),
		"lead": 0.25 + f * 0.7,
		"titanium": maxf(0.0, f - 0.2) * 1.6,
		"thorium": maxf(0.0, f - 0.45) * 2.4,
	}
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var roll := _rng.randf() * total
	for k in ORE_KINDS:
		roll -= float(weights[k])
		if roll <= 0.0:
			return k
	return "copper"


func _clear_spawn_core() -> void:
	# Keep a clean 5x5 landing pad of ground at the home core.
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var p: Vector2i = _core_tile + Vector2i(dx, dy)
			if _owner.has(p):
				_terrain[p] = "ground"
				_ore.erase(p)


# ============================================================================
# RENDERING
# ============================================================================

func _fit_camera() -> void:
	if _owner.is_empty():
		return
	var minp := Vector2i(1 << 30, 1 << 30)
	var maxp := Vector2i(-(1 << 30), -(1 << 30))
	for t in _owner.keys():
		minp = minp.min(t)
		maxp = maxp.max(t)
	var span := Vector2((maxp - minp) + Vector2i.ONE) * float(TILE)
	var center := (Vector2(minp + maxp) * 0.5 + Vector2(0.5, 0.5)) * float(TILE)

	var cam := get_node_or_null("Cam") as Camera2D
	if cam == null:
		cam = Camera2D.new()
		cam.name = "Cam"
		add_child(cam)
	cam.position = center
	var vp := get_viewport_rect().size
	var z: float = minf(vp.x / maxf(span.x, 1.0), vp.y / maxf(span.y, 1.0)) * 0.92
	cam.zoom = Vector2(z, z)
	cam.make_current()


func _draw() -> void:
	# Tiles, with a faint per-chunk hue tint so each organic region reads clearly.
	for t in _owner.keys():
		var r := Rect2(Vector2(t) * float(TILE), Vector2(TILE, TILE))
		draw_rect(r, _terrain_color(String(_terrain.get(t, "ground"))))
		draw_rect(r, _chunk_tint(_owner[t]))
		if _ore.has(t):
			var pad := float(TILE) * 0.22
			var orr := Rect2(r.position + Vector2(pad, pad), r.size - Vector2(pad, pad) * 2.0)
			draw_rect(orr, _ore_color(String(_ore[t])))

	# Borders: outer coastline (void neighbour) thick/dark; chunk seams visible.
	var seam := Color(0.98, 0.9, 0.6, 0.55)
	var edge := Color(0.05, 0.05, 0.07, 0.9)
	for t in _owner.keys():
		var owner_i: int = _owner[t]
		var base := Vector2(t) * float(TILE)
		# Right edge.
		var rn: Vector2i = t + Vector2i(1, 0)
		_edge_line(base + Vector2(TILE, 0), base + Vector2(TILE, TILE), rn, owner_i, seam, edge)
		# Bottom edge.
		var dn: Vector2i = t + Vector2i(0, 1)
		_edge_line(base + Vector2(0, TILE), base + Vector2(TILE, TILE), dn, owner_i, seam, edge)
		# Also draw top/left when neighbour is void so the coastline fully closes.
		var un: Vector2i = t + Vector2i(0, -1)
		if not _owner.has(un):
			draw_line(base, base + Vector2(TILE, 0), edge, 2.0)
		var ln: Vector2i = t + Vector2i(-1, 0)
		if not _owner.has(ln):
			draw_line(base, base + Vector2(0, TILE), edge, 2.0)

	# Core marker.
	var c := Vector2(_core_tile) * float(TILE) + Vector2(TILE, TILE) * 0.5
	draw_circle(c, float(TILE) * 0.9, Color("#f4e2ff"))
	draw_circle(c, float(TILE) * 0.55, Color("#8b5cff"))


func _edge_line(a: Vector2, b: Vector2, nb: Vector2i, owner_i: int, seam: Color, edge: Color) -> void:
	if not _owner.has(nb):
		draw_line(a, b, edge, 2.0)       # outer coastline
	elif _owner[nb] != owner_i:
		draw_line(a, b, seam, 1.5)       # organic chunk seam


# A faint distinct tint per chunk so the organic regions are legible; the spawn
# chunk (index 0) is left untinted so its larger footprint stands out.
func _chunk_tint(i: int) -> Color:
	if i == 0:
		return Color(1, 1, 1, 0.0)
	var h := fmod(float(i) * 0.61803399, 1.0)   # golden-ratio hue spread
	var c := Color.from_hsv(h, 0.55, 1.0)
	c.a = 0.14
	return c


func _terrain_color(t: String) -> Color:
	match t:
		"stone": return Color("#68705f")
		"rock": return Color("#3d4248")
		"water": return Color("#285f82")
		"sand": return Color("#c9b072")
		"magma": return Color("#b5432a")
		"geode": return Color("#7d5ba6")
		_: return Color("#586454")


func _ore_color(kind: String) -> Color:
	match kind:
		"copper": return Color("#d98452")
		"coal": return Color("#2b2b30")
		"lead": return Color("#8a8fb0")
		"titanium": return Color("#8fd0e0")
		"thorium": return Color("#a6e06a")
		_: return Color("#f2c766")
