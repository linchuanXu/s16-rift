-- 十套稀疏剧本：每局 8–12 个高潮，其余分钟安静对线。
-- 选哪一套看对位，同一 BP 同一场仍固定。

local Match = require("domain.mech_matchup")

local M = {}

local function pack(id, beats)
  return {id = id, beats = beats}
end

M.PACKS = {
  pack("classic", {
    {t = 2, act = "scuttle"},
    {t = 4, act = "first_blood", lane = 4},
    {t = 8, act = "grubs"},
    {t = 9, act = "dragon"},
    {t = 10, act = "tower", lane = 4, first = true},
    {t = 14, act = "herald"},
    {t = 16, act = "herald_crash", lane = 3},
    {t = 21, act = "fight"},
    {t = 25, act = "baron"},
    {t = 28, act = "siege"},
  }),
  pack("snowball", {
    {t = 2, act = "first_blood", lane = 4},
    {t = 3, act = "dive", lane = 4},
    {t = 5, act = "tower", lane = 4, first = true},
    {t = 8, act = "dragon"},
    {t = 12, act = "herald"},
    {t = 15, act = "fight"},
    {t = 18, act = "dragon"},
    {t = 21, act = "baron"},
    {t = 22, act = "ace"},
    {t = 26, act = "siege"},
  }),
  pack("scale", {
    {t = 8, act = "first_blood", lane = 4},
    {t = 11, act = "dragon"},
    {t = 15, act = "herald"},
    {t = 17, act = "tower", lane = 3, first = true},
    {t = 19, act = "item", lane = 4},
    {t = 21, act = "dragon"},
    {t = 25, act = "baron"},
    {t = 26, act = "fight"},
    {t = 28, act = "fight"},
  }),
  pack("soul", {
    {t = 4, act = "first_blood", lane = 4},
    {t = 8, act = "dragon"},
    {t = 11, act = "tower", lane = 4, first = true},
    {t = 13, act = "dragon"},
    {t = 16, act = "herald"},
    {t = 18, act = "dragon"},
    {t = 22, act = "dragon"},
    {t = 25, act = "baron"},
    {t = 26, act = "fight"},
    {t = 28, act = "siege"},
  }),
  pack("herald", {
    {t = 1, act = "fail_invade"},
    {t = 5, act = "first_blood", lane = 1},
    {t = 6, act = "grubs"},
    {t = 10, act = "tower", lane = 1, first = true},
    {t = 14, act = "herald"},
    {t = 15, act = "herald_crash", lane = 3},
    {t = 18, act = "dragon"},
    {t = 21, act = "fight"},
    {t = 24, act = "baron"},
    {t = 28, act = "ace"},
  }),
  pack("botlane", {
    {t = 4, act = "first_blood", lane = 4},
    {t = 5, act = "dive", lane = 4},
    {t = 8, act = "tower", lane = 4, first = true},
    {t = 9, act = "dragon"},
    {t = 14, act = "dragon"},
    {t = 15, act = "herald"},
    {t = 18, act = "tower", lane = 3},
    {t = 21, act = "fight"},
    {t = 25, act = "baron"},
    {t = 28, act = "siege"},
  }),
  pack("split", {
    {t = 4, act = "first_blood", lane = 1},
    {t = 9, act = "tower", lane = 1, first = true},
    {t = 10, act = "split", lane = 1},
    {t = 13, act = "dragon"},
    {t = 15, act = "herald"},
    {t = 16, act = "split", lane = 1},
    {t = 21, act = "tower", lane = 3},
    {t = 25, act = "baron"},
    {t = 26, act = "split", lane = 1},
    {t = 27, act = "inhib", lane = 1},
    {t = 28, act = "siege"},
  }),
  pack("throw", {
    {t = 2, act = "first_blood", lane = 1},
    {t = 5, act = "tower", lane = 1, first = true},
    {t = 7, act = "dragon"},
    {t = 14, act = "herald"},
    {t = 21, act = "fight"},
    {t = 23, act = "baron"},
    {t = 24, act = "steal_force"},
    {t = 25, act = "fight"},
    {t = 26, act = "ace"},
    {t = 28, act = "siege"},
  }),
  pack("bait", {
    {t = 5, act = "first_blood", lane = 3},
    {t = 8, act = "dragon"},
    {t = 12, act = "tower", lane = 4, first = true},
    {t = 14, act = "herald"},
    {t = 18, act = "dragon"},
    {t = 21, act = "bait"},
    {t = 22, act = "tower", lane = 3},
    {t = 25, act = "baron"},
    {t = 28, act = "ace"},
  }),
  pack("skirmish", {
    {t = 1, act = "fail_invade"},
    {t = 5, act = "first_blood", lane = 2},
    {t = 9, act = "fight"},
    {t = 11, act = "dragon"},
    {t = 14, act = "herald"},
    {t = 17, act = "tower", lane = 4, first = true},
    {t = 21, act = "fight"},
    {t = 25, act = "baron"},
    {t = 26, act = "fight"},
    {t = 28, act = "siege"},
  }),
}

function M.by_id(id)
  for _, p in ipairs(M.PACKS) do
    if p.id == id then return p end
  end
  return M.PACKS[1]
end

function M.choose(rng, picks)
  if not picks then
    return M.PACKS[rng:int(1, #M.PACKS)]
  end
  local bot = math.abs(Match.lane_delta(picks, 4))
  local top = math.abs(Match.lane_delta(picks, 1))
  local mid = math.abs(Match.lane_delta(picks, 3))
  local jg = math.abs(Match.lane_delta(picks, 2))
  local even = 8 - (bot + top + mid) / 3
  local rows = {
    {id = "classic", s = 4},
    {id = "snowball", s = bot},
    {id = "botlane", s = bot + 0.4},
    {id = "split", s = top},
    {id = "herald", s = top + 0.3},
    {id = "scale", s = even},
    {id = "soul", s = jg + 2},
    {id = "skirmish", s = jg + mid},
    {id = "throw", s = 2.2},
    {id = "bait", s = 2.4},
  }
  table.sort(rows, function(a, b)
    if a.s == b.s then return a.id < b.id end
    return a.s > b.s
  end)
  return M.by_id(rows[rng:int(1, 6)].id)
end

function M.next_hints(beats)
  local out = {}
  for _, b in ipairs(beats) do
    if b.act == "dragon" then
      out[#out + 1] = {t = b.t, kind = "dragon", key = "nxdr"}
    elseif b.act == "herald" then
      out[#out + 1] = {t = b.t, kind = "herald", key = "nxrh"}
    elseif b.act == "baron" or b.act == "steal_force" then
      out[#out + 1] = {t = b.t, kind = "baron", key = "nxbr"}
    elseif b.act == "grubs" then
      out[#out + 1] = {t = b.t, kind = "grubs", key = "nxdr"}
    end
  end
  return out
end

return M
