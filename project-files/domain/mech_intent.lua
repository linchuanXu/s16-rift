-- 按职务打分选意图。分数只读对位、经济、时钟。同分用 rng。
local Match = require("domain.mech_matchup")
local World = require("domain.mech_world")

local M = {}

local function my_delta(side, lane, picks)
  local d = Match.lane_delta(picks, lane)
  return side == "blue" and d or -d
end

local function gold_lead(side, ctx)
  local d = (ctx.gold_b or 0) - (ctx.gold_r or 0)
  return side == "blue" and d or -d
end

local function base_of(side)
  return World.base_region(side)
end

local function own_jg(side)
  return side == "blue" and "jg_b" or "jg_r"
end

local function river(ctx)
  if ctx.clock and ctx.clock.baron then return "baron" end
  if ctx.clock and ctx.clock.herald then return "herald" end
  return "drag"
end

local function obj_urge(min, spawn)
  if not spawn then return 0 end
  if min == spawn then return 13.2 end
  if min == spawn + 1 then return 7.6 end
  if min > spawn then return 3.2 end
  return 0
end

local function weakest_lane(side, picks)
  local best, lane = -1e9, 4
  for _, i in ipairs({1, 3, 4}) do
    local w = -my_delta(side, i, picks)
    if w > best then best, lane = w, i end
  end
  return lane, best
end

function M.options(agent, ctx)
  local side, role, min = agent.side, agent.role, ctx.min or 0
  local picks = ctx.picks
  local clock = ctx.clock or {}
  local lead = gold_lead(side, ctx)
  local rows = {}

  local function add(id, region, score)
    rows[#rows + 1] = {id = id, region = region, score = score}
  end

  if not agent.alive then
    add("recall", base_of(side), 99)
    return rows
  end

  local since = ctx.lane_since or {top = 8, mid = 8, bot = 8}
  local jg_since = ctx.jg_since or 8

  if role == 1 then
    local d = my_delta(side, 1, picks)
    add("hold", "top", 10)
    add("shove", "top", 3.6 + math.max(0, d) * 0.48 + (min >= 10 and 1.2 or 0))
    add("recall", base_of(side), (lead > 900 and min >= 11) and 8.4 or 1.4)
    add("cover_herald", "herald", obj_urge(min, clock.next_herald) * 0.72 + math.max(0, d) * 0.1)
  elseif role == 2 then
    local farm = (min <= 1) and 16 or 10.6
    if jg_since < 3 then farm = farm + 3.2 end
    add("farm", own_jg(side), farm)
    local hunt = (not ctx.blood and min >= 3 and min <= 8)
    local weak, weak_s = weakest_lane(side, picks)
    for _, lane in ipairs({1, 3, 4}) do
      local id = (lane == 1 and "gank_top") or (lane == 3 and "gank_mid") or "gank_bot"
      local region = (lane == 1 and "top") or (lane == 3 and "mid") or "bot"
      local d = my_delta(side, lane, picks)
      local wait = since[region] or 8
      local s = 1.6 + math.max(0, -d) * 0.2 + math.max(0, d) * 0.12 + math.min(5, math.max(0, wait - 4) * 0.4)
      if min <= 1 or wait < 4 or jg_since < 3 then s = 0 end
      if hunt and lane == weak and wait >= 3 then s = s + 8.2 + math.max(0, weak_s) * 0.08 end
      add(id, region, s)
    end
    add("contest_scuttle", "drag", (clock.scuttle and 13.4 or 0.6))
    add("contest_dragon", "drag", obj_urge(min, clock.next_dragon) + (lead > 300 and 1.1 or 0))
    add("contest_herald", "herald", obj_urge(min, clock.next_herald) * 0.95)
    add("contest_baron", "baron", obj_urge(min, clock.next_baron) + (lead > 200 and 1.2 or 0))
  elseif role == 3 then
    local d = my_delta(side, 3, picks)
    add("hold", "mid", 10)
    local function roam(region, lane, extra)
      local wait = since[region] or 8
      local s = 0.8 + math.max(0, -my_delta(side, lane, picks)) * 0.1 + extra
      s = s + math.min(3, math.max(0, wait - 5) * 0.25)
      if wait < 5 then s = 0 end
      return s
    end
    add("roam_bot", "bot", roam("bot", 4, (clock.dragon or clock.scuttle) and 1.4 or 0))
    add("roam_top", "top", roam("top", 1, clock.herald and 1.4 or 0))
    local hv = 2.0
    if clock.dragon or clock.herald or clock.baron or clock.scuttle then
      hv = 11.1 + (lead > 0 and 0.6 or 0)
    end
    add("hover_river", river(ctx), hv + math.max(0, d) * 0.05)
  elseif role == 4 then
    local d = my_delta(side, 4, picks)
    add("hold", "bot", 10)
    add("shove", "bot", 3.8 + math.max(0, d) * 0.46 + (min >= 10 and 1.0 or 0))
    add("recall", base_of(side), (lead > 900 and min >= 11) and 8.2 or 1.2)
    add("cover_dragon", "drag", obj_urge(min, clock.next_dragon) * 0.86)
  else
    add("follow_adc", "bot", 11)
    add("ward_river", "drag", (clock.scuttle or clock.dragon) and 10.2 or 2.8)
    add("cover_dragon", "drag", obj_urge(min, clock.next_dragon) * 0.9)
  end

  if ctx.just_up then
    for _, row in ipairs(rows) do
      if row.id == "hold" or row.id == "farm" or row.id == "follow_adc" then
        row.score = row.score + 5
      elseif World.COMBAT[row.id] then
        row.score = row.score - 4
      end
    end
  end

  return rows
end

local function pick_row(rows, rng)
  local best = -1e9
  for _, row in ipairs(rows) do
    if row.score > best then best = row.score end
  end
  local tied = {}
  for _, row in ipairs(rows) do
    if row.score == best then tied[#tied + 1] = row end
  end
  table.sort(tied, function(a, b) return a.id < b.id end)
  if #tied == 1 or not rng then return tied[1] end
  return tied[rng:int(1, #tied)]
end

function M.choose_one(agent, ctx, rng)
  return pick_row(M.options(agent, ctx), rng)
end

local function lane_of_region(region)
  return World.region_lane(region)
end

local function ahead_on(side, region, picks)
  local lane = lane_of_region(region)
  return my_delta(side, lane, picks) >= 0
end

-- 野/中看一步：若对面野或中也会去同一格且本方该路落后，换发育。
function M.adjust_1ply(agent, row, raw, ctx)
  if agent.role ~= 2 and agent.role ~= 3 then return row end
  if not row or not World.COMBAT[row.id] then return row end
  local foe_jg = raw.jg and raw.jg[agent.side == "blue" and "red" or "blue"]
  local foe_mid = raw.mid and raw.mid[agent.side == "blue" and "red" or "blue"]
  local collide = (foe_jg and foe_jg.region == row.region) or (foe_mid and foe_mid.region == row.region)
  if collide and not ahead_on(agent.side, row.region, ctx.picks) then
    local safer = {id = agent.role == 2 and "farm" or "hold", region = agent.role == 2 and own_jg(agent.side) or "mid", score = row.score - 5}
    return safer
  end
  if World.is_obj(row.region) and not collide and ctx.clock and (ctx.clock.dragon or ctx.clock.herald or ctx.clock.baron) then
    row = {id = row.id, region = row.region, score = row.score + 1.4}
  end
  return row
end

function M.decide(world, ctx, rng)
  ctx = ctx or {}
  local raw = {jg = {}, mid = {}, all = {}}
  for _, a in ipairs(world.agents) do
    local c = {
      min = ctx.min,
      picks = ctx.picks,
      gold_b = ctx.gold_b,
      gold_r = ctx.gold_r,
      clock = ctx.clock,
      blood = ctx.blood,
      lane_since = ctx.lane_since,
      jg_since = (ctx.jg_since and ctx.jg_since[a.side]) or 8,
      just_up = a.alive and a.intent == "recall" and a.region == base_of(a.side),
    }
    local row = M.choose_one(a, c, rng)
    raw.all[a] = {row = row, ctx = c}
    if a.role == 2 then raw.jg[a.side] = row end
    if a.role == 3 then raw.mid[a.side] = row end
  end

  for _, a in ipairs(world.agents) do
    local pack = raw.all[a]
    local row = pack.row
    if a.role == 2 or a.role == 3 then
      row = M.adjust_1ply(a, row, raw, pack.ctx)
    end
    a.intent = row.id
    a.region = row.region
  end

  for _, side in ipairs({"blue", "red"}) do
    local sup = World.agent(world, side, 5)
    local adc = World.agent(world, side, 4)
    if sup and adc and sup.intent == "follow_adc" then
      if adc.alive then
        sup.region = adc.region
      else
        sup.region = base_of(side)
      end
    end
    for _, role in ipairs({1, 2, 3, 4, 5}) do
      local a = World.agent(world, side, role)
      if a and not a.alive then
        a.intent = "recall"
        a.region = base_of(side)
      end
    end
  end
end

return M
