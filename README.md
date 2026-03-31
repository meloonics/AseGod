# AseGod
<img src="https://raw.githubusercontent.com/meloonics/AseGod/main/addons/asegod/AseGodLogo.png" width="500" height="500" alt="AseGodLogo">

### Immaturity Disclaimer
This plugin was written as a submission to the [CrusCord Jam 2](https://itch.io/jam/cruscord-jam-1), a 4-week creative Jam, that I was 3 weeks late for. Needless to say that this code is largely untested, probably not working and misses features all over the place. So this isn't meant to be anywhere near production-ready.
However, this collection of scripts may serve as a baseline for your own system of handling .ase files in your own project. If you want to handle any part of an .ase file without having to touch the complexity of parsing and serializing binary .ase files, this codebase may be your point to start.
If you're looking for something usable out of the box, you can find plenty of more mature Aseprite-Plugins in the [Godot Asset Library](https://godotengine.org/asset-library/asset?filter=aseprite&category=&godot_version=&cost=&sort=updated)

## About
This plugin adds .ase and .aseprite files (they're the same) as first-class resources to your project. Under the hood it encapsulates away the de- and encoding logic of the .ase file format as outlined in the [following specification](https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md). Unlike many Ase importer plugins in the Asset Library, this library focuses on making any part of an .ase file, be it frames, layers, cels, slices, arbitrary user data, or whatever, accessible as Godot-Resources. The AseElement family of custom objects is written in a way, that it could export a bit-by-bit matching replika of your .ase file from Godot only, using nothing but the previously extracted data. 
Since the needs of every project are different, you're encouraged to extend `AseGod` and `AseExportTicket` according to what elements of your file actually matter for the game. This allows you to interpret the data on Godot's end in any way you desire.
If I have had more time, i would've implemented importing behavior for custom data layers based on user data, such as drawn collision polygons, navigation, occlusion, heightmap, normal map, sound effects, you name it. 

## How Worky?
Hopefully at all!
But conceptually, you go a bit like this:

{Your `.ase(prite)-file`} <- {bidirectional de/encoding via `AseParser`} -> {`AseFile` Resource}

{`AseFile`} -> {Custom logic based on `AseExportTicket` executed by `AseGod`} -> {Godot-native Object (scene, resource, file)}

### Coming soon(ish(probably never)): 
- [ ] Tutorial and Documentation
- [ ] Refactor
- [ ] Finish testing all features
- [ ] Confirm the exported resources/scenes are not Bytevomit
- [ ] Extend functionality for smart, UserData-based pixel data interpretation.
- [ ] GUI Export dialog with fine-grained control and custom presets. 
