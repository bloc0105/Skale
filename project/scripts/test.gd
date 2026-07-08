extends SceneTree

func _initialize() -> void:
	var hello := SkaleHello.new()
	print(hello.greet("World"))
	quit()
