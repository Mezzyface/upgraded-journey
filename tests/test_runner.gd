extends TestSuite


func test_scene_tests_can_await_frames() -> void:
	var n := Control.new()
	tree.root.add_child(n)
	await tree.process_frame
	check(n.is_node_ready(), "a node added to the root is ready after one frame")
	n.queue_free()
