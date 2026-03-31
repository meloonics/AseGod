extends AseChunk
class_name AseCelExtra

enum ExtraFlags {
	PRECISE_BOUNDS = 1
}

var flags: int = 0
var precise_x: float = 0.0
var precise_y: float = 0.0
var precise_width: float = 0.0
var precise_height: float = 0.0

func _init(p_data: PackedByteArray = PackedByteArray()) -> void:
	super(p_data, ChunkType.CEL_EXTRA)

func _parse_chunk() -> Error:
	flags = _stream.get_DWORD()
	if flags & 1:
		precise_x = _stream.get_FIXED()
		precise_y = _stream.get_FIXED()
		precise_width = _stream.get_FIXED()
		precise_height = _stream.get_FIXED()
	_stream.get_BYTES(16)  # reserved
	return OK

func _serialize_chunk() -> Dictionary[Error, PackedByteArray]:
	if error != OK:
		return {error: PackedByteArray()}
	var stream = AseDataStream.new()
	# header
	_data.clear()
	stream.data_array = _data
	stream.put_DWORD(0)
	stream.put_WORD(ChunkType.CEL_EXTRA)
	
	# flags
	var out_flags = 0
	if precise_width != 0 or precise_height != 0:
		out_flags |= 1
	
	stream.put_DWORD(out_flags)
	
	if out_flags & 1:
		stream.put_FIXED(precise_x)
		stream.put_FIXED(precise_y)
		stream.put_FIXED(precise_width)
		stream.put_FIXED(precise_height)
	
	stream.pad_BYTES(16)
	
	var total_size = stream.get_position()
	stream.seek(0)
	stream.put_DWORD(total_size)
	
	return {OK: stream.get_data_array()}
