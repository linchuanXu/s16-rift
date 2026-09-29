-- 选手簿：图鉴、仓库、上场、战力。不抽卡、不跑对局。
local Data = require("domain.rift_data")

local M = {}

M.START_POINTS = 1000
M.GIFT = {"theshy", "canyon", "faker", "uzi", "ming"}

-- 对面队力：50 + 签表战力 * 4（HLE≈90，MVK≈54）
local TEAM_FORM = {
  hle = 10, gen = 9, t1 = 8, blg = 7, dk = 6,
  cfo = 5, tsw = 4, g2 = 3, kc = 2, mvk = 1,
}

M.PLAYERS = {
  {id = "theshy", n = "TheShy", cn = "尚志", role = "上", champ = "camille", rating = 86, rarity = "SR"},
  {id = "zeus", n = "Zeus", cn = "宙斯", role = "上", champ = "ksante", rating = 89, rarity = "SSR"},
  {id = "bin", n = "Bin", cn = "泽彬", role = "上", champ = "jayce", rating = 83, rarity = "SR"},
  {id = "canyon", n = "Canyon", cn = "峡谷", role = "野", champ = "leesin", rating = 92, rarity = "SSR"},
  {id = "tian", n = "Tian", cn = "天天", role = "野", champ = "viego", rating = 76, rarity = "R"},
  {id = "jiejie", n = "Jiejie", cn = "杰杰", role = "野", champ = "graves", rating = 72, rarity = "R"},
  {id = "faker", n = "Faker", cn = "相赫", role = "中", champ = "ahri", rating = 95, rarity = "SSR"},
  {id = "rookie", n = "Rookie", cn = "义进", role = "中", champ = "syndra", rating = 82, rarity = "SR"},
  {id = "knight", n = "Knight", cn = "骑士", role = "中", champ = "yone", rating = 84, rarity = "SR"},
  {id = "uzi", n = "Uzi", cn = "乌兹", role = "下", champ = "kaisa", rating = 85, rarity = "SR"},
  {id = "ruler", n = "Ruler", cn = "载赫", role = "下", champ = "jinx", rating = 88, rarity = "SSR"},
  {id = "gala", n = "GALA", cn = "伽乐", role = "下", champ = "ezreal", rating = 75, rarity = "R"},
  {id = "ming", n = "Ming", cn = "明凯", role = "辅", champ = "thresh", rating = 79, rarity = "SR"},
  {id = "meiko", n = "Meiko", cn = "咪哥", role = "辅", champ = "nautilus", rating = 80, rarity = "SR"},
  {id = "keria", n = "Keria", cn = "岷析", role = "辅", champ = "lulu", rating = 90, rarity = "SSR"},
}

local BY_ID = {}
local BY_RARITY = {SSR = {}, SR = {}, R = {}}
for _, p in ipairs(M.PLAYERS) do
  BY_ID[p.id] = p
  local bag = BY_RARITY[p.rarity]
  bag[#bag + 1] = p.id
end

function M.get(id)
  return BY_ID[id]
end

function M.cn(id)
  local p = BY_ID[id]
  return p and (p.cn or p.n) or (id or "")
end

function M.rating(id)
  local p = BY_ID[id]
  return p and p.rating or 70
end

function M.rarity_of(rating)
  if (rating or 0) >= 88 then return "SSR" end
  if (rating or 0) >= 78 then return "SR" end
  return "R"
end

function M.pool(rarity)
  return BY_RARITY[rarity] or {}
end

function M.opp_rating(team_id)
  return 50 + (TEAM_FORM[team_id] or 0) * 4
end

function M.owns(st, id)
  return st and st.owned and st.owned[id] == true
end

function M.add(st, id)
  if not st or not BY_ID[id] then return false end
  st.owned = st.owned or {}
  if st.owned[id] then return false end
  st.owned[id] = true
  return true
end

function M.owned_for_role(st, role)
  local out = {}
  for _, p in ipairs(M.PLAYERS) do
    if p.role == role and M.owns(st, p.id) then
      out[#out + 1] = p.id
    end
  end
  return out
end

function M.ensure(st)
  if not st then return st end
  if st.points == nil then st.points = M.START_POINTS end
  if type(st.owned) ~= "table" then
    st.owned = {}
    for _, id in ipairs(M.GIFT) do
      st.owned[id] = true
    end
  end
  if type(st.starters) ~= "table" or #st.starters < 5 then
    st.starters = {M.GIFT[1], M.GIFT[2], M.GIFT[3], M.GIFT[4], M.GIFT[5]}
  end
  st.pulls = st.pulls or 0
  return st
end

function M.ready(st)
  if not st or type(st.starters) ~= "table" then return false end
  for i, role in ipairs(Data.ROLES) do
    local id = st.starters[i]
    local p = BY_ID[id]
    if not p or p.role ~= role or not M.owns(st, id) then
      return false
    end
  end
  return true
end

function M.set_starter(st, slot, id)
  if not st or not slot or slot < 1 or slot > 5 then return false end
  local p = BY_ID[id]
  local role = Data.ROLES[slot]
  if not p or p.role ~= role or not M.owns(st, id) then return false end
  st.starters = st.starters or {M.GIFT[1], M.GIFT[2], M.GIFT[3], M.GIFT[4], M.GIFT[5]}
  for i = 1, 5 do
    if i ~= slot and st.starters[i] == id then return false end
  end
  st.starters[slot] = id
  return true
end

function M.avg(starters)
  local acc, n = 0, 0
  for i = 1, 5 do
    acc = acc + M.rating(starters and starters[i])
    n = n + 1
  end
  return n > 0 and (acc / n) or 70
end

return M
