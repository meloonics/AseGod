#@tool
extends ASE.DataStream

#TODO: blow this class up into tiny little bits of responsibility,
# works for now, though

signal load_progress(current_frame: int, total_frames: int)
signal load_completed(result: ASE.File)
signal load_error(error_msg: String)

var _current_source_path: String
var cancel_loading: bool = false
var logger_level: ASE.Log.Level = ASE.Log.Level.WARNING

func set_log_level(level: ASE.Log.Level) -> void:
	logger_level = level
	ASE.Log.set_level(level)

func _init(path: String = "") -> void:
	super()
	if not path.is_empty():
		_validate_path(path)
		if error == OK:
			load_ase(path)

func load_ase(path: String) -> Dictionary[Error, ASE.File]:
	if path.is_relative_path() or path.is_absolute_path():
		var data: PackedByteArray = _safe_read_file(path)
		if data.is_empty():
			return {ERR_FILE_CANT_OPEN: ASE.File.INVALID}
		set_data_array(data)
		_current_source_path = path
		return {error: parse()}
	return {ERR_FILE_BAD_PATH: ASE.File.INVALID}

func parse() -> ASE.File:
	var ase: ASE.File = _parse_file_header()
	ase.source_path = _current_source_path
	if ase.error != OK:
		return _handle_parse_error(ase, "Failed to parse file header")
	
	_record_frame_offsets(ase)
	
	ase.set_meta("source_path", _current_source_path)
	var tileset_registry = {}
	ase.set_meta("tileset_registry", tileset_registry)
	
	if ase.n_frames > 10000:
		ASE.Log.warning("File has %d frames, may cause memory issues" % ase.n_frames)
	
	_parse_frames(ase, tileset_registry)
	_resolve_tilemap_cels(ase, tileset_registry)
	
	return ase

func parse_chunk_from_data(data: PackedByteArray, chunk_type: int, ase_flags: int = 0, color_depth: int = 4) -> ASE.Chunk:
	match chunk_type:
		ASE.Chunk.ChunkType.LAYER:
			return ASE.Layer.new(data, ase_flags)
		ASE.Chunk.ChunkType.CEL:
			return ASE.Cel.new(data, color_depth)
		ASE.Chunk.ChunkType.PALETTE:
			return ASE.Palette.new(data)
		_:
			return ASE.MissingNo.new(data)

func _safe_read_file(path: String) -> PackedByteArray:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		ASE.Log.error("Failed to open file: " + path)
		return PackedByteArray()
	var data = file.get_buffer(file.get_length())
	file.close()
	return data

func _validate_path(path: String) -> void:
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		error = ERR_FILE_NOT_FOUND
		ASE.Log.error("File not found: " + path)

func _handle_parse_error(ase: ASE.File, msg: String) -> ASE.File:
	ASE.Log.error(msg)
	ase.error = ERR_PARSE_ERROR
	return ase

func _parse_file_header() -> ASE.File:
	if get_size() < ASE.File.HEADER_SIZE_BYTES:
		return _create_error_ase("File too small to be a valid Aseprite file")
	
	var file_size = get_DWORD()
	if file_size != get_size():
		ASE.Log.warning("File size mismatch: header says %d, actual %d" % [file_size, get_size()])
	
	var magic = get_WORD()
	if magic != ASE.File.MAGIC_NUMBER:
		return _create_error_ase("Invalid magic number: expected 0xA5E0, got 0x%X" % magic)
	
	var ase = ASE.File.new(
		file_size,
		magic,
		get_WORD(),
		Vector2i(get_WORD(), get_WORD()),
		get_WORD(),
		get_DWORD(),
		get_WORD(),
		get_QWORD(),
		get_DWORD() & 0xFF,
		get_WORD(),
		Vector2i(get_BYTE(), get_BYTE()),
		Rect2i(get_SHORT(), get_SHORT(), get_WORD(), get_WORD())
	)
	
	if ase.sprite_size.x <= 0 or ase.sprite_size.y <= 0:
		ASE.Log.error("Invalid sprite size: " + str(ase.sprite_size))
		ase.error = ERR_INVALID_DATA
	
	if not _validate_zeroes(84):
		ASE.Log.verbose("Expected 84 reserved zeroed bytes at position %d" % get_position())
	
	return ase

func _create_error_ase(error_msg: String) -> ASE.File:
	var ase = ASE.File.new(0, 0, 0, Vector2i.ZERO, ASE.File.ColorDepth.RGBA, 0, 0, 0, 0, 0, Vector2i.ONE, Rect2i())
	ase.error = ERR_PARSE_ERROR
	ase._log("[ERROR] %s" % error_msg)
	return ase

func _parse_frames(ase: ASE.File, tileset_registry: Dictionary) -> void:
	for frame_idx in ase.n_frames:
		if cancel_loading:
			ASE.Log.warning("Loading cancelled at frame %d" % frame_idx)
			break
		
		emit_signal("load_progress", frame_idx, ase.n_frames)
		var frame = _get_FRAME(ase, tileset_registry)
		if frame.duration_ms <= 0:
			frame.duration_ms = ase._d_speed
		ase.frames.append(frame)
	
	emit_signal("load_progress", ase.n_frames, ase.n_frames)

func _get_FRAME(ase: ASE.File, tileset_registry: Dictionary) -> ASE.Frame:
	var frame_start = get_position()
	ASE.Log.debug("Parsing frame at 0x%X" % frame_start)
	
	var frame_size = get_DWORD()
	var magic = get_WORD()
	var chunks_old = get_WORD()
	var duration = get_WORD()
	var zero = get_WORD()
	var chunks_new = get_DWORD()
	
	var frame = ASE.Frame.new(frame_size, magic, chunks_old, duration, zero, chunks_new)
	frame._original_new_chunk_count = chunks_new
	frame._uses_extended_format = chunks_old == 0xFFFF
	
	var chunks = []
	var last_cel: AseCel = null
	var last_chunk: ASE.Chunk = null
	var last_tags: AseTags = null
	var last_tileset: ASE.TileSetChunk = null
	var layer_count: int = 0
	var current_external_files: AseExternalFiles = null
	
	var pending_tag_user_data: Array[AseUserData] = []
	var pending_tile_user_data: Array[AseUserData] = []
	
	for chunk_idx in frame.n_chunks:
		var chunk: ASE.Chunk = _get_CHUNK(ase)
		if chunk == null:
			ASE.Log.warning("Failed to parse chunk at index %d" % chunk_idx)
			continue
		
		chunks.append(chunk)
		_handle_chunk(chunk, ase, last_cel, last_chunk, last_tags, last_tileset,
			layer_count, pending_tag_user_data, pending_tile_user_data,
			current_external_files, tileset_registry)
		
		# update references for next iteration
		if chunk is AseCel:
			last_cel = chunk
		if chunk is AseTags:
			last_tags = chunk
		if chunk is ASE.TileSetChunk:
			last_tileset = chunk
		if chunk is ASE.ExternalFiles:
			current_external_files = chunk
		if chunk is ASE.Chunk and chunk.error == OK and not (chunk is ASE.UserData):
			last_chunk = chunk
	
	_attach_pending_user_data(last_tileset, pending_tile_user_data)
	frame.set_chunks(chunks)
	return frame

func _handle_chunk(chunk: ASE.Chunk, ase: ASE.File, last_cel: AseCel, last_chunk: ASE.Chunk,
	last_tags: ASE.FileTags, last_tileset: ASE.Tileset, layer_count: int,
	pending_tag_user_data: Array, pending_tile_user_data: Array,
	current_external_files: AseExternalFiles, tileset_registry: Dictionary) -> void:
	
	match chunk.chunk_type:
		ASE.Chunk.ChunkType.LAYER:
			var layer = chunk as ASE.Layer
			if layer.error == OK:
				layer.set_index(layer_count)
				ase.add_layer(layer, layer_count)
			else:
				ASE.Log.warning("Layer chunk error: %d" % layer.error)
		
		ASE.Chunk.ChunkType.CEL_EXTRA:
			if last_cel and last_cel.error == OK:
				last_cel.extra_data = chunk
		
		ASE.Chunk.ChunkType.TILESET:
			var tileset = chunk as ASE.TileSetChunk
			if tileset.error == OK:
				tileset_registry[tileset.tileset_id] = tileset
				if tileset.is_external and current_external_files:
					var base_path = ase.get_meta("source_path", "")
					tileset.resolve_external_tileset(current_external_files, base_path)
			else:
				ASE.Log.warning("Tileset chunk error: %d" % tileset.error)
		
		ASE.Chunk.ChunkType.CEL:
			var cel = chunk as AseCel
			if cel.cel_type == AseCel.CelType.COMPRESSED_TILEMAP and last_tileset and last_tileset.error == OK:
				cel.set_tileset(last_tileset)
		
		ASE.Chunk.ChunkType.USER_DATA:
			if last_tags:
				pending_tag_user_data.append(chunk)
			elif last_tileset:
				if last_tileset.user_data == null:
					last_tileset.user_data = chunk
				else:
					last_tileset.add_tile_user_data(pending_tile_user_data.size(), chunk)
					pending_tile_user_data.append(chunk)
			elif last_chunk and last_chunk.error == OK:
				last_chunk.user_data = chunk
		
		ASE.Chunk.ChunkType.EXTERNAL_FILES:
			ase.set_meta("external_files", chunk)
		
		ASE.Chunk.ChunkType.TAGS:
			var tags = chunk as AseTags
			for i in range(min(tags.tags.size(), pending_tag_user_data.size())):
				tags.tags[i].user_data = pending_tag_user_data[i]
			pending_tag_user_data.clear()

func _attach_pending_user_data(last_tileset: ASE.TileSet, pending_tile_user_data: Array) -> void:
	if not last_tileset or pending_tile_user_data.is_empty():
		return
	
	ASE.Log.debug("Attaching %d pending user data entries to tileset" % pending_tile_user_data.size())
	
	if pending_tile_user_data.size() > 0 and last_tileset.user_data == null:
		last_tileset.user_data = pending_tile_user_data[0]
	
	for i in range(1, pending_tile_user_data.size()):
		var tile_idx = i - 1
		if tile_idx < last_tileset.num_tiles:
			last_tileset.add_tile_user_data(tile_idx, pending_tile_user_data[i])

func _get_CHUNK(ase: ASE.File) -> ASE.Chunk:
	if get_position() >= get_size():
		ASE.Log.error("Unexpected end of file while reading chunk")
		return null
	
	var pos = get_position()
	
	if get_size() - pos < 6:
		ASE.Log.error("Not enough data for chunk header")
		return null
	
	var chunk_size = get_DWORD()
	var chunk_type: ASE.Chunk.ChunkType = get_WORD()
	
	if chunk_size < 6 or chunk_size > get_size() - pos:
		ASE.Log.warning("Invalid chunk size: %d at position %d" % [chunk_size, pos])
		seek(pos + 6)
		return null
	
	seek(pos)
	var chunk_data: PackedByteArray = get_BYTES(chunk_size)
	var chunk: ASE.Chunk = null
	
	match chunk_type:
		ASE.Chunk.ChunkType.OLD_PALETTE_1, ASE.Chunk.ChunkType.OLD_PALETTE_2, ASE.Chunk.ChunkType.PALETTE:
			chunk = AsePalette.new(chunk_data)
			if chunk.error == OK and chunk is AsePalette:
				self.palette = (chunk as AsePalette).colors
		
		ASE.Chunk.ChunkType.LAYER:
			chunk = ASE.Layer.new(chunk_data, ase.flags)
		
		ASE.Chunk.ChunkType.CEL:
			chunk = AseCel.new(chunk_data, ase.color_depth)
		
		ASE.Chunk.ChunkType.CEL_EXTRA:
			chunk = ACE.CelExtra.new(chunk_data)
		
		ASE.Chunk.ChunkType.COLOR_PROFILE:
			chunk = AseColorProfile.new(chunk_data)
		
		ASE.Chunk.ChunkType.EXTERNAL_FILES:
			chunk = AseExternalFiles.new(chunk_data)
		
		ASE.Chunk.ChunkType.TAGS:
			chunk = AseTags.new(chunk_data)
		
		ASE.Chunk.ChunkType.SLICE:
			chunk = AseSlice.new(chunk_data)
		
		ASE.Chunk.ChunkType.TILESET:
			chunk = ASE.TileSetChunk.new(chunk_data)
		
		ASE.Chunk.ChunkType.USER_DATA:
			chunk = AseUserData.new(chunk_data)
		_:
			ASE.Log.verbose("Unknown chunk type: 0x%X at position %d" % [chunk_type, pos])
			chunk = AseMissingNo.new(chunk_data)
	
	if chunk:
		chunk._chunk_data_size = chunk_size
		chunk.parse()
	
	seek(pos + chunk_size)
	return chunk

func _validate_zeroes(n_bytes: int) -> bool:
	if get_position() + n_bytes > get_size():
		return false
	
	var segment = get_BYTES(n_bytes)
	return segment.count(0) == n_bytes

func _record_frame_offsets(ase: ASE.File) -> void:
	var original_pos = get_position()
	ase._frame_offsets = PackedInt64Array()
	
	for i in ase.n_frames:
		ase._frame_offsets.append(get_position())
		var frame_size = get_DWORD()
		seek(get_position() + frame_size - 4)
	
	seek(original_pos)

func _resolve_tilemap_cels(ase: ASE.File, tileset_registry: Dictionary) -> void:
	
	for frame in ase.frames:
		for chunk in frame.chunks:
			
			if chunk is AseCel and chunk.cel_type == AseCel.CelType.COMPRESSED_TILEMAP:
				var cel = chunk as AseCel
				
				if not cel.tileset:
					var layer = ase.layers_by_index.get(cel.layer_index)
					
					if layer and layer.tileset_index >= 0:
						var tileset = tileset_registry.get(layer.tileset_index)
						
						if tileset and tileset.is_external:
							var external_files = ase.get_meta("external_files", null)
							
							if external_files:
								var base_path = ase.get_meta("source_path", "")
								tileset.resolve_external_tileset(external_files, base_path)
						
						cel.tileset = tileset
