extends HBoxContainer
# 右上角的 EN / 日本語：点了马上换语言，选中的那个亮，另一个暗。

const ON := Color(1, 1, 1, 1)
const OFF := Color(1, 1, 1, 0.45)


func _ready() -> void:
	$EN.pressed.connect(_pick.bind("en"))
	$JA.pressed.connect(_pick.bind("ja"))
	_refresh()


func _pick(lang: String) -> void:
	I18n.set_lang(lang)
	_refresh()


func _refresh() -> void:
	var ja = I18n.current() == "ja"
	$EN.modulate = OFF if ja else ON
	$JA.modulate = ON if ja else OFF
