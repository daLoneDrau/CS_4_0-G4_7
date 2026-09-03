class_name ChargenStepper
extends Node

## Drives the 7-chunk stepper: mounts/unmounts ChargenChunk instances into a
## content container, handles Next/Back, and keeps the progress indicator in
## sync. Owned by character_creation.gd as a plain child node — matches this
## codebase's existing convention for logic-only helper nodes (see
## daLoneDrau-GDEng-ECS/ui/ui_animation_node.gd). Not a Scene subclass
## itself; it isn't a screen.
##
## Per CHARACTER_CREATION_ENGINEERING_NOTES.md §1/§3, and confirmed
## explicitly this session: chunks are instantiated FRESH on every mount and
## freed on unmount — stateless views over the draft Entity, which is the
## only thing that actually persists across Back/Next. That's what makes
## "data persistence on Back" (CHARACTER_CREATION_UI_UX.md §1) work here
## without this class needing to cache anything itself.
##
## SCOPE NOTE: this build step is only mount/unmount/Next/Back/progress. The
## downstream-dependency/reset system (engineering notes §4) and its
## confirmation dialog are separate, later build steps (#8/#9) — nothing
## here calls into either yet. Next is simply disabled at the last chunk;
## "finish chargen" behavior isn't designed yet and isn't invented here.

## Ordered chunk scene paths, per GDD §3.2's chunk grouping. Naming
## convention confirmed this session: chunk_<n>_<gdd-name>.tscn. These files
## don't exist yet as of this build step — build step #7, immediately
## following this one, creates them. load() (not preload()) is used in
## _mount_chunk() specifically so referencing these paths now doesn't break
## script parsing before #7 lands — nothing here is runnable end-to-end
## until then, but this file itself is safe to write and save today.
const CHUNK_SCENE_PATHS: Array[String] = [
	"res://scenes/character_creation/chunks/chunk_1_identity_method.tscn",
	"res://scenes/character_creation/chunks/chunk_2_attributes.tscn",
	"res://scenes/character_creation/chunks/chunk_3_background.tscn",
	"res://scenes/character_creation/chunks/chunk_4_family_circumstance.tscn",
	"res://scenes/character_creation/chunks/chunk_5_character_traits.tscn",
	"res://scenes/character_creation/chunks/chunk_6_physicality.tscn",
	"res://scenes/character_creation/chunks/chunk_7_optional_flourishes.tscn",
]

var _container: Control
var _back_button: Button
var _next_button: Button
var _progress_label: Label
var _character: Entity

var _current_index: int = -1
var _current_chunk: ChargenChunk


## Wires the stepper up to the chrome character_creation.gd owns, and mounts
## chunk 1. Call exactly once, after the draft Entity exists.
func initialize(container: Control, back_button: Button, next_button: Button, progress_label: Label, character: Entity) -> void:
	_container = container
	_back_button = back_button
	_next_button = next_button
	_progress_label = progress_label
	_character = character

	if not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	if not _next_button.pressed.is_connected(_on_next_pressed):
		_next_button.pressed.connect(_on_next_pressed)

	_mount_chunk(0)


func _on_back_pressed() -> void:
	if _current_index <= 0:
		return  # first chunk — Back is also disabled here via _update_button_states(); belt-and-suspenders against a stray signal
	_mount_chunk(_current_index - 1)


func _on_next_pressed() -> void:
	if _current_chunk and not _current_chunk.can_advance():
		return  # chunk is blocking advance — how it surfaces WHY (inline error, etc.) is that chunk's own concern per ChargenChunk.can_advance()'s doc comment, not this controller's
	if _current_index >= CHUNK_SCENE_PATHS.size() - 1:
		return  # last chunk — Next is also disabled here via _update_button_states(); belt-and-suspenders
	_mount_chunk(_current_index + 1)


## Frees the currently-mounted chunk (if any) and instantiates+mounts the
## chunk at `index` fresh. See class doc comment: chunks are stateless,
## re-populated from `_character` every time, by design — this is what
## makes "just free and reinstantiate" a correct, not lossy, operation.
func _mount_chunk(index: int) -> void:
	if _current_chunk:
		_current_chunk.queue_free()
		_current_chunk = null

	var scene: PackedScene = load(CHUNK_SCENE_PATHS[index])
	var chunk: ChargenChunk = scene.instantiate()
	_container.add_child(chunk)
	chunk.mount(_character)

	_current_chunk = chunk
	_current_index = index

	_update_progress_label()
	_update_button_states()


func _update_progress_label() -> void:
	_progress_label.text = "Step %d of %d" % [_current_index + 1, CHUNK_SCENE_PATHS.size()]


func _update_button_states() -> void:
	_back_button.disabled = _current_index <= 0
	_next_button.disabled = _current_index >= CHUNK_SCENE_PATHS.size() - 1
