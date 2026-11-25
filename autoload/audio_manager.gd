extends Node

# Audio Manager v7 with automatic Music Ducking during Voice Playback
# so Protagonist & NPC voices always sound loud, crisp, and foregrounded!
signal live_tts_busy_changed(is_busy: bool)

const VOICE_PITCH: Dictionary = {
	"narrator": 0.97,
	"hero_m": 1.00,
	"hero_f": 1.02,
	"judge": 0.80,
	"herbalist": 1.06,
	"guard": 0.96,
	"malachai": 1.08,
	"villager_f": 1.04,
	"villager_m": 0.96,
	"mother": 1.05,
	"miller": 1.02,
	"elder": 0.89,
	"blacksmith": 0.84,
	"kids": 1.24,
	"slaver": 0.88,
	"boss": 0.72,
	"alchemist": 1.05,
	"knight": 0.93,
	"chronicler": 0.85,
}

var music_player: AudioStreamPlayer
var voice_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_idx: int = 0
var sounds: Dictionary = {}

var is_muted: bool = false
var music_volume: float = 0.65
var sfx_volume: float = 0.90
var voice_volume: float = 1.0

var _voice_bus_idx: int = 0
var _voice_queue: Array[Dictionary] = []
var _tts_thread: Thread = null
var _tts_pending_path: String = ""
var _tts_pending_speaker: String = "hero_m"
var _tts_counter: int = 0


func _ready() -> void:
	_setup_voice_bus()

	for sfx_name in [
		"slash", "firebolt", "dash", "hit", "clue", "verdict",
		"blip", "gate", "magic_charge", "magic_boom", "loot", "boss_roar"
	]:
		var p: String = "res://assets/audio/sfx_%s.wav" % sfx_name
		if ResourceLoader.exists(p):
			sounds[sfx_name] = load(p)

	music_player = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://assets/audio/ambient_prison.wav"):
		music_player.stream = load("res://assets/audio/ambient_prison.wav")
	music_player.finished.connect(_on_music_finished)
	add_child(music_player)

	voice_player = AudioStreamPlayer.new()
	voice_player.bus = "Voice"
	voice_player.finished.connect(_on_voice_finished)
	add_child(voice_player)

	for i in range(12):
		var sp: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(sp)
		sfx_pool.append(sp)

	apply_volumes()
	if music_player.stream:
		music_player.play()


func _process(delta: float) -> void:
	# Smooth music ducking so protagonist & character voices cut through crystal-clear!
	if music_player and not is_muted and music_volume > 0.01:
		var base_db: float = linear_to_db(maxf(0.01, music_volume)) - 4.0
		var target_db: float = (base_db - 8.5) if is_voice_playing() else base_db
		music_player.volume_db = lerpf(music_player.volume_db, target_db, 10.0 * delta)


func _setup_voice_bus() -> void:
	var idx: int = AudioServer.get_bus_index("Voice")
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "Voice")
		AudioServer.set_bus_send(idx, "Master")
		var reverb: AudioEffectReverb = AudioEffectReverb.new()
		reverb.room_size = 0.24
		reverb.damping = 0.76
		reverb.wet = 0.09
		reverb.dry = 0.98
		AudioServer.add_bus_effect(idx, reverb)
	_voice_bus_idx = idx


func apply_volumes() -> void:
	if music_player:
		music_player.stream_paused = is_muted or music_volume <= 0.01
		music_player.volume_db = linear_to_db(maxf(0.01, music_volume)) - 4.0
	if _voice_bus_idx >= 0 and _voice_bus_idx < AudioServer.bus_count:
		AudioServer.set_bus_mute(_voice_bus_idx, is_muted or voice_volume <= 0.01)
		AudioServer.set_bus_volume_db(_voice_bus_idx, linear_to_db(maxf(0.01, voice_volume)) + 3.5)
	if voice_player:
		voice_player.volume_db = 0.0


func _on_music_finished() -> void:
	if not is_muted and music_player.stream:
		music_player.play()


func _on_voice_finished() -> void:
	if not _voice_queue.is_empty():
		var next_item: Dictionary = _voice_queue.pop_front()
		_play_single_voice(str(next_item["vid"]), str(next_item["spk"]), str(next_item["txt"]))


func play_sfx(sfx_id: String, offset_db: float = -3.0) -> void:
	if is_muted or sfx_volume <= 0.01 or not sounds.has(sfx_id):
		return
	var p: AudioStreamPlayer = sfx_pool[sfx_idx]
	sfx_idx = (sfx_idx + 1) % sfx_pool.size()
	p.stream = sounds[sfx_id]
	p.volume_db = offset_db + linear_to_db(sfx_volume)
	p.pitch_scale = randf_range(0.93, 1.07)
	p.play()


func speak_line(voice_file_id: String, speaker_id: String = "narrator", fallback_text: String = "") -> void:
	if is_muted or voice_volume <= 0.01:
		return
	_voice_queue.clear()
	stop_voice_only()
	_play_single_voice(voice_file_id, speaker_id, fallback_text)


func queue_voice_line(voice_file_id: String, speaker_id: String = "narrator", fallback_text: String = "") -> void:
	if is_muted or voice_volume <= 0.01:
		return
	if is_voice_playing() or (_tts_thread != null and _tts_thread.is_alive()):
		_voice_queue.append({"vid": voice_file_id, "spk": speaker_id, "txt": fallback_text})
	else:
		_play_single_voice(voice_file_id, speaker_id, fallback_text)


func speak_hero_then_npc(hero_vid: String, hero_txt: String, npc_vid: String, npc_spk: String, npc_txt: String) -> void:
	if is_muted or voice_volume <= 0.01:
		return
	_voice_queue.clear()
	stop_voice_only()
	var hero_spk: String = CaseManager.get_hero_voice_key()
	_voice_queue.append({"vid": npc_vid, "spk": npc_spk, "txt": npc_txt})
	_play_single_voice(hero_vid, hero_spk, hero_txt)


func _play_single_voice(voice_file_id: String, speaker_id: String, fallback_text: String) -> void:
	voice_player.pitch_scale = float(VOICE_PITCH.get(speaker_id, 1.0))
	if not voice_file_id.is_empty():
		var res_path: String = "res://assets/voice/%s.mp3" % voice_file_id
		if ResourceLoader.exists(res_path):
			voice_player.stream = load(res_path)
			voice_player.play()
			return
	if not fallback_text.strip_edges().is_empty():
		speak_live_text(fallback_text, speaker_id)
	elif not _voice_queue.is_empty():
		_on_voice_finished()


func speak_live_text(text: String, speaker_id: String = "hero_m") -> void:
	if is_muted or voice_volume <= 0.01 or text.strip_edges().is_empty():
		return
	if _tts_thread != null and _tts_thread.is_alive():
		return
	if _tts_thread != null:
		_tts_thread.wait_to_finish()
		_tts_thread = null

	var worker_script: String = ProjectSettings.globalize_path("res://tools/live_tts_worker.py")
	if not FileAccess.file_exists(worker_script):
		return

	_tts_counter += 1
	var out_global: String = ProjectSettings.globalize_path("user://live_reply_%d.mp3" % (_tts_counter % 4))
	_tts_pending_path = out_global
	_tts_pending_speaker = speaker_id
	live_tts_busy_changed.emit(true)

	var clean_txt: String = text.replace("\"", "").replace("\n", " ").strip_edges()
	_tts_thread = Thread.new()
	_tts_thread.start(_run_tts_worker.bind(worker_script, speaker_id, out_global, clean_txt))


func _run_tts_worker(worker_script: String, speaker_id: String, out_global: String, clean_txt: String) -> void:
	var output: Array = []
	var args: PackedStringArray = PackedStringArray([worker_script, speaker_id, out_global, clean_txt])
	OS.execute("python", args, output, false, false)
	call_deferred("_on_tts_worker_done")


func _on_tts_worker_done() -> void:
	if _tts_thread != null:
		_tts_thread.wait_to_finish()
		_tts_thread = null
	live_tts_busy_changed.emit(false)

	if FileAccess.file_exists(_tts_pending_path):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(_tts_pending_path)
		if bytes.size() > 512:
			var stream: AudioStreamMP3 = AudioStreamMP3.new()
			stream.data = bytes
			stop_voice_only()
			voice_player.pitch_scale = float(VOICE_PITCH.get(_tts_pending_speaker, 1.0))
			voice_player.stream = stream
			voice_player.play()
			return
	# Fallback: if live TTS failed (e.g. offline), continue queued NPC response immediately
	if not _voice_queue.is_empty():
		_on_voice_finished()


func is_voice_playing() -> bool:
	return voice_player != null and voice_player.playing


func get_voice_level() -> float:
	if not is_voice_playing():
		return 0.0
	var db: float = AudioServer.get_bus_peak_volume_left_db(_voice_bus_idx, 0)
	return clampf(db_to_linear(db) * 1.9, 0.04, 1.0)


func stop_voice_only() -> void:
	if voice_player and voice_player.playing:
		voice_player.stop()
	DisplayServer.tts_stop()


func stop_voice() -> void:
	_voice_queue.clear()
	stop_voice_only()


func toggle_mute() -> bool:
	is_muted = not is_muted
	if is_muted:
		music_player.stop()
		stop_voice()
	elif music_player.stream:
		music_player.play()
	return is_muted


func _exit_tree() -> void:
	if _tts_thread != null:
		_tts_thread.wait_to_finish()
		_tts_thread = null
