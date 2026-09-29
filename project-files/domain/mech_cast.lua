-- 转播句：结构化事件 → 短中文。语气贴近赛场解说，不引用整段稿。
local Data = require("domain.rift_data")

local M = {}

local OBJ = {
  dragon = "小龙",
  riftherald = "峡谷先锋",
  baron = "大龙",
  elder = "远古巨龙",
  tower = "防御塔",
  grubs = "虚空幼虫",
}

local LANE = {
  [1] = "上路",
  [2] = "野区",
  [3] = "中路",
  [4] = "下路",
  [5] = "下路",
}

function M.champ_name(key)
  local c = Data.champ(key)
  return (c and c.n) or key or "?"
end

local function who(ev)
  return M.champ_name(ev.icon)
end

local function foe(ev)
  return M.champ_name(ev.victim)
end

local function tag(ev)
  return ev.tag or (ev.who == "blue" and "蓝方" or "红方")
end

local function lane_cn(ev)
  return LANE[ev.lane] or "中路"
end

-- 人名进句子，头像仍左右站。句式跟赛评条一样短。
function M.event_text(ev)
  if ev.text then return ev.text end
  local kind = ev.kind
  local lane = lane_cn(ev)
  if kind == "open" then
    return "对线开始"
  end
  if kind == "fail_invade" then
    return who(ev) .. "入侵被抓"
  end
  if kind == "ward" then
    return who(ev) .. "河湾做眼"
  end
  if kind == "split" then
    return who(ev) .. "带线" .. lane
  end
  if kind == "bait" then
    return "佯装开龙"
  end
  if kind == "shutdown" then
    return who(ev) .. "收下大头"
  end
  if kind == "first_blood" then
    if ev.victim then return who(ev) .. "拿下一血" end
    return tag(ev) .. "拿下一血"
  end
  if kind == "solo" or kind == "kill" or kind == "gank" then
    if ev.victim then return who(ev) .. "击杀" .. foe(ev) end
    return who(ev) .. "击杀"
  end
  if kind == "dive" then
    return who(ev) .. lane .. "越塔"
  end
  if kind == "pick" then
    return who(ev) .. "抓到了" .. (ev.victim and foe(ev) or "")
  end
  if kind == "double" then
    return who(ev) .. "完成双杀"
  end
  if kind == "invade" then
    return who(ev) .. "入侵野区"
  end
  if kind == "scuttle" then
    return who(ev) .. "拿下河蟹"
  end
  if kind == "roam" then
    return who(ev) .. "游走" .. lane
  end
  if kind == "dragon" then
    if ev.soul then return tag(ev) .. "点亮龙魂" end
    if ev.n == 1 then return tag(ev) .. "拿下第一条小龙" end
    if ev.n == 2 then return tag(ev) .. "拿下第二条小龙" end
    return tag(ev) .. "拿下小龙"
  end
  if kind == "steal" then
    return tag(ev) .. "抢到了" .. (OBJ[ev.obj] or "龙")
  end
  if kind == "herald" then
    return tag(ev) .. "拿下峡谷先锋"
  end
  if kind == "grubs" then
    return tag(ev) .. "清掉虚空幼虫"
  end
  if kind == "baron" then
    return tag(ev) .. "拿到大龙"
  end
  if kind == "tower" then
    return tag(ev) .. "推掉" .. lane .. (ev.first and "一塔" or "塔")
  end
  if kind == "plate" then
    return tag(ev) .. lane .. "吃到镀层"
  end
  if kind == "herald_crash" then
    return "先锋撞掉" .. lane .. "一塔"
  end
  if kind == "item" then
    return tag(ev) .. (ev.item or "星蚀") .. "做好了"
  end
  if kind == "setup" then
    return (OBJ[ev.obj] or "目标") .. "刷新"
  end
  if kind == "fight" then
    return (ev.lost or 0) .. "换" .. (ev.got or 0)
  end
  if kind == "ace" then
    return tag(ev) .. "团灭"
  end
  if kind == "inhib" then
    return tag(ev) .. "拆掉" .. lane .. "水晶"
  end
  if kind == "siege" then
    return tag(ev) .. "兵线进场"
  end
  return ev.ev or ""
end

function M.phase_text(pose)
  if pose == "late" then return "后期决战" end
  if pose == "mid" then return "中期转线" end
  return "对线期"
end

function M.next_text(kind)
  if kind == "dragon" then return "小龙" end
  if kind == "herald" then return "先锋" end
  if kind == "baron" then return "大龙" end
  if kind == "elder" then return "远古龙" end
  if kind == "grubs" then return "幼虫" end
  return "推家"
end

function M.score_comment(lanes)
  local best_i, best_d, worst_i, worst_d = 1, -1e9, 1, 1e9
  for i, row in ipairs(lanes or {}) do
    local d = row.delta or 0
    if d > best_d then best_i, best_d = i, d end
    if d < worst_d then worst_i, worst_d = i, d end
  end
  local br = Data.ROLES[best_i] or "对线"
  local wr = Data.ROLES[worst_i] or "对线"
  if best_d >= 6 and worst_d <= -6 then
    return br .. "对位占优；" .. wr .. "被压需小心"
  end
  if best_d >= 6 then
    return br .. "对位极优，可做节奏点"
  end
  if worst_d <= -6 then
    return wr .. "对位吃亏，先稳住发育"
  end
  return "五路均势，看野区与小龙"
end

function M.end_stat(frame)
  local tb = (frame and frame.towers_b) or 0
  local tr = (frame and frame.towers_r) or 0
  local db = (frame and frame.drag_b) or 0
  local dr = (frame and frame.drag_r) or 0
  return "塔 " .. tb .. "-" .. tr .. " · 龙 " .. db .. "-" .. dr
end

return M
