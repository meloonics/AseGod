extends AseChunk
class_name AseTags #TODO rename

enum LoopDirection {
	FORWARD = 0,
	REVERSE = 1,
	PING_PONG = 2,
	PING_PONG_REVERSE = 3
}

@export var tags: Array[AseTag] = []

func _init(p_data: PackedByteArray = PackedByteArray()) -> void:
	super(p_data, ChunkType.TAGS)

func _parse_chunk() -> Error:
	var n_tags = _stream.get_WORD()
	_stream.get_BYTES(8)  # reserved
	
	for i in n_tags:
		var from = _stream.get_WORD()
		var to = _stream.get_WORD()
		var dir = _stream.get_BYTE()
		var repeat = _stream.get_WORD()
		_stream.get_BYTES(6)  # reserved
		var r = _stream.get_BYTE()
		var g = _stream.get_BYTE()
		var b = _stream.get_BYTE()
		_stream.get_BYTE()  # extra byte (zero)
		var name = _stream.get_STRING()
		
		tags.append(AseTag.new(from, to, dir, repeat, name, Color8(r, g, b)))
	
	return OK

func _serialize_chunk() -> Dictionary[Error, PackedByteArray]:
	if error != OK:
		return {error: PackedByteArray()}
	
	AseLogger.debug("Serializing %d tags" % tags.size())
	
	var stream = AseDataStream.new()
	_data.clear()
	stream.data_array = _data
	stream.put_DWORD(0)
	stream.put_WORD(ChunkType.TAGS)
	
	stream.put_WORD(tags.size())
	stream.pad_BYTES(8)
	
	for tag in tags:
		stream.put_WORD(tag.from_frame)
		stream.put_WORD(tag.to_frame)
		stream.put_BYTE(tag.direction)
		stream.put_WORD(tag.repeat)
		stream.pad_BYTES(6)
		stream.put_BYTE(int(tag.color.r8))
		stream.put_BYTE(int(tag.color.g8))
		stream.put_BYTE(int(tag.color.b8))
		stream.put_BYTE(0)
		stream.put_STRING(tag.name)
	
	var total_size = stream.get_position()
	stream.seek(0)
	stream.put_DWORD(total_size)
	
	return {OK: stream.get_data_array()}
