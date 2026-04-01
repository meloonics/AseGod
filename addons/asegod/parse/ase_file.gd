#@tool
extends Resource

# TODO: make resource accustomed to indexed sprites specifically
enum ColorDepth {RGBA = 32, GRAYSCALE = 16, INDEXED = 8}
enum TileFormat {BYTE = 1, WORD = 2, DWORD = 4}
enum HeaderFlags {OPACITY_VALID = 1, VALID_FOR_GROUP = 2, HAS_UUID = 4}

const HEADER_SIZE_BYTES: int = 128
const MAGIC_NUMBER: int = 0xA5E0
const INVALID: ASE.File = null

# export shorthands
const _H: PropertyHint = PROPERTY_HINT_NONE
const _U: int = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY

@export_custom(_H, "", _U) var source_path: String
@export_custom(_H, "", _U) var last_updated: String
@export_custom(_H, "", _U) var file_size_B: int
@export_custom(_H, "", _U) var n_frames: int
@export var sprite_size: Vector2i
@export var color_depth: ColorDepth = ColorDepth.RGBA
@export_custom(PROPERTY_HINT_FLAGS, "Layer Opacity Valid:1,Blend Mode/Opacity valid for groups:2,Layers have an UUID:4", _U) var flags: int = 1
@export_custom(_H, "", _U) var n_colors: int = 0
@export_custom(PROPERTY_HINT_LINK, "") var pixel_dimensions: Vector2i
@export var grid: Rect2i
@export var frames: Array[ASE.Frame]
@export_storage var _timestamp: int:
	set(value):
		_timestamp = value
		last_updated = Time.get_datetime_string_from_unix_time(_timestamp)
@export_storage var _file_md5: String
@export_storage var _d_speed: int
@export_storage var _transparent_index: int = 0


var error: Error = OK
var width: int:
	get(): return absi(sprite_size.x)
var height: int:
	get(): return absi(sprite_size.y)
@export_storage var layers_by_index: Dictionary = {}

var _file_path: String = ""
var _frame_offsets: PackedInt64Array = []
var _loaded_frames: Dictionary = {}

# BUG: Somehow this breaks if you don't put a default value for every single parameter, idk.
func _init(
	p_file_size: int = 0,
	p_magic: int = MAGIC_NUMBER,
	p_frames: int = 1,
	p_sprite_size: Vector2i = Vector2i.ZERO,
	p_color_depth: ColorDepth = ColorDepth.RGBA,
	p_flags: int = 1,
	p_speed: int = 0,
	p_zero: int = 0,
	p_palette_entry: int = 0,
	p_n_colors: int = 0,
	p_pixel_dimensions: Vector2i = Vector2i.ONE,
	p_grid: Rect2i = Rect2i(),
) -> void:
	
	file_size_B = p_file_size
	assert(p_magic == MAGIC_NUMBER)
	n_frames = p_frames
	sprite_size = p_sprite_size
	color_depth = p_color_depth
	flags = p_flags
	_d_speed = p_speed
	if p_zero != 0:
		ASE.Log.warning("Unexpected Non-Zero Bytes")
		
	_transparent_index = p_palette_entry
	n_colors = p_n_colors
	pixel_dimensions = p_pixel_dimensions
	grid = p_grid
	error = OK
	

func add_layer(layer: ASE.Layer, index: int) -> void:
	layers_by_index[index] = layer

func serialize_to_ase() -> PackedByteArray:
	var stream = ASE.DataStream.new()
	
	# Write header
	stream.put_DWORD(0)
	stream.put_WORD(MAGIC_NUMBER)
	stream.put_WORD(n_frames)
	stream.put_WORD(sprite_size.x)
	stream.put_WORD(sprite_size.y)
	stream.put_WORD(color_depth)
	stream.put_DWORD(flags)
	stream.put_WORD(_d_speed)
	stream.put_DWORD(0) # Reserved
	stream.put_DWORD(0) # Reserved
	stream.put_BYTE(_transparent_index)
	stream.put_BYTES([0, 0, 0]) # Reserved
	stream.put_WORD(n_colors)
	stream.put_BYTE(pixel_dimensions.x)
	stream.put_BYTE(pixel_dimensions.y)
	stream.put_SHORT(grid.position.x)
	stream.put_SHORT(grid.position.y)
	stream.put_WORD(grid.size.x)
	stream.put_WORD(grid.size.y)
	stream.pad_BYTES(84) # Reserved
	
	var header_size = stream.get_position()
	
	# Write frames
	var frames_data = PackedByteArray()
	for i in range(frames.size()):
		frames_data += _serialize_frame(frames[i])
	
	var total_size = header_size + frames_data.size()
	stream.seek(0)
	stream.put_DWORD(total_size)
	stream.seek(header_size)
	stream.put_BYTES(frames_data)
	
	return stream.get_data_array()

func _serialize_frame(frame: ASE.Frame) -> PackedByteArray:
	ASE.Log.debug("Serializing frame with %d chunks" % frame.chunks.size())
	
	var stream = ASE.DataStream.new()
	var chunks_data = PackedByteArray()
	
	for chunk in frame.chunks:
		if chunk is ASE.Chunk:
			var chunk_result = chunk._serialize_chunk()
			if chunk_result.keys()[0] == OK:
				chunks_data += chunk_result[chunk_result.keys()[0]]
		
		if chunk is ASE.TagsChunk:
			for tag in chunk.tags:
				if tag.user_data and tag.user_data._serialize_chunk().keys()[0] == OK:
					chunks_data += tag.user_data._serialize_chunk()[OK]
	
	# Write header
	var header_start = stream.get_position()
	stream.put_DWORD(16 + chunks_data.size())
	stream.put_WORD(ASE.Frame.MAGIC_NUMBER)
	
	# Check if extended format needed
	var uses_extended = frame._original_new_chunk_count >= 0xFFFF or frame.n_chunks >= 0xFFFF
	if uses_extended:
		stream.put_WORD(0xFFFF)
		stream.put_WORD(frame.duration_ms)
		stream.pad_BYTES(2)
		stream.put_DWORD(frame.n_chunks)
	else:
		stream.put_WORD(frame.n_chunks)
		stream.put_WORD(frame.duration_ms)
		stream.pad_BYTES(2)
		stream.put_DWORD(frame.n_chunks)
	
	stream.put_BYTES(chunks_data)
	return stream.get_data_array()
