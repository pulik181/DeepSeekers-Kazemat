extends Control

const UITheme = preload("res://ui/ui_theme.gd")

# Main Menu & Character Creation Screen
# Includes Title Screen, Character Creator (Gender, 3 Skins, 4 Elements),
# and Settings (Music, SFX, Voice Sliders + 3 RITUAL_KEYWORDS slots).

var title_screen: Control
var char_screen: Control
var settings_modal: ColorRect

var hero_portrait: TextureRect
var hero_sprite_preview: TextureRect
var skin_perk_lbl: Label
var elem_desc_lbl: Label
var btn_male: Button
var btn_female: Button
var skin_btns: Array[Button] = []
var elem_btns: Array[Button] = []
var word_inputs: Array[LineEdit] = []

var _bg_art: TextureRect
var _anim_t: float = 0.0


func _ready() -> void:
	CaseManager.ui_locked = false
	_build_all_screens()
	_refresh_creator_ui()


func _process(delta: float) -> void:
	_anim_t += delta
	if _bg_art:
		var z: float = 1.025 + sin(_anim_t * 0.35) * 0.015
		_bg_art.scale = Vector2(z, z)
		_bg_art.position = Vector2(sin(_anim_t * 0.25) * 6.0 - 16.0, cos(_anim_t * 0.20) * 4.0 - 10.0)


func _build_all_screens() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#08070d")
	add_child(bg)

	_bg_art = TextureRect.new()
	_bg_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_art.pivot_offset = Vector2(640, 360)
	if ResourceLoader.exists("res://assets/ui/menu_bg.png"):
		_bg_art.texture = load("res://assets/ui/menu_bg.png")
	add_child(_bg_art)

	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.03, 0.07, 0.28)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var embers: CPUParticles2D = CPUParticles2D.new()
	embers.position = Vector2(640, 730)
	embers.amount = 48
	embers.lifetime = 5.5
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(660, 20)
	embers.direction = Vector2(0, -1)
	embers.spread = 18.0
	embers.gravity = Vector2(0, -14)
	embers.initial_velocity_min = 35.0
	embers.initial_velocity_max = 85.0
	embers.scale_amount_min = 2.0
	embers.scale_amount_max = 4.5
	embers.color = Color(1.0, 0.74, 0.34, 0.50)
	add_child(embers)

	_build_title_screen()
	_build_character_screen()
	_build_settings_modal()


func _build_title_screen() -> void:
	title_screen = Control.new()
	title_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(title_screen)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_screen.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(480, 450)
	card.add_theme_stylebox_override("panel", UITheme.make_panel(Color(0.06, 0.05, 0.11, 0.80), Color("#e2b464"), 14, 2))
	center.add_child(card)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	card.add_child(vbox)

	var icon_center: HBoxContainer = HBoxContainer.new()
	icon_center.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(icon_center)

	var icon_frame: PanelContainer = PanelContainer.new()
	icon_frame.add_theme_stylebox_override("panel", UITheme.make_panel(Color("#09070e"), Color("#f0be6e"), 12, 2))
	icon_center.add_child(icon_frame)

	var icon_tex: TextureRect = TextureRect.new()
	icon_tex.custom_minimum_size = Vector2(112, 112)
	icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://icon.png"):
		icon_tex.texture = load("res://icon.png")
	icon_frame.add_child(icon_tex)

	var title_lbl: Label = Label.new()
	title_lbl.text = "КАЗЕМАТЫ ДОЗНАНИЯ"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 32)
	title_lbl.add_theme_color_override("font_color", Color("#ffe094"))
	vbox.add_child(title_lbl)

	var sub_lbl: Label = Label.new()
	sub_lbl.text = "Тёмно-фэнтезийная детективно-боевая RPG"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 15)
	sub_lbl.add_theme_color_override("font_color", Color("#b8a8cf"))
	vbox.add_child(sub_lbl)

	var btn_box: VBoxContainer = VBoxContainer.new()
	btn_box.custom_minimum_size = Vector2(340, 0)
	btn_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_box.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_box)

	var btn_play: Button = Button.new()
	btn_play.text = "⚔   НАЧАТЬ ИГРУ"
	btn_play.custom_minimum_size = Vector2(0, 48)
	btn_play.add_theme_font_size_override("font_size", 19)
	UITheme.style_button(btn_play, Color("#f0be6e"), Color("#2c1d18"))
	btn_play.pressed.connect(func():
		AudioManager.play_sfx("blip", -2.0)
		title_screen.visible = false
		char_screen.visible = true
		_refresh_creator_ui()
	)
	btn_box.add_child(btn_play)

	var btn_settings: Button = Button.new()
	btn_settings.text = "⚙   НАСТРОЙКИ"
	btn_settings.custom_minimum_size = Vector2(0, 44)
	btn_settings.add_theme_font_size_override("font_size", 16)
	UITheme.style_button(btn_settings, Color("#9db4ff"), Color("#191628"))
	btn_settings.pressed.connect(func():
		AudioManager.play_sfx("blip", -3.0)
		settings_modal.visible = true
	)
	btn_box.add_child(btn_settings)

	var btn_quit: Button = Button.new()
	btn_quit.text = "🚪   ВЫХОД"
	btn_quit.custom_minimum_size = Vector2(0, 42)
	btn_quit.add_theme_font_size_override("font_size", 16)
	UITheme.style_button(btn_quit, Color("#c85a70"), Color("#22141c"))
	btn_quit.pressed.connect(func(): get_tree().quit())
	btn_box.add_child(btn_quit)


func _build_character_screen() -> void:
	char_screen = Control.new()
	char_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	char_screen.visible = false
	add_child(char_screen)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	char_screen.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(940, 580)
	card.add_theme_stylebox_override("panel", UITheme.make_panel(Color(0.06, 0.05, 0.12, 0.88), Color("#e2b464"), 14, 2))
	center.add_child(card)

	var main_vb: VBoxContainer = VBoxContainer.new()
	main_vb.add_theme_constant_override("separation", 14)
	card.add_child(main_vb)

	var header: HBoxContainer = HBoxContainer.new()
	main_vb.add_child(header)

	var h_title: Label = Label.new()
	h_title.text = "ВЫБОР ГЕРОЯ И СТИХИИ МАГИИ"
	h_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_title.add_theme_font_size_override("font_size", 23)
	h_title.add_theme_color_override("font_color", Color("#ffe094"))
	header.add_child(h_title)

	var back_btn: Button = Button.new()
	back_btn.text = "← Назад"
	UITheme.style_button(back_btn, Color("#8a92a8"))
	back_btn.pressed.connect(func():
		char_screen.visible = false
		title_screen.visible = true
	)
	header.add_child(back_btn)

	var body_hb: HBoxContainer = HBoxContainer.new()
	body_hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hb.add_theme_constant_override("separation", 24)
	main_vb.add_child(body_hb)

	var prev_vb: VBoxContainer = VBoxContainer.new()
	prev_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	prev_vb.add_theme_constant_override("separation", 12)
	body_hb.add_child(prev_vb)

	var pframe: PanelContainer = PanelContainer.new()
	pframe.add_theme_stylebox_override("panel", UITheme.make_panel(Color("#08060c"), Color("#e8b462"), 10, 2))
	prev_vb.add_child(pframe)

	hero_portrait = TextureRect.new()
	hero_portrait.custom_minimum_size = Vector2(220, 220)
	hero_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pframe.add_child(hero_portrait)

	var sframe: PanelContainer = PanelContainer.new()
	sframe.add_theme_stylebox_override("panel", UITheme.make_panel(Color("#161222"), Color("#6d5a86"), 10, 1))
	prev_vb.add_child(sframe)

	hero_sprite_preview = TextureRect.new()
	hero_sprite_preview.custom_minimum_size = Vector2(220, 120)
	hero_sprite_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_sprite_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sframe.add_child(hero_sprite_preview)

	var opts_vb: VBoxContainer = VBoxContainer.new()
	opts_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opts_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	opts_vb.add_theme_constant_override("separation", 12)
	body_hb.add_child(opts_vb)

	var g_lbl: Label = Label.new()
	g_lbl.text = "1. ПОЛ И ОБЛИК ГЕРОЯ:"
	g_lbl.add_theme_font_size_override("font_size", 16)
	g_lbl.add_theme_color_override("font_color", Color("#ffd685"))
	opts_vb.add_child(g_lbl)

	var g_row: HBoxContainer = HBoxContainer.new()
	g_row.add_theme_constant_override("separation", 12)
	opts_vb.add_child(g_row)

	btn_male = Button.new()
	btn_male.text = "♂  Мужской (Дознаватель)"
	btn_male.custom_minimum_size = Vector2(0, 42)
	btn_male.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_male.pressed.connect(func():
		CaseManager.hero_gender = "m"
		AudioManager.play_sfx("blip", -3.0)
		_refresh_creator_ui()
	)
	g_row.add_child(btn_male)

	btn_female = Button.new()
	btn_female.text = "♀  Женский (Дознавательница)"
	btn_female.custom_minimum_size = Vector2(0, 42)
	btn_female.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_female.pressed.connect(func():
		CaseManager.hero_gender = "f"
		AudioManager.play_sfx("blip", -3.0)
		_refresh_creator_ui()
	)
	g_row.add_child(btn_female)

	var sk_lbl: Label = Label.new()
	sk_lbl.text = "2. СНАРЯЖЕНИЕ И СВЕТ ФОНАРЯ:"
	sk_lbl.add_theme_font_size_override("font_size", 16)
	sk_lbl.add_theme_color_override("font_color", Color("#ffd685"))
	opts_vb.add_child(sk_lbl)

	var sk_row: HBoxContainer = HBoxContainer.new()
	sk_row.add_theme_constant_override("separation", 10)
	opts_vb.add_child(sk_row)

	skin_btns.clear()
	for s_idx in range(CaseManager.HERO_SKINS.size()):
		var sb: Button = Button.new()
		sb.text = str(CaseManager.HERO_SKINS[s_idx]["name"])
		sb.custom_minimum_size = Vector2(0, 40)
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.pressed.connect(func():
			CaseManager.hero_skin = s_idx
			AudioManager.play_sfx("blip", -3.0)
			_refresh_creator_ui()
		)
		sk_row.add_child(sb)
		skin_btns.append(sb)

	skin_perk_lbl = Label.new()
	skin_perk_lbl.add_theme_font_size_override("font_size", 14)
	skin_perk_lbl.add_theme_color_override("font_color", Color("#9de8c4"))
	opts_vb.add_child(skin_perk_lbl)

	var el_lbl: Label = Label.new()
	el_lbl.text = "3. СТИХИЯ МАГИИ (2 РЕЖИМА НА [Q]: ПЕЧАТЬ И СТРЕЛЬБА):"
	el_lbl.add_theme_font_size_override("font_size", 16)
	el_lbl.add_theme_color_override("font_color", Color("#ffd685"))
	opts_vb.add_child(el_lbl)

	var el_row: HBoxContainer = HBoxContainer.new()
	el_row.add_theme_constant_override("separation", 10)
	opts_vb.add_child(el_row)

	elem_btns.clear()
	for e_idx in range(CaseManager.ELEMENTS.size()):
		var eb: Button = Button.new()
		eb.text = str(CaseManager.ELEMENTS[e_idx]["name"])
		eb.custom_minimum_size = Vector2(0, 42)
		eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eb.pressed.connect(func():
			CaseManager.hero_element = e_idx
			AudioManager.play_sfx("blip", -3.0)
			_refresh_creator_ui()
		)
		el_row.add_child(eb)
		elem_btns.append(eb)

	elem_desc_lbl = Label.new()
	elem_desc_lbl.add_theme_font_size_override("font_size", 14)
	elem_desc_lbl.add_theme_color_override("font_color", Color("#ffe09c"))
	opts_vb.add_child(elem_desc_lbl)

	var launch_btn: Button = Button.new()
	launch_btn.text = "⚔   ВОЙТИ В ТЕСТОВУЮ ПЕСОЧНИЦУ ФРЕЙМВОРКА"
	launch_btn.custom_minimum_size = Vector2(0, 52)
	launch_btn.add_theme_font_size_override("font_size", 19)
	UITheme.style_button(launch_btn, Color("#f0be6e"), Color("#2c1d18"))
	launch_btn.pressed.connect(_start_sandbox)
	opts_vb.add_child(launch_btn)


func _build_settings_modal() -> void:
	settings_modal = ColorRect.new()
	settings_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_modal.color = Color(0.02, 0.015, 0.04, 0.88)
	settings_modal.visible = false
	add_child(settings_modal)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_modal.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(620, 420)
	card.add_theme_stylebox_override("panel", UITheme.make_panel(Color("#14101ef8"), Color("#9db4ff"), 12, 2))
	center.add_child(card)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	card.add_child(vb)

	var stitle: Label = Label.new()
	stitle.text = "⚙  НАСТРОЙКИ ЗВУКА И КЛЮЧЕВЫХ РУН"
	stitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stitle.add_theme_font_size_override("font_size", 20)
	stitle.add_theme_color_override("font_color", Color("#ffd685"))
	vb.add_child(stitle)

	# 1. Music Slider
	var mus_row: HBoxContainer = HBoxContainer.new()
	vb.add_child(mus_row)
	var mus_l: Label = Label.new()
	mus_l.text = "🎵  Музыка:"
	mus_l.custom_minimum_size = Vector2(210, 0)
	mus_row.add_child(mus_l)
	var mus_sl: HSlider = HSlider.new()
	mus_sl.min_value = 0.0
	mus_sl.max_value = 1.0
	mus_sl.step = 0.05
	mus_sl.value = AudioManager.music_volume
	mus_sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mus_val: Label = Label.new()
	mus_val.custom_minimum_size = Vector2(48, 0)
	mus_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mus_val.text = "%d%%" % int(round(AudioManager.music_volume * 100.0))
	mus_sl.value_changed.connect(func(v):
		AudioManager.music_volume = v
		mus_val.text = "%d%%" % int(round(v * 100.0))
		AudioManager.apply_volumes()
	)
	mus_row.add_child(mus_sl)
	mus_row.add_child(mus_val)

	# 2. Sound Effects Slider
	var sfx_row: HBoxContainer = HBoxContainer.new()
	vb.add_child(sfx_row)
	var sfx_l: Label = Label.new()
	sfx_l.text = "⚔  Звуки и удары:"
	sfx_l.custom_minimum_size = Vector2(210, 0)
	sfx_row.add_child(sfx_l)
	var sfx_sl: HSlider = HSlider.new()
	sfx_sl.min_value = 0.0
	sfx_sl.max_value = 1.0
	sfx_sl.step = 0.05
	sfx_sl.value = AudioManager.sfx_volume
	sfx_sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sfx_val: Label = Label.new()
	sfx_val.custom_minimum_size = Vector2(48, 0)
	sfx_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sfx_val.text = "%d%%" % int(round(AudioManager.sfx_volume * 100.0))
	sfx_sl.value_changed.connect(func(v):
		AudioManager.sfx_volume = v
		sfx_val.text = "%d%%" % int(round(v * 100.0))
		AudioManager.play_sfx("blip", -4.0)
	)
	sfx_row.add_child(sfx_sl)
	sfx_row.add_child(sfx_val)

	# 3. Speaking Voices Slider
	var voc_row: HBoxContainer = HBoxContainer.new()
	vb.add_child(voc_row)
	var voc_l: Label = Label.new()
	voc_l.text = "🗣  Голоса персонажей:"
	voc_l.custom_minimum_size = Vector2(210, 0)
	voc_row.add_child(voc_l)
	var voc_sl: HSlider = HSlider.new()
	voc_sl.min_value = 0.0
	voc_sl.max_value = 1.0
	voc_sl.step = 0.05
	voc_sl.value = AudioManager.voice_volume
	voc_sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var voc_val: Label = Label.new()
	voc_val.custom_minimum_size = Vector2(48, 0)
	voc_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	voc_val.text = "%d%%" % int(round(AudioManager.voice_volume * 100.0))
	voc_sl.value_changed.connect(func(v):
		AudioManager.voice_volume = v
		voc_val.text = "%d%%" % int(round(v * 100.0))
		AudioManager.apply_volumes()
	)
	voc_row.add_child(voc_sl)
	voc_row.add_child(voc_val)

	# 4. RITUAL_KEYWORDS slots (also editable in CaseManager.RITUAL_KEYWORDS)
	var w_lbl: Label = Label.new()
	w_lbl.text = "🔑 Ключевые руны ритуала (RITUAL_KEYWORDS):"
	w_lbl.add_theme_font_size_override("font_size", 14)
	w_lbl.add_theme_color_override("font_color", Color("#9effcb"))
	vb.add_child(w_lbl)

	var w_row: HBoxContainer = HBoxContainer.new()
	w_row.add_theme_constant_override("separation", 8)
	vb.add_child(w_row)
	word_inputs.clear()
	for i in range(3):
		var le: LineEdit = LineEdit.new()
		le.text = CaseManager.ritual_keywords[i] if i < CaseManager.ritual_keywords.size() else ("РУНА_%d" % (i + 1))
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_line_edit(le)
		w_row.add_child(le)
		word_inputs.append(le)

	var fs_btn: Button = Button.new()
	fs_btn.text = "🖥  Полноэкранный / Оконный режим"
	UITheme.style_button(fs_btn, Color("#8ce8b5"))
	fs_btn.pressed.connect(func():
		var cur: int = DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if cur == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	)
	vb.add_child(fs_btn)

	var close_s: Button = Button.new()
	close_s.text = "Сохранить и закрыть"
	UITheme.style_button(close_s, Color("#f0be6e"))
	close_s.pressed.connect(func():
		_save_settings()
		settings_modal.visible = false
	)
	vb.add_child(close_s)


func _save_settings() -> void:
	var updated_words: Array = []
	for i in range(mini(3, word_inputs.size())):
		var v: String = word_inputs[i].text.strip_edges()
		updated_words.append(v if not v.is_empty() else CaseManager.RITUAL_KEYWORDS[i])
	if not updated_words.is_empty():
		CaseManager.set_ritual_keywords(updated_words)
	AudioManager.apply_volumes()


func _refresh_creator_ui() -> void:
	var p_path: String = CaseManager.get_hero_portrait_path()
	var s_path: String = CaseManager.get_hero_sprite_path()
	if ResourceLoader.exists(p_path):
		hero_portrait.texture = load(p_path)
	if ResourceLoader.exists(s_path):
		hero_sprite_preview.texture = load(s_path)

	UITheme.style_button(btn_male, Color("#ffd478") if CaseManager.hero_gender == "m" else Color("#5c546e"), Color("#2c1e18") if CaseManager.hero_gender == "m" else Color("#161320"))
	UITheme.style_button(btn_female, Color("#ffd478") if CaseManager.hero_gender == "f" else Color("#5c546e"), Color("#2c1e18") if CaseManager.hero_gender == "f" else Color("#161320"))

	for i in range(skin_btns.size()):
		var sel: bool = (CaseManager.hero_skin == i)
		UITheme.style_button(skin_btns[i], Color("#7ef7c4") if sel else Color("#5c546e"), Color("#1a2b26") if sel else Color("#161320"))

	for i in range(elem_btns.size()):
		var esel: bool = (CaseManager.hero_element == i)
		var ecol: Color = CaseManager.ELEMENTS[i]["color"]
		UITheme.style_button(elem_btns[i], ecol if esel else Color("#5c546e"), ecol.darkened(0.75) if esel else Color("#161320"))

	skin_perk_lbl.text = "Особенность: " + str(CaseManager.get_skin_data()["perk"])
	elem_desc_lbl.text = "Стихия: " + str(CaseManager.get_element_data()["desc"])


func _start_sandbox() -> void:
	_save_settings()
	AudioManager.stop_voice()
	AudioManager.play_sfx("blip", -2.0)
	CaseManager.reset_case()
	get_tree().change_scene_to_file("res://scenes/framework_sandbox.tscn")
