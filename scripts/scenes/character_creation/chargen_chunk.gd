@abstract class_name ChargenChunk
extends Control

## Shared contract every chargen chunk scene (chunk 1-7) extends.
## Decision + full reasoning: CHARACTER_CREATION_ENGINEERING_NOTES.md §3.
##
## Lifecycle model (per that decision, confirmed explicitly — not the only
## option considered): the stepper controller (build step #6, not yet
## implemented) instantiates a chunk's .tscn FRESH on every mount and frees
## it on unmount. Chunks are stateless views over the draft Entity — the
## Entity is the single persistent source of truth (see engineering notes
## §2), not this node. That means:
##   - mount() must fully repopulate this chunk's controls from the current
##     state of `entity` every time it's called, since the same chunk
##     instance is never reused across visits.
##   - there is deliberately no unmount()/save-back hook. If a concrete
##     chunk writes to the Entity only on some explicit action (e.g. a
##     "confirm" button) rather than live as the player edits fields, any
##     in-progress-but-unconfirmed edit is lost when the stepper frees this
##     node on Back/Next — that's a concrete-chunk design concern, not
##     something this base class tries to solve generically.
##
## This class intentionally defines nothing beyond what the stepper needs to
## drive navigation. Exact shape kept minimal on purpose (engineering notes
## §3) — chunk-specific concerns (validation UI, layout, downstream-
## dependency declarations) belong in each concrete chunk, not here.

## The draft character. Set by mount() — read-only from a chunk's own code
## after that (a chunk should never reassign this to a different Entity).
var entity: Entity


## Called by the stepper immediately after instancing this chunk and adding
## it to the scene tree, before it becomes visible/interactive. Populates
## `entity` and gives the concrete chunk a hook to sync its controls to the
## Entity's current values.
##
## Base implementation only stores the reference — override to additionally
## populate controls, but subclasses overriding this MUST call
## `super.mount(entity)` (or otherwise set `self.entity`) so `entity` and
## `get_player_entity()` stay valid.
func mount(character: Entity) -> void:
	entity = character


## Called by the stepper when the player attempts to advance (Next). Return
## false to block advancing — e.g. required input missing/invalid. Default:
## never blocks. Override in chunks that have advance-blocking validation.
##
## Deliberately returns only a bool, not a reason string — how a chunk
## communicates *why* it's blocking (inline field error, disabled Next
## button, etc.) is that chunk's own UI concern, not part of this contract.
## See engineering notes §3: kept to "the minimal contract the stepper
## needs," not a general validation-messaging system.
func can_advance() -> bool:
	return true
