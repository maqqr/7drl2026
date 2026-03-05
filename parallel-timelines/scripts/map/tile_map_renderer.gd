extends Node3D
class_name TileMapRenderer

class MultiMeshHelper:
	var transforms: Array[Transform3D]
	var tile_positions: Array[Vector2i]
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
var queued_removes: Dictionary[Vector2i, bool] = {}

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
	#if update_queued:
	#	update_queued = false
	#	make_meshes()
	if not queued_removes.is_empty():
		var affected_chunks: Array[Chunk] = []
		for pos in queued_removes:
			var subgrid_pos = pos * 2
			var chunk = _get_chunk(subgrid_pos)
			if not affected_chunks.has(chunk):
				affected_chunks.push_back(chunk)

		for chunk in affected_chunks:
			for mesh in chunk.multimeshes:
				if mesh == floor_mesh:
					continue

				var new_transforms: Array[Transform3D] = []
				var new_tile_positions: Array[Vector2i] = []
				var multimesh_helper = chunk.multimeshes[mesh]
				assert(multimesh_helper.tile_positions.size() == multimesh_helper.transforms.size())
				for i in range(multimesh_helper.tile_positions.size()):
					if not queued_removes.has(multimesh_helper.tile_positions[i]):
						new_transforms.push_back(multimesh_helper.transforms[i])
						new_tile_positions.push_back(multimesh_helper.tile_positions[i])

				multimesh_helper.transforms = new_transforms
				multimesh_helper.tile_positions = new_tile_positions
				multimesh_helper.update_multimesh()

		queued_removes.clear()

func set_tile_map(new_tile_map: TileMap2D):
	tile_map = new_tile_map
	tile_map.tile_changed.connect(_on_tile_map_change)
	make_meshes()

func _on_tile_map_change(pos: Vector2i, _old_tile: Enum.TileType, new_tile: Enum.TileType):
	if new_tile == Enum.TileType.FLOOR:
		queued_removes[pos] = true
	else:
		make_meshes()

func make_meshes() -> void:
	for chunk_pos in chunks:
		for mesh in chunks[chunk_pos].multimeshes:
			chunks[chunk_pos].multimeshes[mesh].transforms.clear()
			chunks[chunk_pos].multimeshes[mesh].tile_positions.clear()

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
				# Create floor models
				var chunk = _get_chunk(Vector2i(x * 2, y * 2))
				if not chunk.multimeshes.has(floor_mesh):
					chunk.multimeshes[floor_mesh] = MultiMeshHelper.new(self, floor_mesh)

				var scene_position = Vector3(x, 0, y)
				var multimesh_helper = chunk.multimeshes[floor_mesh]
				var mm_basis = Basis.from_scale(Vector3(0.5, 0.5, 0.5))
				multimesh_helper.transforms.push_back(Transform3D(mm_basis, scene_position))
				multimesh_helper.tile_positions.push_back(Vector2i(x, y))

	# Create wall models
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
					@warning_ignore("integer_division")
					multimesh_helper.tile_positions.push_back(Vector2i(x / 2, y / 2))

	for chunk_pos in chunks:
		for mesh in chunks[chunk_pos].multimeshes:
			chunks[chunk_pos].multimeshes[mesh].update_multimesh()
