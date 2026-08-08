class_name ProofReader
extends RefCounted
## Spell + literary/punctuation corrections for the typewriter.

## Common mistypes → suggestion (lowercase keys).
const SPELL := {
	"teh": "the", "hte": "the", "adn": "and", "nad": "and", "taht": "that",
	"thier": "their", "theri": "their", "recieve": "receive", "occured": "occurred",
	"seperate": "separate", "definately": "definitely", "accomodate": "accommodate",
	"becuase": "because", "becasue": "because", "wich": "which", "whihc": "which",
	"wiht": "with", "whit": "with", "foram": "from", "fro": "for",
	"ot": "to", "tje": "the", "thsi": "this", "tihs": "this", "waht": "what",
	"whta": "what", "jsut": "just", "jstu": "just", "dont": "don't", "cant": "can't",
	"wont": "won't", "im": "I'm", "ive": "I've", "youre": "you're", "theyre": "they're",
	"thats": "that's", "whats": "what's", "lets": "let's",
	"alot": "a lot", "allright": "all right", "untill": "until", "tommorow": "tomorrow",
	"tommorrow": "tomorrow", "writting": "writing", "begining": "beginning",
	"enviroment": "environment", "goverment": "government", "arguement": "argument",
	"beleive": "believe", "freind": "friend", "wierd": "weird", "neccessary": "necessary",
	"sucess": "success", "succesful": "successful", "buisness": "business",
	"langauge": "language", "literiture": "literature", "litterature": "literature",
	"commma": "comma", "sentance": "sentence", "paragragh": "paragraph",
	"nots": "notes", "typerwriter": "typewriter", "typewirter": "typewriter",
}


static func scan_document(lines: PackedStringArray, spell: bool, literary: bool) -> Array:
	var issues: Array = []
	if literary:
		issues.append_array(_literary_issues(lines))
	if spell:
		issues.append_array(_spell_issues(lines))
	return issues


static func scan_last_word(line: String, col: int) -> Dictionary:
	## Returns {ok, word, suggestion, start, end, kind} for the word before caret.
	if col <= 0 or line.is_empty():
		return {"ok": false}
	var end := mini(col, line.length())
	var i := end - 1
	# Skip trailing whitespace / punct just typed
	while i >= 0 and _is_boundary(line[i]):
		i -= 1
	if i < 0:
		return {"ok": false}
	var w_end := i + 1
	while i >= 0 and not _is_boundary(line[i]):
		i -= 1
	var w_start := i + 1
	var word := line.substr(w_start, w_end - w_start)
	if word.length() < 2:
		return {"ok": false}
	var sug := suggest_spelling(word)
	if sug.is_empty() or sug == word:
		return {"ok": false}
	return {
		"ok": true,
		"kind": "spell",
		"word": word,
		"suggestion": sug,
		"line": -1,
		"start": w_start,
		"end": w_end,
	}


static func suggest_spelling(word: String) -> String:
	var core := word
	var prefix := ""
	var suffix := ""
	# Keep surrounding quotes if any
	if core.begins_with("'") and core.length() > 1:
		prefix = "'"
		core = core.substr(1)
	if core.ends_with("'") and core.length() > 1:
		suffix = "'"
		core = core.substr(0, core.length() - 1)
	var key := core.to_lower()
	if not SPELL.has(key):
		return ""
	var fix: String = str(SPELL[key])
	# Preserve capitalization style
	if core == core.to_upper() and core.length() > 1:
		fix = fix.to_upper()
	elif core.length() > 0 and core[0] == core[0].to_upper():
		fix = fix.substr(0, 1).to_upper() + fix.substr(1)
	return prefix + fix + suffix


static func apply_literary_line(line: String) -> String:
	var s := line
	# Collapse repeated spaces
	while s.contains("  "):
		s = s.replace("  ", " ")
	# No space before punctuation
	for p in [",", ".", ";", ":", "!", "?", ")"]:
		s = s.replace(" " + p, p)
	# Space after punctuation if next is a letter
	s = _space_after_punct(s)
	# Capitalize sentence starts
	s = _capitalize_sentences(s)
	# Lone i → I
	s = _fix_lone_i(s)
	# Ellipsis normalize
	s = s.replace("....", "...")
	s = s.replace(",,,", ",")
	s = s.replace(",,", ",")
	return s


static func apply_issue(lines: PackedStringArray, issue: Dictionary) -> PackedStringArray:
	var out := lines.duplicate()
	var li := int(issue.get("line", 0))
	if li < 0 or li >= out.size():
		return out
	var start := int(issue.get("start", 0))
	var end := int(issue.get("end", 0))
	var sug := str(issue.get("suggestion", ""))
	var line := out[li]
	if start < 0 or end > line.length() or start > end:
		return out
	out[li] = line.substr(0, start) + sug + line.substr(end)
	return out


static func apply_all(lines: PackedStringArray, spell: bool, literary: bool) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for line in lines:
		var s := line
		if literary:
			s = apply_literary_line(s)
		out.append(s)
	if spell:
		for i in out.size():
			out[i] = _spell_fix_line(out[i])
	return out


static func _spell_fix_line(line: String) -> String:
	var result := ""
	var i := 0
	while i < line.length():
		if _is_boundary(line[i]):
			result += line[i]
			i += 1
			continue
		var j := i
		while j < line.length() and not _is_boundary(line[j]):
			j += 1
		var word := line.substr(i, j - i)
		var sug := suggest_spelling(word)
		result += sug if not sug.is_empty() else word
		i = j
	return result


static func _spell_issues(lines: PackedStringArray) -> Array:
	var issues: Array = []
	for li in lines.size():
		var line: String = lines[li]
		var i := 0
		while i < line.length():
			if _is_boundary(line[i]):
				i += 1
				continue
			var j := i
			while j < line.length() and not _is_boundary(line[j]):
				j += 1
			var word := line.substr(i, j - i)
			var sug := suggest_spelling(word)
			if not sug.is_empty() and sug != word:
				issues.append({
					"ok": true,
					"kind": "spell",
					"word": word,
					"suggestion": sug,
					"line": li,
					"start": i,
					"end": j,
				})
			i = j
	return issues


static func _literary_issues(lines: PackedStringArray) -> Array:
	var issues: Array = []
	for li in lines.size():
		var line: String = lines[li]
		var fixed := apply_literary_line(line)
		if fixed != line:
			issues.append({
				"ok": true,
				"kind": "literary",
				"word": line.substr(0, mini(24, line.length())),
				"suggestion": fixed,
				"line": li,
				"start": 0,
				"end": line.length(),
				"label": "comma / literature polish",
			})
	return issues


static func _is_boundary(ch: String) -> bool:
	return ch == " " or ch == "\t" or ",.;:!?\"'()[]{}".contains(ch)


static func _space_after_punct(s: String) -> String:
	var out := ""
	for i in s.length():
		out += s[i]
		if i + 1 < s.length():
			var a := s[i]
			var b := s[i + 1]
			if ",.;:!?".contains(a) and b != " " and b != "\n" and not ",.;:!?".contains(b) and b != "'":
				out += " "
	return out


static func _capitalize_sentences(s: String) -> String:
	if s.is_empty():
		return s
	var chars := s
	var out := ""
	var cap_next := true
	for i in chars.length():
		var ch := chars[i]
		if cap_next and ch != " " and ch != "\t":
			out += ch.to_upper()
			cap_next = false
		else:
			out += ch
		if ".!?".contains(ch):
			cap_next = true
	return out


static func _fix_lone_i(s: String) -> String:
	var parts := s.split(" ")
	for i in parts.size():
		if parts[i] == "i":
			parts[i] = "I"
		elif parts[i].begins_with("i'") and parts[i].length() > 2:
			parts[i] = "I" + parts[i].substr(1)
	return " ".join(parts)
