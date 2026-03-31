extends AseChunk
class_name AseMissingNo

## You should never encounter this class in the wild, but if the parser
## encounters something it doesn't understand it stores the raw bytes.

var raw_data: PackedByteArray

func _init(p_data: PackedByteArray = PackedByteArray()) -> void:
	raw_data = p_data
	super(p_data, ChunkType.INVALID)

func _parse_chunk() -> Error:
	# Only store raw data
	return OK

func _serialize_chunk() -> Dictionary[Error, PackedByteArray]:
	if error != OK:
		return {error: PackedByteArray()}
	if not _stream:
		_stream = AseDataStream.new()
	_data.clear()
	_stream.data_array = _data
	_stream.put_DWORD(0)
	_stream.put_WORD(chunk_type)
	_stream.put_BYTES(raw_data.slice(6))  # skip header
	
	var total_size = _stream.get_position()
	_stream.seek(0)
	_stream.put_DWORD(total_size)
	
	return {OK: _stream.get_data_array()}
