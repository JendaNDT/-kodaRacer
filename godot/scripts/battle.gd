class_name Battle
extends RefCounted
## The balloon battle (Etapa H): the rules, the standings and the computer
## drivers. The Race still moves the karts and the items; it asks this
## wherever the battle works differently from a race.
##
## Every kart starts with Game.BALLOONS balloons. A hit that lands (a
## missile, the blue missile, a banana, oil, a star's push, running over a
## kart shrunk by the lightning) costs exactly one balloon; Kart.hit then
## refuses every further hit for Game.BATTLE_GUARD seconds. The last balloon
## gone, the kart is out. The battle ends with one kart left or after
## Game.BATTLE_TIME: most balloons first, then most balloons popped.

var race: Race
var arena: Arena
var over := false
var end_time := 0.0
var outs: Array = []           # karts that lost their last balloon, first one out first
var pops: Array = []           # every balloon lost: [time, victim, by] (tests, results)
var seen_pop := 0              # Wi-Fi client: the last pop (its number) the host sent
var fast_music := false

const AHEAD := [0.0, 0.35, -0.35, 0.7, -0.7, 1.05, -1.05, 1.45, -1.45, 1.95, -1.95, 2.6, -2.6]
const LOOK := 0.08               # s between two looks around for room


func _init(r: Race, a: Arena) -> void:
	race = r
	arena = a


func setup_kart(k: Kart) -> void:
	k.balloons = Game.BALLOONS
	k.pops = 0
	k.out = false
	k.ai.target = null
	k.ai.retarget = 0.0
	k.ai.rev_steer = 0.0
	k.ai.last_off = 0.0
	k.ai.look_t = randf() * LOOK      # not all on the same step
	k.ai.look_off = 0.0


func time_left() -> float:
	return maxf(0.0, Game.BATTLE_TIME - race.race_time)


func alive() -> Array:
	var out: Array = []
	for k: Kart in race.karts:
		if not k.out:
			out.append(k)
	return out


# ------------------------------------------------------------------ rules
## A hit landed on k (Kart.hit said yes): one balloon gone, `by` popped it.
func pop(k: Kart, by: Kart) -> void:
	if k.out or over:
		return
	k.balloons -= 1
	k.invuln = maxf(k.invuln, Game.BATTLE_GUARD)
	if by != null and by != k:
		by.pops += 1
	pops.append([race.race_time, k, by])
	if k.balloons <= 0:
		_knock_out(k)


## The last balloon gone: the kart leaves the arena (parked far away, so
## nothing runs into it), its player watches the others.
func _knock_out(k: Kart) -> void:
	k.out = true
	k.finished = true
	k.finish_time = race.race_time
	k.out_at = Vector3(k.x, k.y, k.z)
	outs.append(k)
	k.x = 5000.0 + k.driver * 30.0
	k.z = 5000.0
	k.speed = 0.0
	k.boost = 0.0
	k.star = 0.0
	k.item = 0
	k.item_n = 0
	k.roulette = 0.0
	k.drift_active = false
	if alive().size() <= 1:
		_end()


## After every step: the clock.
func tick() -> void:
	if not over and race.state == "race" and race.race_time >= Game.BATTLE_TIME:
		_end()


func _end() -> void:
	over = true
	end_time = race.race_time
	for k: Kart in race.karts:
		if not k.out:
			k.finished = true
			k.finish_time = race.race_time


## Best first: those still in by balloons, then balloons popped; then those
## out, the last one out first. A Wi-Fi client keeps the host's order.
func standings() -> Array:
	if race.mode == Race.Mode.CLIENT:
		var arr: Array = race.karts.duplicate()
		arr.sort_custom(func(a: Kart, b: Kart) -> bool: return a.rank < b.rank)
		return arr
	var still := alive()
	still.sort_custom(func(a: Kart, b: Kart) -> bool:
		if a.balloons != b.balloons:
			return a.balloons > b.balloons
		if a.pops != b.pops:
			return a.pops > b.pops
		return race.karts.find(a) < race.karts.find(b))
	var gone := outs.duplicate()
	gone.reverse()
	return still + gone


func compute_ranks() -> void:
	var rows := standings()
	for i in rows.size():
		(rows[i] as Kart).rank = i + 1
	race.order = rows


func winner() -> Kart:
	return standings()[0] if over else null


# ------------------------------------------------------------------ item targets
## The missile goes for the nearest rival in front of the kart (anyone
## nearest if nobody is in front).
func missile_target(k: Kart) -> Kart:
	var best: Kart = null
	var best_d := INF
	var any: Kart = null
	var any_d := INF
	for o: Kart in alive():
		if o == k:
			continue
		var d := Vector2(o.x - k.x, o.z - k.z).length()
		var ang := absf(Game.wrap_angle(atan2(o.x - k.x, o.z - k.z) - k.heading))
		if ang < 1.2 and d < best_d:
			best = o
			best_d = d
		if d < any_d:
			any = o
			any_d = d
	return best if best != null else any


## The blue missile goes for whoever has the most balloons (the nearest of them).
func blue_target(k: Kart) -> Kart:
	var best: Kart = null
	for o: Kart in alive():
		if o == k:
			continue
		if best == null or o.balloons > best.balloons or (o.balloons == best.balloons and
				Vector2(o.x - k.x, o.z - k.z).length() < Vector2(best.x - k.x, best.z - k.z).length()):
			best = o
	return best


## The draw in a battle: more missiles and bananas, fewer turbos, the same for everybody.
func give_item(k: Kart) -> void:
	var w := [
		[Game.Item.MISSILE, 1, 26.0], [Game.Item.BANANA, 1, 22.0], [Game.Item.SHIELD, 1, 10.0], [Game.Item.OIL, 1, 8.0],
		[Game.Item.TURBO, 1, 8.0], [Game.Item.STAR, 1, 7.0], [Game.Item.BLUE, 1, 5.0], [Game.Item.TURBO, 3, 3.0],
		[Game.Item.LIGHTNING, 1, 2.0],
	]
	var sum := 0.0
	for e in w:
		sum += e[2]
	var r := randf() * sum
	k.item = Game.Item.MISSILE
	k.item_n = 1
	for e in w:
		r -= e[2]
		if r <= 0.0:
			k.item = e[0]
			k.item_n = e[1]
			break


# ------------------------------------------------------------------ computer drivers
## The computer in the arena: picks a rival (the nearest, rather one with
## more balloons), chases and fires when the rival is in range and in
## front; without an item it drives to the nearest box; with one balloon
## left it keeps away and drops bananas behind. It looks ahead for walls,
## the fountain and the snow banks and turns where there is room.
func ai_input(k: Kart, dt: float) -> Dictionary:
	var out := {"steer": 0.0, "gas": true, "brake": false, "drift": false, "item": false}
	if k.finished or race.state != "race":
		out.gas = false
		return out
	var ai: Dictionary = k.ai
	var per: Dictionary = Game.PERSONA[k.driver]
	ai.t = float(ai.t) + dt
	# stuck against something: back off, turning away from it
	if float(ai.rev) > 0.0:
		ai.rev = float(ai.rev) - dt
		out.gas = false
		out.brake = true
		out.steer = float(ai.rev_steer)
		return out
	if absf(k.speed) < 3.0 and k.spin <= 0.0:
		ai.stuck = float(ai.stuck) + dt
		if float(ai.stuck) > 0.7:
			ai.stuck = 0.0
			ai.rev = 0.8
			# backing up turns the kart the other way round: steer so that it
			# ends up facing the open space
			var n := arena.away(k.x, k.z)
			ai.rev_steer = 1.0 if Game.wrap_angle(atan2(n.x, n.y) - k.heading) > 0.0 else -1.0
			return out
	else:
		ai.stuck = 0.0
	# whom to go after
	ai.retarget = float(ai.retarget) - dt
	var tg: Kart = ai.get("target")
	if tg == null or tg.out or float(ai.retarget) <= 0.0:
		tg = _pick_target(k, float(per.hunt))
		ai.target = tg
		ai.retarget = 1.2 + randf() * 1.0
	var goal := Vector2(k.x, k.z)
	var careful := (k.balloons == 1 and float(per.hunt) < 1.3) or (k.balloons == 2 and float(per.hunt) < 0.8)
	var attacking := k.item in [Game.Item.MISSILE, Game.Item.STAR, Game.Item.BLUE, Game.Item.LIGHTNING] or k.star > 0.0
	if k.item == 0 and k.roulette <= 0.0 and k.star <= 0.0:
		goal = _nearest_box(k)
	elif careful and not attacking and tg != null:
		goal = _away_from(k, tg)
	elif tg != null:
		# lead the rival a little
		var lead := clampf(Vector2(tg.x - k.x, tg.z - k.z).length() / 60.0, 0.0, 0.6)
		goal = Vector2(tg.x + sin(tg.heading) * tg.speed * lead, tg.z + cos(tg.heading) * tg.speed * lead)
	var want := atan2(goal.x - k.x, goal.y - k.z)
	# looking around for room costs; every LOOK seconds is plenty, in between
	# it keeps the same turn away from the goal
	ai.look_t = float(ai.look_t) - dt
	if float(ai.look_t) <= 0.0:
		ai.look_t = LOOK
		ai.look_off = Game.wrap_angle(_clear_heading(k, want) - want)
	var h := want + float(ai.look_off)
	var dif := Game.wrap_angle(h - k.heading)
	out.steer = clampf(-dif * 2.4, -1.0, 1.0)
	var top := k.max_speed() * float(ai.skill)
	out.gas = (absf(dif) < 1.7 or k.speed < 10.0) and (k.speed < top or k.boost > 0.0)
	out.brake = absf(dif) > 2.3 and k.speed > 16.0
	_ai_item(k, out, tg, dt, careful)
	return out


func _pick_target(k: Kart, hunt: float) -> Kart:
	var best: Kart = null
	var best_s := INF
	for o: Kart in alive():
		if o == k:
			continue
		var d := Vector2(o.x - k.x, o.z - k.z).length()
		var s := d / (1.0 + 0.3 * (o.balloons - 1) * hunt)
		if o.human:
			s *= 0.9                            # a little keener on the players
		if s < best_s:
			best = o
			best_s = s
	return best


func _nearest_box(k: Kart) -> Vector2:
	var best := INF
	# no box out: a slow round through the middle
	var w := float(k.ai.phase) + float(k.ai.t) * 0.15
	var at := Vector2(sin(w) * 30.0, cos(w) * 30.0)
	for b in race.boxes:
		if not b.active:
			continue
		var d := Vector2(float(b.x) - k.x, float(b.z) - k.z).length()
		# boxes ahead are cheaper than ones behind
		var ang := absf(Game.wrap_angle(atan2(float(b.x) - k.x, float(b.z) - k.z) - k.heading))
		var cost := d + ang * 9.0
		if cost < best:
			best = cost
			at = Vector2(float(b.x), float(b.z))
	return at


## A spot away from the rival, towards open space.
func _away_from(k: Kart, tg: Kart) -> Vector2:
	var d := Vector2(k.x - tg.x, k.z - tg.z)
	if d.length() > 45.0:
		return Vector2(sin(float(k.ai.t) * 0.2 + float(k.ai.phase)) * 25.0, cos(float(k.ai.t) * 0.2 + float(k.ai.phase)) * 25.0)
	var p := Vector2(k.x, k.z) + d.normalized() * 30.0 + arena.away(k.x, k.z) * 15.0
	return p


## How far the kart can drive along heading h before something solid (or
## the high side of a ramp) is in the way, up to `far` metres.
func clearance(px: float, pz: float, h: float, far: float) -> float:
	var dx := sin(h)
	var dz := cos(h)
	var d := 1.5
	while d <= far:
		var x := px + dx * d
		var z := pz + dz * d
		if arena.space(x, z, -INF, true) < Game.KART_R + 0.6:
			return d
		if arena.ramp_blocks(x, z, h, Game.KART_R + 0.6):
			return d                            # a ramp from the side or the back is a wall
		d += 1.5
	return far


## The heading nearest `want` with room ahead.
func _clear_heading(k: Kart, want: float) -> float:
	var far := clampf(absf(k.speed) * 0.8, 8.0, 26.0)
	var best := want
	var best_s := -INF
	var last := float(k.ai.get("last_off", 0.0))
	for off in AHEAD:
		var h: float = want + off
		var c := clearance(k.x, k.z, h, far)
		var turn := absf(Game.wrap_angle(h - k.heading))
		var s := cos(off) * 1.0 + c / far * 1.6 - turn * 0.12
		if signf(off) == signf(last) and off != 0.0:
			s += 0.1                            # keep to the side chosen before
		if s > best_s:
			best_s = s
			best = h
			k.ai.last_off = off
	return best


func _ai_item(k: Kart, out: Dictionary, tg: Kart, dt: float, careful: bool) -> void:
	if k.item == 0 or k.roulette > 0.0:
		return
	var ai: Dictionary = k.ai
	ai.item_t = float(ai.item_t) - dt
	if float(ai.item_t) > 0.0:
		return
	var per: Dictionary = Game.PERSONA[k.driver]
	var aim := float(per.aim) * float(ai.skill)
	var d := INF
	var ang := PI
	if tg != null:
		d = Vector2(tg.x - k.x, tg.z - k.z).length()
		ang = absf(Game.wrap_angle(atan2(tg.x - k.x, tg.z - k.z) - k.heading))
	var use := false
	match k.item:
		Game.Item.MISSILE:
			var mt := missile_target(k)
			if mt != null:
				var md := Vector2(mt.x - k.x, mt.z - k.z).length()
				var ma := absf(Game.wrap_angle(atan2(mt.x - k.x, mt.z - k.z) - k.heading))
				use = md < 18.0 + 30.0 * aim and ma < 0.12 + 0.3 * aim and clearance(k.x, k.z, k.heading, md) >= md - 1.0 \
					and mt.invuln <= 0.0 and mt.star <= 0.0
		Game.Item.BLUE, Game.Item.LIGHTNING:
			use = true
		Game.Item.STAR:
			use = tg != null and d < 30.0
		Game.Item.TURBO:
			use = (tg != null and d > 25.0 and ang < 0.3 and clearance(k.x, k.z, k.heading, 26.0) >= 26.0) or \
				(careful and tg != null and d < 15.0)
		Game.Item.BANANA, Game.Item.OIL:
			use = _someone_behind(k, 18.0) or race._threatened(k) or (careful and randf() < 0.01)
		Game.Item.SHIELD:
			use = k.shield <= 0.0 and (race._threatened(k) or randf() < 0.004 or (careful and randf() < 0.02))
	if use:
		out.item = true
		ai.item_t = 0.4 + randf() * 0.6


func _someone_behind(k: Kart, within: float) -> bool:
	for o: Kart in alive():
		if o == k:
			continue
		var d := Vector2(o.x - k.x, o.z - k.z).length()
		if d < within and absf(Game.wrap_angle(atan2(o.x - k.x, o.z - k.z) - k.heading)) > 2.2:
			return true
	return false
