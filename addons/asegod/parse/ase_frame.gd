extends AseElement
class_name AseFrame

const MAGIC_NUMBER = 0xF1FA

@export_custom(AseFile._H, "", AseFile._U) var valid: bool
@export_custom(AseFile._H, "", AseFile._U) var n_chunks: int = 0
@export_custom(AseFile._H, "", AseFile._U) var n_bytes: int = 0
@export var chunks: Array[AseChunk]
@export_range(1, 1000, 1, "or_greater") var duration_ms: int
@export_storage var _original_new_chunk_count: int = 0
@export_storage var _uses_extended_format: bool = false

func _init(
	p_bytes: int = 0,
	p_magic: int = MAGIC_NUMBER,
	p_chunks_old: int = 0,
	p_duration_ms: int = 100,
	_p_zero: int = 0,
	p_chunks_new: int = 0
) -> void:
	n_bytes = p_bytes
	duration_ms = p_duration_ms
	
	if p_chunks_old == 0xFFFF:
		n_chunks = p_chunks_new
		_original_new_chunk_count = p_chunks_new
	else:
		n_chunks = p_chunks_old
		_original_new_chunk_count = p_chunks_old
	
	if p_magic != MAGIC_NUMBER:
		valid = false
		push_error("AseFrame: Invalid magic number")
	else:
		valid = true
	
	if n_chunks < 0:
		valid = false
		push_error("AseFrame: Invalid chunk count")

func set_chunks(p_chunks: Array) -> void:
	chunks.clear()
	for chunk in p_chunks:
		if chunk is AseChunk:
			chunks.append(chunk)
		else:
			push_error("Cannot add non-AseChunk to frame chunks")

func _validate_data() -> Error:
	return OK
