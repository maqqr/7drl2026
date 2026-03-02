extends Node3D
class_name TileMapRenderer

class MultiMeshHelper:
	var transforms: Array[Transform3D]
	var multimesh_instance: MultiMeshInstance3D

	func _init(parent: Node3D, mesh: Mesh):
		multimesh_instance = MultiMeshInstance3D.new()
		multimesh_instance.multimesh = MultiMesh.new()
		multimesh_instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh_instance.multimesh.mesh = mesh
		parent.add_child(multimesh_instance)

	func update_multimesh():
		multimesh_instance.multimesh.instance_count = transforms.size()
		multimesh_instance.multimesh.visible_instance_count = transforms.size()
		for i in range(transforms.size()):
			multimesh_instance.multimesh.set_instance_transform(i, transforms[i])

var floor_mesh: Mesh = preload("res://models/hull/floor_mesh.res")
var corner_matches: Array[CornerMatch]
var tile_map: TileMap2D
var update_queued = false

class Chunk:
	const SIZE = 8
	var multimeshes: Dictionary[Mesh, MultiMeshHelper]

var chunks: Dictionary[Vector2i, Chunk]

func _get_chunk(subgrid_pos: Vector2i) -> Chunk:
	var chunk_pos = Vector2i(floor(subgrid_pos.x / float(Chunk.SIZE)), floor(subgrid_pos.y / float(Chunk.SIZE)))
	if not chunks.has(chunk_pos):
		chunks[chunk_pos] = Chunk.new()
	return chunks[chunk_pos]

func _ready() -> void:
	for corner_match in CornerMatch.load_all():
		corner_matches.push_back(corner_match)
		match corner_match.allowed_rotations:
			CornerMatch.AllowedRotations.ROTATE180:
				corner_matches.push_back(corner_match.get_rotated_90().get_rotated_90())
			CornerMatch.AllowedRotations.ROTATE90:
				corner_matches.push_back(corner_match.get_rotated_90())
				corner_matches.push_back(corner_match.get_rotated_90().get_rotated_90())
				corner_matches.push_back(corner_match.get_rotated_90().get_rotated_90().get_rotated_90())

func _process(_delta: float) -> void:
	if update_queued:
		update_queued = false
		make_meshes()

func set_tile_map(new_tile_map: TileMap2D):
	tile_map = new_tile_map
	tile_map.tile_changed.connect(_on_tile_map_change)
	make_meshes()

func _on_tile_map_change(_pos: Vector2i, _old_tile: Enum.TileType, _new_tile: Enum.TileType):
	#make_meshes()
	update_queued = true

func make_meshes() -> void:
	for chunk_pos in chunks:
		for mesh in chunks[chunk_pos].multimeshes:
			chunks[chunk_pos].multimeshes[mesh].transforms.clear()

	var wall_subgrid = Array2D.new(tile_map.width * 2, tile_map.height * 2, 0)
	for y in range(tile_map.height):
		for x in range(tile_map.width):
			var tile = tile_map.get_tile(Vector2i(x, y))
			if tile == Enum.TileType.WALL:
				wall_subgrid.set_value(Vector2i(x * 2, y * 2), 1)
				wall_subgrid.set_value(Vector2i(x * 2 + 1, y * 2), 1)
				wall_subgrid.set_value(Vector2i(x * 2, y * 2 + 1), 1)
				wall_subgrid.set_value(Vector2i(x * 2 + 1, y * 2 + 1), 1)
			if tile != Enum.TileType.EMPTY:
				var chunk = _get_chunk(Vector2i(x * 2, y * 2))
				if not chunk.multimeshes.has(floor_mesh):
					chunk.multimeshes[floor_mesh] = MultiMeshHelper.new(self, floor_mesh)

				var scene_position = Vector3(x, 0, y)
				var multimesh_helper = chunk.multimeshes[floor_mesh]
				var mm_basis = Basis.from_scale(Vector3(0.5, 0.5, 0.5))
				multimesh_helper.transforms.push_back(Transform3D(mm_basis, scene_position))

	for y in range(wall_subgrid.height):
		for x in range(wall_subgrid.width):
			for corner_match in corner_matches:
				var subgrid_pos = Vector2i(x, y)
				if corner_match.matches(wall_subgrid, subgrid_pos):
					var chunk = _get_chunk(subgrid_pos)
					if not chunk.multimeshes.has(corner_match.mesh):
						chunk.multimeshes[corner_match.mesh] = MultiMeshHelper.new(self, corner_match.mesh)

					var scene_position = Vector3(x, 0, y) * 0.5 + Vector3(-0.25, 0.0, -0.25)
					var multimesh_helper = chunk.multimeshes[corner_match.mesh]
					var mm_basis = Basis.from_scale(Vector3(0.5, 0.5, 0.5)).rotated(Vector3(0, 1, 0), -corner_match.rotation_90_count * PI * 0.5)
					multimesh_helper.transforms.push_back(Transform3D(mm_basis, scene_position))

	for chunk_pos in chunks:
		for mesh in chunks[chunk_pos].multimeshes:
			chunks[chunk_pos].multimeshes[mesh].update_multimesh()
