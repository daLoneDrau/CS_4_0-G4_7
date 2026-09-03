## Tracks an entity's race — currently Human-only at MVP, sized for more
## later (Character_creation_UI_UX.md §4). Kept as its own single-purpose
## component rather than folded into DescriptionComponent, matching the
## project's existing single-purpose-component convention (see
## AbilitiesComponent/ReputationComponent; GDD §3.3's BackgroundComponent/
## SetOfSkills split cites the same rationale).
class_name CSRaceComponent
extends EntityComponent

const IS_SLOT_ROOT: bool = true

## Default/only legal value at MVP. StringName key rather than an enum —
## deliberately content-data-friendly (matches ReputationComponent's
## faction_id and the direction SetOfSkills/skill ids are heading, GDD
## §3.3) even though no race content-data table exists yet to key into.
const DEFAULT_RACE: StringName = &"human"

## Emitted when race changes.
signal race_changed(entity_id: String, old_race: StringName, new_race: StringName)

@export var race: StringName = DEFAULT_RACE:
	set(value):
		if race != value:
			var old := race
			race = value
			if _lifecycle_initialized:
				race_changed.emit(parent_entity_id, old, value)
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
		"race_changed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)


func _unregister_broadcasters() -> void:
	Switchboard_auto.remove_resource_broadcaster(self, "race_changed")

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
#region Serialization
## —————————————————————————————————————————————

func to_dict() -> Dictionary:
	return {
		"key": get_class_name(),
		"enabled": enabled,
		"race": String(race),
	}


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	race = StringName(data.get("race", DEFAULT_RACE))

#endregion

## —————————————————————————————————————————————
#region Debug
## —————————————————————————————————————————————

func _to_string() -> String:
	return "RaceComponent[%s](%s)" % [parent_entity_id, race]


func print_debug() -> void:
	print("=== RaceComponent Debug ===")
	print("  Entity: %s" % parent_entity_id)
	print("  Race: %s" % race)


func get_summary() -> Dictionary:
	return {
		"entity_id": parent_entity_id,
		"race": String(race),
		}

#endregion
