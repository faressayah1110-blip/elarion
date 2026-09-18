class_name QuestState
extends RefCounted

enum Kind { KILL, REACH }

var id: String
var kind: Kind
var kill_target_id: String = ""
var kill_count_needed: int = 0
var _kill_count: int = 0
var _arrived: bool = false

static func new_kill_quest(quest_id: String, count_needed: int) -> QuestState:
	var q := QuestState.new()
	q.id = quest_id
	q.kind = Kind.KILL
	q.kill_target_id = quest_id
	q.kill_count_needed = count_needed
	return q

static func new_reach_quest(quest_id: String) -> QuestState:
	var q := QuestState.new()
	q.id = quest_id
	q.kind = Kind.REACH
	return q

func record_kill(killed_id: String) -> void:
	if kind == Kind.KILL and killed_id == kill_target_id:
		_kill_count += 1

func record_arrival(location_id: String) -> void:
	if kind == Kind.REACH and location_id == id:
		_arrived = true

func is_complete() -> bool:
	if kind == Kind.KILL:
		return _kill_count >= kill_count_needed
	return _arrived
