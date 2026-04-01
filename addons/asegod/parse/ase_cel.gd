extends ASE.Chunk

enum CelType {
	RAW_IMAGE = 0,
	LINKED_CEL = 1,
	COMPRESSED_IMAGE = 2,
	COMPRESSED_TILEMAP = 3
}

@export var extra_data: ASE.CelExtra = null
@export var layer_index: int = 0
@export var x: int = 0
@export var y: int = 0
@export var opacity: int = 255

# FIX: Stored as int, not CelType enum
# Using enum cast 'as CelType' caused 0x100 shift in tile IDs
@export var cel_type: int = CelType.COMPRESSED_IMAGE

@export var z_index: int = 0
@export var color_depth: ASE.File.ColorDepth = ASE.File.ColorDepth.RGBA

@export_storage var _compressed_data: PackedByteArray = []
var _is_pixels_loaded: bool = false

@export var width: int = 0
@export var height: int = 0
@export_storage var pixels: PackedByteArray = []

@export var linked_frame: int = -1

@export var tilemap_width: int = 0
@export var tilemap_height: int = 0
@export var bits_per_tile: int = 32

# FIX: Masks stored as bytes to prevent Godot resource serialization corruption
# When saved to .tres, exported ints with high bits (>= 0x80000000) get truncated
@export_storage var _tile_id_mask_bytes: PackedByteArray = []
@export_storage var _flip_x_mask_bytes: PackedByteArray = []
@export_storage var _flip_y_mask_bytes: PackedByteArray = []
@export_storage var _flip_diag_mask_bytes: PackedByteArray = []

var tile_id_mask: int:
	get:
		return _tile_id_mask_bytes.decode_u32(0) if _tile_id_mask_bytes.size() == 4 else 0
	set(value):
		_tile_id_mask_bytes = PackedByteArray([value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF, (value >> 24) & 0xFF])

var flip_x_mask: int:
	get:
		return _flip_x_mask_bytes.decode_u32(0) if _flip_x_mask_bytes.size() == 4 else 0
	set(value):
		_flip_x_mask_bytes = PackedByteArray([value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF, (value >> 24) & 0xFF])

var flip_y_mask: int:
	get:
		return _flip_y_mask_bytes.decode_u32(0) if _flip_y_mask_bytes.size() == 4 else 0
	set(value):
		_flip_y_mask_bytes = PackedByteArray([value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF, (value >> 24) & 0xFF])

var flip_diag_mask: int:
	get:
		return _flip_diag_mask_bytes.decode_u32(0) if _flip_diag_mask_bytes.size() == 4 else 0
	set(value):
		_flip_diag_mask_bytes = PackedByteArray([value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF, (value >> 24) & 0xFF])

var tiles: PackedInt64Array = []
@export var tileset: ASE.TileSetChunk = null
@export_storage var _tile_data: PackedByteArray = []
@export_storage var _original_compressed_data: PackedByteArray = []

func set_tileset(p_tileset: ASE.TileSetChunk) -> void:
	tileset = p_tileset

func _init(p_data: PackedByteArray = PackedByteArray(), p_color_depth: ASE.File.ColorDepth = ASE.File.ColorDepth.RGBA) -> void:
	color_depth = p_color_depth
	super(p_data, ChunkType.CEL)

func _parse_chunk() -> Error:
	layer_index = _stream.get_WORD()
	x = _stream.get_SHORT()
	y = _stream.get_SHORT()
	opacity = _stream.get_BYTE()
	cel_type = _stream.get_WORD()
	z_index = _stream.get_SHORT()
	_stream.get_BYTES(5) # Reserved
	
	match cel_type:
		CelType.RAW_IMAGE:
			width = _stream.get_WORD()
			height = _stream.get_WORD()
			var expected_bytes = width * height * color_depth
			if expected_bytes > _stream.get_remaining_bytes():
				return ERR_INVALID_DATA
			pixels = _stream.get_BYTES(expected_bytes)
		
		CelType.LINKED_CEL:
			linked_frame = _stream.get_WORD()
		
		CelType.COMPRESSED_IMAGE:
			width = _stream.get_WORD()
			height = _stream.get_WORD()
			_original_compressed_data = _stream.get_BYTES(_stream.get_size() - _stream.get_position())
			_compressed_data = _original_compressed_data
			_is_pixels_loaded = false
		
		CelType.COMPRESSED_TILEMAP:
			tilemap_width = _stream.get_WORD()
			tilemap_height = _stream.get_WORD()
			bits_per_tile = _stream.get_WORD()
			
			# Read 4 masks as raw bytes (DWORD each)
			_tile_id_mask_bytes = _stream.get_BYTES(4)
			_flip_x_mask_bytes = _stream.get_BYTES(4)
			_flip_y_mask_bytes = _stream.get_BYTES(4)
			_flip_diag_mask_bytes = _stream.get_BYTES(4)
			
			_stream.get_BYTES(10) # Reserved
			
			var remaining = _chunk_data_size - _stream.get_position()
			_original_compressed_data = _stream.get_BYTES(remaining)
			_compressed_data = _original_compressed_data
			
			var decompressed = _compressed_data.decompress(FileAccess.COMPRESSION_DEFLATE)
			_tile_data = decompressed
			tiles = _parse_tiles(decompressed)
	
	return OK

func _validate_data() -> Error:
	if cel_type == CelType.COMPRESSED_TILEMAP and not _tile_data.is_empty() and tiles.is_empty():
		tiles = _parse_tiles(_tile_data)
	return OK

func _serialize_chunk() -> Dictionary[Error, PackedByteArray]:
	if error != OK:
		return {error: PackedByteArray()}
	
	var stream = ASE.DataStream.new()
	var data = PackedByteArray()
	stream.data_array = data
	
	stream.put_DWORD(0) # Size placeholder
	stream.put_WORD(ChunkType.CEL)
	
	stream.put_WORD(layer_index)
	stream.put_SHORT(x)
	stream.put_SHORT(y)
	stream.put_BYTE(opacity)
	stream.put_WORD(cel_type)
	stream.put_SHORT(z_index)
	stream.pad_BYTES(5)
	
	match cel_type:
		CelType.RAW_IMAGE:
			stream.put_WORD(width)
			stream.put_WORD(height)
			stream.put_BYTES(pixels)
		
		CelType.LINKED_CEL:
			stream.put_WORD(linked_frame)
		
		CelType.COMPRESSED_IMAGE:
			stream.put_WORD(width)
			stream.put_WORD(height)
			if not _original_compressed_data.is_empty():
				stream.put_BYTES(_original_compressed_data)
			else:
				var compressed = _compressed_data
				if compressed.is_empty() and not pixels.is_empty():
					compressed = pixels.compress(FileAccess.COMPRESSION_DEFLATE)
				stream.put_BYTES(compressed)
		
		CelType.COMPRESSED_TILEMAP:
			stream.put_WORD(tilemap_width)
			stream.put_WORD(tilemap_height)
			stream.put_WORD(bits_per_tile)
			
			# Write masks from raw bytes
			stream.put_BYTES(_tile_id_mask_bytes if _tile_id_mask_bytes.size() == 4 else [0, 0, 0, 0])
			stream.put_BYTES(_flip_x_mask_bytes if _flip_x_mask_bytes.size() == 4 else [0, 0, 0, 0])
			stream.put_BYTES(_flip_y_mask_bytes if _flip_y_mask_bytes.size() == 4 else [0, 0, 0, 0])
			stream.put_BYTES(_flip_diag_mask_bytes if _flip_diag_mask_bytes.size() == 4 else [0, 0, 0, 0])
			
			stream.pad_BYTES(10)
			
			var compressed = _original_compressed_data
			if compressed.is_empty():
				if not _tile_data.is_empty():
					compressed = _tile_data.compress(FileAccess.COMPRESSION_DEFLATE)
				elif not tiles.is_empty():
					compressed = _serialize_tiles(tiles).compress(FileAccess.COMPRESSION_DEFLATE)
			stream.put_BYTES(compressed)
	
	var total_size = stream.get_position()
	stream.seek(0)
	stream.put_DWORD(total_size)
	
	return {OK: stream.get_data_array()}

func _parse_tiles(data: PackedByteArray) -> PackedInt64Array:
	var _tiles = PackedInt64Array()
	var stream = ASE.DataStream.new()
	stream.set_data_array(data)
	
	var tile_size = max(1, bits_per_tile / 8)
	var total_tiles_count = tilemap_width * tilemap_height
	
	for i in total_tiles_count:
		match tile_size:
			1:
				_tiles.append(stream.get_BYTE())
			2:
				_tiles.append(stream.get_WORD())
			4:
				_tiles.append(stream.get_DWORD())
			_:
				_tiles.append(stream.get_DWORD())
	
	return _tiles

func get_tile_id_with_flips(raw_tile: int) -> Dictionary:
	return {
		"id": raw_tile & tile_id_mask,
		"flip_x": (raw_tile & flip_x_mask) != 0,
		"flip_y": (raw_tile & flip_y_mask) != 0,
		"flip_diag": (raw_tile & flip_diag_mask) != 0
	}

func _serialize_tiles(_tiles: PackedInt64Array) -> PackedByteArray:
	var stream = ASE.DataStream.new()
	var tile_size = max(1, bits_per_tile / 8)
	for tile in _tiles:
		match tile_size:
			1:
				stream.put_BYTE(tile)
			2:
				stream.put_WORD(tile)
			4:
				stream.put_DWORD(tile)
	return stream.get_data_array()

func get_render_order(layer_index: int) -> int:
	return layer_index + z_index

func get_pixels() -> PackedByteArray:
	if not _is_pixels_loaded and not _compressed_data.is_empty():
		pixels = _compressed_data.decompress(FileAccess.COMPRESSION_DEFLATE)
		_is_pixels_loaded = true
	return pixels

func free_pixels() -> void:
	pixels = PackedByteArray()
	_compressed_data = PackedByteArray()
	_is_pixels_loaded = false

func get_tile_info(tile_index: int) -> Dictionary:
	if tile_index < 0 or tile_index >= tiles.size():
		return {"id": -1, "flip_x": false, "flip_y": false, "flip_diag": false}
	
	var raw_tile = tiles[tile_index]
	return {
		"id": raw_tile & tile_id_mask,
		"flip_x": (raw_tile & flip_x_mask) != 0,
		"flip_y": (raw_tile & flip_y_mask) != 0,
		"flip_diag": (raw_tile & flip_diag_mask) != 0
	}

func get_tile_image_at(tile_index: int) -> Image:
	if not tileset:
		return null
	if tile_index < 0 or tile_index >= tiles.size():
		return null
	var raw_tile = tiles[tile_index]
	return tileset.get_tile_from_raw_data(raw_tile, tile_id_mask, flip_x_mask, flip_y_mask, flip_diag_mask)
