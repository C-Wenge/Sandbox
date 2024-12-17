
# ================================================
# -
# -                MAIN CAMERA
# -
# -        主相机，可以使用鼠标滚轮控制缩放
# -
# ================================================

class_name MainCamera
extends Camera2D

func _input(event: InputEvent) -> void:

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom.x = clampf(zoom.x - 0.01,0.1,10.0)
			zoom.y = zoom.x
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom.x = clampf(zoom.x + 0.01,0.1,10.0)
			zoom.y = zoom.x
