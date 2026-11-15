class_name YearPlanText
extends RefCounted

static func materials(s: Dictionary, values: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key: String in YearGame.resources(s):
		if values.has(key):
			parts.append("%s %d" % [TranslationServer.translate("daily.resource." + key), int(values[key])])
	return " · ".join(parts) if not parts.is_empty() else String(TranslationServer.translate("daily.none"))


static func describe(s: Dictionary, result: Dictionary, tile: int) -> String:
	var rows: PackedStringArray = [TranslationServer.translate("yearreview.assumption")]
	var cost: Dictionary = {}
	for key: String in result["reserved"]:
		if int(result["reserved"][key]) > 0:
			cost[key] = int(result["reserved"][key])
	rows.append(String(TranslationServer.translate("yearplus.reserved")) + " " + materials(s, cost))
	rows.append(String(TranslationServer.translate("yearreview.duration")) % int(result["days"]))
	if result["completed"]:
		rows.append(String(TranslationServer.translate("yearreview.completed")) % int(result["completion_day"]) if int(result["completion_day"]) > 0 else String(TranslationServer.translate("yearreview.immediate")))
	else:
		rows.append(String(TranslationServer.translate("yearreview.unfinished." + String(result["reason"]))))
	for branch: String in ["baseline", "planned"]:
		var after: Dictionary = result[branch]
		var summary: String = String(TranslationServer.translate("yearplus." + branch)) + ": " + String(TranslationServer.translate("yearplus.try_summary")) % [int(after["day"]), int(after["resources"]["food"]), int(after["population"]), YearGame.housing(after), int(after["stats"]["damage"]) - int(s["stats"]["damage"]), TranslationServer.translate("year.outcome." + String(after["outcome"]))]
		if YearGame.multi_year(s):
			summary += "\n" + String(TranslationServer.translate("yearmulti.date")) % [YearGame.year_number(after), YearGame.day_of_year(after), int(after["campaign_years"])]
		rows.append(summary)
		rows.append(materials(s, after["resources"]))
		var site: String = after["structures"][tile]
		if site.is_empty():
			site = after["board"]["tiles"][tile]["feature"]
		rows.append(String(TranslationServer.translate("yearreview.local")) % [TranslationServer.translate("year.site." + site), int(after["board"]["tiles"][tile]["elevation"]), float(after["board"]["tiles"][tile]["water"]), int(after["health"][tile]), int(after["crop_growth"][tile])])
	return "\n\n".join(rows)
