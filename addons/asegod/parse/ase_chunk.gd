@abstract
extends AseElement
class_name AseChunk

enum ChunkType {
	INVALID = -1,
	OLD_PALETTE_1 = 0x0004,
	OLD_PALETTE_2 = 0x0011,
	LAYER = 0x2004,
	CEL = 0x2005,
	CEL_EXTRA = 0x2006,
	COLOR_PROFILE = 0x2007,
	EXTERNAL_FILES = 0x2008,
	MASK = 0x2016,
	PATH = 0x2017,
	TAGS = 0x2018,
	PALETTE = 0x2019,
	USER_DATA = 0x2020,
	SLICE = 0x2022,
	TILESET = 0x2023,
}

@export_custom(AseFile._H, "", AseFile._U) var chunk_size: int = 0
@export_custom(AseFile._H, "", AseFile._U) var chunk_type: ChunkType = ChunkType.INVALID

var _stream: AseDataStream
var _cache: Dictionary = {}
@export var user_data: AseUserData = null
@export_storage var _parsed: bool = false
@export_storage var _chunk_data_size: int = 0

func _init(p_data: PackedByteArray = PackedByteArray(), p_chunk_type: ChunkType = ChunkType.INVALID) -> void:
	chunk_type = p_chunk_type
	_data = p_data

func parse() -> Error:
	if _parsed:
		return error
	
	if _data.is_empty():
		error = ERR_INVALID_DATA
		return error
	
	_stream = AseDataStream.new()
	_stream.data_array = _data
	error = _validate_data()
	
	if error == OK:
		chunk_size = _data.size()
		_stream.seek(6)
		error = _parse_chunk()
	
	_parsed = true
	return error

@abstract
func _parse_chunk() -> Error

@abstract
func _serialize_chunk() -> Dictionary[Error, PackedByteArray]

func attach_user_data(data_chunk: AseUserData) -> void:
	user_data = data_chunk
