extends CanvasLayer
## The on-screen display: hearts, the slime counter, and the victory banner.

@onready var hearts: Control = $Hearts
@onready var slime_label: Label = $SlimeCounter
@onready var banner: Label = $Banner

var _health := 5
var _max_health := 5


func _ready() -> void:
	hearts.draw.connect(_draw_hearts)
	banner.visible = false


func set_health(current: int, maximum: int) -> void:
	_health = current
	_max_health = maximum
	hearts.queue_redraw()


func set_slimes(defeated: int, total: int) -> void:
	slime_label.text = "Slimes bonked: %d / %d" % [defeated, total]


func show_banner(text: String) -> void:
	banner.text = text
	banner.visible = true
	banner.modulate.a = 0.0
	create_tween().tween_property(banner, "modulate:a", 1.0, 0.5)


func _draw_hearts() -> void:
	for i in _max_health:
		var center := Vector2(24 + i * 42, 24)
		var full := i < _health
		_draw_heart(center, 1.15, Color(0.15, 0.08, 0.08))  # dark outline
		_draw_heart(center, 1.0, Color(0.95, 0.25, 0.35) if full else Color(0.35, 0.3, 0.32))


func _draw_heart(center: Vector2, size: float, color: Color) -> void:
	var r := 8.0 * size
	hearts.draw_circle(center + Vector2(-7, -2) * size, r, color)
	hearts.draw_circle(center + Vector2(7, -2) * size, r, color)
	hearts.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-14.5, 1) * size,
		center + Vector2(14.5, 1) * size,
		center + Vector2(0, 17) * size,
	]), color)
