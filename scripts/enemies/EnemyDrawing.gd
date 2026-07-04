extends RefCounted

static func draw_enemy(canvas: Node2D, e: Dictionary, edef: Dictionary, enemy_sheets: Dictionary, anim_time: float) -> void:
	var er: float = float(edef.get("radius", 13.0))
	var grow: float = clamp(float(e.get("spawn_anim", 1.0)), 0.18, 1.0)
	var draw_r: float = er * grow
	var facing: Vector2 = e.get("facing", Vector2.RIGHT)
	var phase: float = e.pos.x * 0.2 + e.pos.y * 0.13
	var bob: float = abs(sin(anim_time * 9.0 + phase)) * 2.0
	var draw_pos: Vector2 = e.pos - Vector2(0.0, bob)
	var alpha: float = 0.45 if float(e.get("invuln", 0.0)) > 0.0 else 1.0
	var tint: Color = edef.color
	if e.get("enraged", false):
		tint = tint.lerp(Color(1.0, 0.28, 0.14), 0.45)
	canvas.draw_circle(e.pos + Vector2(0.0, draw_r * 0.55), draw_r * 0.85, Color(0, 0, 0, 0.18 * alpha))
	if edef.has("shield"):
		var half := deg_to_rad(float(edef.shield.arc) * 0.5)
		var a0 := facing.angle() - half
		canvas.draw_arc(draw_pos, draw_r + 5.0, a0, a0 + half * 2.0, 20, Color(0.62, 0.78, 1.0, 0.6 * alpha), 3.0)
	var tex = enemy_sheets.get(String(edef.get("sheet", "")))
	if tex != null:
		var frame: int = int(anim_time * 8.0 + phase) % 6
		var src := Rect2(frame * 32, 0, 32, 32)
		var scale: float = (draw_r * 2.4) / 32.0
		var sx: float = -scale if facing.x < 0.0 else scale
		var modc: Color = tint.lerp(Color(1, 1, 1, 1), 0.35)
		modc.a = alpha
		canvas.draw_set_transform(draw_pos, 0.0, Vector2(sx, scale))
		canvas.draw_texture_rect_region(tex, Rect2(-16, -16, 32, 32), src, modc)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_enemy_shape(canvas, draw_pos, edef, draw_r, tint, alpha, facing, anim_time)
	if float(e.get("hit_flash", 0.0)) > 0.0:
		canvas.draw_circle(draw_pos, draw_r * 0.95, Color(1, 1, 1, 0.5 * alpha))
	if e.get("charging", false):
		var pulse: float = 0.35 + 0.35 * sin(anim_time * 22.0)
		canvas.draw_line(draw_pos, e.get("charge_aim", draw_pos), Color(1.0, 0.35, 0.35, pulse), 1.5)
	if e.hp < float(e.get("max_hp", e.hp)):
		var frac: float = clamp(e.hp / float(e.max_hp), 0.0, 1.0)
		var bw: float = draw_r * 2.0
		var by: Vector2 = e.pos - Vector2(bw * 0.5, draw_r + 8.0)
		canvas.draw_rect(Rect2(by, Vector2(bw, 3.0)), Color(0, 0, 0, 0.55))
		canvas.draw_rect(Rect2(by, Vector2(bw * frac, 3.0)), Color(0.35, 0.85, 0.4).lerp(Color(0.9, 0.3, 0.25), 1.0 - frac))

static func draw_enemy_shape(canvas: Node2D, pos: Vector2, edef: Dictionary, radius: float, col: Color, alpha: float, facing: Vector2, anim_time: float) -> void:
	var ang: float = facing.angle()
	var body: Color = col
	body.a = alpha
	var dark: Color = col.darkened(0.35)
	dark.a = alpha
	match String(edef.get("shape", "diamond")):
		"triangle":
			draw_poly_shape(canvas, pos, ang, radius, [Vector2(1.1, 0), Vector2(-0.8, 0.8), Vector2(-0.8, -0.8)], body, dark)
		"diamond":
			draw_poly_shape(canvas, pos, ang, radius, [Vector2(1.0, 0), Vector2(0, 0.9), Vector2(-1.0, 0), Vector2(0, -0.9)], body, dark)
		"hex":
			var hp: Array = []
			for i in 6:
				var a: float = TAU * float(i) / 6.0
				hp.append(Vector2(cos(a), sin(a)))
			draw_poly_shape(canvas, pos, ang, radius, hp, body, dark)
		"spike":
			var sp: Array = []
			for i in 10:
				var a: float = TAU * float(i) / 10.0
				sp.append(Vector2(cos(a), sin(a)) * (1.0 if i % 2 == 0 else 0.52))
			draw_poly_shape(canvas, pos, anim_time * 2.0, radius, sp, body, dark)
		"arrow":
			draw_poly_shape(canvas, pos, ang, radius, [Vector2(1.3, 0), Vector2(-0.6, 0.7), Vector2(-0.3, 0), Vector2(-0.6, -0.7)], body, dark)
		"blob":
			canvas.draw_circle(pos, radius, body)
			canvas.draw_circle(pos, radius * 0.62, dark)
			for i in 4:
				var a: float = anim_time * 1.6 + TAU * float(i) / 4.0
				canvas.draw_circle(pos + Vector2(cos(a), sin(a)) * radius * 0.72, radius * 0.26, body)
		"cross":
			var w: float = radius * 0.42
			canvas.draw_rect(Rect2(pos.x - w, pos.y - radius, 2.0 * w, 2.0 * radius), body)
			canvas.draw_rect(Rect2(pos.x - radius, pos.y - w, 2.0 * radius, 2.0 * w), body)
			canvas.draw_circle(pos, radius * 0.35, dark)
		_:
			canvas.draw_circle(pos, radius, body)
	canvas.draw_circle(pos + Vector2(cos(ang), sin(ang)) * radius * 0.32, radius * 0.24, Color(1, 1, 1, 0.5 * alpha))

static func draw_poly_shape(canvas: Node2D, pos: Vector2, ang: float, radius: float, unit_pts: Array, fill: Color, outline: Color) -> void:
	var pts := PackedVector2Array()
	for up in unit_pts:
		pts.append(pos + (up as Vector2).rotated(ang) * radius)
	canvas.draw_colored_polygon(pts, fill)
	var loop := pts
	loop.append(pts[0])
	canvas.draw_polyline(loop, outline, 2.0)

static func draw_telegraph(canvas: Node2D, tg: Dictionary) -> void:
	var t: float = clamp(float(tg.life) / float(tg.get("max_life", 1.0)), 0.0, 1.0)
	var c: Color = tg.get("color", Color(1, 1, 1))
	match String(tg.get("type", "")):
		"blast":
			var rr: float = float(tg.radius) * (1.0 - t)
			canvas.draw_circle(tg.pos, max(rr, 1.0), Color(c.r, c.g, c.b, 0.12 * t))
			canvas.draw_arc(tg.pos, max(rr, 1.0), 0.0, TAU, 48, Color(c.r, c.g, c.b, 0.55 * t + 0.12), 4.0)
		"blink":
			canvas.draw_line(tg.from, tg.to, Color(c.r, c.g, c.b, 0.55 * t), 3.0)
			canvas.draw_circle(tg.from, 6.0 * t, Color(c.r, c.g, c.b, 0.4 * t))

static func draw_effect(canvas: Node2D, fx: Dictionary, fx_sheets: Dictionary) -> void:
	var prog: float = clamp(float(fx.t) / float(fx.dur), 0.0, 1.0)
	var radius: float = clamp(float(fx.get("scale", 12.0)), 4.0, 160.0)
	var c: Color = fx.get("color", Color(1, 1, 1))
	var key: String = "hit" if String(fx.kind) == "hit" else "burst"
	var tex = fx_sheets.get(key)
	if tex != null:
		var frames: int = 6 if key == "hit" else 8
		var frame: int = min(int(prog * float(frames)), frames - 1)
		var w: float = radius * 2.0
		var modc := Color(c.r, c.g, c.b, 1.0 - prog * 0.25)
		canvas.draw_texture_rect_region(tex, Rect2(fx.pos.x - w * 0.5, fx.pos.y - w * 0.5, w, w), Rect2(frame * 64, 0, 64, 64), modc)
	else:
		canvas.draw_arc(fx.pos, 3.0 + prog * radius, 0.0, TAU, 22, Color(c.r, c.g, c.b, 1.0 - prog), 2.0)
