shader_type spatial;
render_mode unshaded, cull_disabled;

// PS1-era vertex-snap + affine texture warp.
// Canon per CHIVALRY___SORCERY_GDD.md §1 / Architecture Decision Log; full
// reasoning in CHARACTER_CREATION_ENGINEERING_NOTES.md §6. Applies uniformly
// across all 3D scenes (GDD §1) — Title Screen's `earthworks` backdrop is the
// first retrofit target (build step #2, not part of this file).
//
// Two independent PS1 hallmarks, each a separately-tunable effect on the same
// material:
//
// 1. VERTEX SNAP — quantizes clip-space vertex positions to a coarse grid
//    before the perspective divide, reproducing the geometry "wobble" caused
//    by original PS1 hardware's fixed-point (not floating-point) vertex
//    transforms.
//
// 2. AFFINE TEXTURE WARP — fakes perspective-INCORRECT (screen-space-linear)
//    UV interpolation, reproducing the "swimming texture" look. True affine
//    mapping would need a `noperspective` varying qualifier, which Godot's
//    shader language doesn't currently expose — confirmed via the engine
//    repo's open, unmerged PR #114021 ("Add `noperspective` back into
//    glslang and add Affine texture mapping to BaseMaterial3D"), not assumed.
//    Workaround: scale UV by clip-space W in vertex(), then divide back out
//    in fragment(). This cancels Godot's automatic perspective-correct
//    varying interpolation as a side effect, yielding true screen-space-
//    linear (affine) UVs. Note this uses clip-space W specifically, not
//    VERTEX.z as the engineering notes phrase it loosely — W is the exact
//    quantity Godot's interpolator divides by, and is proportional to
//    view-space depth for a standard perspective projection, so the two
//    descriptions point at the same underlying technique. Same trick
//    referenced in established community Godot PSX shader work
//    (MenacingMecha's `godot-psx-style-demo`; the widely-referenced PS1
//    shader on godotshaders.com) — not a novel invention here.
//
// LIGHTING MODEL: unshaded, driven entirely by baked vertex color (COLOR,
// sourced from glTF COLOR_0 — confirmed present on earthworks.glb) modulating
// the albedo texture. Matches TITLE_SCREEN_UI_UX.md §8.5's baked-vertex-
// lighting intent. Deliberately does NOT respond to scene DirectionalLight3D/
// ambient — the *current* earthworks Material.tres does respond to those
// (plain StandardMaterial3D, no vertex-color flag set), which is the
// discrepancy this shader is intentionally resolving, not preserving.
//
// cull_disabled matches the current earthworks Material.tres (cull_mode = 2,
// i.e. CULL_DISABLED) so the retrofit (step #2) doesn't silently change
// backface behavior.
//
// Vertex-snap grid resolution and warp strength are exposed as tunable
// hint_range uniforms with starting defaults, not locked values — same
// pattern already established by shaders/text_glow.gdshader's glow_radius/
// glow_intensity. Tune in-editor once running against real geometry; this
// can't be visually verified from this environment.

uniform sampler2D albedo_texture : source_color, filter_nearest;

uniform float vertex_snap_resolution : hint_range(16.0, 640.0) = 320.0;
uniform float vertex_snap_strength : hint_range(0.0, 1.0) = 1.0;
uniform float affine_warp_strength : hint_range(0.0, 1.0) = 1.0;

// UV pre-scaled by clip-space W, and W itself, both left to interpolate via
// Godot's default (perspective-correct) varying behavior. Dividing the two
// back apart in fragment() yields affine (non-perspective-corrected) UVs —
// see the technique note above.
varying vec2 warped_uv;
varying float warp_w;

void vertex() {
	vec4 clip_pos = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	float w = clip_pos.w;

	// --- Affine texture warp setup ---
	warped_uv = UV * w;
	warp_w = w;

	// --- Vertex snap ---
	// Quantize NDC xy to a coarse grid, blended by strength, then restore to
	// clip space (multiply back by w) so POSITION receives a normal
	// pre-divide clip-space value as Godot expects.
	vec3 ndc = clip_pos.xyz / w;
	vec2 snapped_xy = floor(ndc.xy * vertex_snap_resolution) / vertex_snap_resolution;
	ndc.xy = mix(ndc.xy, snapped_xy, vertex_snap_strength);
	clip_pos.xyz = ndc * w;

	POSITION = clip_pos;
}

void fragment() {
	// UV here is Godot's own perspective-correct interpolation of the
	// built-in UV varying. uv_affine is the screen-space-linear (affine)
	// reconstruction described above. Blend between them by strength rather
	// than hard-switching, so the effect can be dialed back without being
	// structurally disabled.
	vec2 uv_affine = warped_uv / warp_w;
	vec2 uv = mix(UV, uv_affine, affine_warp_strength);

	vec4 tex = texture(albedo_texture, uv);
	ALBEDO = tex.rgb * COLOR.rgb;
	ALPHA = tex.a;
}
