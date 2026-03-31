extends AseChunk
class_name AseSlice

class SliceKey:
	var frame: int
	var origin: Vector2i
	var size: Vector2i
	var center: Rect2i
	var pivot: Vector2i
	
	func _init(p_frame: int, p_origin: Vector2i, p_size: Vector2i) -> void:
		frame = p_frame
		origin = p_origin
		size = p_size

var flags: int = 0
var name: String = ""
var keys: Array[SliceKey] = []

func _init(p_data: PackedByteArray = PackedByteArray()) -> void:
	super(p_data, ChunkType.SLICE)

func _parse_chunk() -> Error:
	var n_keys = _stream.get_DWORD()
	flags = _stream.get_DWORD()
	_stream.get_DWORD()
	name = _stream.get_STRING()
	
	AseLogger.debug("Parsing slice '%s' with %d keys" % [name, n_keys])
	
	for i in n_keys:
		var frame = _stream.get_DWORD()
		var origin = Vector2i(_stream.get_LONG(), _stream.get_LONG())
		var size = Vector2i(_stream.get_DWORD(), _stream.get_DWORD())
		var key = SliceKey.new(frame, origin, size)
		
		if flags & 1:
			var center_x = _stream.get_LONG()
			var center_y = _stream.get_LONG()
			var center_w = _stream.get_DWORD()
			var center_h = _stream.get_DWORD()
			key.center = Rect2i(center_x, center_y, center_w, center_h)
		
		if flags & 2:
			var pivot_x = _stream.get_LONG()
			var pivot_y = _stream.get_LONG()
			key.pivot = Vector2i(pivot_x, pivot_y)
		
		keys.append(key)
	
	return OK

func _serialize_chunk() -> Dictionary[Error, PackedByteArray]:
	if error != OK:
		return {error: PackedByteArray()}
	
	var stream = AseDataStream.new()
	_data.clear()
	stream.data_array = _data
	stream.put_DWORD(0)
	stream.put_WORD(ChunkType.SLICE)
	
	stream.put_DWORD(keys.size())
	stream.put_DWORD(flags)
	stream.put_DWORD(0)
	stream.put_STRING(name)
	
	for key in keys:
		stream.put_DWORD(key.frame)
		stream.put_LONG(key.origin.x)
		stream.put_LONG(key.origin.y)
		stream.put_DWORD(key.size.x)
		stream.put_DWORD(key.size.y)
		
		if flags & 1:
			stream.put_LONG(key.center.position.x)
			stream.put_LONG(key.center.position.y)
			stream.put_DWORD(key.center.size.x)
			stream.put_DWORD(key.center.size.y)
		
		if flags & 2:
			stream.put_LONG(key.pivot.x)
			stream.put_LONG(key.pivot.y)
	
	var total_size = stream.get_position()
	stream.seek(0)
	stream.put_DWORD(total_size)
	
	return {OK: stream.get_data_array()}
