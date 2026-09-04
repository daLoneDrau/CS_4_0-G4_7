## Static utility owning chargen-process state for the point-buy economy:
## the character's Historic/Heroic/Super-heroic tier, and (point-based
## method only) the PC Points pool spent against it.
##
## Lives on Entity.set_meta()/get_meta(), not a component — both values are
## chargen-process state with no post-chargen meaning, same category as
## chunk 1's creation-method toggle (CHARACTER_CREATION_ENGINEERING_NOTES.md
## §14). Kept as a static-helpers class (no state of its own), matching the
## existing Gender.gd precedent, rather than an autoload/singleton Node —
## there's nothing here that needs to persist independent of the Entity
## whose meta it's reading/writing.
##
## Why tier and pool share one file rather than two: pool is a pure
## function of tier (Historic->125, Heroic->150, Super-heroic->175), not
## independently rolled — see Character_Creation_Expanded_Content.md §2 and
## this session's design discussion. Splitting them would separate a value
## from the single fact that determines it.
##
## Multi-chunk contract: chunk 2 rolls tier for every character (both
## creation methods) and, for point-based only, initializes the pool from
## it. Chunks 3-6 (Background, Family & Circumstance, Character & Traits,
## Character Size) spend against the same pool via spend()/refund() as they
## get built — always through this class, never by touching the meta keys
## directly, so a typo in a later chunk can't silently desync the balance.
class_name PCPointsMeta
extends RefCounted

## —————————————————————————————————————————————
#region Meta Keys (private — nothing outside this file should read/write
## these directly)
## —————————————————————————————————————————————

const KEY_TIER: StringName = &"chargen_character_tier"
const KEY_POINTS_TOTAL: StringName = &"chargen_pc_points_total"
const KEY_POINTS_REMAINING: StringName = &"chargen_pc_points_remaining"

#endregion

## —————————————————————————————————————————————
#region Tier
## —————————————————————————————————————————————

const TIER_HISTORIC: StringName = &"historic"
const TIER_HEROIC: StringName = &"heroic"
const TIER_SUPER_HEROIC: StringName = &"super_heroic"

## D100 tier roll table (house rule — not in the source C&S text; this
## session's own design decision, weighted toward Historic to match the
## GDD's low-fantasy tonal target, Chivalry___Sorcery_GDD.md §0).
## 1-70 Historic / 71-90 Heroic / 91-100 Super-heroic.
const _TIER_ROLL_HISTORIC_MAX: int = 70
const _TIER_ROLL_HEROIC_MAX: int = 90
## (91-100 falls through to Super-heroic)

## Attribute max per tier (Character_Creation_Expanded_Content.md §2,
## "MAXIMUM & MINIMUM ATTRIBUTES"). Minimum is universal (2, not
## tier-dependent) and intentionally not owned here — it belongs with
## whichever script/component actually generates Attribute values, not
## with this points/tier utility.
const _ATTRIBUTE_MAX_BY_TIER: Dictionary[StringName, int] = {
	TIER_HISTORIC: 20,
	TIER_HEROIC: 22,
	TIER_SUPER_HEROIC: 25,
	}

## PC Points starting pool per tier, point-based method only
## (Character_Creation_Expanded_Content.md §2 /
## STEPS_IN_CHARACTER_CREATION.md — 125/150/175, mapped 1:1 to tier per
## this session's design decision).
const _POOL_BY_TIER: Dictionary[StringName, int] = {
	TIER_HISTORIC: 125,
	TIER_HEROIC: 150,
	TIER_SUPER_HEROIC: 175,
	}


## True once this entity's tier has been rolled/set. Distinguishes "never
## touched" from "explicitly Historic" — Historic is also the fallback
## default, so a value-based sentinel (unlike gender's NEUTRAL) isn't
## reliable here; has_meta() is the real signal.
static func has_tier(entity: Entity) -> bool:
	return entity.has_meta(KEY_TIER)


## Rolls a tier per the D100 table above. Pure function, no Entity/meta
## side effects — callers combine this with set_tier().
static func roll_tier() -> StringName:
	var r: int = randi() % 100 + 1
	if r <= _TIER_ROLL_HISTORIC_MAX:
		return TIER_HISTORIC
	elif r <= _TIER_ROLL_HEROIC_MAX:
		return TIER_HEROIC
	else:
		return TIER_SUPER_HEROIC


static func set_tier(entity: Entity, tier: StringName) -> void:
	entity.set_meta(KEY_TIER, tier)


## Defaults to Historic if never set — callers that need to distinguish
## "never set" from "explicitly Historic" should check has_tier() first.
static func get_tier(entity: Entity) -> StringName:
	return entity.get_meta(KEY_TIER, TIER_HISTORIC) as StringName


## Rolls and stores a tier only if this entity doesn't have one yet, then
## returns the (possibly pre-existing) value. First-visit-only, mirroring
## chunk 1's gender-roll pattern (chunk_1_identity_method.gd
## _mount_gender()) — a Back-navigation revisit must reflect the stored
## tier, never re-roll it.
static func ensure_tier(entity: Entity) -> StringName:
	if not has_tier(entity):
		set_tier(entity, roll_tier())
	return get_tier(entity)


## The Attribute ceiling for this entity's current tier (defaults to
## Historic's 20 if tier was never set — see get_tier()).
static func attribute_max(entity: Entity) -> int:
	return _ATTRIBUTE_MAX_BY_TIER.get(get_tier(entity), 20)

#endregion

## —————————————————————————————————————————————
#region PC Points Pool (point-based creation method only — random-method
## chunks should never call init_pool()/spend()/refund())
## —————————————————————————————————————————————

static func has_pool(entity: Entity) -> bool:
	return entity.has_meta(KEY_POINTS_TOTAL)


## Derives the starting pool from this entity's tier (rolling/storing one
## first via ensure_tier() if needed) and stores both total and remaining.
## Idempotent guard: does nothing if a pool already exists, so a
## Back-navigation revisit to chunk 2 doesn't silently reset an
## in-progress spend back to full.
static func init_pool(entity: Entity) -> void:
	if has_pool(entity):
		return
	var tier: StringName = ensure_tier(entity)
	var amount: int = _POOL_BY_TIER.get(tier, _POOL_BY_TIER[TIER_HISTORIC])
	entity.set_meta(KEY_POINTS_TOTAL, amount)
	entity.set_meta(KEY_POINTS_REMAINING, amount)


static func get_total(entity: Entity) -> int:
	return entity.get_meta(KEY_POINTS_TOTAL, 0) as int


static func get_remaining(entity: Entity) -> int:
	return entity.get_meta(KEY_POINTS_REMAINING, 0) as int


static func can_spend(entity: Entity, amount: int) -> bool:
	return amount >= 0 and get_remaining(entity) >= amount


## Returns false (and makes no change) if amount would overdraw the
## remaining balance — deliberately bool-only, no reason string, matching
## ChargenChunk.can_advance()'s own contract (chargen_chunk.gd) so callers
## handle "why" entirely in their own UI, same as that precedent.
static func spend(entity: Entity, amount: int) -> bool:
	if not can_spend(entity, amount):
		return false
	entity.set_meta(KEY_POINTS_REMAINING, get_remaining(entity) - amount)
	return true


## No upper-bound guard against total — refunds beyond the starting pool
## would indicate a caller bug (spending more than was ever granted), not
## a state this class should silently clamp and hide.
static func refund(entity: Entity, amount: int) -> void:
	entity.set_meta(KEY_POINTS_REMAINING, get_remaining(entity) + amount)

#endregion
