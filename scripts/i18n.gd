extends Node
# 语言：第一次打开按浏览器 / 系统语言选（日语 → ja，其他 → en），之后记住玩家选的。
# 文字的翻译在 i18n/strings.csv。日语整段换成 DotGothic16（Uranus 是中文字体，缺很多日文汉字和「ー」）。

const LANGS := ["en", "ja"]
const SETTINGS := "user://settings.cfg"

var ui_font: FontVariation = preload("res://AssetBundle/Fonts/ui_font.tres")
var latin_font: Font = preload("res://AssetBundle/Uranus_Pixel_11Px.ttf")
var ja_font: Font = preload("res://AssetBundle/Fonts/DotGothic16-Regular.ttf")


func _ready() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	var lang = cfg.get_value("game", "lang", "")
	if not lang in LANGS:
		lang = "ja" if OS.get_locale_language() == "ja" else "en"
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
