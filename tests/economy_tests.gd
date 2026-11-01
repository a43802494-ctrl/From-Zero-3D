extends SceneTree

func _init() -> void:
    call_deferred("_check_economy")

func expect_equal(actual: Variant, expected: Variant, description: String) -> bool:
    if actual == expected:
        return true
    push_error("ECONOMY TEST FAILED: %s | got=%s expected=%s" % [description, str(actual), str(expected)])
    print("ECONOMY TEST FAILED: %s | got=%s expected=%s" % [description, str(actual), str(expected)])
    quit(1)
    return false

func _check_economy() -> void:
    if not expect_equal(ContractEconomy.CONTRACTS.size(), 3, "Number of job tiers"): return
    if not expect_equal(ContractEconomy.is_unlocked(0, 0), true, "Initial job unlocked"): return
    if not expect_equal(ContractEconomy.is_unlocked(1, 19), false, "Locked at rep 19"): return
    if not expect_equal(ContractEconomy.is_unlocked(1, 20), true, "Unlocked at rep 20"): return
    if not expect_equal(ContractEconomy.is_unlocked(2, 79), false, "Locked at rep 79"): return
    if not expect_equal(ContractEconomy.is_unlocked(2, 80), true, "Unlocked at rep 80"): return
    if not expect_equal(ContractEconomy.is_unlocked(3, 1000), false, "Invalid job tier"): return
    if not expect_equal(ContractEconomy.payout(100, 1.0), 130, "30 percent on-time bonus"): return
    if not expect_equal(ContractEconomy.payout(100, 0.0), 100, "No bonus for late delivery"): return
    if not expect_equal(ContractEconomy.payout(95, 9.0), 124, "Round 28.5 bonus to 29"): return
    print("CONTRACT ECONOMY TESTS: PASS")
    quit(0)
