class_name Effects
extends RefCounted
## Little visual effects anyone can use, like Effects.poof(...).


## A puff of colorful smoke balls that burst out and fade away.
static func poof(parent: Node, where: Vector3, color: Color, size := 1.0, count := 10) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mesh := SphereMesh.new()
	mesh.radius = 0.25 * size
	mesh.height = 0.5 * size
	mesh.radial_segments = 12
	mesh.rings = 6
	for i in count:
		var ball := MeshInstance3D.new()
		ball.mesh = mesh
		ball.material_override = mat
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(ball)
		ball.global_position = where
		var direction := Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1)).normalized()
		var tween := ball.create_tween()
		tween.set_parallel(true)
		tween.tween_property(ball, "global_position", where + direction * size * randf_range(0.8, 1.6), 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(ball, "scale", Vector3.ONE * 0.1, 0.6)
		tween.chain().tween_callback(ball.queue_free)
	var fade := mat.albedo_color
	fade.a = 0.0
	parent.create_tween().tween_property(mat, "albedo_color", fade, 0.6)


## A flat ring that spreads out along the ground (like a shockwave).
static func shockwave(parent: Node, where: Vector3, color: Color, radius := 4.0) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.85
	mesh.outer_radius = 1.0
	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	ring.global_position = where + Vector3.UP * 0.1
	ring.scale = Vector3(0.3, 0.3, 0.3)
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(radius, 0.4, radius), 0.45).set_ease(Tween.EASE_OUT)
	var fade := color
	fade.a = 0.0
	tween.tween_property(mat, "albedo_color", fade, 0.45)
	tween.chain().tween_callback(ring.queue_free)
