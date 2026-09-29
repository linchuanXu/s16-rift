-- 红方征召：禁威胁、抢对位、补空路。无抖动。同一步同棋盘永远同一人。
local Data = require("domain.rift_data")
local Roles = require("domain.mech_roles")
local Match = require("domain.mech_matchup")

local M = {}

local function listed(rows, key)
  if not rows then return nil end
  for _, row in ipairs(rows) do
    if row[1] == key then return row[3] end
  end
  return nil
end

local function compose(key, board, side)
  local foe = side == "blue" and "red" or "blue"
  local c = Data.champ(key)
  local score = 0
  for _, opp in ipairs(board.picks[foe]) do
    if opp then
      local wr = Match.vs(key, opp) or listed(c.s, opp)
      if wr then score = score + (wr - 50) * 0.35 end
    end
  end
  local i = Roles.index(c.p)
  if i and board.picks[side][i] then
    score = score - 48
  elseif i and not board.picks[side][i] then
    score = score + 14
    local holes = Roles.empty(board.picks[side])
    if #holes <= 2 then score = score + 10 end
  end
  return score
end

local function candidates(board, role)
  local out = {}
  for _, key in ipairs(Data.CHAMP_KEYS) do
    if not board.used[key] then
      if not role or Roles.of(key) == role then
        out[#out + 1] = key
      end
    end
  end
  if #out == 0 and role then
    return candidates(board, nil)
  end
  return out
end

function M.score_ban(key, board, side)
  local foe = side == "blue" and "red" or "blue"
  local c = Data.champ(key)
  local i = Roles.index(c.p)
  local score = Match.threat(key)
  if i and not board.picks[foe][i] then
    score = score + 9
  end
  if i and board.picks[side][i] then
    score = score - 6
  end
  local holes = Roles.empty(board.picks[foe])
  if #holes == 1 and i == holes[1].i then
    score = score + 16
  end
  return score
end

function M.score_pick(key, board, side)
  local foe = side == "blue" and "red" or "blue"
  local c = Data.champ(key)
  local i = Roles.index(c.p)
  local score = Match.power(key) * 0.55
  if i then
    local opp = board.picks[foe][i]
    if opp then
      score = score + (Match.vs_or(key, opp, 50) - 50) * 0.95
    end
  end
  return score + compose(key, board, side)
end

local function best(board, side, kind, role)
  local list = candidates(board, role)
  local top, top_s = nil, -1e9
  for _, key in ipairs(list) do
    local s = kind == "ban" and M.score_ban(key, board, side) or M.score_pick(key, board, side)
    if s > top_s then
      top, top_s = key, s
    end
  end
  return top or Data.CHAMP_KEYS[1]
end

function M.choose(board)
  local step = board.step
  if not step then return Data.CHAMP_KEYS[1] end
  local side = step.side or "red"
  if step.t == "ban" then
    return best(board, side, "ban")
  end
  local holes = Roles.empty(board.picks[side])
  if #holes == 1 then
    return best(board, side, "pick", holes[1].role)
  end
  return best(board, side, "pick")
end

function M.choose_role(board, side, role)
  return best(board, side, "pick", role)
end

function M.fill_bans(board, side, n)
  board.bans = board.bans or {blue = {}, red = {}}
  board.bans[side] = board.bans[side] or {}
  for _ = 1, (n or 5) do
    local key = best(board, side, "ban")
    if not key or board.used[key] then break end
    board.bans[side][#board.bans[side] + 1] = key
    board.used[key] = true
  end
  return board.bans[side]
end

function M.fill_side(board, side)
  local slots = board.picks[side]
  for _, hole in ipairs(Roles.empty(slots)) do
    local key = M.choose_role(board, side, hole.role)
    slots[hole.i] = key
    board.used[key] = true
  end
  return slots
end

return M
