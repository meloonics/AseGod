@tool
extends Resource
class_name AseExportTicket

## Resource to store the export information for .ase(prite) files.
## Extend this class to create powerful custom logic for turning 
## Aseprite Data into Godot-Resources. 
## You usually find these attached in the metadata of Godot-Objects 
## that were generated from an AseFile resource.
## If this behavior is undesired, you can turn the default behavior
## to 'false' by calling set_attach_as_metadata_default() 
## somewhere during your project's initialization.

static var attach_as_meta_default: bool = true: set = set_attach_as_metadata_default
var attach_as_meta_object: bool = true

enum ExportType {
	FILE_ASE,
	FILE_PNG,
	FILE_JSON,
	
	RES_TEXTURE,
	RES_TEXTUREARRAY,
	RES_SPRITEFRAMES,
	RES_ANIMATION,
	RES_ANIMATIONLIBRARY,
	RES_TILESET,
	RES_ASE,
	
	SCN_SPRITE2D,
	SCN_TEXTURERECT,
	SCN_NINEPATCHRECT,
	SCN_TILEMAPLAYER,
	SCN_ANIMATEDSPRITE2D,
}

@export_custom(PROPERTY_HINT_FILE_PATH, "*.ase, *.aseprite") var source_path: String = ""
@export var export_type: ExportType = ExportType.RES_TEXTURE

@export var incl_layers: PackedInt32Array = []
@export var incl_frames: PackedInt32Array = []
@export var incl_tags: PackedStringArray = []
@export var incl_tileset_id: int = -1

@export var merge_layers: bool = false
@export var pivot_normalized: Vector2 = Vector2(0.5, 0.5)
@export var scale_factor: float = 1.0
@export_custom(PROPERTY_HINT_FILE_PATH, "*.tres, *.png, *.tscn") var output_path: String = ""

func _init(of_export_type: ExportType = ExportType.RES_TEXTURE) -> void:
	export_type = of_export_type

func include_layer(index: int) -> void:
	if not incl_layers.has(index):
		incl_layers.append(index)

func exclude_layer(index: int) -> void:
	var idx = incl_layers.find(index)
	if idx != -1:
		incl_layers.remove_at(idx)

func include_layers(indices: Array[int]) -> void:
	for i in indices:
		include_layer(i)

func clear_layers() -> void:
	incl_layers.clear()

func include_frame(index: int) -> void:
	if not incl_frames.has(index):
		incl_frames.append(index)

func exclude_frame(index: int) -> void:
	var idx = incl_frames.find(index)
	if idx != -1:
		incl_frames.remove_at(idx)

func include_frames(indices: Array[int]) -> void:
	for i in indices:
		include_frame(i)

func clear_frames() -> void:
	incl_frames.clear()

func include_tag(name: String) -> void:
	if not incl_tags.has(name):
		incl_tags.append(name)

func exclude_tag(name: String) -> void:
	var idx = incl_tags.find(name)
	if idx != -1:
		incl_tags.remove_at(idx)

func include_tags(names: Array[String]) -> void:
	for n in names:
		include_tag(n)

func clear_tags() -> void:
	incl_tags.clear()

func set_tileset_id(id: int) -> void:
	incl_tileset_id = id

func clear_tileset() -> void:
	incl_tileset_id = -1

func to_dict() -> Dictionary:
	return {
		"source_path": source_path,
		"export_type": export_type,
		"layers": incl_layers.duplicate(),
		"frames": incl_frames.duplicate(),
		"tags": incl_tags.duplicate(),
		"tileset_id": incl_tileset_id, 
		"merge_layers": merge_layers,
		"pivot": pivot_normalized, 
		"scale_factor": scale_factor,
		"output_path": output_path
	}

static func from_dict(data: Dictionary) -> AseExportTicket:
	var ticket = AseExportTicket.new()
	
	ticket.source_path = data.get("source_path", "")
	ticket.export_type = data.get("export_type", ExportType.RES_TEXTURE)
	ticket.incl_layers = data.get("layers", PackedInt32Array())
	ticket.incl_frames = data.get("frames", PackedInt32Array())
	ticket.incl_tags = data.get("tags", PackedStringArray())
	ticket.incl_tileset_id = data.get("tileset_id", -1)
	ticket.merge_layers = data.get("merge_layers", false)
	ticket.pivot_normalized = data.get("pivot", Vector2(0.5, 0.5))
	ticket.scale_factor = data.get("scale_factor", 1.0)
	ticket.output_path = data.get("output_path", "")
	
	return ticket

func should_attach_as_meta() -> bool:
	return attach_as_meta_default and attach_as_meta_object

static func set_attach_as_metadata_default(value: bool) -> void:
	attach_as_meta_default = value
