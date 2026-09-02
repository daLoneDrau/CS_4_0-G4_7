class_name CharacterCreation
extends Scene

## Character Creation — chunk 1 entry point. DELIBERATELY EMPTY at this
## build step: this exists only so TitleScreen's Start button has a real
## destination to transition into. Full behavior spec lives in
## CHARACTER_CREATION_UI_UX.md and STEPS_IN_CHARACTER_CREATION.md — none of
## that is implemented here yet. That's the next build session's work.
##
## What DOES work here: the fade-IN half of the fog-color transition (§7),
## so arriving from Title Screen reads as one continuous cut rather than
## fading to fog and then hard-cutting into whatever this scene's default
## state is. See TitleScreen._begin_transition() for the fade-OUT half.

const FADE_IN_DURATION: float = 0.6

@onready var _fade_overlay: ColorRect = %FadeOverlay


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


## Required override — Scene.do_action() is abstract. No input handling
## designed for this scene yet — real chargen input starts next session.
func do_action(_action: GameAction) -> void:
	pass
