@tool
extends EditorPlugin

var import_plugin

func _enter_tree():
	import_plugin = preload("import/ase_import_plugin.gd").new()
	add_import_plugin(import_plugin)

func _exit_tree():
	remove_import_plugin(import_plugin)
	import_plugin = null


func _handles(object):
	return object is ASE.File

func _edit(object):
	if not object is ASE.File:
		return
	
	var path = object.resource_path
	if path.ends_with(".ase_data.tres"):
		path = path.replace(".ase_data.tres", ".ase")
		if not FileAccess.file_exists(path):
			path = path.replace(".ase", ".aseprite")
	
	if not FileAccess.file_exists(path):
		return
	
