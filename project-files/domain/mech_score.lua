-- 草案分：版本 / 对线 / 禁用。评语由对位表生成。
local Data = require("domain.rift_data")
local Match = require("domain.mech_matchup")
local Cast = require("domain.mech_cast")
local Book = require("domain.mech_book")

local M = {}

local function clamp(n)
  n = math.floor((n or 0) + 0.5)
  if n < 1 then return 1 end
  if n > 99 then return 99 end
  return n
end

local function version_score(side, picks)
  local acc, n = 0, 0
  for i = 1, 5 do
    local key = picks[side][i]
    if key then
      acc = acc + (Data.champ(key).w or 50)
      n = n + 1
    end
  end
  if n == 0 then return 50 end
  return acc / n
end

local function lane_score(side, picks, form)
  local acc, n = 0, 0
  for i = 1, 5 do
    local a, b = picks[side][i], picks[side == "blue" and "red" or "blue"][i]
    local boost = 0
    if form then
      local d = Match.lane_delta(picks, i, form) - Match.lane_delta(picks, i)
      boost = side == "red" and -d or d
    end
    if a and b then
      local wr = Match.vs_or(a, b, 50)
      if side == "red" then wr = 100 - wr end
      acc = acc + wr + boost
      n = n + 1
    elseif a then
      acc = acc + (Data.champ(a).w or 50) + boost
      n = n + 1
    end
  end
  if n == 0 then return 50 end
  return acc / n
end

local function ban_score(side, bans)
  local acc, n = 0, 0
  for _, key in ipairs(bans[side] or {}) do
    if key then
      acc = acc + Match.threat(key)
      n = n + 1
    end
  end
  if n == 0 then return 50 end
  return acc / n
end

function M.rate(board)
  local picks = board.picks
  local bans = board.bans
  local form = Match.player_form(board.starters, board.red_id)
  local function pack(side)
    local vrs = version_score(side, picks)
    local lan = lane_score(side, picks, form)
    local lbn = ban_score(side, bans)
    local total = vrs * 0.42 + lan * 0.38 + lbn * 0.2
    return {
      total = clamp(total),
      items = {{"vrs", clamp(vrs)}, {"lan", clamp(lan)}, {"lbn", clamp(lbn)}},
    }
  end
  local blue, red = pack("blue"), pack("red")
  return {
    blue = blue.total,
    red = red.total,
    items = {blue = blue.items, red = red.items},
    comment = Cast.score_comment(Match.lane_table(picks, form)),
    lanes = Match.lane_table(picks, form),
  }
end

function M.p_blue(board)
  local rate = M.rate(board)
  local p = 0.5 + ((rate.blue or 50) - (rate.red or 50)) / 160
  if board and board.starters then
    p = p + (Book.avg(board.starters) - Book.opp_rating(board.red_id)) / 200
  end
  if p < 0.30 then p = 0.30 end
  if p > 0.70 then p = 0.70 end
  return p
end

return M
