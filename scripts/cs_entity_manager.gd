class_name CSEntityManager
extends EntityManager

## Concrete EntityManager for Chivalry & Sorcery.
##
## At this stage (Title Screen scene/UI construction) no entities exist in
## play yet — chargen hasn't been built, so there's no PC, no items, no
## equipment, no spells to reason about. The bodies below are therefore
## deliberately minimal, honest stand-ins rather than real implementations:
## each is commented with what it actually needs once the relevant system
## (equipment, spellcasting, scripting) exists. Revisit when Character
## Creation construction begins.


## An entity is a PC if it carries the PC tag from PlayerTags.
func is_pc(e: Entity) -> bool:
	return e != null and e.tags.has(PlayerTags.Tag.PC)


## NOTE: item_component.gd's ItemComponent is itself @abstract — no concrete
## item component subclass exists in the repo yet, so there's currently no
## real component name to check for. Returns false until a concrete item
## component type exists to test against.
func is_item(_e: Entity) -> bool:
	return false


## No uniqueness rules have been designed yet (no roster/equipment system
## in play at this stage). Defaulting to "nothing is unique" is the safe,
## inert choice until that system exists.
func is_unique(_e: Entity) -> bool:
	return false


## Spell system isn't wired into any scene yet at this stage — no-op.
func kill_spells_on(_e_id: String) -> void:
	pass


## Equipment system isn't wired into any scene yet at this stage — no-op,
## reports "nothing was unequipped" rather than silently claiming success.
func unequip_from_inventory(_player_entity: Entity, _item_entity: Entity) -> bool:
	return false


## Scripting system isn't wired into any scene yet at this stage — no-op.
func send_init_script_event(_entity: Entity) -> void:
	pass
