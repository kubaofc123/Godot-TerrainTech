@tool

extends Node

@export_category("TerrainTech")
@export var terrain_material : ShaderMaterial : get = _get_terrain_material, set = _set_terrain_material
@export var heightmap : Texture2D : get = _get_heightmap, set = _set_heightmap
@export var refresh_button : bool : get = _get_refresh_button, set = _set_refresh_button

@onready var node_3d = $Node3D

var normal_map : Image
var normal_map_tex : ImageTexture
#==========================================================================

#func _ready() -> void:
#	var rt_empty : bool = true
#	while rt_empty:
#		for a in RT.get_texture().get_image().get_data():
#			if a != 0:
#				rt_empty = false
#				break
#		if rt_empty:
#			await get_tree().process_frame
#
#	var normalmap_image : Image = convert_heightmap_to_normalmap(RT.get_texture().get_image(), 1.0)
#	for a in node_3d.get_children():
#		if a.get_child_count() > 0:
#			for b in a.get_children():
#				b.get_surface_override_material(0).set_shader_parameter("terrain_normalmap", normalmap_image)

func aaaa():
	if not node_3d:
		return

	#var normalmap_image : Image
	if heightmap:
		normal_map = convert_heightmap_to_normalmap(heightmap.get_image(), 1.0)
		normal_map_tex = ImageTexture.create_from_image(normal_map)
	else:
		normal_map = null
		normal_map_tex = null

	for a in node_3d.get_children():
		if a.get_child_count() > 0:
			for b in a.get_children():
				if b as MeshInstance3D:
					if heightmap:
						b.get_surface_override_material(0).set_shader_parameter("heightmap", heightmap)
						b.get_surface_override_material(0).set_shader_parameter("terrain_normalmap", normal_map_tex)
					else:
						b.get_surface_override_material(0).set_shader_parameter("heightmap", null)
						b.get_surface_override_material(0).set_shader_parameter("terrain_normalmap", null)

#region GETTERS / SETTERS
func _get_terrain_material():
	return terrain_material

func _set_terrain_material(new_value : ShaderMaterial):
	terrain_material = new_value
	if not node_3d:
		return
	for a in node_3d.get_children():
		if a.get_child_count() > 0:
			for b in a.get_children():
				if b as MeshInstance3D:
					b.set_surface_override_material(0, terrain_material)


func _get_heightmap():
	return heightmap

func _set_heightmap(new_value : Texture2D):
	heightmap = new_value
	aaaa()


func _get_refresh_button():
	return refresh_button

func _set_refresh_button(new_value : bool):
	refresh_button = false
	aaaa()
#endregion

#region CONVERTERS
## https://github.com/godotengine/godot-proposals/issues/659
func xy_to_index(x : int, y : int, width : int, height : int) -> int:
	x = clamp(x, 0, width - 1);
	y = clamp(y, 0, height - 1);
	return y * width + x;

func convert_heightmap_to_normalmap(in_heightmap : Image, scale : float) -> Image:
	var heightmap_data : PackedByteArray = in_heightmap.get_data()
	var normalmap_data : PackedByteArray
	var width : int = in_heightmap.get_width();
	var height : int = in_heightmap.get_height();
	normalmap_data.resize(width * height * 4)

	for full_y in height:
		for full_x in width:
			# Prevent the edges from having flat normals by using the closest valid normal
			var x : int = clamp(full_x, 1, width - 2)
			var y : int = clamp(full_y, 1, height - 2)

			# Sobel filter for getting the normal at this position
			var bottom_left : float = in_heightmap.get_pixel(x + 1, y + 1).r;
			var bottom_center : float = in_heightmap.get_pixel(x, y + 1).r;
			var bottom_right : float = in_heightmap.get_pixel(x - 1, y + 1).r;

			var center_left : float = in_heightmap.get_pixel(x + 1, y).r;
			var center_center : float = in_heightmap.get_pixel(x, y).r;
			var center_right : float = in_heightmap.get_pixel(x - 1, y).r;

			var top_left : float = in_heightmap.get_pixel(x + 1, y - 1).r;
			var top_center : float = in_heightmap.get_pixel(x, y - 1).r;
			var top_right : float = in_heightmap.get_pixel(x - 1, y - 1).r;

			var calculated_normal : Vector3;
			calculated_normal.x = (top_right + 2.0 * center_right + bottom_right) - (top_left + 2.0 * center_left + bottom_left);
			calculated_normal.y = (bottom_left + 2.0 * bottom_center + bottom_right) - (top_left + 2.0 * top_center + top_right);
			calculated_normal.z = 1.0 / scale;
			var normal = calculated_normal.normalized();

			normalmap_data.set(xy_to_index(full_x, full_y, width, height) * 4 + 0, 127.5 + normal.x * 127.5);
			normalmap_data.set(xy_to_index(full_x, full_y, width, height) * 4 + 1, 127.5 + normal.y * 127.5);
			normalmap_data.set(xy_to_index(full_x, full_y, width, height) * 4 + 2, 127.5 + normal.z * 127.5);
			normalmap_data.set(xy_to_index(full_x, full_y, width, height) * 4 + 3, 255);

	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, normalmap_data)
#endregion

########################## END OF FILE ##########################
