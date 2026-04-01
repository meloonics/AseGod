extends ASE.Chunk

#region Constants
enum LayerFlags {
	VISIBLE = 1,
	EDITABLE = 2,
	LOCK_MOVEMENT = 4,
	BACKGROUND = 8,
	PREFER_LINKED_CELS = 16,
	COLLAPSED = 32,
	REFERENCE = 64
}

enum LayerType {
	NORMAL = 0,
	GROUP = 1,
	TILEMAP = 2
}

enum BlendMode {
	NORMAL = 0,
	MULTIPLY = 1,
	SCREEN = 2,
	OVERLAY = 3,
	DARKEN = 4,
	LIGHTEN = 5,
	COLOR_DODGE = 6,
	COLOR_BURN = 7,
	HARD_LIGHT = 8,
	SOFT_LIGHT = 9,
	DIFFERENCE = 10,
	EXCLUSION = 11,
	HUE = 12,
	SATURATION = 13,
	COLOR = 14,
	LUMINOSITY = 15,
	ADDITION = 16,
	SUBTRACT = 17,
	DIVIDE = 18
}
#endregion

#region Exports
@export var layer_name: String = ""
@export_flags(
	"visible:1", 
	"editable:2", 
	"lock movement:4",
	"is background:8",
	"prefer linked cels:16",
	"collapsed:32",
	"reference:64"
) 
var flags: int = LayerFlags.VISIBLE
@export var layer_type: LayerType = LayerType.NORMAL
@export var child_level: int = 0
@export var blend_mode: BlendMode = BlendMode.NORMAL
@export var layer_index: int = -1
@export var opacity: int = 255
@export var tileset_index: int = -1  # Only for tilemap layers
@export var header_flags: int
@export var uuid: StringName = &""  # Only if header flags have bit 4
@export var has_uuid: bool = false
@export var opacity_valid: bool = true
@export var blend_mode_valid: bool = true
#endregion

func set_index(idx: int) -> void:
	layer_index = idx

func _init(p_data: PackedByteArray = PackedByteArray(), p_header_flags: int = 0, p_index: int = -1) -> void:
	header_flags = p_header_flags
	has_uuid = (header_flags & 4) != 0
	layer_index = p_index
	super(p_data, ChunkType.LAYER)

func _validate_data() -> Error:
	if _data.size() < 6:
		return ERR_FILE_CORRUPT
	
	var size = _data.decode_u32(0)
	var type = _data.decode_u16(4)
	
	if size != _data.size():
		return ERR_FILE_CORRUPT
	if type != ChunkType.LAYER:
		return ERR_INVALID_DATA
	
	return OK

func _parse_chunk() -> Error:
	flags = _stream.get_WORD()
	layer_type = _stream.get_WORD() as LayerType
	blend_mode_valid = (layer_type != LayerType.GROUP) or (header_flags & 2 != 0)
	child_level = _stream.get_WORD()
	_stream.get_WORD()  # default layer width (ignored)
	_stream.get_WORD()  # default layer height (ignored)
	blend_mode = _stream.get_WORD() as BlendMode
	opacity = _stream.get_BYTE()
	opacity_valid = (header_flags & 1 != 0) and (layer_type != LayerType.GROUP)
	_stream.get_BYTES(3)  # reserved
	layer_name = _stream.get_STRING()
	
	if layer_type == LayerType.TILEMAP:
		tileset_index = _stream.get_DWORD()
	
	if has_uuid:
		uuid = _stream.get_UUID()
	
	return OK

func _serialize_chunk() -> Dictionary[Error, PackedByteArray]:
	if error != OK:
		return {error: PackedByteArray()}
	
	var stream = ASE.DataStream.new()
	var data = PackedByteArray()
	stream.data_array = data
	
	stream.put_DWORD(0)  # Size placeholder
	stream.put_WORD(ChunkType.LAYER)
	
	stream.put_WORD(flags)
	stream.put_WORD(layer_type)
	stream.put_WORD(child_level)
	stream.put_WORD(0)  # default layer width (ignored)
	stream.put_WORD(0)  # default layer height (ignored)
	stream.put_WORD(blend_mode)
	stream.put_BYTE(opacity)
	stream.pad_BYTES(3)
	stream.put_STRING(layer_name)
	
	if layer_type == LayerType.TILEMAP:
		stream.put_DWORD(tileset_index)
	
	if has_uuid and not uuid.is_empty():
		stream.put_UUID(uuid)
	
	var total_size = stream.get_position()
	stream.seek(0)
	stream.put_DWORD(total_size)
	
	return {OK: stream.get_data_array()}
