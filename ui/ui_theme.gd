extends RefCounted

# Procedural gothic dark-fantasy UI styling factory (zero external theme assets required).

static func make_panel(bg: Color = Color("#120e18f2"), border: Color = Color("#c89b54"), radius: int = 8, border_w: int = 2) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 10
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func style_button(btn: Button, accent: Color = Color("#d8a657"), bg: Color = Color("#1e1828")) -> void:
	var normal: StyleBoxFlat = make_panel(bg, accent.darkened(0.28), 6, 1)
	normal.shadow_size = 3
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 7
	normal.content_margin_bottom = 7

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = bg.lightened(0.12)
	hover.border_color = accent.lightened(0.18)
	hover.set_border_width_all(2)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = accent.darkened(0.55)
	pressed.border_color = accent

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", Color("#f2e7d5"))
	btn.add_theme_color_override("font_hover_color", Color("#fff6e5"))
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func style_line_edit(le: LineEdit) -> void:
	var sb: StyleBoxFlat = make_panel(Color("#0c0912"), Color("#7d6242"), 6, 1)
	sb.shadow_size = 0
	var focus: StyleBoxFlat = sb.duplicate()
	focus.border_color = Color("#f0be6e")
	focus.set_border_width_all(2)
	le.add_theme_stylebox_override("normal", sb)
	le.add_theme_stylebox_override("focus", focus)
	le.add_theme_color_override("font_color", Color("#f5ecdc"))
	le.add_theme_color_override("font_placeholder_color", Color("#7c7288"))


static func style_bar(bar: ProgressBar, fill_col: Color, bg_col: Color = Color("#0c0912")) -> void:
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = bg_col
	bg.border_color = fill_col.darkened(0.45)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(5)

	var fg: StyleBoxFlat = StyleBoxFlat.new()
	fg.bg_color = fill_col
	fg.set_corner_radius_all(4)

	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
