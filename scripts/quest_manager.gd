class_name QuestManager
extends Node

var kill_quest := QuestState.new_kill_quest("kill_wolves", 3)
var reach_quest := QuestState.new_reach_quest("find_shrine")

signal quest_updated(quest_id: String, complete: bool)

func report_kill(killed_id: String) -> void:
	if not multiplayer.is_server():
		return
	kill_quest.record_kill(killed_id)
	_sync_quest.rpc(kill_quest.id, kill_quest.is_complete())

func report_arrival(location_id: String) -> void:
	if not multiplayer.is_server():
		return
	reach_quest.record_arrival(location_id)
	_sync_quest.rpc(reach_quest.id, reach_quest.is_complete())

@rpc("authority", "call_local", "reliable")
func _sync_quest(quest_id: String, complete: bool) -> void:
	quest_updated.emit(quest_id, complete)
