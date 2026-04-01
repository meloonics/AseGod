extends RefCounted

## Static Helper class for debugging and development. 
# TODO: See if this class can either be removed or used more diligently
# TODO: Make functions variadic
# TODO: Add .log files in res://addons/asegod/debug with log-rotation
enum Level {
	ERROR = 0,
	WARNING = 1,
	INFO = 2,
	VERBOSE = 3,
	DEBUG = 4
}

static var current_level: Level = Level.WARNING
static var output_enabled: bool = false

const PREFIX: String = "[ASE] "

static func set_level(level: Level) -> void:
	current_level = level

static func error(msg: String) -> void:
	if output_enabled and current_level >= Level.ERROR:
		push_error(PREFIX, msg)

static func warning(...msg: Array) -> void:
	if output_enabled and current_level >= Level.WARNING:
		push_warning(PREFIX, msg)

static func info(msg: String) -> void:
	if output_enabled and current_level >= Level.INFO:
		print(PREFIX, msg)

static func verbose(msg: String) -> void:
	if output_enabled and current_level >= Level.VERBOSE:
		print(PREFIX + "V: ", msg)

static func debug(msg: String) -> void:
	if output_enabled and current_level >= Level.DEBUG:
		print(PREFIX + "D: ", msg)

static func print_hex(data: PackedByteArray, max_bytes: int = 64) -> void:
	if current_level < Level.DEBUG:
		return
	var hex_str = ""
	for i in range(min(max_bytes, data.size())):
		if i % 16 == 0:
			hex_str += "\n"
		hex_str += "%02X " % data[i]
	print(PREFIX + "DEBUG: Hex dump:", hex_str)
