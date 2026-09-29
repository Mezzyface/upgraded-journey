extends PanelContainer
## A popup whose %Close button closes it in its PanelHost (market_panel.tscn, expedition_panel.tscn). Everything
## else in those windows is laid out in their scenes.


func _ready() -> void:
	%Close.pressed.connect(func() -> void:
		var host := get_parent() as PanelHost
		if host:
			host.close())
