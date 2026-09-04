class_name Chunk1IdentityMethod
extends ChargenChunk

## Real chunk 1 (Identity & Method) per CHARACTER_CREATION_UI_UX.md §4.
## Replaces the build-step-#7 stub — the creation-method toggle below is
## carried over UNCHANGED from that stub (already real, already tested,
## already wired into ChargenStepper's downstream-reset flow); only the
## race/gender pieces are new this session.
##
## DOWNSTREAM-DEPENDENCY DECLARATION (required per
## CHARACTER_CREATION_ENGINEERING_NOTES.md §4 "definition of done" — every
## chunk must explicitly answer "what does changing this chunk's data
## invalidate downstream?", not leave it implicit):
##   - Creation method: already answered by the stub build step — full
##     reset of chunks 2-7 if changed after they have data. Unchanged here.
##   - Race: no downstream dependents. At MVP, "Human" is the only
##     selectable value (CHARACTER_CREATION_UI_UX.md §4 — others are
##     visibly present but disabled), so no actual change is ever possible
##     through this widget. Nothing to flag.
##   - Gender: no downstream dependents. Nothing in the currently-designed
##     scope of chunks 2-7 (CHARACTER_CREATION_UI_UX.md §6 — none of them
##     have chunk-specific decisions made yet) consumes gender as an input.
##     Revisit this declaration if/when a later chunk is designed to depend
##     on it — per §4's rule, that chunk's own build is where this would
##     need to change, not a deferred cleanup pass here.

signal creation_method_changed(old_method: String, new_method: String)

const META_KEY: StringName = &"chargen_stub_creation_method"
const METHOD_RANDOM: String = "random"
const METHOD_POINT_BASED: String = "point_based"

## Race dropdown contents. StringName keys match RaceComponent.race exactly
## (lowercase, e.g. &"human") — RaceComponent itself stays unopinionated
## about legality (confirmed this session), so enforcing "only Human is
## real" lives entirely here, in the one place that actually offers a
## choice. Elf/Dwarf are visible-but-disabled per §4, using the two named
## candidates on record (Character_creation_UI_UX.md §4's non-canon
## creative note) rather than an anonymous placeholder — confirmed this
## session as the preferred way to telegraph "supports more."
const RACE_OPTIONS: Array[Dictionary] = [
	{"label": "Human", "key": &"human", "enabled": true},
	{"label": "Elf", "key": &"elf", "enabled": false},
	{"label": "Dwarf", "key": &"dwarf", "enabled": false},
]

@onready var _chunk_label: Label = %ChunkLabel
@onready var _race_dropdown: OptionButton = %RaceDropdown
@onready var _male_card: Button = %MaleCard
@onready var _female_card: Button = %FemaleCard
@onready var _method_toggle: CheckButton = %MethodToggle

var _race_component: CSRaceComponent
var _description_component: DescriptionComponent


func mount(character: Entity) -> void:
	super.mount(character)
	_chunk_label.text = "Chunk 1 — Identity & Method"

	# Attached up front in CSEntityManager.create_draft_character() —
	# confirmed this session components live there for new entities, not
	# lazily here. Not defensively re-attached if missing: a chunk 1 mount
	# implies a properly-created draft character; a missing component here
	# would mean create_draft_character() itself is broken, which this
	# chunk shouldn't paper over.
	_race_component = character.get_component(&"CSRaceComponent") as CSRaceComponent
	_description_component = character.get_component(&"DescriptionComponent") as DescriptionComponent

	_mount_race()
	_mount_gender()
	_mount_method()


## —————————————————————————————————————————————
#region Race
## —————————————————————————————————————————————

func _mount_race() -> void:
	_race_dropdown.clear()
	var selected_index: int = 0
	for i in RACE_OPTIONS.size():
		var opt: Dictionary = RACE_OPTIONS[i]
		_race_dropdown.add_item(opt["label"], i)
		_race_dropdown.set_item_disabled(i, not opt["enabled"])
		if opt["key"] == _race_component.race:
			selected_index = i

	# select() alone doesn't fire item_selected — correct here, since this
	# is mount() reflecting existing state, not a new player choice.
	_race_dropdown.select(selected_index)

	if not _race_dropdown.item_selected.is_connected(_on_race_selected):
		_race_dropdown.item_selected.connect(_on_race_selected)


func _on_race_selected(index: int) -> void:
	# Belt-and-suspenders: set_item_disabled() already blocks mouse
	# selection of Elf/Dwarf, but nothing stops a future keyboard-nav path
	# or a stray programmatic select() from reaching here regardless.
	if _race_dropdown.is_item_disabled(index):
		_race_dropdown.select(0)  # snap back to Human
		return
	_race_component.race = RACE_OPTIONS[index]["key"]

#endregion

## —————————————————————————————————————————————
#region Gender
## —————————————————————————————————————————————

func _mount_gender() -> void:
	# First-visit-only random roll: NEUTRAL is DescriptionComponent's own
	# default and chunk 1 never assigns it, so seeing NEUTRAL here means
	# "never touched by this chunk yet" — matches the same
	# read-persisted-state-at-top-of-mount() shape as the method toggle
	# below, just with a randomized rather than fixed initial value.
	# Confirmed this session: revisiting chunk 1 later must reflect the
	# stored value, not re-roll it (chunks are stateless/rebuilt per
	# CHARACTER_CREATION_ENGINEERING_NOTES.md §10, but the Entity's
	# component data is not).
	if _description_component.gender == Gender.Enum.NEUTRAL:
		_description_component.gender = Gender.Enum.MALE if randi() % 2 == 0 else Gender.Enum.FEMALE

	# set_pressed_no_signal() on both — only one should end up pressed,
	# but clearing the other explicitly avoids relying on ButtonGroup's
	# own signal-emitting untoggle behavior during mount() (same
	# no-signal-during-mount discipline as the method toggle below).
	_male_card.set_pressed_no_signal(_description_component.gender == Gender.Enum.MALE)
	_female_card.set_pressed_no_signal(_description_component.gender == Gender.Enum.FEMALE)

	# Connected via `pressed` (fires only on the button actually clicked),
	# not `toggled` — with two ButtonGroup-linked toggle buttons, `toggled`
	# would also fire (with false) on whichever card the group is
	# un-pressing, which isn't a real player choice and isn't a case
	# these handlers need to handle separately.
	if not _male_card.pressed.is_connected(_on_male_card_pressed):
		_male_card.pressed.connect(_on_male_card_pressed)
	if not _female_card.pressed.is_connected(_on_female_card_pressed):
		_female_card.pressed.connect(_on_female_card_pressed)


func _on_male_card_pressed() -> void:
	_description_component.gender = Gender.Enum.MALE
# No confirm step, updates instantly — per §4. There is currently
# nothing in CharacterViewport for this to visually swap (character
# model/rig deferred this session), so today "instant" is satisfied at
# the data layer only.


func _on_female_card_pressed() -> void:
	_description_component.gender = Gender.Enum.FEMALE

#endregion

## —————————————————————————————————————————————
#region Creation Method — unchanged from the build-step-#7 stub
## —————————————————————————————————————————————

func _mount_method() -> void:
	var current_method: String = entity.get_meta(META_KEY, METHOD_RANDOM) as String
	_method_toggle.set_pressed_no_signal(current_method == METHOD_POINT_BASED)
	_update_toggle_text()

	if not _method_toggle.toggled.is_connected(_on_method_toggled):
		_method_toggle.toggled.connect(_on_method_toggled)


func _on_method_toggled(pressed: bool) -> void:
	var old_method: String = entity.get_meta(META_KEY, METHOD_RANDOM) as String
	var new_method: String = METHOD_POINT_BASED if pressed else METHOD_RANDOM
	entity.set_meta(META_KEY, new_method)
	_update_toggle_text()
	creation_method_changed.emit(old_method, new_method)


func revert_to(method: String) -> void:
	entity.set_meta(META_KEY, method)
	_method_toggle.set_pressed_no_signal(method == METHOD_POINT_BASED)
	_update_toggle_text()


func _update_toggle_text() -> void:
	_method_toggle.text = "Point-Based" if _method_toggle.button_pressed else "Random"

#endregion