extends HBoxContainer
# 右上角的 EN / 日本語 / 中文：点了马上换语言，选中的那个亮，其他的暗。

const ON := Color(1, 1, 1, 1)
const OFF := Color(1, 1, 1, 0.45)
const BUTTONS := {"en": "EN", "ja": "JA", "zh": "ZH"}


func _ready() -> void:
	for lang in BUTTONS:
		get_node(BUTTONS[lang]).pressed.connect(_pick.bind(lang))
	_refresh()


func _pick(lang: String) -> void:
	I18n.set_lang(lang)
	_refresh()


func _refresh() -> void:
	for lang in BUTTONS:
		get_node(BUTTONS[lang]).modulate = ON if I18n.current() == lang else OFF
