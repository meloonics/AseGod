extends ASE.Chunk

enum PaletteType { OLD_1 = 0x0004, OLD_2 = 0x0011, NEW = 0x2019 }

var _parse_mode: PaletteType = PaletteType.NEW
@export_custom(ASE.File._H, "", ASE.File._U) var preview: Gradient
@export var _original_type: PaletteType = PaletteType.NEW
@export_storage var _original_packets: Array = []

@export var colors: PackedColorArray = []:
	set(value):
		colors = value
		if not preview:
			var g = Gradient.new()
			g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
			g.colors = colors
			preview = g

@export var color_names: PackedStringArray = []  # Only populated for NEW palettes
@export_storage var _original_from: int = 0
@export_storage var _original_to: int = -1
@export_storage var _is_global: bool = false

func _init(p_data: PackedByteArray = PackedByteArray()) -> void:
	super(p_data, ChunkType.PALETTE)

func _validate_data() -> Error:
	if _data.size() < 6:
		return ERR_FILE_CORRUPT
	
	var size = _data.decode_u32(0)
	var type = _data.decode_u16(4)
	
	if size != _data.size():
		return ERR_FILE_CORRUPT
	
	match type:
		PaletteType.OLD_1:
			_parse_mode = PaletteType.OLD_1
			_original_type = PaletteType.OLD_1
			return OK
		PaletteType.OLD_2:
			_parse_mode = PaletteType.OLD_2
			_original_type = PaletteType.OLD_2
			return OK
		PaletteType.NEW:
			_parse_mode = PaletteType.NEW
			_original_type = PaletteType.NEW
			return OK
		_:
			# If type doesn't match any palette type, check if it's the generic chunk type
			if type == ChunkType.PALETTE:
				_parse_mode = PaletteType.NEW
				_original_type = PaletteType.NEW
				return OK
	
	return ERR_INVALID_DATA

func _parse_chunk() -> Error:
	match _parse_mode:
		PaletteType.OLD_1:
			return _parse_old_palette_1()
		PaletteType.OLD_2:
			return _parse_old_palette_2()
		PaletteType.NEW:
			return _parse_new_palette()
	
	return ERR_INVALID_DATA

func _parse_old_palette_1() -> Error:
	var n_packets = _stream.get_WORD()
	var palette = []
	var current_index = 0
	
	for i in n_packets:
		var skip = _stream.get_BYTE()
		var n_colors = _stream.get_BYTE()
		if n_colors == 0:
			n_colors = 256
		
		current_index += skip
		
		while palette.size() <= current_index + n_colors - 1:
			palette.append(Color.BLACK)
		
		for j in range(n_colors):
			var r = _stream.get_BYTE()
			var g = _stream.get_BYTE()
			var b = _stream.get_BYTE()
			palette[current_index + j] = Color8(r, g, b)
		
		current_index += n_colors
	
	colors = PackedColorArray(palette)
	return OK

func _parse_old_palette_2() -> Error:
	var n_packets = _stream.get_WORD()
	var palette = []
	var current_index = 0
	
	for i in n_packets:
		var skip = _stream.get_BYTE()
		var n_colors = _stream.get_BYTE()
		if n_colors == 0:
			n_colors = 256
		
		current_index += skip
		
		while palette.size() <= current_index + n_colors - 1:
			palette.append(Color.BLACK)
		
		for j in range(n_colors):
			var r = _stream.get_BYTE() * 4
			var g = _stream.get_BYTE() * 4
			var b = _stream.get_BYTE() * 4
			palette[current_index + j] = Color8(r, g, b)
		
		current_index += n_colors
	
	colors = PackedColorArray(palette)
	return OK

func _parse_new_palette() -> Error:
	var new_size = _stream.get_DWORD()
	var from = _stream.get_DWORD()
	var to = _stream.get_DWORD()
	ASE.Log.debug("Palette: size=%d from=%d to=%d" % [new_size, from, to])
	
	# Validate indices
	if from >= new_size or to >= new_size:
		ASE.Log.warning("Palette indices out of bounds: from=%d to=%d size=%d" % [from, to, new_size])
		from = clampi(from, 0, new_size - 1)
		to = clampi(to, from, new_size - 1)
	
	_original_from = from
	_original_to = to
	
	_stream.get_BYTES(8)
	
	if colors.size() < new_size:
		colors.resize(new_size)
		color_names.resize(new_size)
	
	if to >= 0:
		for i in range(from, to + 1):
			if i >= colors.size():
				break
			
			var flags = _stream.get_WORD()
			var r = _stream.get_BYTE()
			var g = _stream.get_BYTE()
			var b = _stream.get_BYTE()
			var a = _stream.get_BYTE()
			colors[i] = Color8(r, g, b, a)
			
			if flags & 1:
				color_names[i] = _stream.get_STRING()
			elif color_names.size() > i:
				color_names[i] = ""
	
	return OK

func get_color(index: int) -> Color:
	if index < 0 or index >= colors.size():
		push_error("Palette index %d out of bounds (size: %d)" % [index, colors.size()])
		return Color.TRANSPARENT
	return colors[index]

func get_color_name(index: int) -> String:
	"""Get the name of a color if available"""
	if index < 0 or index >= color_names.size():
		return ""
	return color_names[index]

func find_color(color: Color, tolerance: float = 0.0) -> int:
	"""Find the index of a color in the palette"""
	for i in range(colors.size()):
		var c = colors[i]
		if tolerance > 0:
			if abs(c.r - color.r) <= tolerance and \
			   abs(c.g - color.g) <= tolerance and \
			   abs(c.b - color.b) <= tolerance and \
			   abs(c.a - color.a) <= tolerance:
				return i
		else:
			if c == color:
				return i
	return -1

func _serialize_chunk() -> Dictionary[Error, PackedByteArray]:
	if error != OK:
		return {error: PackedByteArray()}
	
	var stream = ASE.DataStream.new()
	var data = PackedByteArray()
	stream.data_array = data
	
	# Write chunk header
	stream.put_DWORD(0)  # Size placeholder
	
	# CRITICAL: Use the correct chunk type based on original
	# The original had ChunkType.PALETTE (0x2019), not OLD_1/OLD_2
	if _original_type == PaletteType.OLD_1:
		stream.put_WORD(PaletteType.OLD_1)
	elif _original_type == PaletteType.OLD_2:
		stream.put_WORD(PaletteType.OLD_2)
	else:
		# For NEW palettes, use the standard chunk type
		stream.put_WORD(ChunkType.PALETTE)
	
	# Write palette data using original format
	match _original_type:
		PaletteType.OLD_1:
			_serialize_old_palette_1_to_stream(stream)
		PaletteType.OLD_2:
			_serialize_old_palette_2_to_stream(stream)
		_:
			# For NEW palettes, use NEW format serialization
			_serialize_new_palette_to_stream(stream)
	
	var total_size = stream.get_position()
	stream.seek(0)
	stream.put_DWORD(total_size)
	
	return {OK: stream.get_data_array()}

# Helper methods that take a stream parameter
func _serialize_old_palette_1_to_stream(stream: ASE.DataStream) -> void:
	var packets = _build_old_palette_packets(4)
	stream.put_WORD(packets.size())
	for packet in packets:
		stream.put_BYTE(packet.skip)
		stream.put_BYTE(packet.count)
		for color in packet.colors:
			stream.put_BYTE(int(color.r8))
			stream.put_BYTE(int(color.g8))
			stream.put_BYTE(int(color.b8))

func _serialize_old_palette_2_to_stream(stream: ASE.DataStream) -> void:
	var packets = _build_old_palette_packets(6)
	stream.put_WORD(packets.size())
	for packet in packets:
		stream.put_BYTE(packet.skip)
		stream.put_BYTE(packet.count)
		for color in packet.colors:
			stream.put_BYTE(int(color.r8 / 4))
			stream.put_BYTE(int(color.g8 / 4))
			stream.put_BYTE(int(color.b8 / 4))

func _serialize_new_palette_to_stream(stream: ASE.DataStream) -> void:
	#ASE.Log.debug("Serializing palette: colors.size=", colors.size(), " _original_from=", _original_from, " _original_to=", _original_to)
	stream.put_DWORD(colors.size())
	stream.put_DWORD(_original_from)
	var end_index = _original_to if _original_to >= 0 else colors.size() - 1
	stream.put_DWORD(end_index)
	stream.pad_BYTES(8)
	
	
	var start = _original_from
	var end = end_index
	
	for i in range(start, end + 1):
		if i >= colors.size():
			break
			
		var has_name = i < color_names.size() and not color_names[i].is_empty()
		
		if has_name:
			stream.put_WORD(1)
		else:
			stream.put_WORD(0)
		
		var c = colors[i]
		stream.put_BYTE(c.r8)
		stream.put_BYTE(c.g8)
		stream.put_BYTE(c.b8)
		stream.put_BYTE(c.a8)
		
		if has_name:
			stream.put_STRING(color_names[i])

func _build_old_palette_packets(bits: int) -> Array:
	# group consecutive colors into packets (max 256 per packet)
	var packets = []
	var i = 0
	while i < colors.size():
		var skip = 0
		# Find runs of empty/black? Actually skip is relative to last packet
		# WTF did i mean by this??
		var packet_colors = []
		var count = 0
		while count < 256 and i + count < colors.size():
			packet_colors.append(colors[i + count])
			count += 1
		packets.append({
			"skip": 0,  # in old format, skip is relative to last position
			"count": count,
			"colors": packet_colors
		})
		i += count
	return packets
