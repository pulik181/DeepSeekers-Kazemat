extends Node

# Investigation Chain & RPG State Engine
# Manages character attributes, clue inventory, progression flags, and RITUAL_KEYWORDS.
signal state_changed
signal clue_added(clue_id: String)
signal chain_unlocked(flag_id: String, announcement: String)

# Core symbolic keywords linking clues, dialogue prompts, and the final ritual altar
const RITUAL_KEYWORDS: Array[String] = ["ПЕПЕЛ", "ПЕЧАТЬ", "КЛЯТВА"]
var ritual_keywords: Array[String] = RITUAL_KEYWORDS.duplicate()

var custom_api_url: String = ""
var custom_api_key: String = ""
var custom_api_model: String = "gpt-4o-mini"

# Character Customization
var hero_gender: String = "m"  # "m" / "f"
var hero_skin: int = 0         # 0..2
var hero_element: int = 0      # 0=Fire, 1=Ice, 2=Lightning, 3=Shadow
var spell_mode: int = 0        # 0=Delayed Seal AoE, 1=Shooting Elemental Bolt (toggle with Q)

const HERO_SKINS: Array[Dictionary] = [
	{
		"name": "Багровый Дознаватель",
		"perk": "+5 к урону мечом, тёплый факельный свет",
		"light_color": Color("#ffb65c"),
	},
	{
		"name": "Следопыт Казематов",
		"perk": "+30 к выносливости, изумрудный фонарь",
		"light_color": Color("#7ef7c4"),
	},
	{
		"name": "Хранитель Рун",
		"perk": "+10 к силе стихий и широкий луч фонаря",
		"light_color": Color("#9ed8ff"),
	},
]

const ELEMENTS: Array[Dictionary] = [
	{
		"id": "fire",
		"name": "🔥 Пламя",
		"desc": "Высокий огненный урон по площади и взрывные снаряды",
		"color": Color("#ff8438"),
		"dmg_bonus": 16,
	},
	{
		"id": "ice",
		"name": "❄ Стужа",
		"desc": "Морозные чары сковывают и замедляют врагов на 2.5 сек.",
		"color": Color("#6ce6ff"),
		"dmg_bonus": 6,
	},
	{
		"id": "lightning",
		"name": "⚡ Молния",
		"desc": "Стремительные грозовые разряды с шоковым импульсом",
		"color": Color("#ffe854"),
		"dmg_bonus": 12,
	},
	{
		"id": "shadow",
		"name": "🌑 Тьма",
		"desc": "Магия Бездны вытягивает жизненные силы врагов (+HP)",
		"color": Color("#c864ff"),
		"dmg_bonus": 8,
	},
]

# Suspect Dictionary
var SUSPECTS: Dictionary = {
	"suspect_template": {
		"name": "Узник Каземата",
		"title": "Свидетель древнего обряда",
		"portrait": "res://assets/portraits/suspect_template.png",
		"sprite": "res://assets/sprites/suspect_template.png",
		"greet": "Фонарь дознавателя редко спускается так глубоко. Отыщи рунный осколок в зале и расспроси меня о знаках ритуала!",
		"voice_greet": "test_voice_sample",
		"accent": Color("#8be068"),
		"bio": "Узник подземного яруса, знающий тайну древних печатей и ключевых рун каземата.",
		"prompt_role": "Ты таинственный узник древнего подземелья, которого допрашивает дознаватель.",
	},
}

# Clues Dictionary
var ALL_CLUES: Dictionary = {
	"clue_template_1": {
		"title": "Улика №1: Рунный Осколок",
		"desc": "Древний каменный фрагмент, найденный в каземате. На осколке высечены три знака: %s." % ", ".join(RITUAL_KEYWORDS),
		"act": 1,
		"unlocks_flag": "sandbox_gate_unlocked",
		"unlock_msg": "🔓 Улика изучена! Сработал механизм ворот: Алтарь Ритуала и новые вопросы допроса открыты!",
	},
}

var current_act: int = 1
var ui_locked: bool = false
var spawn_tag: String = "sandbox_start"

var player_hp: int = 135
var player_max_hp: int = 135
var player_stamina: float = 100.0
var player_max_stamina: float = 100.0

var gold: int = 30
var hp_potions: int = 2
var stamina_tonics: int = 2
var bonus_sword_dmg: int = 0
var bonus_magic_dmg: int = 0

var collected_clues: Array[String] = []
var unlocked_flags: Dictionary = {}
var opened_chests: Dictionary = {}
var suspect_panic: Dictionary = {"suspect_template": 15}
var chat_history: Dictionary = {"suspect_template": []}


func load_case_config(new_suspects: Dictionary, new_clues: Dictionary, keywords: Array = []) -> void:
	if not keywords.is_empty():
		set_ritual_keywords(keywords)
	SUSPECTS = new_suspects.duplicate(true)
	ALL_CLUES = new_clues.duplicate(true)
	reset_case()


func set_ritual_keywords(words: Array) -> void:
	ritual_keywords.clear()
	for w in words:
		ritual_keywords.append(str(w))
	if ALL_CLUES.has("clue_template_1"):
		ALL_CLUES["clue_template_1"]["desc"] = "Древний каменный фрагмент, найденный в каземате. На осколке высечены три знака: %s." % ", ".join(ritual_keywords)
	state_changed.emit()


func get_ritual_keywords() -> Array[String]:
	return ritual_keywords


func get_hero_voice_key() -> String:
	return "hero_f" if hero_gender == "f" else "hero_m"


func get_hero_title() -> String:
	return "Дознавательница" if hero_gender == "f" else "Дознаватель"


func get_hero_sprite_path() -> String:
	return "res://assets/sprites/inquisitor_%s_%d.png" % [hero_gender, clampi(hero_skin, 0, 2)]


func get_hero_portrait_path() -> String:
	return "res://assets/portraits/hero_f.png" if hero_gender == "f" else "res://assets/portraits/hero_m.png"


func get_skin_data() -> Dictionary:
	return HERO_SKINS[clampi(hero_skin, 0, 2)]


func get_element_data() -> Dictionary:
	return ELEMENTS[clampi(hero_element, 0, 3)]


func toggle_spell_mode() -> void:
	spell_mode = 1 - spell_mode
	AudioManager.play_sfx("blip", -3.0)
	state_changed.emit()


func reset_case() -> void:
	current_act = 1
	ui_locked = false
	spawn_tag = "sandbox_start"
	spell_mode = 0

	player_max_hp = 135
	player_hp = player_max_hp
	player_max_stamina = 130.0 if hero_skin == 1 else 100.0
	player_stamina = player_max_stamina

	gold = 30
	hp_potions = 2
	stamina_tonics = 2
	bonus_sword_dmg = 5 if hero_skin == 0 else 0
	bonus_magic_dmg = (10 if hero_skin == 2 else 0) + int(get_element_data()["dmg_bonus"] / 2)

	collected_clues.clear()
	unlocked_flags.clear()
	opened_chests.clear()
	suspect_panic.clear()
	chat_history.clear()
	for sid in SUSPECTS.keys():
		suspect_panic[sid] = 15
		chat_history[sid] = []
	state_changed.emit()


func use_healing_potion() -> bool:
	if hp_potions <= 0 or player_hp >= player_max_hp:
		return false
	hp_potions -= 1
	player_hp = mini(player_max_hp, player_hp + 60)
	AudioManager.play_sfx("loot", -2.0)
	state_changed.emit()
	return true


func use_stamina_tonic() -> bool:
	if stamina_tonics <= 0 or player_stamina >= player_max_stamina - 5.0:
		return false
	stamina_tonics -= 1
	player_stamina = player_max_stamina
	AudioManager.play_sfx("loot", -2.0)
	state_changed.emit()
	return true


func grant_chest_loot(chest_id: String, gold_amt: int, add_hp_pot: int, add_stam_pot: int, upg_sword: int = 0) -> String:
	opened_chests[chest_id] = true
	gold += gold_amt
	hp_potions += add_hp_pot
	stamina_tonics += add_stam_pot
	bonus_sword_dmg += mini(upg_sword, 5)
	AudioManager.play_sfx("loot", -1.0)
	state_changed.emit()

	var parts: Array[String] = ["+%d золота" % gold_amt]
	if add_hp_pot > 0: parts.append("+%d Зелье HP [1]" % add_hp_pot)
	if add_stam_pot > 0: parts.append("+%d Бодрость [2]" % add_stam_pot)
	if upg_sword > 0: parts.append("+%d к мечу!" % mini(upg_sword, 5))
	return "💰 Сундук открыт: " + ", ".join(parts)


func has_flag(flag_id: String) -> bool:
	return bool(unlocked_flags.get(flag_id, false))


func unlock_flag(flag_id: String, announcement: String = "") -> void:
	if not has_flag(flag_id):
		unlocked_flags[flag_id] = true
		AudioManager.play_sfx("gate", -1.5)
		if not announcement.is_empty():
			chain_unlocked.emit(flag_id, announcement)
		state_changed.emit()


func add_clue(clue_id: String) -> void:
	if ALL_CLUES.has(clue_id) and not collected_clues.has(clue_id):
		collected_clues.append(clue_id)
		AudioManager.play_sfx("clue", -1.5)
		var cinfo: Dictionary = ALL_CLUES[clue_id]
		var flag_to_unlock: String = str(cinfo.get("unlocks_flag", ""))
		var msg: String = str(cinfo.get("unlock_msg", ""))
		if not flag_to_unlock.is_empty():
			unlock_flag(flag_to_unlock, msg)
		clue_added.emit(clue_id)
		state_changed.emit()


func get_unlocked_questions_for(_suspect_id: String) -> Array[String]:
	var qs: Array[String] = [
		"Что произошло в этом каземате?",
		"Какие улики спрятаны поблизости?",
	]
	for w in ritual_keywords:
		if not w.strip_edges().is_empty():
			qs.append("Что означает рунный знак «%s»?" % w)
	return qs


func append_chat(suspect_id: String, formatted_line: String) -> void:
	if not chat_history.has(suspect_id) or chat_history[suspect_id] == null:
		chat_history[suspect_id] = []
	chat_history[suspect_id].append(formatted_line)


func travel_to(scene_path: String, target_spawn_tag: String) -> void:
	AudioManager.stop_voice()
	AudioManager.play_sfx("gate", -2.0)
	ui_locked = false
	spawn_tag = target_spawn_tag
	get_tree().change_scene_to_file(scene_path)
