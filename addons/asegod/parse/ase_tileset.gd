extends AseChunk
class_name AseTileset

enum TileFlip {
	NONE = 0,
	FLIP_X = 1,
	FLIP_Y = 2,
	FLIP_DIAG = 4
}

#TODO: Figure out which of these actually need storing
@export var tileset_id: int
@export var flags: int
@export var num_tiles: int
@export var tile_width: int
@export var tile_height: int
@export var base_index: int
@export var name: String
@export var tiles_image: PackedByteArray = []
@export var external_file_id: int = -1
@export var external_tileset_id: int = -1
@export var empty_tile_value: int = 0
@export var is_external: bool = false
@export var external_file_path: String = ""
@export var external_tileset: AseTileset = null
@export var tile_user_data: Dictionary = {}
@export_storage var _compressed_data: PackedByteArray
@export_storage var _original_tile_data: PackedByteArray = []

func is_empty_tile(tile_id: int) -> bool:
	return tile_id == empty_tile_value

func _init(p_data: PackedByteArray = PackedByteArray()) -> void:
	super(p_data, ChunkType.TILESET)

func _parse_chunk() -> Error:
	tileset_id = _stream.get_DWORD()
	flags = _stream.get_DWORD()
	num_tiles = _stream.get_DWORD()
	tile_width = _stream.get_WORD()
	tile_height = _stream.get_WORD()
	base_index = _stream.get_SHORT()
	_stream.get_BYTES(14)
	name = _stream.get_STRING()
	
	AseLogger.debug("Parsed tileset '%s' id=%d tiles=%d" % [name, tileset_id, num_tiles])
	
	if flags & 4:
		empty_tile_value = 0
	else:
		empty_tile_value = 0xFFFFFFFF
	
	if flags & 1:
		is_external = true
		external_file_id = _stream.get_DWORD()
		external_tileset_id = _stream.get_DWORD()
	else:
		is_external = false
	
	if flags & 2:
		var data_length = _stream.get_DWORD()
		if data_length > 0:
			_original_tile_data = _stream.get_BYTES(data_length)
			tiles_image = _original_tile_data.decompress(FileAccess.COMPRESSION_DEFLATE)
	
	return OK

func resolve_external_tileset(external_files: AseExternalFiles, base_path: String) -> Error:
	if not is_external:
		return OK
	
	var external_file = null
	for file in external_files.files:
		if file.entry_id == external_file_id:
			external_file = file
			break
	
	if not external_file:
		AseLogger.error("External file not found for tileset %d" % tileset_id)
		return ERR_FILE_NOT_FOUND
	
	external_file_path = _resolve_path(base_path, external_file.filename)
	AseLogger.debug("Loading external tileset from: %s" % external_file_path)
	
	var parser = AseParser.new()
	var result = parser.load_ase(external_file_path)
	
	if result.keys()[0] != OK:
		AseLogger.error("Failed to load external tileset: %s" % external_file_path)
		return result.keys()[0]
	
	var external_ase = result[result.keys()[0]]
	
	for frame in external_ase.frames:
		for chunk in frame.chunks:
			if chunk is AseTileset and chunk.tileset_id == external_tileset_id:
				external_tileset = chunk
				tile_width = external_tileset.tile_width
				tile_height = external_tileset.tile_height
				num_tiles = external_tileset.num_tiles
				tiles_image = external_tileset.tiles_image
				base_index = external_tileset.base_index
				return OK
	
	AseLogger.error("External tileset ID %d not found in %s" % [external_tileset_id, external_file_path])
	return ERR_FILE_CORRUPT

func _resolve_path(base_path: String, relative_path: String) -> String:
	var base_dir = base_path.get_base_dir()
	var full_path = base_dir.path_join(relative_path)
	
	if not FileAccess.file_exists(full_path):
		if FileAccess.file_exists(relative_path):
			return relative_path
		var alt_path = base_dir.path_join(relative_path.get_file())
		if FileAccess.file_exists(alt_path):
			return alt_path
		AseLogger.warning("External file not found: %s" % relative_path)
	
	return full_path

func get_tile_image(tile_index: int) -> Image:
	if tile_index < 0 or tile_index >= num_tiles:
		return null
	
	if external_tileset:
		return external_tileset.get_tile_image(tile_index)
	
	if tiles_image.is_empty():
		return null
	
	var tileset_height = tile_height * num_tiles
	var tileset_image = Image.create_from_data(tile_width, tileset_height, false, Image.FORMAT_RGBA8, tiles_image)
	var tile_y = tile_index * tile_height
	return tileset_image.get_region(Rect2i(0, tile_y, tile_width, tile_height))

func get_tile_from_raw_data(raw_tile: int, tile_id_mask: int, flip_x_mask: int, flip_y_mask: int, flip_diag_mask: int) -> Image:
	var tile_id = raw_tile & tile_id_mask
	var flip_flags = 0
	
	if (raw_tile & flip_x_mask) != 0:
		flip_flags |= TileFlip.FLIP_X
	if (raw_tile & flip_y_mask) != 0:
		flip_flags |= TileFlip.FLIP_Y
	if (raw_tile & flip_diag_mask) != 0:
		flip_flags |= TileFlip.FLIP_DIAG
	
	return get_transformed_tile(tile_id, flip_flags)

func get_transformed_tile(tile_id: int, flip_flags: int) -> Image:
	var base_image = get_tile_image(tile_id)
	if not base_image:
		return null
	
	var transformed = base_image.duplicate()
	
	if flip_flags & TileFlip.FLIP_DIAG:
		transformed = _diagonal_flip(transformed)
	if flip_flags & TileFlip.FLIP_X:
		transformed.flip_x()
	if flip_flags & TileFlip.FLIP_Y:
		transformed.flip_y()
	
	return transformed

func _diagonal_flip(image: Image) -> Image:
	var result = Image.create(image.get_height(), image.get_width(), false, image.get_format())
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			result.set_pixel(y, x, image.get_pixel(x, y))
	return result

func add_tile_user_data(tile_index: int, p_user_data: AseUserData) -> void:
	tile_user_data[tile_index] = p_user_data

func get_tile_user_data(tile_index: int) -> AseUserData:
	return tile_user_data.get(tile_index)

func _serialize_chunk() -> Dictionary[Error, PackedByteArray]:
	if error != OK:
		return {error: PackedByteArray()}
	
	var stream = AseDataStream.new()
	var data = PackedByteArray()
	stream.data_array = data
	
	stream.put_DWORD(0)
	stream.put_WORD(ChunkType.TILESET)
	
	stream.put_DWORD(tileset_id)
	stream.put_DWORD(flags)
	stream.put_DWORD(num_tiles)
	stream.put_WORD(tile_width)
	stream.put_WORD(tile_height)
	stream.put_SHORT(base_index)
	stream.pad_BYTES(14)
	stream.put_STRING(name)
	
	if flags & 1:
		stream.put_DWORD(external_file_id)
		stream.put_DWORD(external_tileset_id)
	
	if flags & 2:
		if not _original_tile_data.is_empty():
			stream.put_DWORD(_original_tile_data.size())
			stream.put_BYTES(_original_tile_data)
		else:
			var compressed = tiles_image.compress(FileAccess.COMPRESSION_DEFLATE)
			stream.put_DWORD(compressed.size())
			stream.put_BYTES(compressed)
	
	var total_size = stream.get_position()
	stream.seek(0)
	stream.put_DWORD(total_size)
	
	return {OK: stream.get_data_array()}
