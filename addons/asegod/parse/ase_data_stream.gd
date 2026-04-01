extends StreamPeerBuffer
## Base class for Bytecrawlers that deal with Aseprite-related files.
##
## Contains helper-functions to better visualize adherence to the specs
## https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md

var error: Error = OK
var palette: PackedColorArray

func _init() -> void:
	# Big Endian is false by default, this is only for explicity's sake
	big_endian = false

func get_remaining_bytes() -> int:
	return get_size() - get_position()

#region Stream Operators
# wrappers to match terminology from ase specification, 
# CAPITALIZED, both to communicate that we're grabbing the ase version of this 
# variable, as according to spec, but return a Godot-native conversion of it.

## > `BYTE`: An 8-bit unsigned integer value
func get_BYTE() -> int:
	return get_u8()

func put_BYTE(value: int) -> void:
	value = clampi(value, 0, 0xFF)
	put_u8(value)

## > `WORD`: A 16-bit unsigned integer value
func get_WORD() -> int:
	return get_u16()

func put_WORD(value: int) -> void:
	value = clampi(value, 0, 0xFFFF)
	put_u16(value)

## > `SHORT`: A 16-bit signed integer value
func get_SHORT() -> int:
	return get_16()

func put_SHORT(value: int) -> void:
	value = clampi(value, -0xFF, 0xFF)
	put_16(value)

## > `DWORD`: A 32-bit unsigned integer value
func get_DWORD() -> int:
	return get_u32()

func put_DWORD(value: int) -> void:
	value = clampi(value, 0, 0xFFFF_FFFF)
	put_u32(value)

## > `LONG`: A 32-bit signed integer value
func get_LONG() -> int:
	return get_32()

func put_LONG(value: int) -> void:
	value = clampi(value, -0xFFFF, 0xFFFF)
	put_32(value)

## > `FIXED`: A 32-bit fixed point (16.16) value
func get_FIXED() -> float:
	var fixed = get_LONG()
	var whole = fixed >> 16
	var frac = fixed & 0xFFFF
	return whole + (frac / 65536.0)

func put_FIXED(value: float) -> void:
	var whole = int(value)
	var frac = int((value - whole) * 65536.0)
	var fixed = (whole << 16) | (frac & 0xFFFF)
	put_LONG(fixed)

# > `FLOAT`: A 32-bit single-precision value
# > `DOUBLE`: A 64-bit double-precision value
# get_float() and get_double(), as well as get_half() already exist in the parent class. and work the same as expected in the spec.

#`QWORD`: A 64-bit unsigned integer value
func get_QWORD() -> int:
	return get_u64()

func put_QWORD(value: int) -> void:
	put_u64(value)

#`LONG64`: A 64-bit signed integer value
func get_LONG64() -> int:
	return get_64()

func put_LONG64(value: int) -> void:
	put_64(value)

#`BYTE[n]`: "n" bytes.
func get_BYTES(n: int) -> PackedByteArray:
	var status = get_data(n)
	if status[0] != OK:
		error = status[0]
		return PackedByteArray()
	return status[1]

func put_BYTES(bytes: PackedByteArray) -> void:
	put_data(bytes)

func pad_BYTES(n: int, value: int = 0) -> void:
	for i in n:
		put_BYTE(value)

#`STRING`:
  #- `WORD`: string length (number of bytes)
  #- `BYTE[length]`: characters (in UTF-8)
  #The `'\0'` character is not included.
func get_STRING() -> String:
	var length = get_WORD()
	
	var bytes = get_BYTES(length)
	var s : String = bytes.get_string_from_utf8()
	
	return s

func put_STRING(value: String) -> void:
	var bytes = value.to_utf8_buffer()
	# The spec requires WORD for string length
	if bytes.size() > 0xFFFF:
		push_error("String too long for ASE format: ", bytes.size(), " bytes")
		bytes = bytes.slice(0, 0xFFFF)
	put_WORD(bytes.size())
	put_BYTES(bytes)

#`POINT`:
  #- `LONG`: X coordinate value
  #- `LONG`: Y coordinate value

func get_POINT() -> Vector2i: 
	return Vector2i(get_LONG(), get_LONG())

#* `SIZE`:
  #- `LONG`: Width value
  #- `LONG`: Height value
func get_SIZE() -> Vector2i:
	#WARNING: this method is technically redundant and only here for the sake of context
	return get_POINT()

func put_VEC2I(value: Vector2i) -> void:
	put_LONG(value.x)
	put_LONG(value.y)

#`RECT`:
  #- `POINT`: Origin coordinates
  #- `SIZE`: Rectangle size
func get_RECT() -> Rect2i:
	return Rect2i(get_POINT(), get_SIZE())

func put_RECT2I(value: Rect2i) -> void:
	put_LONG(value.position.x)
	put_LONG(value.position.y)
	put_LONG(value.size.x)
	put_LONG(value.size.y)

#`PIXEL`: One pixel, depending on the image pixel format:
  #- **RGBA**: `BYTE[4]`, each pixel have 4 bytes in this order Red, Green, Blue, Alpha.
  #- **Grayscale**: `BYTE[2]`, each pixel have 2 bytes in the order Value, Alpha.
  #- **Indexed**: `BYTE`, each pixel uses 1 byte (the index).
func get_PIXEL(format: ASE.File.ColorDepth = ASE.File.ColorDepth.RGBA) -> Color:
	match format:
		ASE.File.ColorDepth.INDEXED:
			var index: int = get_BYTE()
			if palette.is_empty():
				push_error("No palette loaded for indexed image")
				return Color.TRANSPARENT
			if index >= palette.size():
				push_error("Index %d out of bounds (max %d)" % [index, palette.size() - 1])
				return Color.TRANSPARENT
			return palette[index]
		ASE.File.ColorDepth.GRAYSCALE:
			var value = get_BYTE()
			var alpha = get_BYTE()
			return Color8(value, value, value, alpha)
		_:  # RGBA
			return Color8(get_BYTE(), get_BYTE(), get_BYTE(), get_BYTE())

func put_PIXEL(value: Color, format: ASE.File.ColorDepth = ASE.File.ColorDepth.RGBA) -> void:
	match format:
		ASE.File.ColorDepth.GRAYSCALE: #Grayscale (1 BYTE  Value, 1 BYTE Alpha)
			var gray_value = (value.r8 + value.g8 + value.b8) / 3
			put_BYTE(gray_value)
			put_BYTE(value.a8)
		ASE.File.ColorDepth.INDEXED: #Indexed (1 BYTE for index)
			var idx: int = palette.find(value)
			put_BYTE(idx)
		_:
			if format != ASE.File.ColorDepth.RGBA:
				error = ERR_INVALID_PARAMETER
				push_error("Unknown image pixel format of '%s' Bytes size, using default..." % format)
			put_BYTE(value.r8)
			put_BYTE(value.g8)
			put_BYTE(value.b8)
			put_BYTE(value.a8)
		
	

#`TILE`: **Tilemaps**: Each tile can be a 8-bit (`BYTE`), 16-bit
  #(`WORD`), or 32-bit (`DWORD`) value and there are masks related to
  #the meaning of each bit.
func get_TILE(format: ASE.File.TileFormat = ASE.File.TileFormat.BYTE) -> int:
	match format:
		ASE.File.TileFormat.BYTE:
			return get_BYTE()
		ASE.File.TileFormat.WORD:
			return get_WORD()
		ASE.File.TileFormat.DWORD:
			return get_DWORD()
		_:
			push_error("Unknown TileFormat: '%s', using default instead..." % format)
			return get_TILE()

func put_TILE(value: int, format: ASE.File.TileFormat = ASE.File.TileFormat.BYTE) -> void:
	match format:
		ASE.File.TileFormat.BYTE:
			put_BYTE(value)
		ASE.File.TileFormat.WORD:
			put_WORD(value)
		ASE.File.TileFormat.DWORD:
			put_DWORD(value)
		_:
			push_error("Unknown TileFormat: '%s', using default instead..." % format)
			put_TILE(value)


func get_UUID() -> StringName:
	var bytes = get_BYTES(16)
	var hex = ""
	for b in bytes:
		hex += "%02x" % b
	var uuid_str = "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12)
	]
	return StringName(uuid_str)


func put_UUID(uuid: StringName) -> void:
	var hex = str(uuid).replace("-", "")
	var bytes = PackedByteArray()
	for i in range(0, 32, 2):
		bytes.append(hex.substr(i, 2).hex_to_int())
	put_BYTES(bytes)
#endregion
