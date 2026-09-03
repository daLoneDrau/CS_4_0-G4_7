class_name CharacterCreation
extends Scene

## Character Creation — owns the standard-chunk chrome (CHARACTER_CREATION_UI_UX.md
## §2) for the whole 7-chunk session: creates the draft Entity, owns the
## Stepper that mounts/unmounts chunk content, owns the local reset-
## confirmation modal (engineering notes §5 — scene-local UI state, not
## GameEngine.push_modal_scene(), which pauses the whole tree), and holds
## the fade-in half of the Title-Screen-to-here transition (§7 — see
## TitleScreen._begin_transition() for the fade-OUT half).
##
## STILL NOT REAL as of this build step: chunks 2-7 having any actual
## fields/data (they're stubs — one per chunk, e.g.
## chunks/chunk_2_attributes.gd), and therefore the downstream-reset system
## only has one real case to exercise (chunk 1's method toggle) rather than
## the general rule CHARACTER_CREATION_UI_UX.md §1 describes.

const FADE_IN_DURATION: float = 0.6

@onready var _fade_overlay: ColorRect = %FadeOverlay
@onready var _stepper: ChargenStepper = %Stepper
@onready var _chunk_container: Control = %ChunkContainer
@onready var _back_button: Button = %BackButton
@onready var _next_button: Button = %NextButton
@onready var _progress_label: Label = %ProgressLabel
@onready var _confirm_modal: Control = %ConfirmModal
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton

## The in-progress character. Per CHARACTER_CREATION_ENGINEERING_NOTES.md §2:
## a real Entity (not a plain draft object), created the moment chargen
## starts and tagged PC immediately — not promoted to PC later. Handed to
## _stepper.initialize(), which passes it to each ChargenChunk's mount()
## on every mount (chunks re-read it fresh every time — see ChargenStepper's
## class doc comment).
var draft_character: Entity

## Set by _on_downstream_reset_requested(), consumed by _on_confirm_pressed().
## Not needed by _on_cancel_pressed() — ChargenStepper tracks what it needs
## to revert internally (_pending_revert_old_method).
var _pending_reset_from_index: int = -1
var _pending_reset_through_index: int = -1


func _ready() -> void:
	# See TitleScreen's identical note: Scene.on_enter()/on_exit() are
	# declared but never actually invoked by GameEngine anywhere in the
	# repo. Calling on_enter() from _ready() here keeps that pattern
	# consistent across scenes until/unless the engine is updated to call
	# these automatically on scene swap.
	on_enter()


func on_enter() -> void:
	_fade_overlay.color = CSGameEngine.TRANSITION_FOG_COLOR
	var tween: Tween = create_tween()
	tween.tween_property(_fade_overlay, "color:a", 0.0, FADE_IN_DURATION)

	# Entity creation + immediate PC tagging lives on CSEntityManager
	# (create_draft_character()), not here — this just calls it and keeps
	# the reference. Assumes this runs exactly once: character_creation is
	# the single scene owning the whole 7-chunk session (no change_scene()
	# between chunks, per §1), so on_enter() firing more than once per
	# session isn't expected under the current architecture. No guard added
	# against that, matching this file's/TitleScreen's existing on_enter()
	# pattern, which doesn't guard against re-entry either.
	draft_character = CSEntityManager_auto.create_draft_character()

	# Stepper mounts chunk 1 immediately as part of initialize() — see
	# ChargenStepper.initialize(). Chunk scene files don't exist until build
	# step #7; this call is correct code today, just not runnable
	# end-to-end until those files land (ChargenStepper._mount_chunk() uses
	# load(), not preload(), specifically so this doesn't break parsing in
	# the meantime).
	_stepper.initialize(_chunk_container, _back_button, _next_button, _progress_label, draft_character)

	if not _stepper.downstream_reset_requested.is_connected(_on_downstream_reset_requested):
		_stepper.downstream_reset_requested.connect(_on_downstream_reset_requested)
	if not _confirm_button.pressed.is_connected(_on_confirm_pressed):
		_confirm_button.pressed.connect(_on_confirm_pressed)
	if not _cancel_button.pressed.is_connected(_on_cancel_pressed):
		_cancel_button.pressed.connect(_on_cancel_pressed)


## Shows the confirmation modal — ordinary scene-local visibility toggle,
## per engineering notes §5. Stores which chunk range is pending so
## _on_confirm_pressed() can pass it through to ChargenStepper.reset_chunks().
func _on_downstream_reset_requested(from_index: int, through_index: int) -> void:
	_pending_reset_from_index = from_index
	_pending_reset_through_index = through_index
	_confirm_modal.visible = true


func _on_confirm_pressed() -> void:
	_stepper.reset_chunks(_pending_reset_from_index, _pending_reset_through_index)
	_hide_confirm_modal()


func _on_cancel_pressed() -> void:
	_stepper.revert_pending_method_change()
	_hide_confirm_modal()


func _hide_confirm_modal() -> void:
	_confirm_modal.visible = false
	_pending_reset_from_index = -1
	_pending_reset_through_index = -1


## Required override — Scene.do_action() is abstract. No input handling
## designed for this scene yet — real chargen input starts next session.
func do_action(_action: GameAction) -> void:
	pass
