extends Control
## Theme gallery. After `--`, `--screenshot=<path>` saves a capture and quits, `--scroll=<px>` scrolls first.
## Used to verify the theme from the command line:
##   godot --path . -- --screenshot=out.png --scroll=600

func _ready() -> void:
	var shot := ""
	var scroll_to := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scroll="):
			scroll_to = int(arg.trim_prefix("--scroll="))
		elif arg.begins_with("--screenshot="):
			shot = arg.trim_prefix("--screenshot=")
	if scroll_to >= 0:
		await get_tree().process_frame
		$Scroll.scroll_vertical = scroll_to
	if shot != "":
		await RenderingServer.frame_post_draw
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()
