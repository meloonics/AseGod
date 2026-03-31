@abstract
extends Resource
class_name AseElement

var error: Error = OK
var _data: PackedByteArray

#TODO: abstract this and override it explicitly for each aseelement.
func _validate_data() -> Error:
	return OK
