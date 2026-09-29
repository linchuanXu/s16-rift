-- 对局：从职业时间线库抽一条，再按草案分偏谁赢。不再跑意图/混格。
local Rng = require("domain.mech_rng")
local Score = require("domain.mech_score")
local Cast = require("domain.mech_cast")
local Pose = require("domain.mech_pose")
local Fact = require("domain.mech_fact")
local Scripts = require("domain.mech_scripts")
local Data = require("domain.rift_data")

local M = {}

M.END_MIN = 28

local GOLD = {
  p = 80,
  k = 280,
  fb = 300,
  d = 220,
  e = 260,
  h = 180,
  g = 70,
  br = 320,
  t = 160,
  inh = 200,
  nx = 120,
}

local function pose_name(min)
  if min >= 25 then return "late" end
  if min >= 14 then return "mid" end
  return "laning"
end

local function add_gold(st, side, n)
  if side == "blue" then
    st.gold_b = st.gold_b + n
  else
    st.gold_r = st.gold_r + n
  end
end

local function other(side)
  return side == "blue" and "red" or "blue"
end

local function as_side(code)
  return code == "b" and "blue" or "red"
end

local function flip_code(code)
  return code == "b" and "r" or "b"
end

local function role_ok(n)
  return type(n) == "number" and n >= 1 and n <= 5
end

local function kill_lane(ev)
  local vr, ar = ev.vr, ev.ar
  if vr == 1 or vr == 3 or vr == 4 then return vr end
  if vr == 5 then return 4 end
  if ar == 1 or ar == 3 or ar == 4 then return ar end
  return ev.l or 3
end

local function region_of(ev)
  local k = ev.k
  if k == "d" or k == "e" then return "drag" end
  if k == "h" or k == "g" then return "herald" end
  if k == "br" then return "baron" end
  local l = ev.l or kill_lane(ev)
  if l == 1 then return "top" end
  if l == 4 or l == 5 then return "bot" end
  if l == 2 then return ev.s == "b" and "jg_b" or "jg_r" end
  return "mid"
end

local function roles_of(ev)
  local r = {}
  if role_ok(ev.ar) then r[ev.ar] = true end
  if role_ok(ev.vr) then r[ev.vr] = true end
  local k = ev.k
  if k == "d" or k == "e" then
    r[2] = true
    r[4] = true
    r[5] = true
  elseif k == "h" or k == "br" then
    r[1] = true
    r[2] = true
    r[3] = true
  elseif k == "g" then
    r[1] = true
    r[2] = true
  elseif k == "t" or k == "inh" or k == "nx" then
    local l = ev.l or 3
    r[l] = true
    if l == 4 then r[5] = true end
  elseif k == "fb" or k == "k" then
    local l = kill_lane(ev)
    r[l] = true
    if ev.ar == 2 or ev.vr == 2 then r[2] = true end
    if ev.vr == 5 or ev.ar == 5 then r[5] = true end
  end
  return r
end

local PRI = {br = 1, e = 2, d = 3, h = 4, fb = 5, k = 6, t = 7, g = 8, inh = 9, nx = 10}

local function pick_key(picks, side, role)
  return picks[side] and picks[side][role]
end

local function ev_kind(k)
  if k == "fb" then return "first_blood" end
  if k == "k" then return "kill" end
  if k == "d" or k == "e" then return "dragon" end
  if k == "h" then return "herald" end
  if k == "g" then return "grubs" end
  if k == "br" then return "baron" end
  if k == "t" then return "tower" end
  if k == "inh" then return "inhib" end
  if k == "nx" then return "siege" end
  if k == "p" then return "plate" end
  return k
end

local function story_kind(ev)
  if ev.k == "fb" then return "first_blood" end
  if ev.k == "k" then
    if ev.ar == 2 and ev.vr and ev.vr ~= 2 then return "gank" end
    if ev.ar and ev.vr and ev.ar == ev.vr and ev.ar ~= 2 then return "solo" end
    return "kill"
  end
  return ev_kind(ev.k)
end

local function actor_role_of(ev)
  if role_ok(ev.ar) then return ev.ar end
  local k = ev.k
  local lane = ev.l or 3
  if k == "t" or k == "inh" or k == "nx" then
    return (lane == 4) and 4 or lane
  end
  if k == "d" or k == "e" or k == "h" or k == "g" or k == "br" then
    return 2
  end
  if k == "fb" or k == "k" then
    return kill_lane(ev)
  end
  return 2
end

local function victim_role_of(ev)
  if role_ok(ev.vr) then return ev.vr end
  if ev.k == "fb" or ev.k == "k" then
    return kill_lane(ev)
  end
  return nil
end

local function drop_outer(st, side, lane)
  local col = (lane == 1) and "top" or ((lane == 4 or lane == 5) and "bot" or "mid")
  local key = col .. "_" .. (side == "blue" and "r" or "b")
  if st.tower_up[key] then
    st.tower_up[key] = false
    if side == "blue" then st.outers_b = st.outers_b + 1 else st.outers_r = st.outers_r + 1 end
    return true
  end
  return false
end

local function one_event(st, ev)
  ev.text = Cast.event_text(ev)
  st.feed = st.feed or {}
  table.insert(st.feed, 1, ev)
  while #st.feed > 6 do
    table.remove(st.feed)
  end
  st.hot = true
  return ev
end

local function apply(st, picks, ev)
  local side = as_side(ev.s)
  local k = ev.k
  if k == "p" then
    add_gold(st, side, GOLD.p)
    return nil
  end
  local lane = kill_lane(ev)
  local actor_role = actor_role_of(ev)
  local victim_role = victim_role_of(ev)
  local actor = pick_key(picks, side, actor_role) or pick_key(picks, side, 2)
  local victim
  if k == "fb" or k == "k" then
    victim = victim_role and pick_key(picks, other(side), victim_role)
    victim = victim or pick_key(picks, other(side), lane) or pick_key(picks, other(side), 3)
    if side == "blue" then st.blue = st.blue + 1 else st.red = st.red + 1 end
    add_gold(st, side, GOLD[k] or 280)
    add_gold(st, other(side), 80)
    if victim and victim_role then
      st.dead[other(side)][victim_role] = st.min + (st.min >= 25 and 3 or 2)
    end
  elseif k == "d" or k == "e" then
    if side == "blue" then st.drag_b = st.drag_b + 1 else st.drag_r = st.drag_r + 1 end
    add_gold(st, side, GOLD[k])
    local n = (side == "blue" and st.drag_b or st.drag_r)
    if n >= 2 then st.soul = side end
  elseif k == "h" then
    if side == "blue" then st.heralds_b = st.heralds_b + 1 else st.heralds_r = st.heralds_r + 1 end
    add_gold(st, side, GOLD.h)
  elseif k == "g" then
    if side == "blue" then st.grubs_b = st.grubs_b + 1 else st.grubs_r = st.grubs_r + 1 end
    add_gold(st, side, GOLD.g)
  elseif k == "br" then
    st.baron_side = side
    add_gold(st, side, GOLD.br)
  elseif k == "t" then
    local first = false
    if (ev.tier or 1) <= 1 then
      first = not st.first_tower and drop_outer(st, side, lane)
      if first then st.first_tower = side end
      if not first then
        drop_outer(st, side, lane)
      end
    end
    if side == "blue" then st.towers_b = st.towers_b + 1 else st.towers_r = st.towers_r + 1 end
    add_gold(st, side, first and 220 or GOLD.t)
  elseif k == "inh" then
    if side == "blue" then st.inhibs_b = st.inhibs_b + 1 else st.inhibs_r = st.inhibs_r + 1 end
    add_gold(st, side, GOLD.inh)
  elseif k == "nx" then
    add_gold(st, side, GOLD.nx)
  end
  local kind = story_kind(ev)
  local icon = actor
  if k == "h" then st.herald_at = st.min end
  if kind == "tower" and st.herald_at and st.min - st.herald_at <= 2 then
    kind = "herald_crash"
    icon = "riftherald"
  elseif kind == "tower" or kind == "inhib" or kind == "siege" then
    icon = "tower"
  end
  if kind == "herald" then icon = actor or "riftherald" end
  if kind == "dragon" then icon = actor or "dragon" end
  if kind == "baron" then icon = actor or "baron" end
  local row = {
    t = st.min,
    kind = kind,
    side = side == "blue" and "l" or "r",
    icon = icon,
    who = side,
    tag = st.tag and st.tag[side],
    lane = lane,
    ar = actor_role,
    vr = victim_role,
    victim = victim,
    first = (kind == "tower" and st.first_tower == side and (st.outers_b + st.outers_r) == 1) or nil,
    obj = (kind == "dragon" and "dragon") or (kind == "herald" and "herald") or (kind == "baron" and "baron") or nil,
    n = (kind == "dragon") and (st.drag_b + st.drag_r) or nil,
    soul = (kind == "dragon" and st.soul == side) or nil,
  }
  return Fact.build({
    act = kind,
    region = region_of(ev),
    roles = roles_of(ev),
    keys = {actor, victim},
    who = side,
    ev = row,
  })
end

local function by_minute(script, flip)
  local bags = {}
  for _, e in ipairs(script.ev or {}) do
    local row = {}
    for k, v in pairs(e) do row[k] = v end
    if flip then row.s = flip_code(row.s) end
    local t = row.t or 0
    if t < 0 then t = 0 end
    if t > M.END_MIN then t = M.END_MIN end
    bags[t] = bags[t] or {}
    bags[t][#bags[t] + 1] = row
  end
  return bags
end

local function choose(rng, picks, bans, input)
  local board = {
    picks = picks,
    bans = bans or {blue = {}, red = {}},
    starters = input and input.starters,
    blue_id = input and input.blue_id,
    red_id = input and input.red_id,
  }
  local rate = Score.rate(board)
  local want = rng:chance(Score.p_blue(board)) and "b" or "r"
  local list = Scripts.LIST or {}
  local src = list[rng:int(1, math.max(1, #list))] or {id = 0, won = "b", dur = 28, ev = {}}
  return src, src.won ~= want, want, rate
end

local function flavor_minute(st, picks, min)
  if min < 12 or min > 24 then return nil end
  if #(st.feed or {}) >= 4 then return nil end
  local lead = (st.gold_b >= st.gold_r) and "blue" or "red"
  local tag = st.tag and st.tag[lead]
  if not st.item_done and min >= 15 and min <= 19 then
    st.item_done = true
    local who = pick_key(picks, lead, 2) or pick_key(picks, lead, 3)
    local row = {
      t = min,
      kind = "item",
      side = lead == "blue" and "l" or "r",
      icon = "i6692",
      who = lead,
      tag = tag,
      item = "星蚀",
    }
    one_event(st, row)
    return Fact.build({
      act = "item",
      region = lead == "blue" and "jg_b" or "jg_r",
      roles = {[2] = true},
      keys = {who},
      who = lead,
      ev = row,
    })
  end
  if (st.split_n or 0) < 2 and min >= 14 then
    st.split_n = (st.split_n or 0) + 1
    local role = (min % 2 == 0) and 1 or 2
    local key = pick_key(picks, lead, role)
    local lane = role == 1 and 1 or 3
    local row = {
      t = min,
      kind = "split",
      side = lead == "blue" and "l" or "r",
      icon = key,
      who = lead,
      tag = tag,
      lane = lane,
    }
    one_event(st, row)
    return Fact.build({
      act = "split",
      region = lane == 1 and "top" or "mid",
      roles = {[role] = true},
      keys = {key},
      who = lead,
      ev = row,
    })
  end
  return nil
end

local function next_hint(bags, min)
  local rank = {d = 1, e = 1, br = 2, h = 3, g = 4, t = 5, inh = 6, nx = 6}
  local name = {d = "dragon", e = "dragon", br = "baron", h = "herald", g = "grubs", t = "push", inh = "push", nx = "push"}
  local best
  for t = min + 1, M.END_MIN do
    for _, e in ipairs(bags[t] or {}) do
      local r = rank[e.k]
      if r and (not best or r < best.r) then
        best = {kind = name[e.k], t = t, r = r}
      end
    end
    if best and best.r <= 4 then
      break
    end
  end
  if not best then return "push", 28, "nxpush" end
  local key = (best.kind == "dragon" and "nxdr") or (best.kind == "herald" and "nxrh") or (best.kind == "baron" and "nxbr") or "nxpush"
  return best.kind, best.t, key
end

local function world_objs(st)
  local S = Pose.S
  local out = {}
  if st.show_dragon then out[#out + 1] = {"dragon", S.obj_dragon[1], S.obj_dragon[2]} end
  if st.show_baron then out[#out + 1] = {"baron", S.obj_baron[1], S.obj_baron[2]} end
  if st.show_herald then out[#out + 1] = {"riftherald", S.obj_herald[1], S.obj_herald[2]} end
  local tw = {
    {"top_b", S.tw_top_b},
    {"mid_b", S.tw_mid_b},
    {"bot_b", S.tw_bot_b},
    {"top_r", S.tw_top_r},
    {"mid_r", S.tw_mid_r},
    {"bot_r", S.tw_bot_r},
  }
  for _, row in ipairs(tw) do
    if st.tower_up[row[1]] then
      out[#out + 1] = {"tower", row[2][1], row[2][2]}
    end
  end
  return out
end

local function ghost_world(st, min)
  local agents = {}
  for _, side in ipairs({"blue", "red"}) do
    for i = 1, 5 do
      local dead_until = st.dead[side][i] or -1
      local alive = min >= dead_until
      agents[#agents + 1] = {
        side = side,
        role = i,
        alive = alive,
        region = alive and "top" or (side == "blue" and "base_b" or "base_r"),
      }
    end
  end
  return {agents = agents}
end

local function snapshot(st, pieces, fact)
  local lead = st.gold_b - st.gold_r
  local total = math.max(1, st.gold_b + st.gold_r)
  local pct = math.floor(st.gold_b / total * 100 + 0.5)
  if pct < 18 then pct = 18 end
  if pct > 82 then pct = 82 end
  local events = {}
  for i, ev in ipairs(st.feed or {}) do
    events[i] = ev
  end
  return {
    min = st.min,
    label = st.label,
    pose = st.pose,
    blue = st.blue,
    red = st.red,
    towers_b = st.towers_b,
    towers_r = st.towers_r,
    outers_b = st.outers_b,
    outers_r = st.outers_r,
    drag_b = st.drag_b,
    drag_r = st.drag_r,
    gold_b = st.gold_b,
    gold_r = st.gold_r,
    gold_lead = lead,
    gold_lead_abs = math.abs(lead),
    gold_side = lead >= 0 and "b" or "r",
    gold_pct = pct,
    events = events,
    clash = fact and fact.spot and {{fact.spot[1], fact.spot[2]}} or {},
    objs = world_objs(st),
    pieces = pieces,
    fact = fact,
    ended = st.ended,
    hot = st.hot,
    next_key = st.next_key,
    next_at = st.next_at,
    next_kind = st.next_kind,
  }
end

function M.play(input)
  local picks = input.picks or {blue = {}, red = {}}
  local seed
  if input.starters then
    seed = Rng.hash(
      input.blue_id or "blue",
      input.red_id or "red",
      input.round or 0,
      table.concat(picks.blue or {}, ","),
      table.concat(picks.red or {}, ","),
      table.concat(input.starters, ",")
    )
  else
    seed = Rng.hash(
      input.blue_id or "blue",
      input.red_id or "red",
      input.round or 0,
      table.concat(picks.blue or {}, ","),
      table.concat(picks.red or {}, ",")
    )
  end
  local rng = Rng.new(seed)
  local src, flip, want = choose(rng, picks, input.bans, input)
  local bags = by_minute(src, flip)
  local st = {
    min = 0,
    pose = "laning",
    label = "ph1",
    blue = 0,
    red = 0,
    towers_b = 0,
    towers_r = 0,
    outers_b = 0,
    outers_r = 0,
    drag_b = 0,
    drag_r = 0,
    gold_b = 2500,
    gold_r = 2500,
    grubs_b = 0,
    grubs_r = 0,
    heralds_b = 0,
    heralds_r = 0,
    inhibs_b = 0,
    inhibs_r = 0,
    soul = nil,
    baron_side = nil,
    first_tower = nil,
    feed = {},
    tag = {
      blue = Data.team_by_id(input.blue_id or "t1").name,
      red = Data.team_by_id(input.red_id or "blg").name,
    },
    herald_at = nil,
    item_done = false,
    split_n = 0,
    ended = false,
    hot = false,
    show_dragon = false,
    show_herald = false,
    show_baron = false,
    dead = {blue = {}, red = {}},
    tower_up = {
      top_b = true, mid_b = true, bot_b = true,
      top_r = true, mid_r = true, bot_r = true,
    },
  }
  local frames = {}
  local first_min
  for min = 0, M.END_MIN do
    st.min = min
    st.hot = false
    local pose = pose_name(min)
    if pose ~= st.pose then
      st.pose = pose
      if pose == "mid" then st.label = "ph2" end
      if pose == "late" then st.label = "ph3" end
    end
    add_gold(st, "blue", 42)
    add_gold(st, "red", 42)
    local fact
    local featured
    local merged = {}
    local kills = {}
    for _, ev in ipairs(bags[min] or {}) do
      local built = apply(st, picks, ev)
      if built then
        for r, v in pairs(built.roles or {}) do
          merged[r] = v
        end
        if ev.k == "fb" or ev.k == "k" then
          kills[#kills + 1] = built
        end
        if not featured or (PRI[ev.k] or 99) < (PRI[featured.k] or 99) then
          featured = {k = ev.k, fact = built}
        end
      end
    end
    fact = featured and featured.fact or Fact.idle()
    if fact.act ~= "idle" and next(merged) then
      fact.roles = merged
    end
    if featured and featured.fact and featured.fact.ev then
      local kind = featured.fact.ev.kind
      if kind == "solo" or kind == "gank" or kind == "kill" or kind == "first_blood" then
        local n = 0
        local last
        for _, row in ipairs(kills) do
          if row.ev then
            one_event(st, row.ev)
            last = row
            n = n + 1
            if n >= 2 then break end
          end
        end
        if last then fact = last end
      else
        one_event(st, featured.fact.ev)
      end
    else
      local extra = flavor_minute(st, picks, min)
      if extra then fact = extra end
    end
    if fact.act ~= "idle" and not first_min then first_min = min end
    local nk, nt, nkey = next_hint(bags, min)
    st.next_kind, st.next_at, st.next_key = nk, nt, nkey
    st.show_dragon = nk == "dragon" and nt and (nt - min) <= 4
    st.show_herald = nk == "herald" and nt and (nt - min) <= 3
    st.show_baron = nk == "baron" and nt and (nt - min) <= 4
    local lead = (st.gold_b >= st.gold_r) and "blue" or "red"
    local layout = Pose.place({
      min = min,
      fact = fact,
      lead = lead,
      picks = picks,
      world = ghost_world(st, min),
    })
    frames[min] = snapshot(st, Pose.pieces(picks, layout), fact)
  end
  local last = frames[M.END_MIN]
  return {
    seed = seed,
    script = string.format("gol:%d:%s:%s", src.id or 0, flip and "f" or "n", want),
    frames = frames,
    won = want == "b",
    end_stat = Cast.end_stat(last),
  }
end

function M.at(log, min)
  if not log or not log.frames then return nil end
  local m = math.floor(min or 0)
  if m < 0 then m = 0 end
  if m > M.END_MIN then m = M.END_MIN end
  return log.frames[m]
end

return M
