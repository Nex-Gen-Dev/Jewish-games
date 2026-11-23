extends RefCounted
## Medals: data-driven achievements (data/medals.json). Each medal watches one stat
## and has up to 3 tiers (bronze, silver, gold) that give a reward when claimed.
## To add a medal for a game: have the game call Profile.stat_add("key") / stat_max("key", v)
## and add an entry to medals.json using that key. No launcher code needed.

const TIER_NAMES := ["Bronze", "Silver", "Gold"]
const TIER_COLORS := [Color("#cd7f32"), Color("#c4cbd3"), Color("#ffc83d")]


static func all(game_id := "") -> Array:
	var f := FileAccess.open("res://data/medals.json", FileAccess.READ)
	if f == null:
		return []
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return []
	var out := []
	for m in d.get("medals", []):
		if game_id == "" or m.get("game", "") == game_id:
			out.append(m)
	return out


static func _levels_done(game_id: String) -> int:
	var n := 0
	for g in Profile.manifest.get("games", []):
		if game_id != "" and g["id"] != game_id:
			continue
		for lv in g.get("levels", []):
			if Profile.is_completed(str(lv["id"])):
				n += 1
	return n


static func value(stat: String) -> int:
	match stat:
		"levels_done":
			return _levels_done("")
		"fighter_levels":
			return _levels_done("fighter")
		"runner_levels":
			return _levels_done("runner")
		"city_levels":
			return _levels_done("city")
		"race_levels":
			return _levels_done("race")
	return Profile.stat(stat)


## Number of tiers whose goal has been reached.
static func reached(m: Dictionary) -> int:
	var v := value(str(m["stat"]))
	var n := 0
	for t in m["tiers"]:
		if v >= int(t["goal"]):
			n += 1
	return n


static func claimable(m: Dictionary) -> int:
	return maxi(reached(m) - Profile.medal_tiers_claimed(str(m["id"])), 0)


static func total_claimable() -> int:
	var n := 0
	for m in all():
		n += claimable(m)
	return n


static func claim(m: Dictionary) -> Dictionary:
	var got := Profile.medal_tiers_claimed(str(m["id"]))
	if claimable(m) <= 0:
		return {}
	var reward: Dictionary = m["tiers"][got]["reward"]
	Profile.set_medal_claimed(str(m["id"]), got + 1)
	Profile.grant(reward)
	return reward


static func reward_text(reward: Dictionary) -> String:
	var parts := []
	if reward.has("coins"):
		parts.append("+%d coins" % int(reward["coins"]))
	if reward.has("item"):
		var nm := str(reward["item"])
		for it in Profile.manifest.get("shop", []):
			if it["id"] == nm:
				nm = str(it["name"])
		parts.append(nm)
	if reward.has("title"):
		parts.append("Title: " + str(reward["title"]))
	return " + ".join(parts)
