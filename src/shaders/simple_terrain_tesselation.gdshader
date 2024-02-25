shader_type spatial;

// VARYING
varying vec2 texture_position;

// TERRAIN CONFIG
group_uniforms ShaderParameters.TerrainConfig;
uniform sampler2D heightmap : hint_default_black, repeat_disable;
uniform float amplitude;
uniform float uv_scale = 1;
uniform float normal_depth = 1;
uniform float displacement_amount = 0;

// BASE LAYER
group_uniforms ShaderParameters.BaseLayer;
uniform sampler2D base_layer_albedo : source_color, repeat_enable;
uniform sampler2D base_layer_normal : hint_normal, repeat_enable;
uniform sampler2D base_layer_mrao : hint_default_white, repeat_enable;
uniform sampler2D base_layer_displacement : hint_default_white, repeat_enable;
uniform float base_layer_metallic_multiplier = 0;
uniform float base_layer_roughness_multiplier = 1;
uniform float base_layer_specular = 0.5;


void vertex() {
	// World aligned vertices for heightmap
	vec3 world_vertex = VERTEX + MODEL_MATRIX[3].xyz;
	texture_position = world_vertex.xz/float(textureSize(heightmap,0).x);
	vec3 heightmap_vertex = VERTEX;
	heightmap_vertex.y = texture(heightmap, texture_position).r * amplitude;

	vec2 my_uv = UV * uv_scale;
	vec4 base_layer_displacement_read = texture(base_layer_displacement, my_uv);
	float calculated_displacement = (base_layer_displacement_read.g - 0.5) * (displacement_amount * uv_scale);

	// Output
	VERTEX = heightmap_vertex + (NORMAL * vec3(0.0, calculated_displacement, 0.0));
}


void fragment() {
	// UV's
	vec2 my_uv = UV * uv_scale;

	// Texture reads
	vec4 base_layer_albedo_read = texture(base_layer_albedo, my_uv);
	vec4 base_layer_normal_read = texture(base_layer_normal, my_uv);
	vec4 base_layer_mrao_read = texture(base_layer_mrao, my_uv);

	// Output
	ALBEDO = vec3(base_layer_albedo_read.xyz);
	SPECULAR = base_layer_mrao_read.b * base_layer_specular;
	NORMAL_MAP = vec3(base_layer_normal_read.xyz);
	NORMAL_MAP_DEPTH = normal_depth;
	METALLIC = base_layer_mrao_read.r * base_layer_metallic_multiplier;
	ROUGHNESS = base_layer_mrao_read.g * base_layer_roughness_multiplier;
	AO = base_layer_mrao_read.b;
}


//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
