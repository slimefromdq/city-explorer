class_name PlaceholderSfx
extends RefCounted
## Tiny synthesized sounds so every action has an audio tell before real audio
## exists. Each sound is a pitch sweep (plus optional noise) generated once and
## cached. Swap these for real files later by assigning streams in the scenes.

const MIX_RATE := 22050

static var _cache := {}


## A sweep from f_start to f_end Hz over `duration` seconds. `noise` (0..1)
## mixes in white noise for whooshes.
static func sweep(key: String, f_start: float, f_end: float, duration: float, volume := 0.4, noise := 0.0) -> AudioStreamWAV:
	if _cache.has(key):
		return _cache[key]
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	for i in n:
		var t := float(i) / float(n)
		var f := lerpf(f_start, f_end, t)
		phase += TAU * f / MIX_RATE
		var env := minf(1.0, t * 40.0) * pow(1.0 - t, 1.6)
		var s := sin(phase) * (1.0 - noise) + rng.randf_range(-1.0, 1.0) * noise
		var v := int(clampf(s * env * volume, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = data
	_cache[key] = w
	return w
