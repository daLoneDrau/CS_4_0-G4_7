class_name TitleScreen
extends Scene

## Title Screen — MVP entry point. Full behavior spec: TITLE_SCREEN_UI_UX.md.
##
## Scope at THIS build step (scene skeleton only): registering as a working
## Scene subclass with a non-blank placeholder. Layout (§2), logotype (§4),
## menu (§5), glow (§3/§6), input (§6), and transition (§7) are later build
## steps — none of that lives here yet.

@onready var _backdrop: TextureRect = %Backdrop
@onready var _title_label: Label = %TitleLabel
@onready var _menu_list: VBoxContainer = %MenuList
@onready var _fade_overlay: ColorRect = %FadeOverlay

## STAND-IN for the scene's real fog color (§1/§7 — transition fades through
## the same fog color used for ambient atmosphere, "one fog definition, not
## two"). Matches Environment_backdrop's fog_light_color/background_color in
## the scene file — both are first-pass placeholder values for "warm muted
## grey overcast," not colorimetrically locked numbers. If one changes,
## update the other; ideally these get pulled from one shared source once
## the render pipeline is less of a moving target.
const TRANSITION_FOG_COLOR: Color = Color(0.62, 0.6, 0.58, 1.0)

## Fade duration in seconds. Placeholder-tunable, same caveat as glow
## radius/font sizes elsewhere in this file.
const TRANSITION_FADE_DURATION: float = 0.6

## Keyboard-focus target value for a menu item's glow_intensity shader
## parameter. Kept in sync with StartButton/GlowHover's
## hover_shader_parameter_float_setting in the scene file BY HAND — both
## represent the same "focused" glow target (§6: focus, whether via hover
## or keyboard, increases the same glow). If one changes, update the other.
const FOCUS_GLOW_INTENSITY: float = 2.0
const BASELINE_GLOW_INTENSITY: float = 1.0

## Buttons that are actually keyboard-reachable (disabled == false), in
## menu order. Currently just [StartButton] — Continue/Settings/Credits are
## disabled per §5, and §6 explicitly excludes disabled items from keyboard
## focus order. Built generically (filtered from MenuList's children, not
## hardcoded to Start) so this doesn't need rewriting once more items are
## enabled post-MVP.
var _reachable_buttons: Array[Button] = []

## Index into _reachable_buttons of the currently keyboard-focused item.
## -1 means nothing focused yet.
var _focused_menu_index: int = -1

## True once Start has been pressed and the transition is underway — blocks
## re-entry (double-click, keyboard confirm spam) from both the mouse path
## (via _fade_overlay's mouse_filter, set in _begin_transition) and the
## keyboard path (checked directly in do_action, since the overlay's mouse
## blocking has no effect on the custom keyboard action-map system).
var _transitioning: bool = false


func _ready() -> void:
	# NOTE ON on_enter()/on_exit(): Scene (engine/scene.gd) declares these as
	# lifecycle hooks, but nothing in GameEngine actually calls them anywhere
	# in the repo — confirmed via grep, they're declared, never invoked.
	# Calling on_enter() from _ready() here keeps the intended semantics
	# meaningful without fighting that gap. If the engine is ever updated to
	# call these automatically on scene swap, revisit this — calling
	# on_enter() from both places at that point would double-fire.
	on_enter()


func on_enter() -> void:
	_apply_logotype_font()
	_apply_menu_font()
	_setup_menu_input()


## Applies the display face (IM Fell English, GDD §1.2) to the title text.
## Per the decorative-vs-functional chrome heuristic (CHARACTER_CREATION_UI_UX.md
## §3, referenced by TITLE_SCREEN_UI_UX.md §4): the logotype TEXT is legible
## content and stays clean — only the divider ornament (already tagged with
## the "decorative_chrome" group in the scene) is warp-eligible once the PS1
## vertex-warp shader exists (separate render-pipeline build step).
func _apply_logotype_font() -> void:
	var font: FontFile = CSGameEngine_auto.assets.get_font("display", false)
	if font:
		_title_label.add_theme_font_override("font", font)
	else:
		push_warning("TitleScreen: display font (IM Fell English) not loaded — check res://assets/fonts/IMFellEnglish-Regular.ttf exists.")


## Applies the UI face (EB Garamond, GDD §1.2) to every menu item. Per the
## same functional-text rule cited above: menu text is content the player
## must read/parse precisely, so it uses the UI face, not the display face,
## and never receives the PS1 vertex-warp treatment.
##
## Disabled-state visuals (Continue/Settings/Credits per §5 — "visibly
## present but non-functional," dimmed opacity only, no lock icon) are set
## declaratively in the scene file itself (modulate alpha + disabled=true),
## not here — nothing about that state depends on the font load succeeding
## or failing.
func _apply_menu_font() -> void:
	var font: FontFile = CSGameEngine_auto.assets.get_font("ui", false)
	if font:
		for child: Node in _menu_list.get_children():
			if child is Button:
				(child as Button).add_theme_font_override("font", font)
	else:
		push_warning("TitleScreen: UI font (EB Garamond) not loaded — check res://assets/fonts/EBGaramond-static/EBGaramond-Regular.ttf exists.")


## Required override — Scene.do_action() is abstract. This is where the
## custom keyboard action-map system (registered below in _setup_menu_input)
## actually gets handled. Mouse click/hover are separate — Buttons handle
## click natively, and hover-glow is UiAnimationNode (scene file), not this.
func do_action(action: GameAction) -> void:
	if _transitioning:
		return
	if not action.is_pressed():
		return  # react on key-down only; ignore the matching key-up event
	match action.name:
		"menu_up":
			_move_menu_focus(-1)
		"menu_down":
			_move_menu_focus(1)
		"menu_confirm":
			_confirm_menu_focus()


## Registers keyboard actions (§6: arrow-key navigation + confirm) and
## establishes initial keyboard focus. Also connects StartButton's `pressed`
## signal once, so mouse click and keyboard-confirm both funnel through the
## same _on_start_pressed() — native Button click handling already covers
## the mouse half; this only adds the keyboard half.
func _setup_menu_input() -> void:
	_reachable_buttons.clear()
	for child: Node in _menu_list.get_children():
		if child is Button and not (child as Button).disabled:
			_reachable_buttons.append(child as Button)

	register_action("Up", "menu_up")
	register_action("Down", "menu_down")
	register_action("Enter", "menu_confirm")
	register_action("Space", "menu_confirm")

	# Start pre-focused on scene entry, since it's the sole reachable item —
	# standard "first/only actionable item highlighted by default" menu
	# convention, not requiring an initial keystroke to reveal itself.
	if not _reachable_buttons.is_empty():
		_set_menu_focus(0)

	var start_button: Button = %StartButton
	if start_button and not start_button.pressed.is_connected(_on_start_pressed):
		start_button.pressed.connect(_on_start_pressed)


## Moves keyboard focus by `delta` within _reachable_buttons, clamped (no
## wraparound) at either end. With only Start currently reachable this is
## presently always a no-op — kept general rather than special-cased so it
## starts working correctly the moment more items are enabled post-MVP,
## with no rewrite needed here.
func _move_menu_focus(delta: int) -> void:
	if _reachable_buttons.is_empty():
		return
	var new_index: int = clampi(_focused_menu_index + delta, 0, _reachable_buttons.size() - 1)
	if new_index != _focused_menu_index:
		_set_menu_focus(new_index)


## Sets keyboard focus to _reachable_buttons[index], reverting the
## previously-focused item's glow to baseline and raising the new one.
##
## KNOWN MINOR EDGE CASE: this and UiAnimationNode's mouse-hover tween both
## drive the same glow_intensity parameter independently. If the mouse
## hovers then leaves Start while it's ALSO keyboard-focused, mouse_exited
## will revert glow to baseline even though keyboard focus is still active
## — the two aren't unified into one focus-state source of truth. Minor/
## rare in practice with a single reachable item; worth a proper unified
## focus manager if this becomes a real problem once more items exist.
func _set_menu_focus(index: int) -> void:
	if _focused_menu_index >= 0 and _focused_menu_index < _reachable_buttons.size():
		_set_button_glow(_reachable_buttons[_focused_menu_index], BASELINE_GLOW_INTENSITY)
	_focused_menu_index = index
	_set_button_glow(_reachable_buttons[_focused_menu_index], FOCUS_GLOW_INTENSITY)


func _set_button_glow(button: Button, intensity: float) -> void:
	if button.material is ShaderMaterial:
		(button.material as ShaderMaterial).set_shader_parameter("glow_intensity", intensity)


## Activates whichever button currently holds keyboard focus — the
## keyboard-confirm equivalent of a mouse click.
func _confirm_menu_focus() -> void:
	if _focused_menu_index < 0 or _focused_menu_index >= _reachable_buttons.size():
		return
	_reachable_buttons[_focused_menu_index].pressed.emit()


## Fires on Start being pressed, by mouse OR keyboard confirm (both funnel
## here — see _setup_menu_input). Begins the fade transition (§7).
func _on_start_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	_begin_transition()


## §7: fade through the scene's own fog color (TRANSITION_FOG_COLOR — see
## its own doc comment on why this is currently a placeholder, not real
## fog), not a plain black fade, not a hard cut.
func _begin_transition() -> void:
	# Block further mouse input during the transition. Keyboard input is
	# separately blocked via the _transitioning check in do_action() above —
	# this overlay's mouse_filter has no effect on that custom system.
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var tween: Tween = create_tween()
	tween.tween_property(_fade_overlay, "color", TRANSITION_FOG_COLOR, TRANSITION_FADE_DURATION)
	tween.tween_callback(_on_transition_covered)


## Called once the fade has fully covered the screen. This is where the
## actual hand-off into Character Creation chunk 1 belongs — but that scene
## doesn't exist anywhere in the codebase yet (confirmed: scenes/ only has
## title/ at this point), so there's nothing real to change_scene() to.
## Left as a clearly-marked stub rather than a change_scene() call that
## would just fail against a nonexistent path. Whoever builds Character
## Creation's scene skeleton should replace this print with the real
## register_scene()/change_scene() call, and give that scene's own on_enter()
## a matching fade-IN from this same fog color, so the cut reads as
## continuous rather than as fade-out-then-hard-cut.
func _on_transition_covered() -> void:
	print("TitleScreen: transition complete, screen covered by fog-color placeholder. Character Creation hand-off not wired — that scene doesn't exist yet.")
