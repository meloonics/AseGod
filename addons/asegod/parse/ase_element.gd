@abstract
extends Resource

var error: Error = OK
var _data: PackedByteArray

#TODO: abstract this and override it explicitly for each ASE.Component.
func _validate_data() -> Error:
	return OK
