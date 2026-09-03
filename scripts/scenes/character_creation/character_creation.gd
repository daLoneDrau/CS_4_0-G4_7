class_name CharacterCreation
extends Scene

## Character Creation — owns the standard-chunk chrome (CHARACTER_CREATION_UI_UX.md
## §2) for the whole 7-chunk session: creates the draft Entity, owns the
## Stepper that mounts/unmounts chunk content, and holds the fade-in half of
## the Title-Screen-to-here transition (§7 — see TitleScreen._begin_transition()
## for the fade-OUT half).
##
## STILL NOT REAL as of this build step: the 7 chunk scene files themselves
## (build step #7, next), and the downstream-dependency/reset system +
## confirmation dialog (steps #8/#9). The chrome, draft-entity creation, and
## Next/Back/mount-unmount plumbing are real as of this step; nothing in
## those later steps is implemented yet.

const FADE_IN_DURATION: float = 0.6

@onready var _fade_overlay: ColorRect = %FadeOverlay
@onready var _stepper: ChargenStepper = %Stepper
@onready var _chunk_container: Control = %ChunkContainer
@onready var _back_button: Button = %BackButton
@onready var _next_button: Button = %NextButton
@onready var _progress_label: Label = %ProgressLabel

## The in-progress character. Per CHARACTER_CREATION_ENGINEERING_NOTES.md §2:
## a real Entity (not a plain draft object), created the moment chargen
## starts and tagged PC immediately — not promoted to PC later. Handed to
## _stepper.initialize(), which passes it to each ChargenChunk's mount()
## on every mount (chunks re-read it fresh every time — see ChargenStepper's
## class doc comment).
var draft_character: Entity


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


## Required override — Scene.do_action() is abstract. No input handling
## designed for this scene yet — real chargen input starts next session.
func do_action(_action: GameAction) -> void:
	pass
