shader_type canvas_item;

uniform float focus = 0.0;

void fragment() {
	vec4 color = texture(TEXTURE,UV);

	float value = (sin(TIME*6.0)+1.0)/2.0;
	color.rgb *= mix(1.0,0.8+(0.5*value),focus);

	COLOR = color;
}