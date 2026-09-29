-- 十人地块世界。时钟是规则，不是剧本。相遇只认混格。
local M = {}

M.REGIONS = {
  "baron", "drag", "herald", "bot", "mid", "top", "jg_b", "jg_r", "base_b", "base_r",
}

M.DRAGON_SPAWNS = {5, 12, 18, 25}
M.HERALD_SPAWN = 14
M.BARON_SPAWN = 20
M.SCUTTLE_SPAWN = 2

M.COMBAT = {
  gank_top = true,
  gank_mid = true,
  gank_bot = true,
  contest_scuttle = true,
  contest_dragon = true,
  contest_herald = true,
  contest_baron = true,
  roam_top = true,
  roam_bot = true,
  hover_river = true,
  cover_herald = true,
  cover_dragon = true,
  ward_river = true,
}

function M.home_region(role, side)
  if role == 1 then return "top" end
  if role == 2 then return side == "blue" and "jg_b" or "jg_r" end
  if role == 3 then return "mid" end
  if role == 4 or role == 5 then return "bot" end
  return "mid"
end

function M.base_region(side)
  return side == "blue" and "base_b" or "base_r"
end

function M.region_lane(region)
  if region == "top" then return 1 end
  if region == "jg_b" or region == "jg_r" then return 2 end
  if region == "mid" then return 3 end
  if region == "bot" or region == "drag" then return 4 end
  if region == "herald" or region == "baron" then return 1 end
  return 3
end

function M.is_obj(region)
  return region == "drag" or region == "herald" or region == "baron"
end

function M.next_after(list, min)
  for _, t in ipairs(list) do
    if t > min then return t end
  end
  return nil
end

function M.spawn(picks)
  local agents = {}
  for _, side in ipairs({"blue", "red"}) do
    for role = 1, 5 do
      agents[#agents + 1] = {
        side = side,
        role = role,
        key = picks[side] and picks[side][role],
        region = M.home_region(role, side),
        intent = "hold",
        alive = true,
        back_at = 0,
      }
    end
  end
  return {agents = agents}
end

function M.agent(world, side, role)
  for _, a in ipairs(world.agents) do
    if a.side == side and a.role == role then return a end
  end
  return nil
end

function M.by_key(world, key)
  if not key then return nil end
  for _, a in ipairs(world.agents) do
    if a.key == key then return a end
  end
  return nil
end

function M.respawn(world, min)
  for _, a in ipairs(world.agents) do
    if not a.alive and min >= (a.back_at or 0) then
      a.alive = true
      a.region = M.base_region(a.side)
      a.intent = "recall"
    end
  end
end

-- 刚复活的这一分钟留在家里，下一分钟再出线。
function M.hold_base(world, min)
  for _, a in ipairs(world.agents) do
    if a.alive and min > 0 and a.back_at == min then
      a.intent = "recall"
      a.region = M.base_region(a.side)
    end
  end
end

function M.kill(world, key, min, late)
  local a = M.by_key(world, key)
  if not a then return end
  a.alive = false
  a.back_at = min + (late and 3 or 2)
end

function M.occupy(world)
  local tiles = {}
  for _, id in ipairs(M.REGIONS) do
    tiles[id] = {region = id, blue = {}, red = {}}
  end
  for _, a in ipairs(world.agents) do
    if a.key then
      local t = tiles[a.region]
      if t then t[a.side][#t[a.side] + 1] = a end
    end
  end
  return tiles
end

local function has_combat(people)
  for _, a in ipairs(people) do
    if M.COMBAT[a.intent] then return true end
  end
  return false
end

function M.encounters(world)
  local tiles = M.occupy(world)
  local out = {}
  for _, id in ipairs(M.REGIONS) do
    local t = tiles[id]
    if #t.blue > 0 and #t.red > 0 then
      local people = {}
      for _, a in ipairs(t.blue) do people[#people + 1] = a end
      for _, a in ipairs(t.red) do people[#people + 1] = a end
      local combat = has_combat(people)
      if M.is_obj(id) or combat then
        local pri = 0
        if id == "baron" then pri = 90
        elseif id == "drag" then pri = 80
        elseif id == "herald" then pri = 70
        elseif combat then pri = 40
        end
        pri = pri + #people
        out[#out + 1] = {
          region = id,
          blue = t.blue,
          red = t.red,
          people = people,
          combat = combat,
          obj = M.is_obj(id),
          pri = pri,
        }
      end
    end
  end
  table.sort(out, function(a, b)
    if a.pri == b.pri then return a.region < b.region end
    return a.pri > b.pri
  end)
  return out
end

function M.primary(world)
  local list = M.encounters(world)
  return list[1]
end

function M.roles_on(enc)
  local roles = {}
  if not enc then return roles end
  for _, a in ipairs(enc.people) do
    roles[a.role] = true
  end
  return roles
end

function M.keys_on(enc)
  local keys = {}
  if not enc then return keys end
  for _, a in ipairs(enc.people) do
    if a.key then keys[#keys + 1] = a.key end
  end
  return keys
end

function M.lane_only(tiles, region)
  local t = tiles[region]
  if not t then return nil end
  if #t.blue > 0 and #t.red == 0 then return "blue", t.blue end
  if #t.red > 0 and #t.blue == 0 then return "red", t.red end
  return nil
end

function M.clock(min, st)
  st = st or {}
  local scuttle = min == M.SCUTTLE_SPAWN and not st.scuttle_taken
  local dragon = st.next_dragon and min >= st.next_dragon
  local herald = st.next_herald and min >= st.next_herald
  local baron = st.next_baron and min >= st.next_baron
  return {
    scuttle = scuttle,
    dragon = dragon and true or false,
    herald = herald and true or false,
    baron = baron and true or false,
    next_dragon = st.next_dragon,
    next_herald = st.next_herald,
    next_baron = st.next_baron,
  }
end

function M.init_objs()
  return {
    next_dragon = M.DRAGON_SPAWNS[1],
    next_herald = M.HERALD_SPAWN,
    next_baron = M.BARON_SPAWN,
    scuttle_taken = false,
  }
end

function M.claim_dragon(st, min)
  st.next_dragon = M.next_after(M.DRAGON_SPAWNS, min)
end

function M.claim_herald(st)
  st.next_herald = nil
end

function M.claim_baron(st)
  st.next_baron = nil
end

function M.obj_visible(st, min)
  local out = {dragon = false, herald = false, baron = false}
  if st.next_dragon and min >= st.next_dragon - 2 then out.dragon = true end
  if st.next_herald and min >= st.next_herald - 2 then out.herald = true end
  if st.next_baron and min >= st.next_baron - 2 then out.baron = true end
  return out
end

function M.next_hint(min, st)
  local rows = {}
  if st.next_dragon then
    rows[#rows + 1] = {t = st.next_dragon, kind = "dragon", key = "nxdr"}
  end
  if st.next_herald then
    rows[#rows + 1] = {t = st.next_herald, kind = "herald", key = "nxrh"}
  end
  if st.next_baron then
    rows[#rows + 1] = {t = st.next_baron, kind = "baron", key = "nxbr"}
  end
  table.sort(rows, function(a, b)
    if a.t == b.t then return a.kind < b.kind end
    return a.t < b.t
  end)
  for _, row in ipairs(rows) do
    if row.t >= min then return row end
  end
  return {t = nil, kind = "push", key = "nxpush"}
end

return M
