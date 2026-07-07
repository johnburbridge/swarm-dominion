extends GutTest
## Tests for the ResourceManager autoload (SPI-1383).

const TEAM_1: int = 1
const TEAM_2: int = 2


func before_each() -> void:
	ResourceManager.reset()


# --- Initial state ---


func test_unknown_team_starts_at_zero() -> void:
	assert_eq(ResourceManager.get_resources(TEAM_1), 0, "unknown team should read 0 biomass")


# --- Scenario 1: per-team isolation ---


func test_add_is_isolated_per_team() -> void:
	ResourceManager.add_resources(TEAM_1, 10)
	assert_eq(ResourceManager.get_resources(TEAM_1), 10, "team 1 should have 10")
	assert_eq(ResourceManager.get_resources(TEAM_2), 0, "team 2 should be unaffected")


# --- Scenario 2: add resources ---


func test_add_resources_increases_biomass() -> void:
	ResourceManager.add_resources(TEAM_1, 10)
	assert_eq(ResourceManager.get_resources(TEAM_1), 10, "biomass should become 10")


func test_add_resources_emits_resources_changed() -> void:
	watch_signals(EventBus)
	ResourceManager.add_resources(TEAM_1, 10)
	assert_signal_emitted_with_parameters(EventBus, "resources_changed", [TEAM_1, 10])


# --- Scenario 3: spend resources ---


func test_spend_resources_decreases_biomass() -> void:
	ResourceManager.add_resources(TEAM_1, 50)
	var ok := ResourceManager.spend_resources(TEAM_1, 30)
	assert_true(ok, "spend should succeed when affordable")
	assert_eq(ResourceManager.get_resources(TEAM_1), 20, "biomass should become 20")


func test_spend_resources_emits_resources_changed() -> void:
	ResourceManager.add_resources(TEAM_1, 50)
	watch_signals(EventBus)
	ResourceManager.spend_resources(TEAM_1, 30)
	assert_signal_emitted_with_parameters(EventBus, "resources_changed", [TEAM_1, 20])


# --- Scenario 4: cannot overspend ---


func test_cannot_overspend() -> void:
	ResourceManager.add_resources(TEAM_1, 20)
	var ok := ResourceManager.spend_resources(TEAM_1, 30)
	assert_false(ok, "spend should fail when unaffordable")
	assert_eq(ResourceManager.get_resources(TEAM_1), 20, "biomass should remain 20")


func test_overspend_does_not_emit() -> void:
	ResourceManager.add_resources(TEAM_1, 20)
	watch_signals(EventBus)
	ResourceManager.spend_resources(TEAM_1, 30)
	assert_signal_not_emitted(EventBus, "resources_changed", "failed spend should not emit")


# --- Scenario 5: affordability ---


func test_can_afford_true_when_enough() -> void:
	ResourceManager.add_resources(TEAM_1, 50)
	assert_true(ResourceManager.can_afford(TEAM_1, 30), "50 should afford 30")


func test_can_afford_false_when_insufficient() -> void:
	ResourceManager.add_resources(TEAM_1, 50)
	assert_false(ResourceManager.can_afford(TEAM_1, 60), "50 should not afford 60")


func test_can_afford_exact_amount() -> void:
	ResourceManager.add_resources(TEAM_1, 50)
	assert_true(ResourceManager.can_afford(TEAM_1, 50), "should afford exact amount")


# --- Non-positive guards ---


func test_add_non_positive_is_noop() -> void:
	ResourceManager.add_resources(TEAM_1, 10)
	watch_signals(EventBus)
	ResourceManager.add_resources(TEAM_1, 0)
	ResourceManager.add_resources(TEAM_1, -5)
	assert_eq(
		ResourceManager.get_resources(TEAM_1), 10, "non-positive add should not change biomass"
	)
	assert_signal_not_emitted(EventBus, "resources_changed", "non-positive add should not emit")


func test_spend_non_positive_returns_false() -> void:
	ResourceManager.add_resources(TEAM_1, 10)
	assert_false(ResourceManager.spend_resources(TEAM_1, 0), "spend of 0 should return false")
	assert_false(ResourceManager.spend_resources(TEAM_1, -5), "negative spend should return false")
	assert_eq(ResourceManager.get_resources(TEAM_1), 10, "biomass unchanged after invalid spend")


# --- reset ---


func test_reset_clears_all_teams() -> void:
	ResourceManager.add_resources(TEAM_1, 10)
	ResourceManager.add_resources(TEAM_2, 20)
	ResourceManager.reset()
	assert_eq(ResourceManager.get_resources(TEAM_1), 0, "team 1 cleared after reset")
	assert_eq(ResourceManager.get_resources(TEAM_2), 0, "team 2 cleared after reset")
