extends CanvasLayer

const UITheme = preload("res://ui/ui_theme.gd")

# Interrogation & Ritual Verdict UI
# Works with any suspect defined in CaseManager.SUSPECTS and automatically surfaces
# CaseManager.RITUAL_KEYWORDS in both interrogation questions and the Final Ritual Altar!
signal closed
signal verdict_chosen(accused_id: String)

var modal_bg: ColorRect
var portrait_rect: TextureRect
var name_lbl: Label
var role_lbl: Label
var bio_lbl: Label
var wave_bars: Array[ColorRect] = []
var panic_bar: ProgressBar
var panic_lbl: Label

var chat_log: RichTextLabel
var quick_flow: HFlowContainer
var clue_flow: HFlowContainer
var question_input: LineEdit
var ask_btn: Button

var verdict_bg: ColorRect
var ritual_summary_lbl: Label
var verdict_buttons_box: VBoxContainer

var current_suspect: String = ""
var _pending_hero_txt: String = ""
var _wave_time: float = 0.0


func _ready() -> void:
	_build_interrogation_modal()
	_build_verdict_modal()
	AIInterrogator.reply_ready.connect(_on_ai_reply)


func _process(delta: float) -> void:
	if not modal_bg.visible:
		return
	_wave_time += delta * 14.0
	var lvl: float = AudioManager.get_voice_level()
	var speaking: bool = AudioManager.is_voice_playing()

	for i in range(wave_bars.size()):
		var bar: ColorRect = wave_bars[i]
		var target_h: float = 4.0
		if speaking:
			var wave: float = 0.45 + 0.55 * absf(sin(_wave_time + float(i) * 0.65))
			target_h = clampf(4.0 + lvl * 34.0 * wave, 5.0, 34.0)
		bar.custom_minimum_size.y = lerpf(bar.custom_minimum_size.y, target_h, 18.0 * delta)
		bar.color = Color("#ffbe5c") if speaking else Color("#3c354a")


func _build_interrogation_modal() -> void:
	modal_bg = ColorRect.new()
	modal_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_bg.color = Color(0.02, 0.015, 0.035, 0.88)
	modal_bg.visible = false
	add_child(modal_bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	modal_bg.add_child(margin)

	var frame: PanelContainer = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.make_panel(Color("#130f1cf8"), Color("#d8a657"), 12, 2))
	margin.add_child(frame)

	var main_hbox: HBoxContainer = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 20)
	frame.add_child(main_hbox)

	var left_col: VBoxContainer = VBoxContainer.new()
	left_col.custom_minimum_size = Vector2(275, 0)
	left_col.add_theme_constant_override("separation", 10)
	main_hbox.add_child(left_col)

	var port_frame: PanelContainer = PanelContainer.new()
	port_frame.add_theme_stylebox_override("panel", UITheme.make_panel(Color("#09070e"), Color("#b88946"), 8, 2))
	left_col.add_child(port_frame)

	portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = Vector2(248, 232)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	port_frame.add_child(portrait_rect)

	name_lbl = Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 21)
	name_lbl.add_theme_color_override("font_color", Color("#ffe09c"))
	left_col.add_child(name_lbl)

	role_lbl = Label.new()
	role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_lbl.add_theme_font_size_override("font_size", 14)
	role_lbl.add_theme_color_override("font_color", Color("#b8a898"))
	left_col.add_child(role_lbl)

	var wave_panel: PanelContainer = PanelContainer.new()
	wave_panel.add_theme_stylebox_override("panel", UITheme.make_panel(Color("#0b0912"), Color("#4d3e5e"), 6, 1))
	left_col.add_child(wave_panel)

	var wave_hbox: HBoxContainer = HBoxContainer.new()
	wave_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	wave_hbox.custom_minimum_size = Vector2(0, 34)
	wave_hbox.add_theme_constant_override("separation", 5)
	wave_panel.add_child(wave_hbox)

	wave_bars.clear()
	for i in range(16):
		var bar: ColorRect = ColorRect.new()
		bar.custom_minimum_size = Vector2(8, 5)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.color = Color("#3c354a")
		wave_hbox.add_child(bar)
		wave_bars.append(bar)

	panic_lbl = Label.new()
	panic_lbl.add_theme_font_size_override("font_size", 14)
	panic_lbl.add_theme_color_override("font_color", Color("#f2cad2"))
	left_col.add_child(panic_lbl)

	panic_bar = ProgressBar.new()
	panic_bar.custom_minimum_size = Vector2(0, 15)
	panic_bar.max_value = 100
	panic_bar.show_percentage = false
	UITheme.style_bar(panic_bar, Color("#e04868"))
	left_col.add_child(panic_bar)

	bio_lbl = Label.new()
	bio_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bio_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bio_lbl.add_theme_font_size_override("font_size", 13)
	bio_lbl.add_theme_color_override("font_color", Color("#9f96ad"))
	left_col.add_child(bio_lbl)

	var right_col: VBoxContainer = VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 10)
	main_hbox.add_child(right_col)

	var header: HBoxContainer = HBoxContainer.new()
	right_col.add_child(header)

	var h_title: Label = Label.new()
	h_title.text = "🔥 ОКНО ИИ-ДОПРОСА И ПРОВЕРКИ УЛИК"
	h_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_title.add_theme_font_size_override("font_size", 19)
	h_title.add_theme_color_override("font_color", Color("#ffd685"))
	header.add_child(h_title)

	var close_btn: Button = Button.new()
	close_btn.text = "Завершить разговор [ESC]"
	UITheme.style_button(close_btn, Color("#d95b72"))
	close_btn.pressed.connect(close_interrogation)
	header.add_child(close_btn)

	var chat_panel: PanelContainer = PanelContainer.new()
	chat_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_panel.add_theme_stylebox_override("panel", UITheme.make_panel(Color("#0b0811"), Color("#4b3c58"), 8, 1))
	right_col.add_child(chat_panel)

	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = true
	chat_log.scroll_following = true
	chat_log.selection_enabled = true
	chat_log.add_theme_font_size_override("normal_font_size", 16)
	chat_log.add_theme_font_size_override("bold_font_size", 16)
	chat_log.add_theme_font_size_override("italics_font_size", 15)
	chat_panel.add_child(chat_log)

	quick_flow = HFlowContainer.new()
	quick_flow.add_theme_constant_override("h_separation", 8)
	quick_flow.add_theme_constant_override("v_separation", 6)
	right_col.add_child(quick_flow)

	clue_flow = HFlowContainer.new()
	clue_flow.add_theme_constant_override("h_separation", 8)
	clue_flow.add_theme_constant_override("v_separation", 6)
	right_col.add_child(clue_flow)

	var input_row: HBoxContainer = HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 10)
	right_col.add_child(input_row)

	question_input = LineEdit.new()
	question_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question_input.placeholder_text = "Спросить своими словами (или упомянуть ключевой рунный знак)..."
	UITheme.style_line_edit(question_input)
	question_input.text_submitted.connect(func(_t): _on_ask_pressed())
	input_row.add_child(question_input)

	ask_btn = Button.new()
	ask_btn.text = "Спросить [Enter]"
	UITheme.style_button(ask_btn, Color("#e8b059"))
	ask_btn.pressed.connect(_on_ask_pressed)
	input_row.add_child(ask_btn)


func _build_verdict_modal() -> void:
	verdict_bg = ColorRect.new()
	verdict_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	verdict_bg.color = Color(0.03, 0.01, 0.02, 0.92)
	verdict_bg.visible = false
	add_child(verdict_bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	verdict_bg.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(720, 420)
	card.add_theme_stylebox_override("panel", UITheme.make_panel(Color("#180e1af8"), Color("#e8b059"), 12, 3))
	center.add_child(card)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	var title: Label = Label.new()
	title.text = "⚖ АЛТАРЬ РИТУАЛА И ВЕРДИКТА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#ffd685"))
	vbox.add_child(title)

	ritual_summary_lbl = Label.new()
	ritual_summary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ritual_summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ritual_summary_lbl.add_theme_font_size_override("font_size", 15)
	ritual_summary_lbl.add_theme_color_override("font_color", Color("#ead8dc"))
	vbox.add_child(ritual_summary_lbl)

	verdict_buttons_box = VBoxContainer.new()
	verdict_buttons_box.add_theme_constant_override("separation", 10)
	vbox.add_child(verdict_buttons_box)

	var cancel_btn: Button = Button.new()
	cancel_btn.text = "Вернуться в песочницу [ESC]"
	UITheme.style_button(cancel_btn, Color("#8a7e96"))
	cancel_btn.pressed.connect(func():
		AudioManager.stop_voice()
		verdict_bg.visible = false
		CaseManager.ui_locked = false
	)
	vbox.add_child(cancel_btn)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if modal_bg.visible:
			close_interrogation()
			get_viewport().set_input_as_handled()
		elif verdict_bg.visible:
			AudioManager.stop_voice()
			verdict_bg.visible = false
			CaseManager.ui_locked = false
			get_viewport().set_input_as_handled()


func open_interrogation(suspect_id: String) -> void:
	current_suspect = suspect_id
	CaseManager.ui_locked = true
	modal_bg.visible = true

	var info: Dictionary = CaseManager.SUSPECTS[suspect_id]
	if ResourceLoader.exists(str(info["portrait"])):
		portrait_rect.texture = load(str(info["portrait"]))
	name_lbl.text = str(info["name"])
	role_lbl.text = str(info["title"])
	bio_lbl.text = str(info["bio"])
	_refresh_panic()

	var hero_title: String = CaseManager.get_hero_title()
	var hero_open_txt: String = "Начинаю допрос. Назови то, что тебе известно о тайне каземата."
	var greet_txt: String = str(info["greet"])
	var greet_vid: String = str(info.get("voice_greet", "test_voice_sample"))

	chat_log.clear()
	var hist: Array = CaseManager.chat_history.get(suspect_id, [])
	if hist.is_empty():
		var h_line: String = "[b][color=#7ce8ff]%s:[/color][/b] «%s»\n" % [hero_title, hero_open_txt]
		var s_line: String = "[b][color=#ffd27d]%s:[/color][/b] «%s»\n\n" % [str(info["name"]), greet_txt]
		CaseManager.append_chat(suspect_id, h_line)
		CaseManager.append_chat(suspect_id, s_line)
		chat_log.append_text(h_line + s_line)
	else:
		for line in hist:
			chat_log.append_text(str(line))

	AudioManager.speak_line(greet_vid, suspect_id)
	_rebuild_buttons()
	question_input.grab_focus()


func _rebuild_buttons() -> void:
	for c in quick_flow.get_children():
		c.queue_free()
	for c in clue_flow.get_children():
		c.queue_free()

	for q_txt in CaseManager.get_unlocked_questions_for(current_suspect):
		var b: Button = Button.new()
		b.text = q_txt
		UITheme.style_button(b, Color("#8fa8dc"), Color("#1a1626"))
		b.pressed.connect(_send_question.bind(q_txt, ""))
		quick_flow.add_child(b)

	if CaseManager.collected_clues.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "Улик пока нет — подберите светящуюся тестовую улику в комнате!"
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.add_theme_color_override("font_color", Color("#9a90aa"))
		clue_flow.add_child(empty_lbl)
	else:
		for cid in CaseManager.collected_clues:
			var cinfo: Dictionary = CaseManager.ALL_CLUES[cid]
			var cb: Button = Button.new()
			cb.text = "🔍 Предъявить: " + str(cinfo["title"])
			UITheme.style_button(cb, Color("#f0be6e"), Color("#241b1e"))
			cb.pressed.connect(_send_question.bind("Объясни происхождение этой улики и связь с тремя рунными знаками!", str(cid)))
			clue_flow.add_child(cb)


func _on_ask_pressed() -> void:
	var txt: String = question_input.text.strip_edges()
	if txt.is_empty():
		return
	question_input.text = ""
	_send_question(txt, "")


func _send_question(q_txt: String, clue_id: String) -> void:
	var hero_title: String = CaseManager.get_hero_title()
	var line: String = ""
	if not clue_id.is_empty():
		var title: String = str(CaseManager.ALL_CLUES[clue_id]["title"])
		line = "[b][color=#7ce8ff]%s:[/color][/b] [i][color=#ffd984](Предъявляет: %s)[/color][/i] «%s»\n" % [hero_title, title, q_txt]
	else:
		line = "[b][color=#7ce8ff]%s:[/color][/b] «%s»\n" % [hero_title, q_txt]

	_pending_hero_txt = q_txt
	CaseManager.append_chat(current_suspect, line)
	chat_log.append_text(line)
	AudioManager.play_sfx("blip", -5.0)
	AIInterrogator.ask_suspect(current_suspect, q_txt, clue_id)


func _on_ai_reply(suspect_id: String, reply_text: String, _panic_delta: int, _used_llm: bool, voice_id: String) -> void:
	if suspect_id != current_suspect or not modal_bg.visible:
		return
	var sname: String = str(CaseManager.SUSPECTS[suspect_id]["name"])
	var reply_line: String = "[b][color=#ffd27d]%s:[/color][/b] «%s»\n\n" % [sname, reply_text]
	CaseManager.append_chat(suspect_id, reply_line)
	chat_log.append_text(reply_line)

	AudioManager.speak_line(voice_id, suspect_id, reply_text)
	_refresh_panic()
	_rebuild_buttons()


func _refresh_panic() -> void:
	var val: int = int(CaseManager.suspect_panic.get(current_suspect, 0))
	panic_bar.value = val
	panic_lbl.text = "Напряжение: %d%%" % val


func close_interrogation() -> void:
	AudioManager.stop_voice()
	modal_bg.visible = false
	CaseManager.ui_locked = false
	closed.emit()


func open_verdict_menu() -> void:
	CaseManager.ui_locked = true
	verdict_bg.visible = true

	for c in verdict_buttons_box.get_children():
		c.queue_free()

	var words_str: String = " • ".join(CaseManager.get_ritual_keywords())
	ritual_summary_lbl.text = "Собрано улик: %d / %d\nКлючевые рунные знаки ритуала (RITUAL_KEYWORDS):\n[ %s ]" % [
		CaseManager.collected_clues.size(), CaseManager.ALL_CLUES.size(), words_str
	]

	for sid in CaseManager.SUSPECTS.keys():
		var sinfo: Dictionary = CaseManager.SUSPECTS[sid]
		var b: Button = Button.new()
		b.text = "🔥 Завершить ритуал / Вынести вердикт: %s (%s)" % [str(sinfo["name"]), words_str]
		UITheme.style_button(b, Color("#ffbe42"), Color("#3b1522"))
		b.pressed.connect(func():
			verdict_bg.visible = false
			verdict_chosen.emit(str(sid))
		)
		verdict_buttons_box.add_child(b)
