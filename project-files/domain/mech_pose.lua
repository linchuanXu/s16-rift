-- 峡谷几何。只按 MinuteFact 摆人：idle 待线，有事实才离开本线。
-- 地图左 480 是峡谷。蓝方家左下，红方家右上。
-- 召唤师峡谷是 180° 旋转对称，不是左右镜像。
-- 对线期双方站在同一波兵线附近（差不多的位置），略偏向己方，不是各守外塔。
-- 48 头像左上角：绕 (240,240) 转 180° → (432-x, 432-y)。蓝上对红下，蓝中对红中。

local M = {}

local S = {
  base_b = {46, 392},
  base_r = {404, 36},
  -- 上路兵线：两人贴在一起。整组靠左上角落，贴着上路外塔那一段。
  top_b = {84, 36},
  top_r = {120, 36},
  top_out_b = {140, 20},
  top_out_r = {56, 52},
  clash_top = {102, 28},
  -- 野区：蓝左营地，红是它的 180°。
  jg_b = {100, 210},
  jg_r = {332, 222},
  jg_krug_b = {62, 154},
  jg_krug_r = {370, 278},
  jg_rap_b = {136, 252},
  jg_rap_r = {296, 180},
  clash_jg = {240, 200},
  -- 中路兵线：两人靠近河道，红 = 蓝的 180°。
  mid_b = {200, 232},
  mid_r = {232, 200},
  clash_mid = {216, 216},
  mid_river = {216, 216},
  -- 下路兵线：上路的 180°。整组靠右，贴红方下路外塔那一段。
  bot_b = {312, 396},
  bot_r = {348, 396},
  clash_bot = {330, 404},
  bot_out_b = {376, 396},
  bot_out_r = {284, 396},
  sup_b = {288, 408},
  sup_r = {368, 384},
  scuttle_b = {268, 304},
  scuttle_t = {214, 156},
  dragon = {286, 318},
  baron = {154, 108},
  herald = {186, 196},
  mid_tw = {216, 216},
  inhib_b = {96, 348},
  inhib_r = {318, 132},
  tw_top_b = {72, 96},
  tw_top_r = {352, 44},
  tw_mid_b = {148, 268},
  tw_mid_r = {268, 168},
  tw_bot_b = {80, 400},
  tw_bot_r = {352, 400},
  obj_dragon = {303, 337},
  obj_baron = {150, 108},
  obj_herald = {188, 188},
}

M.S = S

local MAP = {x0 = 10, y0 = 10, x1 = 418, y1 = 414}

local function clamp(x, y)
  if x < MAP.x0 then x = MAP.x0 end
  if y < MAP.y0 then y = MAP.y0 end
  if x > MAP.x1 then x = MAP.x1 end
  if y > MAP.y1 then y = MAP.y1 end
  return {x, y}
end

local function add(p, dx, dy)
  return clamp(p[1] + dx, p[2] + dy)
end

local function wobble(min, role, side)
  local s = (side == "blue") and 3 or 8
  local k = min * 19 + role * 11 + s
  -- 上路走廊窄，少抖，免得滑进河里。
  if role == 1 then
    return (k % 7) - 3, (k % 5) - 2
  end
  return (k % 13) - 6, (k % 9) - 4
end

local function lane_home(role, side, min)
  local b = side == "blue"
  if role == 1 then
    return b and S.top_b or S.top_r
  end
  if role == 2 then
    local path = b
      and {S.jg_b, S.jg_krug_b, S.jg_rap_b, S.jg_b}
      or {S.jg_r, S.jg_krug_r, S.jg_rap_r, S.jg_r}
    return path[(min % 4) + 1]
  end
  if role == 3 then
    return b and S.mid_b or S.mid_r
  end
  if role == 4 then
    return b and S.bot_b or S.bot_r
  end
  return b and S.sup_b or S.sup_r
end

-- 打架时围在同一点旁边，不把人甩出这条线。
local RING_B = {{14, 2}, {4, 12}, {-12, 6}, {-10, -6}, {6, -10}}
local RING_R = {{-14, -2}, {-4, -12}, {12, -6}, {10, 6}, {-6, 10}}

local function around(center, i, side)
  local ring = side == "blue" and RING_B or RING_R
  local d = ring[((i - 1) % 5) + 1]
  return add(center, d[1], d[2])
end

local LANE_SPOT = {
  [1] = {S.top_b, S.top_r},
  [2] = {S.jg_b, S.jg_r},
  [3] = {S.mid_b, S.mid_r},
  [4] = {S.bot_b, S.bot_r},
  [5] = {S.sup_b, S.sup_r},
}

function M.home(role, side, min)
  return lane_home(role, side, min or 0)
end

function M.lane_xy(role, side)
  local pair = LANE_SPOT[role] or LANE_SPOT[3]
  return side == "blue" and pair[1] or pair[2]
end

local function pulled(fact, role, side)
  if not fact or fact.act == "idle" or not fact.roles or not fact.roles[role] then
    return false
  end
  if fact.only and fact.only ~= side then return false end
  return true
end

local function agent_at(world, side, role)
  if not world or not world.agents then return nil end
  for _, a in ipairs(world.agents) do
    if a.side == side and a.role == role then return a end
  end
  return nil
end

function M.place(ctx)
  local min = ctx.min or 0
  local fact = ctx.fact
  local lead = ctx.lead
  local world = ctx.world
  local out = {}
  for i = 1, 5 do
    local function one(side)
      local home = lane_home(i, side, min)
      local ag = agent_at(world, side, i)
      if pulled(fact, i, side) then
        local c = fact.spot
        if fact.split and side == "red" and fact.spot_r then c = fact.spot_r end
        if c then home = around(c, i, side) end
      elseif ag and (not ag.alive or ag.region == "base_b" or ag.region == "base_r") then
        home = side == "blue" and S.base_b or S.base_r
      end
      local dx, dy = wobble(min, i, side)
      if lead == side and min >= 8 and i ~= 2 and not pulled(fact, i, side) then
        dx = dx + (side == "blue" and 6 or -6)
        dy = dy + (side == "blue" and -4 or 4)
      end
      return add(home, dx, dy)
    end
    out[i] = {b = one("blue"), r = one("red")}
  end
  return out
end

function M.clash(lane)
  if lane == 1 then return S.clash_top end
  if lane == 2 then return S.clash_jg end
  if lane == 3 then return S.clash_mid end
  return S.clash_bot
end

function M.region_clash(region)
  if region == "top" then return S.clash_top end
  if region == "mid" then return S.clash_mid end
  if region == "bot" then return S.clash_bot end
  if region == "jg_b" or region == "jg_r" then return S.clash_jg end
  if region == "drag" then return S.dragon end
  if region == "herald" then return S.herald end
  if region == "baron" then return S.baron end
  if region == "base_b" then return S.base_b end
  if region == "base_r" then return S.base_r end
  return S.clash_mid
end

function M.region_home(region, role, side, min)
  if region == "base_b" or region == "base_r" then
    return side == "blue" and S.base_b or S.base_r
  end
  if region == "drag" then return S.dragon end
  if region == "herald" then return S.herald end
  if region == "baron" then return S.baron end
  return lane_home(role, side, min or 0)
end

-- 闲时钉在本线，不在河中游荡。
function M.approach(prev, target)
  return target or prev
end

function M.pieces(picks, layout, hide)
  hide = hide or {}
  local out = {}
  for i = 1, 5 do
    local spot = layout[i]
    local bk, rk = picks.blue[i], picks.red[i]
    if bk and not hide[bk] then out[#out + 1] = {"blue", bk, spot.b[1], spot.b[2]} end
    if rk and not hide[rk] then out[#out + 1] = {"red", rk, spot.r[1], spot.r[2]} end
  end
  return out
end

function M.dist2(x, y, spot)
  local dx, dy = x - spot[1], y - spot[2]
  return dx * dx + dy * dy
end

return M
