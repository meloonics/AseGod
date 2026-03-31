@tool
extends EditorImportPlugin

func _get_importer_name():
	return "aseprite"

func _get_visible_name():
	return "Aseprite File"

func _get_recognized_extensions():
	return ["ase", "aseprite"]

func _get_save_extension():
	return "tres"

func _get_resource_type():
	return "AseFile"

func _get_import_options(path, preset_index):
	return []

func _get_preset_count():
	return 1

func _get_preset_name(preset_index):
	return "Default"

func _import(source_file, save_path, options, platform_variants, gen_files):
	AseLogger.debug("Importing: " + str(source_file))
	
	var parser = AseParser.new()
	var result = parser.load_ase(source_file)
	
	if result.keys()[0] != OK:
		#print("Parse failed: ", result.keys()[0])
		return result.keys()[0]
	
	var ase_file = result[result.keys()[0]]
	#print("Parsed OK, frames: ", ase_file.frames.size())
	
	var save_file = save_path + "." + _get_save_extension()
	var err = ResourceSaver.save(ase_file, save_file)
	
	if err != OK:
		AseLogger.error("Save failed: " + str(err))
		return err
	
	var data_path = save_path + ".ase_data.tres"
	err = ResourceSaver.save(ase_file, data_path)
	if err == OK:
		gen_files.append(data_path)
		AseLogger.debug("Data saved to: " + data_path)
	
	return OK
