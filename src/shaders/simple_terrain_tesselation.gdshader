shader_type spatial;

// VARYING
varying vec2 texture_position;
varying vec3 uv1_power_normal;
varying vec3 uv1_triplanar_pos;

// TERRAIN CONFIG
group_uniforms ShaderParameters.TerrainConfig;
uniform sampler2D heightmap : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float amplitude;
uniform float uv_scale = 1;
uniform float normal_strength = 1;
uniform float displacement_amount = 0;

// BASE LAYER
group_uniforms ShaderParameters.BaseLayer;
uniform sampler2D base_layer_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D base_layer_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D base_layer_orm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D base_layer_displacement : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float base_layer_metallic_multiplier = 0;
uniform float base_layer_roughness_multiplier = 1;
uniform float base_layer_specular = 0.5;

// CLEANUP
uniform vec2 terrain_dimensions;
uniform vec2 heightmap_dimensions;
uniform float heightmap_scale;
uniform float uv1_blend_sharpness = 4.0;
uniform vec3 uv1_scale = vec3(1.0, 1.0, 1.0);
uniform vec3 uv1_offset;
uniform vec4 albedo : source_color;
uniform sampler2D terrain_normalmap : hint_normal, filter_linear_mipmap, repeat_enable;

// heightmap_location = the XZ coordinates of the terrain, in meters.
// The terrain is texture modulated by `heightmap`
vec3 get_normal_from_heightmap_simple(vec2 heightmap_location) {
    // The width of the terrain, in meters
	float terrain_scale = terrain_dimensions.x;
	// The texelSize, referring to the resolution of the heightmap.
	float delta = 1.0 / heightmap_dimensions.x;
	float top = texture(heightmap, heightmap_location + vec2(0, -delta)).x;
	float bottom = texture(heightmap, heightmap_location + vec2(0, delta)).x;
	float left = texture(heightmap, heightmap_location + vec2(-delta, 0)).x;
	float right = texture(heightmap, heightmap_location + vec2(delta, 0)).x;
	// heightmap_scale = The number of meters difference in height between heightmap=0 and heightmap=1
	return normalize(vec3(-(right-left), 2.0*delta*terrain_scale/heightmap_scale, (top-bottom)));
}

vec3 get_normal_from_heightmap(vec2 heightmap_location) {
	float terrain_scale = terrain_dimensions.x;
	float delta = 1.0 / heightmap_dimensions.x;
	// 3x3 Edge-Detection Filter
	// [6][7][8]
	// [3][4][5]
	// [0][1][2]
	float s6 = texture(heightmap, heightmap_location + vec2(-delta, -delta)).x;
	float s7 = texture(heightmap, heightmap_location + vec2(0, -delta)).x;
	float s8 = texture(heightmap, heightmap_location + vec2(delta, -delta)).x;
	float s3 = texture(heightmap, heightmap_location + vec2(-delta, 0)).x;
	// float s4 = texture(heightmap, heightmap_location + vec2(0, 0)).x;
	float s5 = texture(heightmap, heightmap_location + vec2(delta, 0)).x;
	float s0 = texture(heightmap, heightmap_location + vec2(-delta, delta)).x;
	float s1 = texture(heightmap, heightmap_location + vec2(0, delta)).x;
	float s2 = texture(heightmap, heightmap_location + vec2(delta, delta)).x;
	// Scharr Filter
	vec3 n;
	n.x = -((s2-s0)+(10.0/3.0)*(s5-s3)+(s8-s6));
	n.y = delta*terrain_scale/heightmap_scale*(32.0/3.0);
	n.z = ((s6-s0)+(10.0/3.0)*(s7-s1)+(s8-s2));
	return normalize(n);
}

/// Source : https://github.com/boku-ilen/geodot-plugin/issues/14
//vec3 get_normal(vec2 normal_uv_pos) {
//	// To calculate the normal vector, height values on the left/right/top/bottom of the current pixel are compared.
//	// e is the offset factor.
//	float texture_size = float(textureSize(heightmap, 0).x);
//	float e = ((size / size_without_skirt) / texture_size);
//
//	// Sobel filter for getting the normal at this position
//	float bottom_left = get_height_no_falloff(normal_uv_pos + vec2(-e, -e));
//	float bottom_center = get_height_no_falloff(normal_uv_pos + vec2(0, -e));
//	float bottom_right = get_height_no_falloff(normal_uv_pos + vec2(e, -e));
//
//	float center_left = get_height_no_falloff(normal_uv_pos + vec2(-e, 0));
//	float center_center = get_height_no_falloff(normal_uv_pos + vec2(0, 0));
//	float center_right = get_height_no_falloff(normal_uv_pos + vec2(e, 0));
//
//	float top_left = get_height_no_falloff(normal_uv_pos + vec2(-e, e));
//	float top_center = get_height_no_falloff(normal_uv_pos + vec2(0, e));
//	float top_right = get_height_no_falloff(normal_uv_pos + vec2(e, e));
//
//	vec3 long_normal;
//
//	long_normal.x = -(bottom_right - bottom_left + 2.0 * (center_right - center_left) + top_right - top_left) / (size_without_skirt / texture_size);
//	long_normal.y = (top_left - bottom_left + 2.0 * (top_center - bottom_center) + top_right - bottom_right) / (size_without_skirt / texture_size);
//	long_normal.z = 1.0;
//
//	return normalize(long_normal);
//}


vec4 triplanar_texture(sampler2D p_sampler,vec3 p_weights,vec3 p_triplanar_pos) {
	vec4 samp=vec4(0.0);
	samp+= texture(p_sampler,p_triplanar_pos.xy) * p_weights.z;
	samp+= texture(p_sampler,p_triplanar_pos.xz) * p_weights.y;
	samp+= texture(p_sampler,p_triplanar_pos.zy * vec2(-1.0,1.0)) * p_weights.x;
	return samp;
}


void vertex() {
	vec3 normal = MODEL_NORMAL_MATRIX * NORMAL;
	TANGENT = vec3(0.0,0.0,-1.0) * abs(normal.x);
	TANGENT+= vec3(1.0,0.0,0.0) * abs(normal.y);
	TANGENT+= vec3(1.0,0.0,0.0) * abs(normal.z);
	TANGENT = inverse(MODEL_NORMAL_MATRIX) * normalize(TANGENT);
	BINORMAL = vec3(0.0,1.0,0.0) * abs(normal.x);
	BINORMAL+= vec3(0.0,0.0,-1.0) * abs(normal.y);
	BINORMAL+= vec3(0.0,1.0,0.0) * abs(normal.z);
	BINORMAL = inverse(MODEL_NORMAL_MATRIX) * normalize(BINORMAL);
	uv1_power_normal=pow(abs(normal),vec3(uv1_blend_sharpness));
	uv1_triplanar_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0f)).xyz * uv1_scale + uv1_offset;
	uv1_power_normal/=dot(uv1_power_normal,vec3(1.0));
	uv1_triplanar_pos *= vec3(1.0,-1.0, 1.0);

	// World aligned vertices for heightmap
	vec3 world_vertex = VERTEX + MODEL_MATRIX[3].xyz;
	texture_position = world_vertex.xz/float(textureSize(heightmap,0).x)*1.0;
	vec3 heightmap_vertex = VERTEX;
	heightmap_vertex.y = (texture(heightmap, texture_position*1.0).r - 0.5) * amplitude;

	vec2 my_uv = UV * uv_scale;
	vec4 base_layer_displacement_read = texture(base_layer_displacement, my_uv);
	float calculated_displacement = (base_layer_displacement_read.g - 0.5) * (displacement_amount * uv_scale);

	// TODO: Continue here
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 scaled_coords = world_pos.xz * (100.0/2048.0); // Modify this line
	float height = texture(heightmap, scaled_coords).r;
	VERTEX.y += height * amplitude;
	VERTEX.y += (NORMAL * vec3(0.0, calculated_displacement, 0.0)).g;
	//vec4 heightmap_tex = triplanar_texture(heightmap,uv1_power_normal,uv1_triplanar_pos);
	// Output
	//VERTEX = heightmap_vertex + (NORMAL * vec3(0.0, calculated_displacement, 0.0));
}


void fragment() {
	// UV's
	//vec2 my_uv = UV * uv_scale;

	// Texture reads
	//vec4 base_layer_albedo_read = texture(base_layer_albedo, my_uv);
	//vec4 base_layer_normal_read = texture(base_layer_normal, my_uv);
	//vec4 base_layer_orm_read = texture(base_layer_orm, my_uv);

	// ALBEDO
	vec4 albedo_tex = triplanar_texture(base_layer_albedo,uv1_power_normal,uv1_triplanar_pos);
	ALBEDO = albedo_tex.rgb;

	// NORMAL
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 normal = texture(terrain_normalmap, world_pos.xz * (100.0/2048.0)).rgb;
	// Convert the normal from [0, 1] to [-1, 1]
	//normal = normal * 2.0 - 1.0;
	NORMAL_MAP = normal;
	//NORMAL = (VIEW_MATRIX * vec4(get_normal_from_heightmap(UV), 0.0)).xyz; // 1.87ms
	//NORMAL_MAP = texture(terrain_normalmap, UV).rgb;
	//NORMAL_MAP = triplanar_texture(base_layer_normal,uv1_power_normal,uv1_triplanar_pos).rgb;
	NORMAL_MAP_DEPTH = normal_strength;

	//ALBEDO = vec3(base_layer_albedo_read.xyz);
	//SPECULAR = base_layer_orm_read.b * base_layer_specular;
	SPECULAR = 0.1;
	//NORMAL = (VIEW_MATRIX * vec4(get_normal_from_heightmap_simple(UV), 0.0)).xyz;
	//NORMAL_MAP = vec3(base_layer_normal_read.xyz);
	//NORMAL_MAP_DEPTH = normal_depth;
	//AO = base_layer_orm_read.r;
	//ROUGHNESS = base_layer_orm_read.g * base_layer_roughness_multiplier;
	//METALLIC = base_layer_orm_read.b * base_layer_metallic_multiplier;
}


//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
