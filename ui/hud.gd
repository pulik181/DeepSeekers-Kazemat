extends CanvasLayer

const UITheme = preload("res://ui/ui_theme.gd")

# Dark-Fantasy HUD
# Displays HP, Stamina, Elemental Spell Mode [Q], Potions [1]/[2], Dossier [TAB] (with RITUAL_KEYWORDS),
# Boss Health Bar, Toasts, Prompts, and Ritual Completion Screen.

var hp_bar: ProgressBar
var hp_lbl: Label
var stam_bar: ProgressBar
var stam_lbl: Label
var spell_mode_btn: Button
var loot_lbl: Label
var quest_lbl: Label

var boss_panel: PanelContainer
var boss_name_lbl: Label
var boss_hp_bar: ProgressBar

var toast_panel: PanelContainer
var toast_lbl: Label
var prompt_panel: PanelContainer
var prompt_lbl: Label
var mute_btn: Button

var dossier_bg: ColorRect
var dossier_list: VBoxContainer

var ending_bg: ColorRect
var ending_title: Label
var ending_desc: Label


func _ready() -> void:
	_build_ui()
	CaseManager.state_changed.connect(refresh)
	CaseManager.clue_added.connect(_on_clue_added)
	CaseManager.chain_unlocked.connect(_on_chain_unlocked)
	refresh()


func _process(_delta: float) -> void:
	if stam_bar:
		stam_bar.max_value = CaseManager.player_max_stamina
		stam_bar.value = CaseManager.player_stamina
		stam_lbl.text = "%d%%" % int(round(CaseManager.player_stamina / maxf(1.0, CaseManager.player_max_stamina) * 100.0))


func _build_ui() -> void:
	var root_ctrl: Control = Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ctrl)

	var top_panel: PanelContainer = PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_left = 12
	top_panel.offset_right = -12
	top_panel.offset_top = 10
	top_panel.offset_bottom = 64
	top_panel.add_theme_stylebox_override("panel", UITheme.make_panel(Color("#110d17f0"), Color("#9e7840"), 8, 2))
	root_ctrl.add_child(top_panel)

	var top_hbox: HBoxContainer = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 12)
	top_panel.add_child(top_hbox)

	var hp_box: HBoxContainer = HBoxContainer.new()
	hp_box.add_theme_constant_override("separation", 5)
	hp_box.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hbox.add_child(hp_box)

	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(110, 16)
	hp_bar.show_percentage = false
	hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UITheme.style_bar(hp_bar, Color("#d93b58"))
	hp_box.add_child(hp_bar)

	hp_lbl = Label.new()
	hp_lbl.add_theme_font_size_override("font_size", 13)
	hp_lbl.add_theme_color_override("font_color", Color("#f2dfe4"))
	hp_box.add_child(hp_lbl)

	var st_box: HBoxContainer = HBoxContainer.new()
	st_box.add_theme_constant_override("separation", 5)
	st_box.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hbox.add_child(st_box)

	var st_icon: Label = Label.new()
	st_icon.text = "⚡"
	st_box.add_child(st_icon)

	stam_bar = ProgressBar.new()
	stam_bar.custom_minimum_size = Vector2(92, 16)
	stam_bar.show_percentage = false
	stam_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UITheme.style_bar(stam_bar, Color("#49c6e5"))
	st_box.add_child(stam_bar)

	stam_lbl = Label.new()
	stam_lbl.add_theme_font_size_override("font_size", 12)
	stam_lbl.add_theme_color_override("font_color", Color("#bfefff"))
	st_box.add_child(stam_lbl)

	spell_mode_btn = Button.new()
	spell_mode_btn.pressed.connect(func(): CaseManager.toggle_spell_mode())
	top_hbox.add_child(spell_mode_btn)

	loot_lbl = Label.new()
	loot_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loot_lbl.add_theme_font_size_override("font_size", 13)
	loot_lbl.add_theme_color_override("font_color", Color("#f2e4c8"))
	top_hbox.add_child(loot_lbl)

	var dossier_btn: Button = Button.new()
	dossier_btn.text = "📜 Дневник [TAB]"
	UITheme.style_button(dossier_btn, Color("#d8a657"))
	dossier_btn.pressed.connect(toggle_dossier)
	top_hbox.add_child(dossier_btn)

	mute_btn = Button.new()
	mute_btn.text = "🔊"
	UITheme.style_button(mute_btn, Color("#8a96b8"))
	mute_btn.pressed.connect(_on_mute_pressed)
	top_hbox.add_child(mute_btn)

	var menu_btn: Button = Button.new()
	menu_btn.text = "Меню"
	UITheme.style_button(menu_btn, Color("#b86b78"))
	menu_btn.pressed.connect(func():
		AudioManager.stop_voice()
		CaseManager.ui_locked = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	top_hbox.add_child(menu_btn)

	var quest_panel: PanelContainer = PanelContainer.new()
	quest_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	quest_panel.offset_left = 90
	quest_panel.offset_right = -90
	quest_panel.offset_top = 68
	quest_panel.offset_bottom = 104
	quest_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest_panel.add_theme_stylebox_override("panel", UITheme.make_panel(Color("#161120d9"), Color("#634c32"), 6, 1))
	root_ctrl.add_child(quest_panel)

	quest_lbl = Label.new()
	quest_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_lbl.add_theme_font_size_override("font_size", 14)
	quest_lbl.add_theme_color_override("font_color", Color("#f7e8cc"))
	quest_panel.add_child(quest_lbl)

	boss_panel = PanelContainer.new()
	boss_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	boss_panel.offset_left = 240
	boss_panel.offset_right = -240
	boss_panel.offset_top = 110
	boss_panel.offset_bottom = 166
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_panel.add_theme_stylebox_override("panel", UITheme.make_panel(Color("#1e0d1af0"), Color("#ff4c78"), 8, 2))
	boss_panel.visible = false
	root_ctrl.add_child(boss_panel)

	var boss_vb: VBoxContainer = VBoxContainer.new()
	boss_vb.add_theme_constant_override("separation", 4)
	boss_panel.add_child(boss_vb)

	boss_name_lbl = Label.new()
	boss_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_lbl.add_theme_font_size_override("font_size", 15)
	boss_name_lbl.add_theme_color_override("font_color", Color("#ff9eb5"))
	boss_vb.add_child(boss_name_lbl)

	boss_hp_bar = ProgressBar.new()
	boss_hp_bar.custom_minimum_size = Vector2(0, 16)
	boss_hp_bar.show_percentage = false
	UITheme.style_bar(boss_hp_bar, Color("#e83864"))
	boss_vb.add_child(boss_hp_bar)

	toast_panel = PanelContainer.new()
	toast_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_panel.offset_left = 140
	toast_panel.offset_right = -140
	toast_panel.offset_top = 172
	toast_panel.offset_bottom = 216
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_theme_stylebox_override("panel", UITheme.make_panel(Color("#1a2b24f2"), Color("#6be8a8"), 8, 2))
	toast_panel.visible = false
	root_ctrl.add_child(toast_panel)

	toast_lbl = Label.new()
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_lbl.add_theme_font_size_override("font_size", 15)
	toast_lbl.add_theme_color_override("font_color", Color("#b8ffd8"))
	toast_panel.add_child(toast_lbl)

	prompt_panel = PanelContainer.new()
	prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_panel.offset_top = -68
	prompt_panel.offset_bottom = -24
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_panel.add_theme_stylebox_override("panel", UITheme.make_panel(Color("#191224f0"), Color("#f0be6e"), 8, 2))
	prompt_panel.visible = false
	root_ctrl.add_child(prompt_panel)

	prompt_lbl = Label.new()
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.add_theme_font_size_override("font_size", 17)
	prompt_lbl.add_theme_color_override("font_color", Color("#ffe29e"))
	prompt_panel.add_child(prompt_lbl)

	_build_dossier_modal(root_ctrl)
	_build_ending_modal(root_ctrl)


func _build_dossier_modal(root_ctrl: Control) -> void:
	dossier_bg = ColorRect.new()
	dossier_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dossier_bg.color = Color(0.03, 0.02, 0.05, 0.88)
	dossier_bg.visible = false
	root_ctrl.add_child(dossier_bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dossier_bg.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(820, 500)
	card.add_theme_stylebox_override("panel", UITheme.make_panel(Color("#14101cf8"), Color("#d8a657"), 10, 2))
	center.add_child(card)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var head: HBoxContainer = HBoxContainer.new()
	vbox.add_child(head)

	var title: Label = Label.new()
	title.text = "📜 ДНЕВНИК УЛИК И КЛЮЧЕВЫХ РУН ДЕЛА"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#ffd685"))
	head.add_child(title)

	var close_btn: Button = Button.new()
	close_btn.text = "Закрыть [TAB]"
	UITheme.style_button(close_btn, Color("#d95b72"))
	close_btn.pressed.connect(toggle_dossier)
	head.add_child(close_btn)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	dossier_list = VBoxContainer.new()
	dossier_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier_list.add_theme_constant_override("separation", 8)
	scroll.add_child(dossier_list)


func _build_ending_modal(root_ctrl: Control) -> void:
	ending_bg = ColorRect.new()
	ending_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ending_bg.color = Color(0.02, 0.015, 0.03, 0.93)
	ending_bg.visible = false
	root_ctrl.add_child(ending_bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ending_bg.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(760, 360)
	card.add_theme_stylebox_override("panel", UITheme.make_panel(Color("#15101ef8"), Color("#e0a958"), 12, 3))
	center.add_child(card)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	card.add_child(vbox)

	ending_title = Label.new()
	ending_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(ending_title)

	ending_desc = Label.new()
	ending_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ending_desc.custom_minimum_size = Vector2(680, 0)
	ending_desc.add_theme_font_size_override("font_size", 17)
	ending_desc.add_theme_color_override("font_color", Color("#efe4d2"))
	vbox.add_child(ending_desc)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 18)
	vbox.add_child(btn_row)

	var retry_btn: Button = Button.new()
	retry_btn.text = "🔄 Перезапустить песочницу"
	UITheme.style_button(retry_btn, Color("#e0a958"))
	retry_btn.pressed.connect(func():
		AudioManager.stop_voice()
		CaseManager.reset_case()
		get_tree().change_scene_to_file("res://scenes/framework_sandbox.tscn")
	)
	btn_row.add_child(retry_btn)

	var menu_btn: Button = Button.new()
	menu_btn.text = "В Главное Меню"
	UITheme.style_button(menu_btn, Color("#8a96b8"))
	menu_btn.pressed.connect(func():
		AudioManager.stop_voice()
		CaseManager.ui_locked = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	btn_row.add_child(menu_btn)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dossier") and not ending_bg.visible:
		toggle_dossier()


func toggle_dossier() -> void:
	if ending_bg.visible:
		return
	dossier_bg.visible = not dossier_bg.visible
	CaseManager.ui_locked = dossier_bg.visible
	AudioManager.play_sfx("blip", -5.0)
	if dossier_bg.visible:
		_populate_dossier()


func _populate_dossier() -> void:
	for c in dossier_list.get_children():
		c.queue_free()

	# Display active RITUAL_KEYWORDS card
	var words_card: PanelContainer = PanelContainer.new()
	words_card.add_theme_stylebox_override("panel", UITheme.make_panel(Color("#192328"), Color("#6be8a8"), 6, 2))
	var wvb: VBoxContainer = VBoxContainer.new()
	words_card.add_child(wvb)
	var wt: Label = Label.new()
	wt.text = "🔑 КЛЮЧЕВЫЕ РУНЫ РАССЛЕДОВАНИЯ (RITUAL_KEYWORDS):"
	wt.add_theme_font_size_override("font_size", 15)
	wt.add_theme_color_override("font_color", Color("#9effcb"))
	wvb.add_child(wt)
	var wd: Label = Label.new()
	wd.text = " • ".join(CaseManager.get_ritual_keywords())
	wd.add_theme_font_size_override("font_size", 16)
	wd.add_theme_color_override("font_color", Color("#ffffff"))
	wvb.add_child(wd)
	dossier_list.add_child(words_card)

	for cid in CaseManager.ALL_CLUES.keys():
		var found: bool = CaseManager.collected_clues.has(cid)
		var info: Dictionary = CaseManager.ALL_CLUES[cid]
		var item: PanelContainer = PanelContainer.new()
		item.add_theme_stylebox_override("panel", UITheme.make_panel(
			Color("#1c1628") if found else Color("#100d16"),
			Color("#d8a657") if found else Color("#3c3448"), 6, 1
		))
		var vb: VBoxContainer = VBoxContainer.new()
		item.add_child(vb)

		var t: Label = Label.new()
		t.text = ("✔ " + str(info["title"])) if found else "🔒 Неизвестная улика (найдите в сцене)"
		t.add_theme_font_size_override("font_size", 15)
		t.add_theme_color_override("font_color", Color("#ffd984") if found else Color("#787088"))
		vb.add_child(t)

		if found:
			var d: Label = Label.new()
			d.text = str(info["desc"])
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.add_theme_font_size_override("font_size", 13)
			d.add_theme_color_override("font_color", Color("#e6dccb"))
			vb.add_child(d)
		dossier_list.add_child(item)


func refresh() -> void:
	var elem: Dictionary = CaseManager.get_element_data()
	var m_str: String = "Стрельба" if CaseManager.spell_mode == 1 else "Печать"
	spell_mode_btn.text = "[Q] %s: %s" % [str(elem["name"]), m_str]
	UITheme.style_button(spell_mode_btn, elem["color"], Color("#191426"))

	hp_bar.max_value = CaseManager.player_max_hp
	hp_bar.value = CaseManager.player_hp
	hp_lbl.text = "%d HP" % CaseManager.player_hp
	loot_lbl.text = "💰 %d  |  [1] HP: %d  |  [2] Бодрость: %d  |  Улики: %d/%d" % [
		CaseManager.gold, CaseManager.hp_potions, CaseManager.stamina_tonics,
		CaseManager.collected_clues.size(), CaseManager.ALL_CLUES.size()
	]
	mute_btn.text = "🔇" if AudioManager.is_muted else "🔊"


func update_boss_bar(boss_title: String, cur_hp: int, max_hp: int) -> void:
	if cur_hp <= 0:
		boss_panel.visible = false
		return
	boss_panel.visible = true
	boss_name_lbl.text = "%s  (%d / %d HP)" % [boss_title, cur_hp, max_hp]
	boss_hp_bar.max_value = max_hp
	boss_hp_bar.value = cur_hp


func show_toast(msg: String, duration: float = 5.0) -> void:
	toast_lbl.text = msg
	toast_panel.visible = true
	toast_panel.modulate.a = 1.0
	var tw: Tween = create_tween()
	tw.tween_interval(duration)
	tw.tween_property(toast_panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): toast_panel.visible = false)


func _on_clue_added(clue_id: String) -> void:
	var title: String = str(CaseManager.ALL_CLUES[clue_id]["title"])
	show_toast("✨ Найдена улика: %s!" % title, 4.5)


func _on_chain_unlocked(_flag_id: String, announcement: String) -> void:
	show_toast(announcement, 6.0)


func _on_mute_pressed() -> void:
	AudioManager.toggle_mute()
	refresh()


func set_quest(text: String) -> void:
	quest_lbl.text = text


func set_prompt(text: String) -> void:
	prompt_panel.visible = not text.is_empty()
	prompt_lbl.text = text


func show_ending(title: String, desc: String, is_good: bool, voice_id: String = "", speaker: String = "narrator") -> void:
	CaseManager.ui_locked = true
	dossier_bg.visible = false
	boss_panel.visible = false
	ending_bg.visible = true
	ending_title.text = title
	ending_title.add_theme_color_override("font_color", Color("#7dffb3") if is_good else Color("#ff5c7c"))
	ending_desc.text = desc
	if not voice_id.is_empty():
		AudioManager.speak_line(voice_id, speaker, desc)
