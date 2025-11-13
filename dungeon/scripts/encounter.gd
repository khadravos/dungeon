extends Node

enum Turn { PLAYER, ENEMY }
var current_turn: Turn = Turn.PLAYER
var in_combat: bool = false

func start_battle():
	in_combat = true
	current_turn = Turn.PLAYER
	print("A wild enemy appears!")
	# You can hide the dungeon camera, switch to a battle scene, etc.

func player_attack():
	if current_turn != Turn.PLAYER:
		return
	print("Player attacks!")
	current_turn = Turn.ENEMY
	await get_tree().create_timer(1.0).timeout
	enemy_turn()

func enemy_turn():
	print("Enemy attacks!")
	current_turn = Turn.PLAYER
