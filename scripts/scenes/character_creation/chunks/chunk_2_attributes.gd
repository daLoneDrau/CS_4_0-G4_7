class_name Chunk2Attributes
extends ChargenChunk

## Real chunk 2 (Attributes) — Birth Omens portion only, per
## CHARACTER_CREATION_UI_UX.md §4a. Replaces the build-step-#7 stub.
##
## NOT YET DONE, flagged honestly rather than silently incomplete: the
## nine-Attributes half of this chunk (§4a's own header notes this).
## mount() below only wires the Aspect widget.
##
## DOWNSTREAM-DEPENDENCY DECLARATION (required per
## CHARACTER_CREATION_ENGINEERING_NOTES.md §4 "definition of done"):
##   - Aspect: Poorly Aspected obligates at least one Curse, a field
##     belonging to chunk 4 (Family & Circumstance), which doesn't exist
##     yet. Chunk 4, once built, must check
##     CSCharacterComponent.aspect == CSCharacterComponent.ASPECT_POORLY
##     and require a Curse selection.
##   - Aspect / PC Points pool interaction: Back-navigating into chunk 2
##     and changing Aspect after a later chunk has already spent PC Points
##     isn't caught by anything today — not a real scenario yet since
##     chunks 3-6 don't spend from the pool, but will need the stepper's
##     downstream-dependency/reset rule (§1) once they do. Flagged in
##     CHARACTER_CREATION_UI_UX.md §4a.
##   - Character tier (PCPointsMeta): only consumed by this chunk itself
##     so far (attribute_max(), not yet called until the Attributes widget
##     exists). No other downstream dependents yet.
##   - This declaration is itself incomplete per §4's rule, honestly:
##     Attributes plausibly feed the Skillskape formula and chunk 6's
##     derived stats, but neither is built, so today's honest answer is
##     "no consumer built" — same shape as chunk 1's race/gender
##     declarations. Revisit once Attributes exist in this file.

## Card copy — kept as data (title/blurb per Aspect) separate from the
## cost line, which differs by creation method and is composed at mount
## time rather than duplicated per method.
const ASPECT_TITLES: Dictionary[StringName, String] = {
	CSCharacterComponent.ASPECT_WELL: "Well Aspected",
	CSCharacterComponent.ASPECT_NEUTRAL: "Neutrally Aspected",
	CSCharacterComponent.ASPECT_POORLY: "Poorly Aspected",
}

## Paraphrased from Character_Creation_Expanded_Content.md §1. Hand-wrapped
## with explicit newlines rather than relying on Button autowrap (matches
## chunk 1's gender-card precedent of manual multi-line Button text) — a
## real richer card component can replace this during an actual art pass.
const ASPECT_BLURBS: Dictionary[StringName, String] = {
	CSCharacterComponent.ASPECT_WELL: "Touched by the supernatural with a strong pull\ntoward Magick. +10 PMF in every Mode of practice;\nMagick Resistance drops to 0%.",
	CSCharacterComponent.ASPECT_NEUTRAL: "No unusual magical presence. Magick Resistance\n10%. Practicing Magick usually requires a magical\nvocation, even where mana is plentiful.",
	CSCharacterComponent.ASPECT_POORLY: "Marked by hostile supernatural attention — not\nevil, but singled out. Carries at least one Curse.\nAlso gains +10 PMF in every Mode; MR drops to 0%.",
}

@onready var _chunk_label: Label = %ChunkLabel
@onready var _points_remaining_label: Label = %PointsRemainingLabel
@onready var _well_card: Button = %WellCard
@onready var _neutral_card: Button = %NeutralCard
@onready var _poorly_card: Button = %PoorlyCard

var _char_component: CSCharacterComponent


func mount(character: Entity) -> void:
	super.mount(character)
	_chunk_label.text = "Chunk 2 — Attributes"

	# Attached up front in CSEntityManager.create_draft_character() — same
	# precedent as chunk 1's components (CSRaceComponent/DescriptionComponent),
	# not lazily attached here.
	_char_component = character.get_component(&"CSCharacterComponent") as CSCharacterComponent

	# Tier rolls for every character regardless of creation method — see
	# PCPointsMeta doc comment. Idempotent (has_tier() guard inside), so
	# safe to call unconditionally on every mount/revisit.
	PCPointsMeta.ensure_tier(character)

	_mount_panel_style()
	_mount_birth_omens()


func _is_point_based() -> bool:
	var method: String = entity.get_meta(Chunk1IdentityMethod.META_KEY, Chunk1IdentityMethod.METHOD_RANDOM) as String
	return method == Chunk1IdentityMethod.METHOD_POINT_BASED


## Placeholder differentiation only — real per-method panel art/theming
## isn't designed yet (Art Direction Rule §3 hasn't had an actual pass
## applied to this chunk's chrome). A visible-but-clearly-provisional tint
## stands in for CHARACTER_CREATION_UI_UX.md §4a's "panel styling differs
## per method" requirement (applying chunk 3's §5 precedent here) so it
## isn't silently unmet — not a real art pass.
func _mount_panel_style() -> void:
	self_modulate = Color(0.85, 0.8, 1.0) if _is_point_based() else Color(1.0, 0.9, 0.75)


## —————————————————————————————————————————————
#region Birth Omens
## —————————————————————————————————————————————

func _mount_birth_omens() -> void:
	if _is_point_based():
		_mount_birth_omens_point_based()
	else:
		_mount_birth_omens_random()


func _mount_birth_omens_random() -> void:
	_points_remaining_label.visible = false
	_set_card_texts(false)

	# First-visit-only roll, gated on aspect_determined — the value alone
	# (Neutral) can't be trusted as a "never rolled" sentinel since it's
	# also D100's most likely actual outcome. See CSCharacterComponent's
	# own doc comment on this field.
	if not _char_component.aspect_determined:
		_char_component.aspect = _roll_aspect()
		_char_component.aspect_determined = true

	# All three cards locked, non-interactive — same greyed-out-but-visible
	# treatment as chunk 1's disabled race entries (§4), not hidden.
	for card: Button in [_well_card, _neutral_card, _poorly_card]:
		card.toggle_mode = true
		card.disabled = true

	_resync_cards_to_current_aspect()


func _roll_aspect() -> StringName:
	var r: int = randi() % 100 + 1
	if r <= 15:
		return CSCharacterComponent.ASPECT_WELL
	elif r <= 85:
		return CSCharacterComponent.ASPECT_NEUTRAL
	else:
		return CSCharacterComponent.ASPECT_POORLY


func _mount_birth_omens_point_based() -> void:
	PCPointsMeta.init_pool(entity)  # idempotent — no-op on revisit, tier already resolved above
	# Point-based method's own "determination" is immediate:
	# default-to-Neutral IS the resolution, nothing left to roll. Matches
	# CSCharacterComponent.aspect_determined's doc comment ("random roll OR
	# point-based default-to-Neutral").
	_char_component.aspect_determined = true

	_points_remaining_label.visible = true
	_update_points_remaining_label()
	_set_card_texts(true)

	for card: Button in [_well_card, _neutral_card, _poorly_card]:
		card.toggle_mode = true
		card.disabled = false

	_resync_cards_to_current_aspect()

	if not _well_card.pressed.is_connected(_on_well_card_pressed):
		_well_card.pressed.connect(_on_well_card_pressed)
	if not _neutral_card.pressed.is_connected(_on_neutral_card_pressed):
		_neutral_card.pressed.connect(_on_neutral_card_pressed)
	if not _poorly_card.pressed.is_connected(_on_poorly_card_pressed):
		_poorly_card.pressed.connect(_on_poorly_card_pressed)


func _on_well_card_pressed() -> void:
	_try_select_aspect(CSCharacterComponent.ASPECT_WELL, _well_card)


func _on_neutral_card_pressed() -> void:
	_try_select_aspect(CSCharacterComponent.ASPECT_NEUTRAL, _neutral_card)


func _on_poorly_card_pressed() -> void:
	_try_select_aspect(CSCharacterComponent.ASPECT_POORLY, _poorly_card)


## Attempts the selection; on rejection (can't afford it), snaps the
## pressed button back to reflect the actual (unchanged) current aspect
## rather than leaving the UI showing a selection that didn't take.
func _try_select_aspect(new_aspect: StringName, pressed_card: Button) -> void:
	if not _select_aspect(new_aspect):
		pressed_card.set_pressed_no_signal(false)
		_resync_cards_to_current_aspect()
		return
	_update_points_remaining_label()


func _resync_cards_to_current_aspect() -> void:
	_well_card.set_pressed_no_signal(_char_component.aspect == CSCharacterComponent.ASPECT_WELL)
	_neutral_card.set_pressed_no_signal(_char_component.aspect == CSCharacterComponent.ASPECT_NEUTRAL)
	_poorly_card.set_pressed_no_signal(_char_component.aspect == CSCharacterComponent.ASPECT_POORLY)


func _update_points_remaining_label() -> void:
	_points_remaining_label.text = "PC Points remaining: %d / %d" % [
		PCPointsMeta.get_remaining(entity), PCPointsMeta.get_total(entity)
	]


func _set_card_texts(include_cost: bool) -> void:
	_well_card.text = _card_text(CSCharacterComponent.ASPECT_WELL, include_cost)
	_neutral_card.text = _card_text(CSCharacterComponent.ASPECT_NEUTRAL, include_cost)
	_poorly_card.text = _card_text(CSCharacterComponent.ASPECT_POORLY, include_cost)


func _card_text(aspect: StringName, include_cost: bool) -> String:
	var title: String = ASPECT_TITLES[aspect]
	var blurb: String = ASPECT_BLURBS[aspect]
	if not include_cost:
		return "%s\n\n%s" % [title, blurb]
	return "%s\n\n%s\n\n%s" % [title, blurb, _aspect_cost_line(aspect)]


func _aspect_cost_line(aspect: StringName) -> String:
	match aspect:
		CSCharacterComponent.ASPECT_WELL:
			return "Cost: 10 PC Points"
		CSCharacterComponent.ASPECT_POORLY:
			return "Refunds 10 PC Points"
		_:
			return "Free (default)"

#endregion

## —————————————————————————————————————————————
#region Aspect Selection Logic (point-based method only)
## —————————————————————————————————————————————

## Returns false (no state change) if new_aspect can't be afforded — same
## bool-only, no-reason-string contract as PCPointsMeta.spend()/
## ChargenChunk.can_advance().
func _select_aspect(new_aspect: StringName) -> bool:
	var old_aspect: StringName = _char_component.aspect
	if old_aspect == new_aspect:
		return true

	_reverse_aspect_cost(old_aspect)
	if not _apply_aspect_cost(new_aspect):
		_apply_aspect_cost(old_aspect)  # roll back, always succeeds
		return false

	_char_component.aspect = new_aspect
	return true


## Positive = PC Points spent, negative = PC Points refunded. Matches
## Table 1.3a's own sign convention (Well -10, Poorly +10 as pool deltas).
func _aspect_cost(aspect: StringName) -> int:
	match aspect:
		CSCharacterComponent.ASPECT_WELL:
			return 10
		CSCharacterComponent.ASPECT_POORLY:
			return -10
		_:
			return 0


func _apply_aspect_cost(aspect: StringName) -> bool:
	var cost: int = _aspect_cost(aspect)
	if cost > 0:
		return PCPointsMeta.spend(entity, cost)
	elif cost < 0:
		PCPointsMeta.refund(entity, -cost)
	return true


func _reverse_aspect_cost(aspect: StringName) -> void:
	var cost: int = _aspect_cost(aspect)
	if cost > 0:
		PCPointsMeta.refund(entity, cost)
	elif cost < 0:
		PCPointsMeta.spend(entity, -cost)

#endregion
