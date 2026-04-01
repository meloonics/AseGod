extends RefCounted

const A = ASE.File.MAGIC_NUMBER
enum {
	ERR_NO_VALID_FRAMES = A,
	ERR_SHIDDED_MY_PANT = A+1,
}

var _ase: ASE.File = null :
	set(value):
		if value:
			_ase = value
			_status = _ase.error
		else:
			_status = ERR_DOES_NOT_EXIST
var _tkt: ASE.ExportTicket = null
var _status: Error = ERR_DOES_NOT_EXIST

#region Constructors
func _init(from_asefile: ASE.File = null, with_ticket: ASE.ExportTicket = null) -> void:
	_ase = from_asefile
	if _ase:
		if with_ticket:
			_tkt = with_ticket
		else:
			_tkt = ASE.ExportTicket.new()
	else:
		_ase = create_minimal_asefile()
		if with_ticket:
			_tkt = with_ticket
		else:
			_tkt = ASE.ExportTicket.new(ASE.ExportTicket.ExportType.FILE_ASE)
		
		if not _tkt.source_path.is_empty():
			_load_ase(_tkt.source_path)

func _load_ase(path: String) -> void:
	if FileAccess.file_exists(path):
		_ase = load(path) as ASE.File
	else:
		_status = ERR_FILE_NOT_FOUND
		push_error("AseGod: Source file not found: ", path)


static func from_ticket(ticket: ASE.ExportTicket) -> ASE.God:
	return ASE.God.new(null, ticket)

static func from_dict(dict: Dictionary) -> ASE.God:
	return from_ticket(ASE.ExportTicket.from_dict(dict))

static func from_path(path: String, export_type: ASE.ExportTicket.ExportType = ASE.ExportTicket.ExportType.RES_TEXTURE) -> ASE.God:
	var tkt: ASE.ExportTicket = ASE.ExportTicket.new(export_type)
	tkt.source_path = path
	return from_ticket(tkt)

static func from_resource(res: Resource) -> ASE.God:
	var meta = res.get_meta("asegod", {}) as Dictionary
	if meta.is_empty():
		push_error("AseGod: Given resource at '%s' has no asegod metadata attached." %res.resource_path)
		return null
	return from_dict(meta)
#endregion

static func create_minimal_asefile(
	p_sprite_size: Vector2i = Vector2i(100, 100), 
	p_color_depth: ASE.File.ColorDepth = ASE.File.ColorDepth.RGBA
	) -> ASE.File:
	
	var ase = ASE.File.new()
	
	# Override the defaults with actual data
	ase.sprite_size = p_sprite_size
	ase.color_depth = p_color_depth
	ase.flags = ASE.File.HeaderFlags.OPACITY_VALID
	
	# Add frame
	var frame = ASE.Frame.new()
	frame.duration_ms = 100
	ase.frames.append(frame)
	
	# Add layer
	var layer = ASE.Layer.new()
	layer.layer_name = "Layer 1"
	layer.layer_type = ASE.Layer.LayerType.NORMAL
	layer.opacity = 255
	layer.flags = ASE.Layer.LayerFlags.VISIBLE
	layer.layer_index = 0
	ase.add_layer(layer, 0)
	
	# Add empty cel
	var cel = ASE.Cel.new()
	cel.layer_index = 0
	cel.x = 0
	cel.y = 0
	cel.width = 64
	cel.height = 64
	cel.cel_type = ASE.Cel.CelType.COMPRESSED_IMAGE
	
	var empty_pixels = PackedByteArray()
	empty_pixels.resize(p_sprite_size.x * p_sprite_size.y * (p_color_depth / 8))
	empty_pixels.fill(0)
	cel.pixels = empty_pixels
	
	frame.chunks.append(cel)
	
	return ase

func clear() -> ASE.God:
	_ase = create_minimal_asefile()
	_tkt = ASE.ExportTicket.new(ASE.ExportTicket.ExportType.FILE_ASE)
	return self

func sprite_size(width: int, height: int = 0) -> ASE.God:
	#TODO: Guard function, that pushes warnings and checks for errors and shit
	_ase.sprite_size = Vector2i(maxi(1, width), maxi(1, height))
	
	return self

func color_depth(depth: ASE.File.ColorDepth = ASE.File.ColorDepth.RGBA) -> ASE.God:
	_ase.color_depth = depth
	return self

func add_layer(name: String = "", layer_type: ASE.Layer.LayerType = ASE.Layer.LayerType.NORMAL, opacity: int = 255) -> ASE.God:
	
	var layer = ASE.Layer.new()
	layer.layer_name = name
	layer.layer_type = layer_type
	layer.opacity = opacity
	layer.layer_index = _ase.layers_by_index.size()
	_ase.add_layer(layer, layer.layer_index)
	return self

func add_frame(duration_ms: int = 100) -> ASE.God:
	var frame = ASE.Frame.new()
	frame.duration_ms = duration_ms
	_ase.frames.append(frame)
	return self

func add_cel(frame_idx: int, layer_idx: int, x: int = 0, y: int = 0) -> ASE.God:
	var cel = ASE.Cel.new()
	cel.layer_index = layer_idx
	cel.x = x
	cel.y = y
	cel.cel_type = ASE.Cel.CelType.COMPRESSED_IMAGE
	
	if frame_idx < _ase.frames.size():
		_ase.frames[frame_idx].chunks.append(cel)
	return self

func add_tag(name: String, from_frame: int, to_frame: int, color: Color = Color.RED) -> ASE.God:
	var tags_chunk: ASE.TagsChunk = null
	
	for frame in _ase.frames:
		for chunk in frame.chunks:
			if chunk is ASE.TagsChunk:
				tags_chunk = chunk
				break
	
	if not tags_chunk:
		tags_chunk = ASE.TagsChunk.new()
		if _ase.frames.size() > 0:
			_ase.frames[0].chunks.append(tags_chunk)
	
	var tag = ASE.Tag.new(from_frame, to_frame, 0, 0, name, color)
	tags_chunk.tags.append(tag)
	return self

func add_tileset(name: String, tile_width: int, tile_height: int, num_tiles: int) -> ASE.God:
	var tileset = ASE.TileSetChunk.new()
	tileset.name = name
	tileset.tile_width = tile_width
	tileset.tile_height = tile_height
	tileset.num_tiles = num_tiles
	tileset.tileset_id = _get_next_tileset_id()
	
	if _ase.frames.size() > 0:
		_ase.frames[0].chunks.append(tileset)
	
	return self

func save_ase(path: String) -> Error:
	var data = _ase.serialize_to_ase()
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return ERR_CANT_CREATE
	
	file.store_buffer(data)
	return OK

func _get_next_tileset_id() -> int:
	var max_id = -1
	for frame in _ase.frames:
		for chunk in frame.chunks:
			if chunk is ASE.TileSetChunk:
				max_id = max(max_id, chunk.tileset_id)
	return max_id + 1
