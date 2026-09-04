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
## SCOPE NOTE: mount/unmount/Next/Back/progress, plus the one specified
## downstream-dependency case (chunk 1's method toggle → flag chunks 2-7
## for reset). The confirmation dialog that gates that reset
## (CHARACTER_CREATION_UI_UX.md §1: "any destructive reset/flag action
## requires a confirmation dialog before executing") is character_creation.gd's
## local modal, which listens for downstream_reset_requested below and
## calls back into reset_chunks()/revert_pending_method_change(). "Finish
## chargen" behavior at chunk 7 isn't designed yet and isn't invented here.

## Emitted when a destructive downstream reset is needed. This class does
## NOT execute the reset itself when this fires — see
## flag_downstream_and_confirm(). character_creation.gd's local
## confirmation modal is the listener: it shows the modal, then calls
## reset_chunks() on Confirm or revert_pending_method_change() on Cancel.
signal downstream_reset_requested(from_index: int, through_index: int)

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

## Furthest chunk index reached this session (0-based). Proxy for "chunks
## 2-7 have data" per this session's explicit call: chunks 2-7 currently
## write nothing to the Entity (pure stub labels), so there's no real
## per-chunk data to check yet. This tracks "has the player navigated past
## chunk 1 at least once" as the stand-in condition instead. Reset back to
## 0 by reset_chunks() once that's actually invoked (by #9, on confirm).
var _furthest_index_reached: int = 0

## Chunk 1's method value before the change that triggered the currently-
## pending reset request, if any. Needed for revert_pending_method_change()
## (Cancel path) — captured here rather than re-derived, since by the time
## Cancel is pressed the Entity meta already holds the NEW value.
var _pending_revert_old_method: String = ""


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
	if index > _furthest_index_reached:
		_furthest_index_reached = index

	# Chunk 1's method-toggle signal is specific to its own script
	# (chunk_1_identity_method.gd), not part of the generic ChargenChunk
	# contract — checked via has_signal() rather than a static type check,
	# so this doesn't need to import that concrete script just to wire one
	# signal. Reconnected fresh every mount since chunk instances are never
	# reused (see class doc comment).
	if chunk.has_signal("creation_method_changed"):
		chunk.connect("creation_method_changed", _on_creation_method_changed)

	_update_progress_label()
	_update_button_states()


## Handles the one specified downstream-dependency case (engineering notes
## §4): if the method changes after the player has ever progressed past
## chunk 1 this session, chunks 2-7 need flagging for reset. Stores
## old_method for a possible later revert_pending_method_change() call —
## see that method and chunk_1_identity_method.gd's revert_to().
func _on_creation_method_changed(old_method: String, new_method: String) -> void:
	if _furthest_index_reached > 0:
		_pending_revert_old_method = old_method
		flag_downstream_and_confirm(1, CHUNK_SCENE_PATHS.size() - 1)


## Requests a destructive downstream reset covering chunk indices
## [from_index, through_index] inclusive (0-based). Named to match
## engineering notes §4's "something like flag_downstream_and_confirm(...)"
## — built as a small reusable utility, not hardcoded to only the chunk-1
## case, even though that's the only caller right now.
##
## Deliberately does NOT perform the reset itself — only emits
## downstream_reset_requested. Per CHARACTER_CREATION_UI_UX.md §1, any
## destructive reset requires a confirmation dialog BEFORE executing; that
## dialog is character_creation.gd's local modal (build step #9). Auto-
## executing here would violate that rule even temporarily, so this stops
## at "flagged" — reset_chunks() below is the actual execution, and is only
## ever called from character_creation.gd's _on_confirm_pressed().
func flag_downstream_and_confirm(from_index: int, through_index: int) -> void:
	downstream_reset_requested.emit(from_index, through_index)


## Performs the actual reset. Called by character_creation.gd's
## _on_confirm_pressed(). Chunk 2 (index 1) now has real data
## (CSCharacterComponent, PCPointsMeta) as of this session's Birth Omens
## build — a full reset covering it must actually clear that data, not
## just drop the progress marker as before. Guarded by range (rather than
## unconditional) so a future partial reset that excludes chunk 2 doesn't
## wrongly clear it; the one caller today (chunk 1's method-change flow)
## always covers it in practice.
func reset_chunks(from_index: int, through_index: int) -> void:
	_furthest_index_reached = 0

	if from_index <= 1 and 1 <= through_index:
		var char_comp := _character.get_component(&"CSCharacterComponent") as CSCharacterComponent
		if char_comp:
			char_comp.aspect = CSCharacterComponent.DEFAULT_ASPECT
			char_comp.aspect_determined = false
		PCPointsMeta.reset(_character)


## Cancel-path counterpart to reset_chunks() — called by character_creation.gd's
## _on_cancel_pressed() instead of reset_chunks() when the player cancels.
## Reverts chunk 1's toggle (both its own displayed state and the Entity
## meta value) back to what it was before the change that triggered this
## whole flow, so canceling truly changes nothing.
##
## Checked via has_method() rather than a static Chunk1IdentityMethodStub
## type check, matching the has_signal() check in _mount_chunk() — this
## stays correct even if chunk 1 isn't the currently-mounted chunk for some
## future reason (no-ops safely instead of erroring).
func revert_pending_method_change() -> void:
	if _current_chunk and _current_chunk.has_method("revert_to"):
		_current_chunk.call("revert_to", _pending_revert_old_method)
	_pending_revert_old_method = ""


func _update_progress_label() -> void:
	_progress_label.text = "Step %d of %d" % [_current_index + 1, CHUNK_SCENE_PATHS.size()]


func _update_button_states() -> void:
	_back_button.disabled = _current_index <= 0
	_next_button.disabled = _current_index >= CHUNK_SCENE_PATHS.size() - 1
