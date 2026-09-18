class_name NetworkManager
extends Node

const PORT := 7777
const MAX_PLAYERS := 8

signal player_joined(peer_id: int)
signal player_left(peer_id: int)

func host_session() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		push_error("Failed to host session: %s" % err)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func join_session(address: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err != OK:
		push_error("Failed to join session: %s" % err)
		return
	multiplayer.multiplayer_peer = peer

func _on_peer_connected(peer_id: int) -> void:
	player_joined.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	player_left.emit(peer_id)
