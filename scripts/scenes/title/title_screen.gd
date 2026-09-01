class_name TitleScreen
extends Scene

## Title Screen — MVP entry point. Full behavior spec: TITLE_SCREEN_UI_UX.md.
##
## Scope at THIS build step (scene skeleton only): registering as a working
## Scene subclass with a non-blank placeholder. Layout (§2), logotype (§4),
## menu (§5), glow (§3/§6), input (§6), and transition (§7) are later build
## steps — none of that lives here yet.

@onready var _backdrop: ColorRect = %Backdrop
@onready var _title_label: Label = %TitleLabel
@onready var _menu_list: VBoxContainer = %MenuList


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
# Glow effect (§3/§6), keyboard/mouse input wiring (§6), and Start's
# actual scene-transition connection (§7) are later build steps —
# the menu exists structurally here but isn't wired to anything yet.


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


## Required override — Scene.do_action() is abstract. Real input-action
## routing (§6: keyboard nav skipping disabled items, confirm) is a later
## build step; this is a safe no-op until then, not a forgotten stub.
func do_action(_action: GameAction) -> void:
	pass
