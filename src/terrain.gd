@tool

extends Node

@export_category("TerrainTech")
@export var terrain_material : ShaderMaterial: get = _get_terrain_material, set = _set_terrain_material

#==========================================================================


#region GETTERS / SETTERS
func _get_terrain_material():
	return terrain_material


func _set_terrain_material(new_value : ShaderMaterial):
	terrain_material = new_value
	for a in get_children():
		if a.get_child_count() > 0:
			for b in a.get_children():
				if b as MeshInstance3D:
					b.set_surface_override_material(0, terrain_material)
#endregion

########################## END OF FILE ##########################

