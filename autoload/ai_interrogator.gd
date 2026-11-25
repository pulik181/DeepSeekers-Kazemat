extends Node

# AI & Offline Interrogation Engine
# Integrates CaseManager.RITUAL_KEYWORDS into LLM system prompts and offline fallback responses.
signal reply_ready(suspect_id: String, reply_text: String, panic_delta: int, used_llm: bool, voice_id: String)

const RITUAL_KEYWORDS: Array[String] = CaseManager.RITUAL_KEYWORDS

var http_req: HTTPRequest
var _timeout_timer: Timer
var _pending_suspect: String = ""
var _pending_question: String = ""
var _pending_clue: String = ""
var _waiting_llm: bool = false


func _ready() -> void:
	http_req = HTTPRequest.new()
	add_child(http_req)
	http_req.request_completed.connect(_on_llm_completed)

	_timeout_timer = Timer.new()
	_timeout_timer.wait_time = 6.5
	_timeout_timer.one_shot = true
	_timeout_timer.timeout.connect(_on_llm_timeout)
	add_child(_timeout_timer)


func ask_suspect(suspect_id: String, question: String, presented_clue_id: String = "") -> void:
	_pending_suspect = suspect_id
	_pending_question = question
	_pending_clue = presented_clue_id

	var api_key: String = CaseManager.custom_api_key.strip_edges()
	if api_key.is_empty():
		api_key = OS.get_environment("LLM_API_KEY")
	var api_url: String = CaseManager.custom_api_url.strip_edges()
	if api_url.is_empty():
		api_url = OS.get_environment("LLM_API_URL")

	if api_key.is_empty() and not OS.get_environment("GEMINI_API_KEY").is_empty():
		api_key = OS.get_environment("GEMINI_API_KEY")
		if api_url.is_empty():
			api_url = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
			CaseManager.custom_api_model = "gemini-3.5-flash-lite"

	if not api_key.is_empty() and not api_url.is_empty():
		if _try_send_llm_request(suspect_id, question, presented_clue_id, api_url, api_key):
			return

	_generate_offline_reply(suspect_id, question, presented_clue_id)


func _try_send_llm_request(suspect_id: String, question: String, clue_id: String, url: String, key: String) -> bool:
	http_req.cancel_request()
	var sys_prompt: String = _build_system_prompt(suspect_id)
	var user_prompt: String = question
	if not clue_id.is_empty() and CaseManager.ALL_CLUES.has(clue_id):
		var c: Dictionary = CaseManager.ALL_CLUES[clue_id]
		user_prompt = "Дознаватель предъявляет улику «%s» (%s) и спрашивает: %s" % [
			str(c["title"]), str(c["desc"]), question
		]

	var payload: Dictionary = {
		"model": CaseManager.custom_api_model,
		"messages": [
			{"role": "system", "content": sys_prompt},
			{"role": "user", "content": user_prompt},
		],
		"max_tokens": 150,
		"temperature": 0.72,
	}
	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + key,
	])
	var err: int = http_req.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err == OK:
		_waiting_llm = true
		_timeout_timer.start()
		return true
	return false


func _on_llm_timeout() -> void:
	if _waiting_llm:
		_waiting_llm = false
		http_req.cancel_request()
		_generate_offline_reply(_pending_suspect, _pending_question, _pending_clue)


func _on_llm_completed(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not _waiting_llm:
		return
	_waiting_llm = false
	_timeout_timer.stop()

	if code == 200:
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary and parsed.has("choices"):
			var choices: Array = parsed["choices"]
			if not choices.is_empty():
				var txt: String = str(choices[0]["message"]["content"]).strip_edges()
				if not txt.is_empty():
					_apply_panic(_pending_suspect, 6)
					reply_ready.emit(_pending_suspect, txt, 6, true, "")
					return

	_generate_offline_reply(_pending_suspect, _pending_question, _pending_clue)


func _build_system_prompt(suspect_id: String) -> String:
	var sinfo: Dictionary = CaseManager.SUSPECTS.get(suspect_id, {"name": "Узник", "title": "Подозреваемый"})
	var role_txt: String = str(sinfo.get("prompt_role", sinfo.get("bio", "")))
	var words_str: String = ", ".join(CaseManager.get_ritual_keywords())
	return "Ты %s (%s). %s Органично вплетай в контекст расследования ключевые рунные символы дела: [%s]. Отвечай атмосферно, 2-3 предложениями на русском языке без звёздочек." % [
		str(sinfo["name"]), str(sinfo["title"]), role_txt, words_str
	]


func _generate_offline_reply(suspect_id: String, question: String, clue_id: String) -> void:
	var q: String = question.to_lower()
	var words: Array[String] = CaseManager.get_ritual_keywords()
	var w1: String = words[0] if words.size() > 0 else "ПЕПЕЛ"
	var w2: String = words[1] if words.size() > 1 else "ПЕЧАТЬ"
	var w3: String = words[2] if words.size() > 2 else "КЛЯТВА"
	var reply: String = ""
	var p_delta: int = 5

	if not clue_id.is_empty() and CaseManager.ALL_CLUES.has(clue_id):
		var ctitle: String = str(CaseManager.ALL_CLUES[clue_id]["title"])
		reply = "Ты нашёл «%s»! На камне высечены три древних знака: «%s», «%s» и «%s». Теперь путь к Алтарю Ритуала открыт!" % [
			ctitle, w1, w2, w3
		]
		p_delta = 12
		_apply_panic(suspect_id, p_delta)
		reply_ready.emit(suspect_id, reply, p_delta, false, "")
		return

	for w in words:
		if not w.is_empty() and w.to_lower() in q:
			reply = "Рунный знак «%s» — часть древнего пророчества казематов. Сопоставь его с остальными символами (%s, %s) у Алтаря!" % [
				w, w1, w2
			]
			_apply_panic(suspect_id, 8)
			reply_ready.emit(suspect_id, reply, 8, false, "")
			return

	if "улик" in q or "спрятан" in q:
		reply = "Осмотри светящийся рунный осколок в центре каменного зала и предъяви его мне во время допроса."
	else:
		reply = "Стены каземата хранят молчание. Помни о трёх рунных знаках этого дела: «%s», «%s», «%s»." % [
			w1, w2, w3
		]

	_apply_panic(suspect_id, p_delta)
	reply_ready.emit(suspect_id, reply, p_delta, false, "")


func _apply_panic(suspect_id: String, delta: int) -> void:
	var cur: int = int(CaseManager.suspect_panic.get(suspect_id, 0))
	CaseManager.suspect_panic[suspect_id] = clampi(cur + delta, 0, 100)
