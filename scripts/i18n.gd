extends Node
# 语言：第一次打开按浏览器 / 系统语言选（中文 → zh，日语 → ja，其他 → en），之后记住玩家选的。
# 文字的翻译在 i18n/strings.csv。英文、中文用 Uranus（中文像素字体，缺字 fallback 到 DotGothic16）；
# 日语整段换成 DotGothic16（Uranus 缺很多日文汉字和「ー」）。

const LANGS := ["en", "ja", "zh"]
const SETTINGS := "user://settings.cfg"

var ui_font: FontVariation = preload("res://AssetBundle/Fonts/ui_font.tres")
var latin_font: Font = preload("res://AssetBundle/Uranus_Pixel_11Px.ttf")
var ja_font: Font = preload("res://AssetBundle/Fonts/DotGothic16-Regular.ttf")


func _ready() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	var lang = cfg.get_value("game", "lang", "")
	if not lang in LANGS:
		var os_lang = OS.get_locale_language()
		lang = os_lang if os_lang in LANGS else "en"
	_apply(lang)


func current() -> String:
	return TranslationServer.get_locale().substr(0, 2)


func set_lang(lang: String) -> void:
	_apply(lang)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("game", "lang", lang)
	cfg.save(SETTINGS)


func _apply(lang: String) -> void:
	ui_font.base_font = ja_font if lang == "ja" else latin_font
	TranslationServer.set_locale(lang)
