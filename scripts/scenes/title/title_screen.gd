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
# Menu content/glow/input wiring: later build steps.


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


## Required override — Scene.do_action() is abstract. Real input-action
## routing (§6: keyboard nav skipping disabled items, confirm) is a later
## build step; this is a safe no-op until then, not a forgotten stub.
func do_action(_action: GameAction) -> void:
	pass