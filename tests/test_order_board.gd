extends TestSuite


func test_tiers_and_slots() -> void:
	eq(OrderBoard.tier(0), 0, "0")
	eq(OrderBoard.tier(19), 0, "19")
	eq(OrderBoard.tier(20), 1, "20")
	eq(OrderBoard.tier(200), 4, "200")
	eq(OrderBoard.tier(999), 4, "999")
	var st := GameState.new()
	eq(OrderBoard.slots(st), 2, "tier 0 slots")
	st.reputation = 50
	eq(OrderBoard.slots(st), 4, "tier 2 slots")


func test_offers_respect_tier_and_never_duplicate() -> void:
	var db := Fixtures.db()
	for seed_value in 20:
		var st := GameState.new()
		OrderBoard.post_offers(st, db, Fixtures.rng(seed_value))
		check(not st.board.has(&"t1_dark"), "tier-1 template hidden at tier 0")
		eq(st.board.size(), 2, "only two eligible templates, even when 3 or 4 are wanted")
		check(st.board[0] != st.board[1], "no duplicates")


func test_offers_exclude_already_active_orders() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	st.orders.assign([{"template": "t0_slime", "deadline_day": 5}])
	for seed_value in 20:
		st.board.clear()
		OrderBoard.post_offers(st, db, Fixtures.rng(seed_value))
		check(not st.board.has(&"t0_slime"), "already active, not offered again")


func test_recent_templates_are_skipped_when_possible() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	st.reputation = 20  # tier 1: three eligible
	st.recent_templates.assign([&"t0_slime", &"t0_power"])
	OrderBoard.post_offers(st, db, Fixtures.rng(3))
	eq(st.board[0], &"t1_dark", "the fresh template is offered first")
	check(st.recent_templates.size() <= OrderBoard.RECENT_LIMIT, "recent list capped")


func test_accept_deliver_and_rewards() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	st.board.assign([&"t0_power", &"t0_slime"])
	eq(OrderBoard.accept(st, db, &"t1_dark"), "not on the board", "must be offered")
	eq(OrderBoard.accept(st, db, &"t0_power"), "", "accepted")
	eq(st.orders[0], {"template": "t0_power", "deadline_day": 1 + 4}, "deadline = day + computed days")
	check(not st.board.has(&"t0_power"), "left the board")
	var weak := Fixtures.adult(st, "spider", 50)  # power E
	check(OrderBoard.deliver(st, db, 0, weak).begins_with("missing"), "not good enough")
	eq(st.money, 500, "no pay yet")
	var strong := Fixtures.adult(st, "spider", 300)  # power C: required D, bonus C
	eq(OrderBoard.deliver(st, db, 0, strong), "", "delivered")
	eq(st.money, 500 + 100 + 50, "reward + bonus")
	eq(st.reputation, 4, "reputation")
	eq(strong.status, CreatureData.Status.GONE, "creature handed over")
	check(st.orders.is_empty(), "order closed")
	eq(OrderBoard.deliver(st, db, 0, weak), "no such order", "bad index")


func test_deliver_refuses_a_busy_creature() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	st.orders.assign([{"template": "t0_slime", "deadline_day": 5}])
	var c := Fixtures.adult(st, "slime")
	st.busy.append(c.id)
	eq(OrderBoard.deliver(st, db, 0, c), "busy on an expedition today", "refused")
	eq(st.orders.size(), 1, "order unchanged")


func test_order_slots_limit_accepting() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	st.board.assign([&"t0_power", &"t0_slime"])
	st.orders.assign([{"template": "t0_slime", "deadline_day": 5}, {"template": "t0_slime", "deadline_day": 5}])
	eq(OrderBoard.accept(st, db, &"t0_power"), "no free order slots", "tier 0 has 2 slots")
	eq(st.board.size(), 2, "board unchanged")


func test_missed_deadlines_cost_reputation_with_floor() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	st.day = 5
	st.reputation = 2
	st.orders.assign([{"template": "t0_slime", "deadline_day": 5}, {"template": "t0_power", "deadline_day": 6}])
	var events := OrderBoard.expire(st, db)
	eq(st.orders, [{"template": "t0_power", "deadline_day": 6}], "only the due order expires")
	eq(st.reputation, 0, "2 - 3 floors at 0")
	eq(events.size(), 1, "one event")
