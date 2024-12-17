shader_type canvas_item;

uniform vec4 water_color :source_color;
uniform vec4 water_edge_color :source_color;
uniform float water_edge_width = 1.0;
uniform float water_depth = 0.0;

void fragment() {

	vec4 color1 = texture(TEXTURE,UV);
	vec4 color2 = vec4(mix(color1.rgb,water_color.rgb,0.5),color1.a);
	float water_edge_value = step(1.0-UV.y,water_depth*TEXTURE_PIXEL_SIZE.y);
	float water_value = step(1.0-UV.y,water_depth*TEXTURE_PIXEL_SIZE.y-(water_edge_width*TEXTURE_PIXEL_SIZE.y));

	color1 = vec4(mix(color1.rgb,water_edge_color.rgb,water_edge_value),color1.a);
	color1 = mix(color1,color2,water_value);

	COLOR = color1;
}
