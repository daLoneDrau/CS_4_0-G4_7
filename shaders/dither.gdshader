shader_type canvas_item;

// Ordered (Bayer) dithering + color-depth quantization, applied as a
// post-process on the low-res 3D backdrop before it's stretched to the
// full-res canvas. Companion to shaders/ps1_warp.gdshader — that shader
// handles the 3D-side geometry/UV warp, this one handles the PS1's
// actual 15-bit (5-bit-per-channel) color limitation, which the
// original hardware hid behind dithering rather than smooth banding.
//
// Applied to the `Backdrop` TextureRect in title_screen.tscn, which
// displays the Viewport3D SubViewport's output (480x270). The dither
// threshold is computed from that SOURCE texture's pixel grid (via
// TEXTURE_PIXEL_SIZE), not the final on-screen pixel grid, so the grain
// stays locked to the same blockiness as the nearest-neighbor upscale
// instead of being a fine pattern riding on top of chunky pixels.
//
// bits / matrix_size / dither_strength are tunable uniforms, same
// pattern as ps1_warp.gdshader's strength params — dial in-editor, not
// locked here.

uniform float bits : hint_range(2.0, 8.0) = 5.0; // 5 = period-accurate PS1 (15-bit color, 5 bits/channel)
uniform float matrix_size : hint_range(4.0, 8.0) = 4.0; // only 4 or 8 are used; anything <=6 rounds to 4
uniform float dither_strength : hint_range(0.0, 1.0) = 1.0; // blend between plain quantized and fully dithered

const float BAYER_4X4[16] = float[](
	0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

const float BAYER_8X8[64] = float[](
	0.0, 48.0, 12.0, 60.0,  3.0, 51.0, 15.0, 63.0,
	32.0, 16.0, 44.0, 28.0, 35.0, 19.0, 47.0, 31.0,
	8.0, 56.0,  4.0, 52.0, 11.0, 59.0,  7.0, 55.0,
	40.0, 24.0, 36.0, 20.0, 43.0, 27.0, 39.0, 23.0,
	2.0, 50.0, 14.0, 62.0,  1.0, 49.0, 13.0, 61.0,
	34.0, 18.0, 46.0, 30.0, 33.0, 17.0, 45.0, 29.0,
	10.0, 58.0,  6.0, 54.0,  9.0, 57.0,  5.0, 53.0,
	42.0, 26.0, 38.0, 22.0, 41.0, 25.0, 37.0, 21.0
);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	vec2 source_pixel = floor(UV / TEXTURE_PIXEL_SIZE);
	bool use_8x8 = matrix_size > 6.0;
	int size = use_8x8 ? 8 : 4;
	int x = int(mod(source_pixel.x, float(size)));
	int y = int(mod(source_pixel.y, float(size)));
	int idx = y * size + x;

	float threshold = use_8x8
		? (BAYER_8X8[idx] + 0.5) / 64.0
		: (BAYER_4X4[idx] + 0.5) / 16.0;

	float levels = pow(2.0, bits) - 1.0;
	vec3 dithered = floor(tex.rgb * levels + threshold) / levels;
	vec3 plain_quantized = floor(tex.rgb * levels + 0.5) / levels;

	COLOR = vec4(mix(plain_quantized, dithered, dither_strength), tex.a);
}