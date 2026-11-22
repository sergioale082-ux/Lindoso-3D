class_name LudoBot
extends RefCounted
## IA simples: pontua cada jogada possível e escolhe a melhor.
## Prioridade: chegar ao centro > comer peão > sair da base > fugir de perigo > casa segura.


static func choose(player: LudoPlayer, dice: int, players: Array) -> int:
	var best := -1
	var best_score := -INF
	for i in player.movable_pawns(dice):
		var s := _score(player, i, dice, players) + randf() * 0.5
		if s > best_score:
			best_score = s
			best = i
	return best


static func _score(player: LudoPlayer, i: int, dice: int, players: Array) -> float:
	var r: int = player.rel[i]
	var nr: int = 0 if r == LudoPlayer.BASE_REL else r + dice
	var score := 0.0

	if nr == LudoPlayer.FINISH_REL:
		score += 100.0
	if r == LudoPlayer.BASE_REL:
		score += 60.0

	if nr <= 50:
		var cell: int = (LudoPlayer.START_INDEX[player.seat] + nr) % 52
		var safe: bool = cell in LudoPlayer.SAFE_CELLS
		if safe:
			score += 15.0
		else:
			for other in players:
				if other == player:
					continue
				for j in 4:
					if other.abs_index(j) == cell:
						score += 80.0 + float(other.rel[j])
			if _threatened(player, cell, players):
				score -= 25.0
	else:
		score += 25.0  # reta final é segura

	if r >= 0 and r <= 50:
		var cur: int = (LudoPlayer.START_INDEX[player.seat] + r) % 52
		if not (cur in LudoPlayer.SAFE_CELLS) and _threatened(player, cur, players):
			score += 30.0  # fugir de uma casa ameaçada

	score += float(nr) * 0.5
	return score


## Há peão inimigo de 1 a 6 casas atrás desta casa?
static func _threatened(player: LudoPlayer, cell: int, players: Array) -> bool:
	for other in players:
		if other == player:
			continue
		for j in 4:
			var a: int = other.abs_index(j)
			if a < 0:
				continue
			var dist := (cell - a + 52) % 52
			if dist >= 1 and dist <= 6:
				return true
	return false
