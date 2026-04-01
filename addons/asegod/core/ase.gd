# Abstract only so it can't be instantiated by accident.
# No intention to extend this class in any way.
@abstract
extends Object

# All Caps, because it's short for 'Allegro Sprite Editor'
class_name ASE 

## This class mostly acts as a centralized interface point for the user
## and as a pseudo-namespace to better separate Aseprite-related matters 
## from whatever project this is used in, while decluttering the global 
## namespace entirely.
## Some plugin-wide utility functions can be found here as well. 

#region Static Utilities
static func load(path: String) -> ASE.File:
	var parser = ASE.Parser.new()
	return parser.parse_file(path)

static func create() -> ASE.Builder:
	return ASE.Builder.new()

static func is_valid(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		return false
	var magic = f.get_16()
	f.close()
	return magic == 0xA5E0
#endregion

#region Pseudo Namespace Subclasses

# Pseudo-Namespace via shoelace-inheritance-system:
# Example:
# [Public Interface]  ↔  [Private Backend]
# ASE.SubThing → extends → "path/to/ase_subthing.gd"
#   ┏━━━━━━━━━━━ extends ━━━━━━━━━━━┛
# ASE.Thing    → extends → "path/to/ase_thing.gd"
#   ┏━━━━━━━━━━━ extends ━━━━━━━━━━━┛
# Godot Native Class, usually Resource, sometimes RefCounted.
# Inheritance relationships in the Backend remain intact,
# meanwhile each Object is easily accessible via this ASE.Subclass.
# This way the plugin only claims the word 'ASE' in global name space.

#region Static Util Subclasses
class Log extends "res://addons/asegod/parse/ase_logger.gd": pass
#endregion

#region Parsing Resource Layer
class DataStream extends "res://addons/asegod/parse/ase_data_stream.gd": pass
class Parser extends "res://addons/asegod/parse/ase_parser.gd": pass
class File extends "res://addons/asegod/parse/ase_file.gd": pass
class Frame extends "res://addons/asegod/parse/ase_frame.gd": pass
class Component extends "res://addons/asegod/parse/ase_element.gd": pass
@abstract class Chunk extends "res://addons/asegod/parse/ase_chunk.gd": pass

class Cel extends "res://addons/asegod/parse/ase_cel.gd": pass
class CelExtra extends "res://addons/asegod/parse/ase_cel_extra.gd": pass
class ColorProfile extends "res://addons/asegod/parse/ase_color_profile.gd": pass
class ExternalFiles extends "res://addons/asegod/parse/ase_external_files.gd": pass
class Layer extends "res://addons/asegod/parse/ase_layer.gd": pass
class MissingNo extends "res://addons/asegod/parse/ase_missing_no.gd": pass
class Palette extends "res://addons/asegod/parse/ase_palette.gd": pass
class Slice extends "res://addons/asegod/parse/ase_slice.gd": pass
class TagsChunk extends "res://addons/asegod/parse/ase_tags.gd": pass
class TileSetChunk extends "res://addons/asegod/parse/ase_tileset.gd": pass
class UserDataChunk extends "res://addons/asegod/parse/ase_user_data.gd": pass
class Tag extends "res://addons/asegod/parse/ase_tag.gd": pass
#endregion

#region Export RefCounted Workers
#maybe do one class for all export matters? not sure. 
class Export extends "res://addons/asegod/import/ase_export_ticket.gd": pass
class God extends "res://addons/asegod/import/asegod.gd" : pass
# TODO: Builder, Serializer, Converter, Caster, UDManager, TagsManager, 
# DataLayer custom parser, Resource extending Image that deals with indexed textures
# A billion more worker classes for each tiny task. 
#endregion

#endregion
