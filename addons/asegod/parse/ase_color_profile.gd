extends AseChunk
class_name AseColorProfile

enum ProfileType {
	NONE = 0,
	SRGB = 1,
	ICC = 2
}

enum ProfileFlags {
	USE_FIXED_GAMMA = 1
}

@export var profile_type: ProfileType = ProfileType.NONE
@export var flags: int = 0
@export var fixed_gamma: float = 1.0
@export var icc_data: PackedByteArray = []

func apply_color_profile(color: Color) -> Color:
	#TODO implement this maybe
	return color

func _init(p_data: PackedByteArray = PackedByteArray()) -> void:
	super(p_data, ChunkType.COLOR_PROFILE)

func _parse_chunk() -> Error:
	profile_type = _stream.get_WORD()
	flags = _stream.get_WORD()
	
	if flags & 1:
		fixed_gamma = _stream.get_FIXED()
	else:
		var gamma = _stream.get_FIXED()
		fixed_gamma = gamma
	
	_stream.get_BYTES(8)
	
	if profile_type == ProfileType.ICC:
		var icc_size = _stream.get_DWORD()
		icc_data = _stream.get_BYTES(icc_size)
	
	return OK

func _serialize_chunk() -> Dictionary[Error, PackedByteArray]:
	if error != OK:
		return {error: PackedByteArray()}
	
	var stream = AseDataStream.new()
	var data = PackedByteArray()
	stream.data_array = data
	
	stream.put_DWORD(0)
	stream.put_WORD(ChunkType.COLOR_PROFILE)
	
	stream.put_WORD(profile_type)
	stream.put_WORD(flags)
	stream.put_FIXED(fixed_gamma)
	stream.pad_BYTES(8)
	
	if profile_type == ProfileType.ICC:
		stream.put_DWORD(icc_data.size())
		stream.put_BYTES(icc_data)
	
	var total_size = stream.get_position()
	stream.seek(0)
	stream.put_DWORD(total_size)
	
	return {OK: stream.get_data_array()}
