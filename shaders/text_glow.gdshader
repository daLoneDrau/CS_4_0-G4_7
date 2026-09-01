shader_type canvas_item;

// Soft glow for legible UI/display text (TITLE_SCREEN_UI_UX.md §3). Draws
// the font's own crisp glyph on top of a soft blurred glow of the same
// shape, in a single pass on the text node itself — no duplicate node
// needed behind it.
//
// glow_intensity is the parameter TITLE_SCREEN_UI_UX.md §6 tweens on
// hover/keyboard-focus ("focus increases the glow already used for text
// legibility") via UiAnimationNode's hover_shader_parameter support.
//
// CAVEAT — verify visually once in-editor, can't run Godot from this
// environment to confirm: this samples a few pixels outside each glyph's
// own UV rect within the font's dynamic texture atlas. Godot's font
// rendering normally leaves a few pixels of padding around each glyph for
// its own antialiasing, which is usually enough headroom for this small a
// blur radius — but if bleeding/artifacts from neighboring glyphs show up
// at some font size, the safe fallback is rendering the text to a
// SubViewport and blurring that isolated texture instead.

uniform float glow_radius : hint_range(0.0, 4.0) = 1.5;
uniform vec4 glow_color : source_color = vec4(0.95, 0.9, 0.78, 1.0);
uniform float glow_intensity : hint_range(0.0, 3.0) = 1.0;

void fragment() {
	// COLOR at this point is the engine's default result for this fragment
	// (font_color tinted by the glyph texture's alpha coverage) — capture
	// it before overwriting, rather than re-deriving it from raw TEXTURE.
	vec4 sharp = COLOR;

	vec2 px = TEXTURE_PIXEL_SIZE * glow_radius;
	float glow_alpha = 0.0;
	glow_alpha += texture(TEXTURE, UV + vec2(-px.x, -px.y)).a;
	glow_alpha += texture(TEXTURE, UV + vec2( 0.0,  -px.y)).a;
	glow_alpha += texture(TEXTURE, UV + vec2( px.x, -px.y)).a;
	glow_alpha += texture(TEXTURE, UV + vec2(-px.x,  0.0)).a;
	glow_alpha += texture(TEXTURE, UV + vec2( px.x,  0.0)).a;
	glow_alpha += texture(TEXTURE, UV + vec2(-px.x,  px.y)).a;
	glow_alpha += texture(TEXTURE, UV + vec2( 0.0,   px.y)).a;
	glow_alpha += texture(TEXTURE, UV + vec2( px.x,  px.y)).a;
	glow_alpha = (glow_alpha / 8.0) * glow_intensity;

	vec3 out_rgb = mix(glow_color.rgb, sharp.rgb, sharp.a);
	float out_alpha = max(sharp.a, glow_alpha * glow_color.a);

	COLOR = vec4(out_rgb, out_alpha);
}
