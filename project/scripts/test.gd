extends SceneTree

func _initialize() -> void:
	var sim := SkaleSimulation.new()

	# Falling box — starts at y=5
	var box := SkaleBody.new()
	box.position = Vector3(0, 5, 0)
	box.initialize_box(sim, Vector3(0.5, 0.5, 0.5), 1000.0, false)

	# Static floor
	var floor_body := SkaleBody.new()
	floor_body.position = Vector3(0, 0, 0)
	floor_body.initialize_box(sim, Vector3(10.0, 0.2, 10.0), 1000.0, true)

	print("--- Skale Physics Test ---")
	print("  t(s)     box_y")
	for i in range(241):
		if i % 20 == 0:
			print("  %.3f    %.4f" % [i / 60.0, box.position.y])
		sim.step(1.0 / 60.0)

	print("--- Done ---")
	quit()
