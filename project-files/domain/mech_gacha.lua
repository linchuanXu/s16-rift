-- 抽卡：扣分、按稀有度加权、重复折现。种子用 pulls，不读时钟。
local Book = require("domain.mech_book")
local Rng = require("domain.mech_rng")

local M = {}

M.COST = 100
M.DUP = 50
M.WIN = 500

local function pick_id(rng)
  local roll = rng:int(1, 100)
  local rarity = "R"
  if roll <= 8 then
    rarity = "SSR"
  elseif roll <= 30 then
    rarity = "SR"
  end
  local bag = Book.pool(rarity)
  return rng:pick(bag) or Book.PLAYERS[1].id
end

function M.can_draw(st)
  return st and (st.points or 0) >= M.COST
end

function M.draw(st)
  Book.ensure(st)
  if not M.can_draw(st) then
    return nil
  end
  local pulls = st.pulls or 0
  st.points = st.points - M.COST
  st.pulls = pulls + 1
  local rng = Rng.new(Rng.hash("gacha", pulls))
  local id = pick_id(rng)
  local dup = Book.owns(st, id)
  if dup then
    st.points = st.points + M.DUP
  else
    Book.add(st, id)
  end
  st.last_draw = {
    id = id,
    dup = dup,
    refund = dup and M.DUP or 0,
  }
  return st.last_draw
end

function M.award_win(st)
  if not st or st.match_paid then return false end
  st.match_paid = true
  st.points = (st.points or 0) + M.WIN
  return true
end

return M
