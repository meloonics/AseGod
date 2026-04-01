extends ASE.Component

@export var from_frame: int
@export var to_frame: int
@export var direction: ASE.TagsChunk.LoopDirection
@export var repeat: int
@export var name: String
# BUG: So, if Color isn't initialized with Transparent color, 
# the resulting serialized .ase file will mismatch, 
# because Godot defaults to Color(0, 0, 0, 1), and not Color(0, 0, 0 ,0)
@export var color: Color = Color.TRANSPARENT
@export var user_data: ASE.UserDataChunk

func _init(p_from: int = -1, 
		p_to: int = -1, 
		p_dir: ASE.TagsChunk.LoopDirection = ASE.TagsChunk.LoopDirection.FORWARD, 
		p_repeat: int = -1, 
		p_name: String = "", 
		p_color: Color = Color.TRANSPARENT) -> void:
	from_frame = p_from
	to_frame = p_to
	direction = p_dir
	repeat = p_repeat
	name = p_name
	color = p_color
