-- 对位与强度。征召 AI、评分、对局推演共用同一套数字，避免各写各的。
local Data = require("domain.rift_data")
local Book = require("domain.mech_book")

local M = {}

local function clamp_wr(n)
  if n < 27 then return 27 end
  if n > 73 then return 73 end
  return n
end

function M.vs(a, b)
  if not a or not b then return nil end
  local wr = Data.vs_wr(a, b)
  if wr then return wr end
  local rev = Data.vs_wr(b, a)
  if rev then return 100 - rev end
  return clamp_wr(50 + (M.power(a) - M.power(b)) * 0.38)
end

function M.vs_or(a, b, fallback)
  return M.vs(a, b) or fallback or 50
end

function M.power(key)
  local c = Data.champ(key)
  return (c.w or 50) + (c.pk or 0) * 0.25
end

function M.threat(key)
  local c = Data.champ(key)
  return (c.bn or 0) * 1.1 + (c.pk or 0) * 0.7 + (c.w or 50) * 0.2
end

local function player_delta(form, i)
  if not form then return 0 end
  local blue = form.blue and form.blue[i]
  local red = form.red and form.red[i]
  if not blue or not red then return 0 end
  return (blue - red) * 0.25
end

-- 正数表示蓝方该路占优。form 有 starters 时才加选手差。
function M.lane_delta(picks, i, form)
  local extra = player_delta(form, i)
  local a, b = picks.blue[i], picks.red[i]
  if not a and not b then return extra end
  if not b then return (M.power(a) - 50) * 0.4 + extra end
  if not a then return (50 - M.power(b)) * 0.4 + extra end
  local wr = M.vs_or(a, b, 50)
  local jg = 0
  if i ~= 2 then
    local jb, jr = picks.blue[2], picks.red[2]
    if jb and jr then
      jg = (M.power(jb) - M.power(jr)) * 0.12
    end
  end
  local duo = 0
  if i >= 4 then
    local bb, bs = picks.blue[4], picks.blue[5]
    local rb, rs = picks.red[4], picks.red[5]
    if bb and bs and rb and rs then
      duo = ((M.power(bb) + M.power(bs)) - (M.power(rb) + M.power(rs))) * 0.08
    end
  end
  return (wr - 50) + (M.power(a) - M.power(b)) * 0.35 + jg + duo + extra
end

function M.player_form(starters, red_id)
  if not starters then return nil end
  local opp = Book.opp_rating(red_id)
  local blue, red = {}, {}
  for i = 1, 5 do
    blue[i] = Book.rating(starters[i])
    red[i] = opp
  end
  return {blue = blue, red = red}
end

function M.lane_table(picks, form)
  local out = {}
  for i, role in ipairs(Data.ROLES) do
    out[i] = {role = role, delta = M.lane_delta(picks, i, form)}
  end
  return out
end

function M.team_form(id)
  local rank = {hle = 10, gen = 9, t1 = 8, blg = 7, dk = 6, cfo = 5, tsw = 4, g2 = 3, kc = 2, mvk = 1}
  return rank[id] or 0
end

function M.stronger(a, b)
  if not a then return b end
  if not b then return a end
  local fa, fb = M.team_form(a), M.team_form(b)
  if fa == fb then
    return a < b and a or b
  end
  return fa > fb and a or b
end

return M
