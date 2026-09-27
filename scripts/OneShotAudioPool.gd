extends Node3D

var source_stream: AudioStream
var sample_duration := 0.2
var sample_spacing := 0.3
var sample_volume_db := 0.0
var sample_max_distance := 18.0
var sample_unit_size := 3.0
var voice_count := 4

var sample_starts: PackedFloat32Array = PackedFloat32Array()
var voices: Array[AudioStreamPlayer3D] = []
var stop_timers: Array[Timer] = []
var next_voice_index := 0

func configure(stream: AudioStream, duration: float, spacing: float, volume_db: float, max_distance: float, unit_size: float, pool_size: int):
    sample_duration = maxf(0.04, duration)
    sample_spacing = maxf(sample_duration, spacing)
    sample_volume_db = volume_db
    sample_max_distance = max_distance
    sample_unit_size = unit_size
    voice_count = maxi(1, pool_size)
    _set_stream(stream)
    _create_voices()

func set_stream(stream: AudioStream):
    _set_stream(stream)
    for voice in voices:
        voice.stream = source_stream
    _rebuild_sample_starts()

func set_sample_starts(starts: PackedFloat32Array):
    sample_starts.clear()
    if source_stream == null:
        return
    var last_start := maxf(0.0, source_stream.get_length() - sample_duration)
    for start in starts:
        if start >= 0.0 and start <= last_start:
            sample_starts.append(start)
    if sample_starts.is_empty():
        _rebuild_sample_starts()

func _set_stream(stream: AudioStream):
    source_stream = stream
    _rebuild_sample_starts()

func _create_voices():
    for child in get_children():
        child.queue_free()
    voices.clear()
    stop_timers.clear()
    next_voice_index = 0
    for index in range(voice_count):
        var voice := AudioStreamPlayer3D.new()
        voice.name = "OneShotVoice_%02d" % index
        voice.stream = source_stream
        voice.volume_db = sample_volume_db
        voice.max_distance = sample_max_distance
        voice.unit_size = sample_unit_size
        voice.max_polyphony = 1
        add_child(voice)
        voices.append(voice)

        var timer := Timer.new()
        timer.name = "OneShotStop_%02d" % index
        timer.one_shot = true
        timer.timeout.connect(_stop_voice.bind(index))
        add_child(timer)
        stop_timers.append(timer)

func _rebuild_sample_starts():
    sample_starts.clear()
    if source_stream == null:
        return
    var last_start := maxf(0.0, source_stream.get_length() - sample_duration)
    var start := minf(0.03, last_start)
    while start <= last_start:
        sample_starts.append(start)
        start += sample_spacing
    if sample_starts.is_empty():
        sample_starts.append(0.0)

func play_random_one_shot():
    if voices.is_empty() or sample_starts.is_empty():
        return
    var voice_index := next_voice_index
    next_voice_index = (next_voice_index + 1) % voices.size()
    var voice := voices[voice_index]
    var timer := stop_timers[voice_index]
    timer.stop()
    voice.stop()
    voice.pitch_scale = randf_range(0.98, 1.02)
    voice.play(sample_starts[randi_range(0, sample_starts.size() - 1)])
    timer.start(sample_duration)

func _stop_voice(voice_index: int):
    if voice_index >= 0 and voice_index < voices.size():
        voices[voice_index].stop()
