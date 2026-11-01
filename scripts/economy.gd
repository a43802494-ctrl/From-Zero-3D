extends RefCounted
class_name ContractEconomy

# A single source of truth for unlocks, delivery times and rewards.
const CONTRACTS := [
	{"min_rep": 0, "reward": 95, "time": 80.0},
	{"min_rep": 20, "reward": 160, "time": 65.0},
	{"min_rep": 80, "reward": 260, "time": 50.0},
]
const ON_TIME_BONUS_RATE := 0.30

static func is_unlocked(tier: int, reputation: int) -> bool:
	return tier >= 0 and tier < CONTRACTS.size() and reputation >= int(CONTRACTS[tier]["min_rep"])

static func payout(base_reward: int, seconds_left: float) -> int:
	return base_reward + (roundi(float(base_reward) * ON_TIME_BONUS_RATE) if seconds_left > 0.0 else 0)
