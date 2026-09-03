class_name Chunk3Background
extends ChargenChunk

## Generic placeholder for chunks 2-7 (build step #7) — exists to exercise
## the stepper end-to-end (mount/unmount/Next/Back/progress indicator).
## NOT any chunk's real UI/fields; those are undesigned —
## CHARACTER_CREATION_UI_UX.md §6 explicitly lists chunks 2, 4-7 as having
## no chunk-specific decisions made at all, and chunk 3/Background's data
## is drafted in the GDD (§3.3) but its on-screen UI isn't specced either.
##
## Chunk 1 has its own script (chunk_1_identity_method.gd) since it needs a
## real, changeable value for build step #8 (downstream-dependency/reset)
## to hook into. These six chunks need no such thing at this build step, so
## one shared stub script covers all of them rather than six near-identical
## files.

@export var chunk_label_text: String = "Chunk (stub)"

@onready var _chunk_label: Label = %ChunkLabel


func mount(character: Entity) -> void:
	super.mount(character)
	_chunk_label.text = chunk_label_text