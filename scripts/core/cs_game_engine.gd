class_name CSGameEngine
extends GameEngine

## Concrete GameEngine for Chivalry & Sorcery. Autoloaded singleton — see
## project.godot's [autoload] section for load order (this must come after
## Switchboard_auto and CSEntityManager).

## Shared stand-in for the game's fog color (GDD §1/TITLE_SCREEN_UI_UX.md
## §7 — scene transitions fade through the same fog color used for each
## scene's ambient atmosphere, "one fog definition, not two"). No real fog
## exists yet anywhere in the render pipeline — every scene's actual fog/
## background is still first-pass placeholder (see e.g. TitleScreen's
## Environment_backdrop resource). This constant exists so every scene that
## needs "the fog color" (fade-outs, fade-ins, ambient background) reads
## from ONE place instead of each duplicating the same magic Color value —
## update here once real fog is designed, not per-scene.
const TRANSITION_FOG_COLOR: Color = Color(0.62, 0.6, 0.58, 1.0)


func _ready() -> void:
	super._ready()  # sets process_mode, running = true, caches `window`
	run()  # GameEngine.run(): _initialize_systems() -> load_resources() -> _setup_window() -> _start_game()


## No GameSystems are needed yet for Title Screen scene/UI construction —
## this hook is for later build steps (combat, inventory, etc.) that need
## systems registered globally rather than per-scene.
func _initialize_systems() -> void:
	pass


## The full fixed-16:9/letterbox render pipeline (GDD §1.1) is scoped for
## build step 3, not this step — this just sets a sane window title for now.
## Window size itself comes from project.godot's [display] section.
func _setup_window() -> void:
	window.title = "Chivalry & Sorcery"


func _start_game() -> void:
	# NOTE ON SEQUENCING — worth verifying directly in the Godot editor,
	# since I can't run Godot in this environment to confirm behavior:
	#
	# project.godot's run/main_scene is set directly to title_screen.tscn,
	# rather than relying on change_scene() to load it. That's deliberate:
	# _ready() (and therefore run() and this method) fires during autoload
	# initialization, *before* Godot has added the main scene to the tree —
	# so get_tree().current_scene is still null here, and calling
	# change_scene_to_file() at this point would be reaching for a scene
	# tree that doesn't exist yet (and risks double-loading title_screen
	# once Godot's own main-scene boot catches up).
	#
	# Instead: register "title_screen" as a known key (so GameEngine can
	# change_scene() back to it later, e.g. once Settings is real), then
	# reuse the engine's own _on_scene_changed() polling helper (already
	# written to wait for get_tree().current_scene to resolve to a Scene)
	# to sync GameEngine's primary_scene bookkeeping once Godot's normal
	# boot sequence actually brings the scene up.
	register_scene("title_screen", "res://scenes/title/title_screen.tscn")
	register_scene("character_creation", "res://scenes/character_creation/character_creation.tscn")
	primary_scene_key = "title_screen"
	call_deferred("_on_scene_changed", "title_screen")


func load_resources() -> void:
	assets = AssetsLibrary.new()
	assets.name = "AssetsLibrary"
	add_child(assets)

	# Display + UI fonts per GDD §1.2. These files aren't fetchable by me
	# (network access here is restricted to package registries, not Google
	# Fonts) — download links were given in chat. add_font() already warns
	# gracefully on a missing file rather than crashing, so this is safe to
	# run before the fonts exist; text will just fall back to the default
	# system font until they're in place.
	if not assets.add_font("display", "res://assets/fonts/IMFellEnglish-Regular.ttf"):
		push_warning("CSGameEngine: display font (IM Fell English) not found at res://assets/fonts/ yet.")

	if not assets.add_font("ui", "res://assets/fonts/EBGaramond-static/EBGaramond-Regular.ttf"):
		push_warning("CSGameEngine: UI font (EB Garamond) not found at res://assets/fonts/ yet.")
