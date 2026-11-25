
extends Control

# ==========================================
# PROCEDURAL ROCK GENERATOR
# Godot 4.x
# ==========================================

# Your exact rock palette
const OUTLINE := Color("#2E222F")
const SHADOW := Color("#3E3546")
const BASE := Color("#625565")
const HIGHLIGHT := Color("#7F708A")

const MIN_SIZE := 16
const MAX_SIZE := 64

var rng := RandomNumberGenerator.new()

var preview: TextureRect
var size_label: Label
var create_button: Button


func _ready() -> void:
	rng.randomize()
	_build_interface()
	generate_rock()


# ==========================================
# USER INTERFACE
# ==========================================

func _build_interface() -> void:
	var main := VBoxContainer.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.add_theme_constant_override("separation", 12)
	main.add_theme_constant_override("margin_left", 16)
	main.add_theme_constant_override("margin_right", 16)
	main.add_theme_constant_override("margin_top", 16)
	main.add_theme_constant_override("margin_bottom", 16)
	add_child(main)

	var title := Label.new()
	title.text = "PROCEDURAL ROCK GENERATOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_child(title)

	size_label = Label.new()
	size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_child(size_label)

	preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(512, 512)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	main.add_child(preview)

	create_button = Button.new()
	create_button.text = "CREATE ROCK"
	create_button.custom_minimum_size = Vector2(0, 48)
	create_button.pressed.connect(generate_rock)
	main.add_child(create_button)


# ==========================================
# ROCK GENERATION
# ==========================================

func generate_rock() -> void:
	var width := rng.randi_range(MIN_SIZE, MAX_SIZE)
	var height := rng.randi_range(MIN_SIZE, MAX_SIZE)

	var img := Image.create(
		width,
		height,
		false,
		Image.FORMAT_RGBA8
	)

	img.fill(Color(0, 0, 0, 0))

	# Generate random rock proportions
	var margin_x := maxi(1, int(width * 0.07))
	var center_x := width / 2.0

	var half_width := rng.randf_range(
		width * 0.34,
		width * 0.46
	)

	var baseline := rng.randi_range(
		int(height * 0.76),
		height - 2
	)

	var rock_height := rng.randf_range(
		height * 0.48,
		height * 0.70
	)

	var curve_power := rng.randf_range(0.45, 0.85)
	var roughness := rng.randf_range(0.5, 2.0)

	var mask := PackedByteArray()
	mask.resize(width * height)

	var top_edges := PackedInt32Array()
	var bottom_edges := PackedInt32Array()

	top_edges.resize(width)
	bottom_edges.resize(width)

	for x in range(width):
		top_edges[x] = height
		bottom_edges[x] = -1

	# --------------------------------------
	# CREATE IRREGULAR ROCK SILHOUETTE
	# --------------------------------------

	for x in range(margin_x, width - margin_x):
		var nx := (float(x) - center_x) / half_width

		if absf(nx) > 1.0:
			continue

		var profile := pow(
			maxf(0.0, 1.0 - nx * nx),
			curve_power
		)

		var ripple := (
			sin(nx * rng.randf_range(5.0, 9.0))
			* roughness
		)

		var jagged := rng.randf_range(-1.0, 1.0)

		var top := int(
			baseline
			- profile * rock_height
			+ ripple
			+ jagged
		)

		var bottom := baseline + int(
			(1.0 - absf(nx))
			* rng.randf_range(0.0, height * 0.04)
		)

		top = clampi(top, 1, height - 2)
		bottom = clampi(bottom, top, height - 1)

		top_edges[x] = top
		bottom_edges[x] = bottom

		for y in range(top, bottom + 1):
			mask[y * width + x] = 1

	# --------------------------------------
	# DRAW ROCK PIXELS
	# --------------------------------------

	var shadow_start := baseline - int(height * 0.20)

	for y in range(height):
		for x in range(width):
			var index := y * width + x

			if mask[index] == 0:
				continue

			var is_outline := false

			# Check surrounding pixels
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					if ox == 0 and oy == 0:
						continue

					var nx := x + ox
					var ny := y + oy

					if (
						nx < 0 or nx >= width
						or ny < 0 or ny >= height
					):
						is_outline = true
						break

					if mask[ny * width + nx] == 0:
						is_outline = true
						break

				if is_outline:
					break

			if is_outline:
				img.set_pixel(x, y, OUTLINE)
			else:
				var pixel_color := BASE

				# Bottom shadow
				if y >= shadow_start:
					pixel_color = SHADOW

				# Additional darker lower-side areas
				elif (
					y > baseline - int(height * 0.32)
					and (
						x < center_x - half_width * 0.48
						or x > center_x + half_width * 0.48
					)
				):
					pixel_color = SHADOW

				img.set_pixel(x, y, pixel_color)

	# --------------------------------------
	# ADD HIGHLIGHT CLUSTERS
	# --------------------------------------

	var highlight_count := rng.randi_range(1, 3)

	for i in range(highlight_count):
		var hx := center_x + rng.randf_range(
			-half_width * 0.60,
			half_width * 0.35
		)

		var hy := baseline - rock_height * rng.randf_range(
			0.35,
			0.78
		)

		var rx := rng.randf_range(
			maxf(1.0, width * 0.07),
			maxf(1.5, width * 0.17)
		)

		var ry := rng.randf_range(
			maxf(1.0, height * 0.035),
			maxf(1.5, height * 0.09)
		)

		_draw_highlight(
			img,
			mask,
			width,
			height,
			hx,
			hy,
			rx,
			ry
		)

	# --------------------------------------
	# DISPLAY GENERATED ROCK
	# --------------------------------------

	var texture := ImageTexture.create_from_image(img)

	preview.texture = texture

	size_label.text = (
		"Generated Rock: %d × %d pixels"
		% [width, height]
	)


# ==========================================
# HIGHLIGHT DRAWING
# ==========================================

func _draw_highlight(
	img: Image,
	mask: PackedByteArray,
	width: int,
	height: int,
	cx: float,
	cy: float,
	rx: float,
	ry: float
) -> void:

	var start_x := maxi(0, int(cx - rx - 1))
	var end_x := mini(width - 1, int(cx + rx + 1))

	var start_y := maxi(0, int(cy - ry - 1))
	var end_y := mini(height - 1, int(cy + ry + 1))

	for y in range(start_y, end_y + 1):
		for x in range(start_x, end_x + 1):

			if mask[y * width + x] == 0:
				continue

			var dx := (float(x) - cx) / rx
			var dy := (float(y) - cy) / ry

			var distance := dx * dx + dy * dy

			if distance <= 0.72:
				# Preserve the dark outline
				var current := img.get_pixel(x, y)

				if current == BASE:
					img.set_pixel(x, y, HIGHLIGHT)


# ==========================================
# OPTIONAL: GENERATE ROCK FROM A SEED
# ==========================================

func generate_from_seed(seed_value: int) -> void:
	rng.seed = seed_value
	generate_rock()
