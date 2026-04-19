extends Object
## Tokenization and "decompose" stepping for parade line strings.
## {text} joins the enclosed (including spaces) into a single sign; braces are not shown.
## A bare token with no letters or digits (e.g. "," or "!") is appended to the previous spec's front.
## Transition order: leading loyal () / <a,b> flips; fleeing <word> before the first [...]; then for each
## disloyal bracket, first flip, flips/omits of tokens strictly between this bracket and the next,
## then the bracket's omit step.
class_name ParadeLineSyntax

const _WS := " \t\n\r"


static func _pit_spec() -> Dictionary:
	return {"loyal": true, "front": "pppp", "back": "pp"}


## When [param can_pit] is true and the parsed line has at most six specs, bookends the line with
## pit entries ([code]front[/code] and [code]back[/code] [code]"pp"[/code] → two personal-space units each).
static func parse_line(s: String, can_pit: bool = true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var pos: int = 0
	var n: int = s.length()
	while pos < n:
		pos = _skip_ws(s, pos, n)
		if pos >= n:
			break
		var c: String = s[pos]
		if c == "{":
			var brace_close: int = s.find("}", pos + 1)
			if brace_close < 0:
				brace_close = n
			var grouped: String = s.substr(pos + 1, brace_close - pos - 1).strip_edges()
			pos = brace_close + 1 if brace_close < n else n
			if not grouped.is_empty():
				result.append({"loyal": true, "front": grouped, "back": ""})
		elif c == "(" or c == "[" or c == "<":
			var close_ch: String = ")" if c == "(" else ("]" if c == "[" else ">")
			var close_i: int = s.find(close_ch, pos + 1)
			if close_i < 0:
				close_i = n
			var inner: String = s.substr(pos + 1, close_i - pos - 1).strip_edges()
			pos = close_i + 1 if close_i < n else n
			var comma: int = inner.find(",")
			var front: String = inner if comma < 0 else inner.substr(0, comma).strip_edges()
			var back: String = "" if comma < 0 else inner.substr(comma + 1).strip_edges()
			match c:
				"(":
					result.append({"loyal": true, "front": front, "back": back})
				"[":
					result.append({"loyal": false, "front": front, "back": back})
				"<":
					var d: Dictionary = {"loyal": true, "front": front, "back": back, "fleeing": true}
					result.append(d)
				_:
					pass
		else:
			var start: int = pos
			pos += 1
			while pos < n and not s[pos] in _WS and not s[pos] in "()[]<>{}":
				pos += 1
			var word: String = s.substr(start, pos - start).strip_edges()
			if word.is_empty():
				continue
			if _token_is_punctuation_only(word) and not result.is_empty():
				var last: Dictionary = result[-1]
				last["front"] = str(last["front"]) + word
			else:
				result.append({"loyal": true, "front": word, "back": ""})
	if can_pit and result.size() <= 5:
		var pit_head: Dictionary = _pit_spec()
		var pit_tail: Dictionary = _pit_spec()
		var wrapped: Array[Dictionary] = []
		wrapped.append(pit_head)
		wrapped.append_array(result)
		wrapped.append(pit_tail)
		return wrapped
	return result


static func _skip_ws(s: String, from: int, n: int) -> int:
	var i: int = from
	while i < n and s[i] in _WS:
		i += 1
	return i


static func _unicode_is_decimal_digit(code: int) -> bool:
	return code >= 0x0030 and code <= 0x0039


## True if the token has no letters or digits (so it is punctuation/symbols only).
static func _token_is_punctuation_only(word: String) -> bool:
	var ts: TextServer = TextServerManager.get_primary_interface()
	for i: int in word.length():
		var u: int = word.unicode_at(i)
		if ts.is_valid_letter(u) or _unicode_is_decimal_digit(u):
			return false
	return true


static func _has_flip(spec: Dictionary) -> bool:
	return not str(spec.get("back", "")).is_empty()


static func _is_fleeing_omit(spec: Dictionary) -> bool:
	return spec.get("fleeing", false) and str(spec.get("back", "")).is_empty()


static func _is_loyal_pair(spec: Dictionary) -> bool:
	return spec.get("loyal", false) and _has_flip(spec) and not spec.get("fleeing", false)


static func _is_loyal_angle_pair(spec: Dictionary) -> bool:
	return spec.get("loyal", false) and spec.get("fleeing", false) and _has_flip(spec)


static func _is_disloyal_bracket(spec: Dictionary) -> bool:
	return not spec.get("loyal", true) and _has_flip(spec)


static func _leading_loyal_flip_indices(specs: Array[Dictionary]) -> Array[int]:
	var first_bracket: int = -1
	for i: int in range(specs.size()):
		if _is_disloyal_bracket(specs[i]):
			first_bracket = i
			break
	var out: Array[int] = []
	var limit: int = first_bracket if first_bracket >= 0 else specs.size()
	for i: int in range(limit):
		var sp: Dictionary = specs[i]
		if _is_loyal_pair(sp) or _is_loyal_angle_pair(sp):
			out.append(i)
	return out


static func _next_disloyal_bracket(specs: Array[Dictionary], from_idx: int) -> int:
	for j: int in range(from_idx, specs.size()):
		if _is_disloyal_bracket(specs[j]):
			return j
	return -1


## Ordered spec indices: each entry is one transition applied at that global step.
static func transition_indices(specs: Array[Dictionary]) -> Array[int]:
	var order: Array[int] = []
	for i: int in _leading_loyal_flip_indices(specs):
		order.append(i)

	var fb: int = _next_disloyal_bracket(specs, 0)
	if fb >= 0:
		for j: int in range(fb):
			if _is_fleeing_omit(specs[j]):
				order.append(j)
	else:
		for j: int in range(specs.size()):
			if _is_fleeing_omit(specs[j]):
				order.append(j)

	var d: int = fb
	while d >= 0:
		order.append(d)
		var next_d: int = _next_disloyal_bracket(specs, d + 1)
		var upper: int = next_d if next_d >= 0 else specs.size()
		for j: int in range(d + 1, upper):
			var sp: Dictionary = specs[j]
			if _is_fleeing_omit(sp) or _is_loyal_pair(sp) or _is_loyal_angle_pair(sp):
				order.append(j)
		order.append(d)
		d = next_d
	return order


static func _max_state(spec: Dictionary) -> int:
	if _is_disloyal_bracket(spec):
		return 2
	if _is_fleeing_omit(spec):
		return 1
	if _is_loyal_pair(spec) or _is_loyal_angle_pair(spec):
		return 1
	return 0


static func _piece_text(spec: Dictionary, state: int) -> String:
	if not _has_flip(spec):
		return str(spec.get("front", ""))
	if _is_disloyal_bracket(spec):
		if state <= 0:
			return str(spec.get("front", ""))
		if state == 1:
			return str(spec.get("back", ""))
		return ""
	if _is_fleeing_omit(spec):
		return str(spec.get("front", "")) if state <= 0 else ""
	# Loyal pair (paren or <a,b>)
	if state <= 0:
		return str(spec.get("front", ""))
	return str(spec.get("back", ""))


static func _apply_steps(specs: Array[Dictionary], order: Array[int], steps: int) -> PackedStringArray:
	var states: Array[int] = []
	states.resize(specs.size())
	for i: int in range(specs.size()):
		states[i] = 0

	var n_steps: int = order.size()
	var k: int = n_steps if steps < 0 else mini(steps, n_steps)
	for s: int in range(k):
		var idx: int = order[s]
		var mx: int = _max_state(specs[idx])
		if states[idx] < mx:
			states[idx] += 1

	var parts: PackedStringArray = PackedStringArray()
	for i: int in range(specs.size()):
		var t: String = _piece_text(specs[i], states[i])
		if not t.is_empty():
			parts.append(t)
	return parts


## steps: number of transitions applied in canonical order (see transition_indices). -1 = all.
static func decompose(s: String, steps: int = 0) -> String:
	var specs: Array[Dictionary] = parse_line(s, false)
	if specs.is_empty():
		return ""
	var order: Array[int] = transition_indices(specs)
	var parts: PackedStringArray = _apply_steps(specs, order, steps)
	return " ".join(parts)


## Character length of visible text for [param specs] at [param steps] (same join rules as [method decompose]).
static func visible_text_length(specs: Array[Dictionary], steps: int = 0) -> int:
	if specs.is_empty():
		return 0
	var order: Array[int] = transition_indices(specs)
	var parts: PackedStringArray = _apply_steps(specs, order, steps)
	return " ".join(parts).length()
