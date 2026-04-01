extends ASE.Chunk

enum Flags {
	HAS_TEXT = 1,
	HAS_COLOR = 2,
	HAS_PROPERTIES = 4
}

enum UDTypeWord {
	UNDEFINED = 0,
	BOOL = 0x0001,
	INT8 = 0x0002,
	UINT8 = 0x0003,
	INT16 = 0x0004,
	UINT16 = 0x0005,
	INT32 = 0x0006,
	UINT32 = 0x0007,
	INT64 = 0x0008,
	UINT64 = 0x0009,
	FIXED = 0x000A,
	FLOAT = 0x000B,
	DOUBLE = 0x000C,
	STRING = 0x000D,
	POINT = 0x000E, # -> Vec2i
	SIZE = 0x000F, # -> Vec2i
	RECT = 0x0010, 
	VECTOR = 0x0011, # -> Array
	NESTED = 0x0012, # -> Dictionary
	UUID = 0x0013,
}

@export var text: String = ""
@export var color: Color = Color.TRANSPARENT
@export var properties: Dictionary = {}
@export_storage var _original_flags: int = 0
@export_storage var _has_text: bool = false
@export_storage var _has_color: bool = false
@export_storage var _has_properties: bool = false

func _init(p_data: PackedByteArray = PackedByteArray()) -> void:
	super(p_data, ChunkType.USER_DATA)
	_original_flags = 0

func _parse_chunk() -> Error:
	var flags = _stream.get_DWORD()
	_original_flags = flags
	_has_text = (flags & Flags.HAS_TEXT) != 0
	_has_color = (flags & Flags.HAS_COLOR) != 0
	_has_properties = (flags & Flags.HAS_PROPERTIES) != 0
	
	if flags & Flags.HAS_TEXT:
		text = _stream.get_STRING()
	
	if flags & Flags.HAS_COLOR:
		var r = _stream.get_BYTE()
		var g = _stream.get_BYTE()
		var b = _stream.get_BYTE()
		var a = _stream.get_BYTE()
		color = Color8(r, g, b, a)
	
	if flags & Flags.HAS_PROPERTIES:
		properties = _parse_properties()
	
	return OK

#TODO: Test this
func _parse_properties() -> Dictionary:
	var total_size = _stream.get_DWORD()
	var start_pos = _stream.get_position()
	var n_maps = _stream.get_DWORD()
	var result = {}
	
	ASE.Log.debug("Parsing properties: size=%d maps=%d" % [total_size, n_maps])
	
	for i in range(n_maps):
		if _stream.get_position() - start_pos > total_size:
			ASE.Log.warning("Properties map exceeds declared size")
			break
		
		var map_key = _stream.get_DWORD()
		var n_props = _stream.get_DWORD()
		
		for j in range(n_props):
			if _stream.get_position() - start_pos > total_size:
				ASE.Log.warning("Properties exceed declared size")
				break
			
			var name = _stream.get_STRING()
			var type = _stream.get_WORD()
			var value = _parse_property_value(type)
			
			if map_key == 0:
				result[name] = value
	
	return result

func _parse_property_value(type: int):
	match type:
		UDTypeWord.BOOL: return _stream.get_BYTE() != 0
		UDTypeWord.INT8: return _stream.get_BYTE()
		UDTypeWord.UINT8: return _stream.get_BYTE()
		UDTypeWord.INT16: return _stream.get_SHORT()
		UDTypeWord.UINT16: return _stream.get_WORD()
		UDTypeWord.INT32: return _stream.get_LONG()
		UDTypeWord.UINT32: return _stream.get_DWORD()
		UDTypeWord.INT64: return _stream.get_LONG64()
		UDTypeWord.UINT64: return _stream.get_QWORD()
		UDTypeWord.FIXED: return _stream.get_FIXED()
		UDTypeWord.FLOAT: return _stream.get_float()
		UDTypeWord.DOUBLE: return _stream.get_double()
		UDTypeWord.STRING: return _stream.get_STRING()
		UDTypeWord.POINT: return _stream.get_POINT()
		UDTypeWord.SIZE: return _stream.get_SIZE()
		UDTypeWord.RECT: return _stream.get_RECT()
		UDTypeWord.VECTOR: return _parse_vector()
		UDTypeWord.NESTED: return _parse_nested_properties()
		UDTypeWord.UUID: return _stream.get_UUID()
		_: 
			ASE.Log.error("Unknown property type: 0x%X" % type)
			return null

func _parse_vector() -> Array:
	var num_elements = _stream.get_DWORD()
	var element_type = _stream.get_WORD()
	var result = []
	
	if element_type == UDTypeWord.UNDEFINED:
		#mixed array
		for k in range(num_elements):
			var elem_type = _stream.get_WORD()
			result.append(_parse_property_value(elem_type))
	else:
		#typed array
		for k in range(num_elements):
			result.append(_parse_property_value(element_type))
	
	return result

func _parse_nested_properties() ->Dictionary:
	var num_props = _stream.get_DWORD()
	var nested = {}
	
	for k in range(num_props):
		var name = _stream.get_STRING()
		var type = _stream.get_WORD()
		nested[name] = _parse_property_value(type)
	
	return nested

func _serialize_chunk() -> Dictionary[Error, PackedByteArray]:
	if error != OK:
		return {error: PackedByteArray()}
	
	var stream = ASE.DataStream.new()
	_data.clear()
	stream.data_array = _data
	stream.put_DWORD(0)
	stream.put_WORD(ChunkType.USER_DATA)
	
	var flags = _original_flags
	if flags == 0:
		if not text.is_empty():
			flags |= Flags.HAS_TEXT
		if color != Color.TRANSPARENT:
			flags |= Flags.HAS_COLOR
		if not properties.is_empty():
			flags |= Flags.HAS_PROPERTIES
	
	stream.put_DWORD(flags)
	
	if flags & Flags.HAS_TEXT:
		stream.put_STRING(text)
	
	if flags & Flags.HAS_COLOR:
		stream.put_BYTE(int(color.r8))
		stream.put_BYTE(int(color.g8))
		stream.put_BYTE(int(color.b8))
		stream.put_BYTE(int(color.a8))
	
	if flags & Flags.HAS_PROPERTIES:
		if properties.is_empty():
			stream.put_DWORD(8)
			stream.put_DWORD(0)
		else:
			_serialize_properties(stream)
	
	var total_size = stream.get_position()
	stream.seek(0)
	stream.put_DWORD(total_size)
	
	return {OK: stream.get_data_array()}

func _serialize_properties(stream: ASE.DataStream) -> void:
	var temp = ASE.DataStream.new()
	temp.put_DWORD(1)
	temp.put_DWORD(properties.size())
	
	for key in properties.keys():
		temp.put_STRING(str(key))
		var value = properties[key]
		var type = _get_property_type(value)
		temp.put_WORD(type)
		_serialize_property_value(temp, type, value)
	
	var props_data = temp.get_data_array()
	stream.put_DWORD(props_data.size() + 4)
	stream.put_BYTES(props_data)

func _get_property_type(value) -> int:
	match typeof(value):
		TYPE_BOOL: return UDTypeWord.BOOL
		TYPE_INT: return UDTypeWord.INT32
		TYPE_FLOAT: return UDTypeWord.FLOAT
		TYPE_STRING: return UDTypeWord.STRING
		TYPE_VECTOR2I: return UDTypeWord.POINT
		TYPE_RECT2I: return UDTypeWord.RECT
		_: return UDTypeWord.STRING

func _serialize_property_value(stream: ASE.DataStream, type: int, value) -> void:
	match type:
		UDTypeWord.BOOL: stream.put_BYTE(1 if value else 0)
		UDTypeWord.INT32: stream.put_LONG(value)
		UDTypeWord.FLOAT: stream.put_float(value)
		UDTypeWord.STRING: stream.put_STRING(str(value))
		UDTypeWord.POINT:
			stream.put_LONG(value.x)
			stream.put_LONG(value.y)
		UDTypeWord.RECT:
			stream.put_LONG(value.position.x)
			stream.put_LONG(value.position.y)
			stream.put_LONG(value.size.x)
			stream.put_LONG(value.size.y)
