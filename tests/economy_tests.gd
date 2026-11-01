extends SceneTree

func _init() -> void:
	assert(ContractEconomy.CONTRACTS.size() == 3)
	assert(ContractEconomy.is_unlocked(0, 0))
	assert(not ContractEconomy.is_unlocked(1, 19))
	assert(ContractEconomy.is_unlocked(1, 20))
	assert(not ContractEconomy.is_unlocked(2, 79))
	assert(ContractEconomy.is_unlocked(2, 80))
	assert(not ContractEconomy.is_unlocked(3, 1000))
	assert(ContractEconomy.payout(100, 1.0) == 130)
	assert(ContractEconomy.payout(100, 0.0) == 100)
	assert(ContractEconomy.payout(95, 9.0) == 124)
	print("CONTRACT ECONOMY TESTS: PASS")
	quit(0)
