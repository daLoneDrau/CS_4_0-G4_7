## Catch-all for C&S-specific character-sheet fields that don't warrant
## their own single-purpose component and aren't covered by
## AbilitiesComponent (Attributes) or the engine's generic components
## (DescriptionComponent, etc.). Deliberately a departure from this
## project's single-purpose-component convention (see CSRaceComponent's
## own header, CHARACTER_CREATION_ENGINEERING_NOTES.md §15) — Aspect alone
## wasn't judged big enough to warrant a dedicated file. Revisit the split
## if this file grows enough fields to need one.
##
## Aspect (Birth Omens): Character_Creation_Expanded_Content.md §1.
## Random method: rolled once via D100, final, no reroll. Point-based
## method: defaults to Neutral, player may spend/refund PC Points
## (PCPointsMeta) to change it. Poorly Aspected obligates at least one
## Curse — a field that lives in chunk 4 (Family & Circumstance), not yet
## built. Flagging that as this component's downstream dependency now,
## per the chunk-completion rule (CHARACTER_CREATION_ENGINEERING_NOTES.md
## §4): chunk 4, once built, must check aspect == ASPECT_POORLY and
## require a Curse selection.
class_name CSCharacterComponent
extends EntityComponent

const IS_SLOT_ROOT: bool = true

## Aspect values — StringName constants rather than an enum, matching
## CSRaceComponent's content-data-friendly convention, even though (unlike
## race) this is a closed, rules-fixed set of three with no future-content
## table anticipated.
const ASPECT_WELL: StringName = &"well_aspected"
const ASPECT_NEUTRAL: StringName = &"neutrally_aspected"
const ASPECT_POORLY: StringName = &"poorly_aspected"

## Default for both creation methods before chunk 2 resolves it — random
## method immediately overwrites via roll; point-based method's default
## *is* Neutral, so this doubles as that method's real starting value.
const DEFAULT_ASPECT: StringName = ASPECT_NEUTRAL

## Emitted when aspect changes.
signal aspect_changed(entity_id: String, old_aspect: StringName, new_aspect: StringName)

@export var aspect: StringName = DEFAULT_ASPECT:
	set(value):
		if aspect != value:
			var old := aspect
			aspect = value
			if _lifecycle_initialized:
				aspect_changed.emit(parent_entity_id, old, value)
				emit_update_signal()


## —————————————————————————————————————————————
#region Initialization
## —————————————————————————————————————————————

func _init() -> void:
	super()
	_register_broadcasters()


func _register_broadcasters() -> void:
	Switchboard_auto.add_resource_broadcaster(
		self,
		"aspect_changed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)


func _unregister_broadcasters() -> void:
	Switchboard_auto.remove_resource_broadcaster(self, "aspect_changed")

#endregion

## —————————————————————————————————————————————
#region Lifecycle
## —————————————————————————————————————————————

func on_added(entity: Entity, em: EntityManager) -> void:
	super.on_added(entity, em)


func on_removed(entity: Entity, em: EntityManager) -> void:
	super.on_removed(entity, em)


func _unregister_from_switchboard() -> void:
	_unregister_broadcasters()
	super._unregister_from_switchboard()

#endregion

## —————————————————————————————————————————————
#region State Queries
## —————————————————————————————————————————————

func is_poorly_aspected() -> bool:
	return aspect == ASPECT_POORLY

#endregion

## —————————————————————————————————————————————
#region Serialization
## —————————————————————————————————————————————

func to_dict() -> Dictionary:
	return {
		"key": get_class_name(),
		"enabled": enabled,
		"aspect": String(aspect),
	}


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	aspect = StringName(data.get("aspect", DEFAULT_ASPECT))

#endregion

## —————————————————————————————————————————————
#region Debug
## —————————————————————————————————————————————

func _to_string() -> String:
	return "CSCharacterComponent[%s](aspect=%s)" % [parent_entity_id, aspect]


func print_debug() -> void:
	print("=== CSCharacterComponent Debug ===")
	print("  Entity: %s" % parent_entity_id)
	print("  Aspect: %s" % aspect)


func get_summary() -> Dictionary:
	return {
		"entity_id": parent_entity_id,
		"aspect": String(aspect),
	}

#endregion
