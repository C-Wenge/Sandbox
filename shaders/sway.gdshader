shader_type canvas_item;

uniform float range:hint_range(0.0, 4.0, 0.1) = 1.0;
uniform float speed:hint_range(0.0, 4.0, 0.1) = 1.0;

void vertex() {
	VERTEX.x += sin(TIME*speed)*range*(1.0-UV.y);
}
