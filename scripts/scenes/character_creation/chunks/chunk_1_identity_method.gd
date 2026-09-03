class_name Chunk1IdentityMethodStub
extends ChargenChunk

## STUB for chunk 1 (Identity & Method) — build step #7. Exercises the
## stepper end-to-end; NOT the real chunk 1 spec from
## CHARACTER_CREATION_UI_UX.md §4 (race/gender/method widgets, backdrop
## swap, instant character-window preview, etc.) — that's explicitly out of
## scope for this session per the original scope note ("chunk 1 content is
## NOT part of this session").
##
## The one piece of real (non-stub) behavior here is the creation-method
## toggle: built now because build step #8 (downstream-dependency/reset)
## needs a real, changeable value on chunk 1 to wire its one specified
## reset case to (CHARACTER_CREATION_ENGINEERING_NOTES.md §4 — "chunk 1's
## creation-method toggle, if changed after chunks 2-7 have data, triggers
## a full reset of chunks 2-7"). This is a functional-text control widget
## per the decorative-vs-functional heuristic (§3) — never warp-eligible.

signal creation_method_changed(old_method: String, new_method: String)

const META_KEY: StringName = &"chargen_stub_creation_method"
const METHOD_RANDOM: String = "random"
const METHOD_POINT_BASED: String = "point_based"

@onready var _chunk_label: Label = %ChunkLabel
@onready var _method_toggle: CheckButton = %MethodToggle


func mount(character: Entity) -> void:
	super.mount(character)
	_chunk_label.text = "Chunk 1 — Identity & Method (stub)"

	# Persisted via Entity.set_meta()/get_meta() — NOT Entity.groups
	# (confirmed this session: groups is reserved for actual in-game
	# faction/NPC tagging consumed by scripted events, e.g. "Town_Guards",
	# not scalar chargen state) and not a formal component (none designed
	# yet for creation method — BackgroundComponent, GDD §3.3, doesn't cover
	# this). Deliberately provisional; replace once a real component exists.
	var current_method: String = character.get_meta(META_KEY, METHOD_RANDOM) as String
	_method_toggle.button_pressed = (current_method == METHOD_POINT_BASED)
	_update_toggle_text()

	if not _method_toggle.toggled.is_connected(_on_method_toggled):
		_method_toggle.toggled.connect(_on_method_toggled)


## Emits creation_method_changed with BOTH old and new values — build step
## #9's confirmation modal needs the old value to revert on Cancel, and by
## the time this fires the Entity meta has already been overwritten, so the
## old value has to be captured and passed here or it's gone. Connects to
## ChargenStepper._on_creation_method_changed(), wired in build step #8.
func _on_method_toggled(pressed: bool) -> void:
	var old_method: String = entity.get_meta(META_KEY, METHOD_RANDOM) as String
	var new_method: String = METHOD_POINT_BASED if pressed else METHOD_RANDOM
	entity.set_meta(META_KEY, new_method)
	_update_toggle_text()
	creation_method_changed.emit(old_method, new_method)


## Reverts both the Entity meta value and the toggle's own displayed state
## back to `method`, WITHOUT re-emitting creation_method_changed — that
## would loop straight back into the stepper's reset-confirmation flow that
## called this in the first place. Called by
## ChargenStepper.revert_pending_method_change() (build step #9), itself
## called by character_creation.gd's modal on Cancel.
##
## Uses set_pressed_no_signal() specifically — assigning .button_pressed
## directly would fire `toggled` and re-trigger _on_method_toggled(),
## causing exactly the loop this method exists to avoid.
func revert_to(method: String) -> void:
	entity.set_meta(META_KEY, method)
	_method_toggle.set_pressed_no_signal(method == METHOD_POINT_BASED)
	_update_toggle_text()


func _update_toggle_text() -> void:
	_method_toggle.text = "Point-Based" if _method_toggle.button_pressed else "Random"
