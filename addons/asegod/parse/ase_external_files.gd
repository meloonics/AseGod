extends ASE.Chunk

# TODO: Test this
class ExternalFile:
	var entry_id: int
	var type: int
	var filename: String
	
	func _init(p_id: int, p_type: int, p_name: String) -> void:
		entry_id = p_id
		type = p_type
		filename = p_name

var files: Array[ExternalFile] = []

func _init(p_data: PackedByteArray = PackedByteArray()) -> void:
	super(p_data, ChunkType.EXTERNAL_FILES)

func _parse_chunk() -> Error:
	var n_entries = _stream.get_DWORD()
	_stream.get_BYTES(8)
	
	ASE.Log.debug("Parsing %d external files" % n_entries)
	
	for i in n_entries:
		var entry_id = _stream.get_DWORD()
		var type = _stream.get_BYTE()
		_stream.get_BYTES(7)
		var filename = _stream.get_STRING()
		files.append(ExternalFile.new(entry_id, type, filename))
	
	return OK

func _serialize_chunk() -> Dictionary[Error, PackedByteArray]:
	if error != OK:
		return {error: PackedByteArray()}
	
	var stream = ASE.DataStream.new()
	_data.clear()
	stream.data_array = _data
	stream.put_DWORD(0)
	stream.put_WORD(ChunkType.EXTERNAL_FILES)
	
	stream.put_DWORD(files.size())
	stream.pad_BYTES(8)
	
	for file in files:
		stream.put_DWORD(file.entry_id)
		stream.put_BYTE(file.type)
		stream.pad_BYTES(7)
		stream.put_STRING(file.filename)
	
	var total_size = stream.get_position()
	stream.seek(0)
	stream.put_DWORD(total_size)
	
	return {OK: stream.get_data_array()}
