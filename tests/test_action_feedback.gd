extends TestCase

const Feedback = preload("res://view/action_feedback.gd")


func test_marker_cap_removes_oldest_and_retains_newest_positions() -> void:
	var feedback: Node3D = Feedback.new()
	feedback.show_marker(Vector3.ZERO, "+ไม้", Color.WHITE)
	var first: WeakRef = weakref(feedback.get_child(0))
	for index: int in range(1, 17):
		feedback.show_marker(Vector3(float(index), 2.0, 3.0), "+1", Color.WHITE)
	assert_eq(feedback.get_child_count(), 12)
	assert_eq(first.get_ref(), null, "the oldest marker is freed when the cap is reached")
	for index: int in range(feedback.get_child_count()):
		assert_eq((feedback.get_child(index) as Node3D).position, Vector3(float(index + 5), 2.0, 3.0))
	feedback.free()


func test_clear_frees_owned_effects_and_stops_processing() -> void:
	var feedback: Node3D = Feedback.new()
	feedback.show_marker(Vector3.ONE, "+อาหาร", Color.WHITE)
	feedback.show_marker(Vector3.UP, "สร้างแล้ว", Color.WHITE)
	var references: Array[WeakRef] = []
	for marker: Node in feedback.get_children():
		assert_eq(marker.owner, feedback)
		references.append(weakref(marker))
		for visual: Node in marker.get_children():
			assert_eq(visual.owner, marker)
			references.append(weakref(visual))
	feedback.clear()
	assert_eq(feedback.get_child_count(), 0)
	assert_true(not feedback.is_processing())
	for reference: WeakRef in references:
		assert_eq(reference.get_ref(), null, "clear frees every marker and its visuals immediately")
	feedback.clear()
	feedback.free()


func test_reduced_motion_keeps_static_label_ring_and_expires_normally() -> void:
	var feedback: Node3D = Feedback.new()
	feedback.set_reduced_motion(true)
	var at: Vector3 = Vector3(2.0, 1.4, -3.0)
	feedback.show_marker(at, "+2 ไม้", Color("#a2c8aa"))
	var marker: Node3D = feedback.get_child(0) as Node3D
	var label: Label3D = marker.get_node("Label") as Label3D
	var ring: Node3D = marker.get_node("Ring") as Node3D
	var label_at: Vector3 = label.position
	var ring_scale: Vector3 = ring.scale
	assert_true(not marker.has_node("Burst"), "reduced motion creates no particles")
	feedback._process(0.4)
	assert_eq(marker.position, at, "the caller's tile position is unchanged")
	assert_eq(label.position, label_at)
	assert_eq(ring.scale, ring_scale)
	feedback._process(2.0)
	assert_eq(feedback.get_child_count(), 0)
	assert_true(not feedback.is_processing())
	feedback.free()


func test_enabling_reduced_motion_stops_existing_movement_and_particles() -> void:
	var feedback: Node3D = Feedback.new()
	feedback.show_marker(Vector3.ZERO, "สำเร็จ", Color.WHITE)
	var marker: Node3D = feedback.get_child(0) as Node3D
	var label: Label3D = marker.get_node("Label") as Label3D
	var ring: Node3D = marker.get_node("Ring") as Node3D
	var initial_label_at: Vector3 = label.position
	feedback._process(0.12)
	assert_true(label.position.y > initial_label_at.y)
	var burst: WeakRef = weakref(marker.get_node("Burst"))
	feedback.set_reduced_motion(true)
	assert_eq(burst.get_ref(), null, "changing the preference removes active particles")
	var static_label_at: Vector3 = label.position
	var static_ring_scale: Vector3 = ring.scale
	feedback._process(0.3)
	assert_eq(label.position, static_label_at)
	assert_eq(ring.scale, static_ring_scale)
	feedback.show_marker(Vector3.ONE, "คงที่", Color.WHITE)
	assert_true(not feedback.get_child(1).has_node("Burst"))
	feedback.set_reduced_motion(false)
	feedback.show_marker(Vector3.RIGHT, "เคลื่อนไหว", Color.WHITE)
	assert_true(feedback.get_child(2).has_node("Burst"), "later effects follow the updated preference")
	feedback.free()


func test_normal_effect_has_bounded_burst_and_freeing_parent_removes_all_nodes() -> void:
	var feedback: Node3D = Feedback.new()
	feedback.show_marker(Vector3(4.0, 0.5, 2.0), "แรงงานไม่พอ", Color.WHITE, "error")
	var marker: Node3D = feedback.get_child(0) as Node3D
	var marker_reference: WeakRef = weakref(marker)
	var burst: MultiMeshInstance3D = marker.get_node("Burst") as MultiMeshInstance3D
	assert_true(burst.multimesh.instance_count <= 4, "one small burst cannot grow with elapsed frames")
	var burst_reference: WeakRef = weakref(burst)
	feedback._process(0.6)
	assert_eq(burst_reference.get_ref(), null, "the burst is released before the label expires")
	assert_eq(marker.position, Vector3(4.0, 0.5, 2.0))
	var label_reference: WeakRef = weakref(marker.get_node("Label"))
	feedback.free()
	assert_eq(marker_reference.get_ref(), null)
	assert_eq(label_reference.get_ref(), null, "parent ownership removes the running effect without callbacks")


func test_emptied_emits_once_after_last_expiry_or_nonempty_clear_and_never_on_cap() -> void:
	var feedback: Node3D = Feedback.new()
	var notifications: Array[int] = []
	feedback.connect("emptied", func(): notifications.append(feedback.get_child_count()))
	feedback.show_marker(Vector3.ZERO, "first", Color.WHITE)
	feedback._process(0.8)
	feedback.show_marker(Vector3.ONE, "later", Color.WHITE)
	feedback._process(0.5)
	assert_eq(notifications.size(), 0, "expiry of an older marker cannot announce an empty view")
	feedback._process(0.8)
	assert_eq(notifications, [0], "the last expiry emits after removing all visuals")
	feedback._process(2.0)
	feedback.clear()
	assert_eq(notifications, [0], "an already empty view stays silent")
	for index: int in range(17):
		feedback.show_marker(Vector3(float(index), 0.0, 0.0), "+1", Color.WHITE)
	assert_eq(notifications, [0], "evicting old markers at the cap is not an empty transition")
	feedback.clear()
	assert_eq(notifications, [0, 0], "clearing an active view emits exactly once after cleanup")
	feedback.clear()
	assert_eq(notifications, [0, 0])
	feedback.free()
