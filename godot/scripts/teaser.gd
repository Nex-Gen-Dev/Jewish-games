extends Control
## Looping gameplay preview. A still frame shows first, the real recorded
## gameplay video plays over it. Fills its box like a photo ("cover").
## Files by convention: res://assets/teasers/<game_id>.ogv and
## res://assets/levels/<level_id>.jpg (a missing video just keeps the still).

const VW := 448.0
const VH := 252.0

var player: VideoStreamPlayer
var poster: TextureRect


func setup(game_id: String, poster_level := "") -> Control:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pp := "res://assets/levels/%s.jpg" % poster_level
	if poster_level != "" and ResourceLoader.exists(pp):
		poster = TextureRect.new()
		poster.texture = load(pp)
		poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		poster.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(poster)
	var vp := "res://assets/teasers/%s.ogv" % game_id
	if ResourceLoader.exists(vp):
		var st: Variant = load(vp)
		if st is VideoStream:
			player = VideoStreamPlayer.new()
			player.stream = st
			player.expand = true
			player.volume_db = -80.0
			player.loop = true
			player.autoplay = true
			player.mouse_filter = Control.MOUSE_FILTER_IGNORE
			player.add_to_group("teaser_video")
			add_child(player)
	resized.connect(_fit)
	visibility_changed.connect(func():
		if player and is_instance_valid(player):
			player.paused = not is_visible_in_tree())
	_fit.call_deferred()
	return self


func _fit() -> void:
	if player == null or size.x < 2.0:
		return
	var s := maxf(size.x / VW, size.y / VH)
	player.size = Vector2(VW, VH) * s
	player.position = (size - player.size) / 2.0
