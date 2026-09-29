local Data = require("domain.rift_data")
local Type = require("domain.rift_type")
local Book = require("domain.mech_book")
local Gacha = require("domain.mech_gacha")

local M = {}
local BLACK, WHITE = 15, 0
local W, H = 800, 480
local TEAM_TYPE = {
  hle = "nhle", gen = "ngen", t1 = "nt1", dk = "ndk", blg = "nblg",
  tsw = "ntsw", cfo = "ncfo", mvk = "nmvk", g2 = "ng2", kc = "nkc",
}
local DRAFT_NAME = {
  hle = "thle", gen = "tgen", t1 = "tt1", dk = "tdk", blg = "tblg",
  tsw = "ttsw", cfo = "tcfo", mvk = "tmvk", g2 = "tg2", kc = "tkc",
}
-- 原型 .sb-meta / 事件句内队名 12–13px
local LEAD_NAME = {
  hle = "lhle", gen = "lgen", t1 = "lt1", dk = "ldk", blg = "lblg",
  tsw = "ltsw", cfo = "lcfo", mvk = "lmvk", g2 = "lg2", kc = "lkc",
}
local ROLE_TYPE = { ["上"] = "rtop", ["野"] = "rjg", ["中"] = "rmid", ["下"] = "radc", ["辅"] = "rsup" }
local ROLE_FACE = { ["上"] = "itop", ["野"] = "ijg", ["中"] = "imid", ["下"] = "iadc", ["辅"] = "isup" }

local hits = {}

local function add_hit(id, x, y, w, h)
  hits[#hits + 1] = {id = id, x = x, y = y, w = w, h = h}
end

function M.reset_hits()
  hits = {}
end

function M.hit_at(x, y)
  for i = #hits, 1, -1 do
    local r = hits[i]
    if x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h then
      return r.id
    end
  end
  return nil
end

local function fill(g, x, y, w, h, c)
  g:rect(x, y, w, h, "fill", c)
end

local function stroke(g, x, y, w, h, c)
  g:rect(x, y, w, h, "stroke", c or BLACK)
end

-- CSS 2px solid
local function frame(g, x, y, w, h)
  stroke(g, x, y, w, h)
  stroke(g, x + 1, y + 1, w - 2, h - 2)
end

local function box(g, x, y, w, h, fill_c)
  if fill_c then fill(g, x, y, w, h, fill_c) end
  frame(g, x, y, w, h)
end

local function rule(g, x, y, w)
  fill(g, x, y, w, 2, BLACK)
end

local function img(g, key, x, y, white)
  if white then
    g:image(key, x, y, { color = 0 })
  else
    g:image(key, x, y)
  end
end

local function label(g, key, x, y, white)
  if white then
    return Type.draw(g, key, x, y, { color = 0 })
  end
  return Type.draw(g, key, x, y)
end

-- outline 3px, offset 2px（候选 / 按钮焦点）
local function focus_out(g, x, y, w, h)
  g:rect(x - 2, y - 2, w + 4, h + 4, "stroke", BLACK)
  g:rect(x - 3, y - 3, w + 6, h + 6, "stroke", BLACK)
  g:rect(x - 4, y - 4, w + 8, h + 8, "stroke", BLACK)
end

-- outline 3px, offset 3px（选边卡 / 主按钮）
local function focus_ring(g, x, y, w, h)
  g:rect(x - 3, y - 3, w + 6, h + 6, "stroke", BLACK)
  g:rect(x - 4, y - 4, w + 8, h + 8, "stroke", BLACK)
  g:rect(x - 5, y - 5, w + 10, h + 10, "stroke", BLACK)
end

-- 空位用实线框：虚线段数会把单帧命令顶过 1024。
local function dash_box(g, x, y, w, h)
  box(g, x, y, w, h, WHITE)
end

local function team_name(g, id, x, y, white)
  return label(g, TEAM_TYPE[id] or "nt1", x, y, white)
end

local function draft_name(g, id, x, y, white)
  return label(g, DRAFT_NAME[id] or "tt1", x, y, white)
end

local function lead_name(g, id, x, y, white)
  return label(g, LEAD_NAME[id] or "lt1", x, y, white)
end

local function champ48(g, key, x, y)
  img(g, key, x, y, false)
end

local function champ32(g, key, x, y)
  img(g, "h" .. key, x, y, false)
end

local function champ56(g, key, x, y)
  img(g, "m" .. key, x, y, false)
end

local function champ72(g, key, x, y)
  img(g, "c" .. key, x, y, false)
end

-- 禁用叉：两条对角各描一次。旧实现 36 条线，征程禁用一多就顶破 1024。
local function ban_x(g, x, y, s)
  s = s or 82
  local pad = math.max(4, math.floor(s * 0.14))
  local x0, y0 = x + pad, y + pad
  local x1, y1 = x + s - 1 - pad, y + s - 1 - pad
  g:line(x0, y0, x1, y1, BLACK)
  g:line(x0 + 1, y0, x1 + 1, y1, BLACK)
  g:line(x1, y0, x0, y1, BLACK)
  g:line(x1 + 1, y0, x0 + 1, y1, BLACK)
end

local function champ_confirm(g, key)
  -- 确认弹窗同一时刻只画一张；不再装 480 全量头像，用英雄池 72 居中。
  local slot, face = 200, 72
  local sx = math.floor((480 - slot) / 2)
  local sy = math.floor((H - slot) / 2)
  box(g, sx, sy, slot, slot, WHITE)
  champ72(g, key, sx + math.floor((slot - face) / 2), sy + math.floor((slot - face) / 2))
end

local function team32(g, id, x, y)
  img(g, "v" .. id, x, y, false)
end

local function team48(g, id, x, y)
  img(g, id, x, y, false)
end

local function team56(g, id, x, y)
  img(g, "p" .. id, x, y, false)
end

local function team64(g, id, x, y)
  img(g, "u" .. id, x, y, false)
end

local function btn(g, x, y, w, h, key, kind, focused)
  local primary = kind == "primary"
  local ink_white = primary or focused
  box(g, x, y, w, h, ink_white and BLACK or WHITE)
  if focused then focus_ring(g, x, y, w, h) end
  local tw = Type.w[key] or 0
  label(g, key, x + math.floor((w - tw) / 2), y + math.floor((h - 24) / 2), ink_white)
end

local function header(g, title_key, bar_key, extra_key)
  fill(g, 0, 0, W, 40, WHITE)
  label(g, title_key, 16, 6, false)
  local x = W - 16
  if extra_key then
    x = x - (Type.w[extra_key] or 0)
    label(g, extra_key, x, 11, false)
    if bar_key then
      x = x - (Type.w.mdot or 0)
      Type.draw(g, "mdot", x, 11)
    end
  end
  if bar_key then
    x = x - (Type.w[bar_key] or 0)
    label(g, bar_key, x, 11, false)
  end
  rule(g, 0, 38, W)
end

local function champ_name(g, id, x, y, white)
  return label(g, "nm" .. id, x, y, white)
end

local function face_name(g, id, x, y, white)
  local key = "fn" .. id
  if Type.w[key] then
    return label(g, key, x, y, white)
  end
  return champ_name(g, id, x, y, white)
end

local function role_badge(g, role, x, y)
  local key = ROLE_TYPE[role] or "rjg"
  local tw = Type.w[key] or 13
  box(g, x, y, tw + 10, 18, WHITE)
  label(g, key, x + 5, y + 1, false)
  return tw + 10
end

local function role_badge_lg(g, role, x, y)
  local key = ROLE_FACE[role] or ROLE_TYPE[role] or "rjg"
  local tw = Type.w[key] or 16
  box(g, x, y, tw + 16, 24, WHITE)
  label(g, key, x + 8, y + 2, false)
  return tw + 16
end

local function vsline(g, vs, x, y)
  if not vs or vs.kind ~= "wr" then
    return 0
  end
  local cx = x
  cx = cx + champ_name(g, vs.a, cx, y, false)
  cx = cx + Type.draw(g, "vss", cx, y)
  cx = cx + champ_name(g, vs.b, cx, y, false)
  cx = cx + Type.draw(g, "vsw", cx, y)
  cx = cx + Type.num(g, vs.wr, cx, y)
  Type.draw(g, "pct", cx, y)
  return 20
end

local function match_row(g, title, rows, x, y)
  if not rows or #rows == 0 then
    return 0
  end
  label(g, title, x, y + 18, false)
  local cx = x + 40
  for i = 1, math.min(3, #rows) do
    local row = rows[i]
    champ56(g, row[1], cx, y)
    local nw = Type.num(g, row[3], cx + 6, y + 58)
    Type.draw(g, "pct", cx + 6 + nw, y + 58)
    cx = cx + 78
  end
  return 78
end

local function mode_chip(g, x, y, w, h, key, on, focused)
  box(g, x, y, w, h, on and BLACK or WHITE)
  if focused then focus_ring(g, x, y, w, h) end
  local tw = Type.w[key] or 64
  label(g, key, x + math.floor((w - tw) / 2), y + math.floor((h - 20) / 2), on)
end

local function player_name(g, id, x, y, white)
  local key = "pn" .. (id or "")
  if Type.w[key] then
    return label(g, key, x, y, white)
  end
  local p = Book.get(id)
  if p and p.champ then
    return champ_name(g, p.champ, x, y, white)
  end
  return 0
end

local function rarity_key(rarity)
  if rarity == "SSR" then return "rssr" end
  if rarity == "SR" then return "rsr" end
  return "rrare"
end

local function points_row(g, n, x, y, white)
  local opts = white and { color = 0 } or nil
  local w = label(g, "pts", x, y, white)
  return w + 8 + Type.num(g, n or 0, x + w + 8, y, opts)
end

local function draw_home_hold(g, st)
  if st.hold ~= "roster" then return end
  fill(g, 0, 0, W, H, WHITE)
  add_hit("hold-close", 0, 0, W, H)
  label(g, "bbook", 16, 10, false)
  rule(g, 0, 42, W)
  local y = 56
  for _, role in ipairs(Data.ROLES) do
    role_badge(g, role, 20, y + 18)
    local x = 68
    for _, id in ipairs(Book.owned_for_role(st, role)) do
      local p = Book.get(id)
      local on = false
      for i = 1, 5 do
        if st.starters and st.starters[i] == id then on = true end
      end
      box(g, x, y, 148, 58, WHITE)
      if on then focus_out(g, x, y, 148, 58) end
      if p then
        champ32(g, p.champ, x + 10, y + 13)
        player_name(g, id, x + 50, y + 16, false)
      end
      add_hit("book-" .. id, x, y, 148, 58)
      x = x + 160
    end
    y = y + 66
  end
  fill(g, 0, 400, W, 80, WHITE)
  rule(g, 0, 400, W)
  btn(g, 320, 416, 160, 48, "kclose", "primary", st.focus == "hold-close")
  add_hit("hold-close", 320, 416, 160, 48)
end

function M.draw_title(g, st)
  M.reset_hits()
  Book.ensure(st)
  if st.hold == "roster" then
    fill(g, 0, 0, W, H, WHITE)
    draw_home_hold(g, st)
    return
  end
  fill(g, 0, 0, W, H, WHITE)
  fill(g, 0, 0, W, 40, WHITE)
  label(g, "bhome", 16, 6, false)
  points_row(g, st.points, 200, 11, false)
  local mode = st.mode or "easy"
  mode_chip(g, 560, 4, 100, 32, "measy", mode ~= "pro", st.focus == "mode-easy")
  add_hit("mode-easy", 560, 4, 100, 32)
  mode_chip(g, 668, 4, 100, 32, "mpro", mode == "pro", st.focus == "mode-pro")
  add_hit("mode-pro", 668, 4, 100, 32)
  rule(g, 0, 38, W)

  local face = Book.get(st.starters and st.starters[1])
  box(g, 40, 56, 200, 200, WHITE)
  if face then
    champ72(g, face.champ, 104, 120)
  end
  if face then
    role_badge_lg(g, face.role, 256, 72)
    player_name(g, face.id, 256, 110, false)
    label(g, rarity_key(face.rarity), 256, 144, false)
  end
  local chips_y = 276
  for i = 1, 5 do
    local id = st.starters and st.starters[i]
    local p = Book.get(id)
    local x = 40 + (i - 1) * 92
    box(g, x, chips_y, 84, 100, WHITE)
    if p then
      champ48(g, p.champ, x + 18, chips_y + 8)
      role_badge(g, p.role, x + 8, chips_y + 62)
    end
  end

  btn(g, 560, 70, 220, 56, "bgacha", "ghost", st.focus == "gacha")
  add_hit("gacha", 560, 70, 220, 56)
  btn(g, 560, 138, 220, 56, "bprep", "ghost", st.focus == "prep")
  add_hit("prep", 560, 138, 220, 56)
  btn(g, 560, 206, 220, 56, "kplay", "primary", st.focus == "start")
  add_hit("start", 560, 206, 220, 56)

  fill(g, 0, 428, W, 52, WHITE)
  rule(g, 0, 428, W)
  local dock = {
    {"dock-home", "hdock"},
    {"dock-roster", "hbook"},
    {"dock-prep", "hprep"},
    {"dock-play", "hplay"},
  }
  for i, row in ipairs(dock) do
    local x = (i - 1) * 200
    local on = st.focus == row[1] or (row[1] == "dock-home" and not st.hold)
    box(g, x, 428, 200, 52, on and BLACK or WHITE)
    if st.focus == row[1] then focus_ring(g, x, 428, 200, 52) end
    local tw = Type.w[row[2]] or 32
    label(g, row[2], x + math.floor((200 - tw) / 2), 440, on)
    add_hit(row[1], x, 428, 200, 52)
  end
  draw_home_hold(g, st)
end

function M.draw_gacha(g, st)
  M.reset_hits()
  Book.ensure(st)
  fill(g, 0, 0, W, H, WHITE)
  header(g, "bgacha")
  points_row(g, st.points, 640, 11, false)
  local ev = st.last_draw
  if ev and ev.id then
    local p = Book.get(ev.id)
    box(g, 280, 80, 240, 220, WHITE)
    if p then
      champ72(g, p.champ, 364, 110)
      player_name(g, p.id, 340, 196, false)
      label(g, rarity_key(p.rarity), 340, 226, false)
      label(g, ev.dup and "dup" or "newc", 420, 226, false)
    end
  else
    label(g, "ghint", 300, 180, false)
  end
  local can = Gacha.can_draw(st)
  if not can then
    label(g, "nokpts", 348, 320, false)
  end
  btn(g, 220, 378, 190, 54, "kdraw", "primary", st.focus == "draw")
  add_hit("draw", 220, 378, 190, 54)
  btn(g, 430, 378, 150, 54, "kback", "ghost", st.focus == "back")
  add_hit("back", 430, 378, 150, 54)
end

function M.draw_prep(g, st)
  M.reset_hits()
  Book.ensure(st)
  fill(g, 0, 0, W, H, WHITE)
  header(g, "bprep")
  local slot = st.prep_slot
  for i = 1, 5 do
    local id = st.starters and st.starters[i]
    local p = Book.get(id)
    local x = 20 + (i - 1) * 156
    local on = slot == (i - 1)
    box(g, x, 56, 148, 150, WHITE)
    if on or st.focus == ("slot-" .. (i - 1)) then
      focus_ring(g, x, 56, 148, 150)
    end
    if p then
      role_badge(g, p.role, x + 8, 64)
      champ56(g, p.champ, x + 46, 90)
      player_name(g, p.id, x + 16, 156, false)
    end
    add_hit("slot-" .. (i - 1), x, 56, 148, 150)
  end
  if slot == nil then
    label(g, "phint", 40, 230, false)
  else
    local role = Data.ROLES[slot + 1]
    local x = 40
    for _, id in ipairs(Book.owned_for_role(st, role)) do
      local p = Book.get(id)
      local used = false
      for i = 1, 5 do
        if i ~= (slot + 1) and st.starters and st.starters[i] == id then used = true end
      end
      local cur = st.starters and st.starters[slot + 1] == id
      local fid = used and "" or ("own-" .. id)
      box(g, x, 226, 120, 100, (cur or st.focus == fid) and BLACK or WHITE)
      if st.focus == fid then focus_out(g, x, 226, 120, 100) end
      if p then
        champ48(g, p.champ, x + 36, 238)
        player_name(g, id, x + 16, 294, cur or st.focus == fid)
      end
      if fid ~= "" then add_hit(fid, x, 226, 120, 100) end
      x = x + 132
    end
  end
  btn(g, 220, 378, 190, 54, "klock", "primary", st.focus == "ok")
  add_hit("ok", 220, 378, 190, 54)
  btn(g, 430, 378, 150, 54, "kback", "ghost", st.focus == "back")
  add_hit("back", 430, 378, 150, 54)
end

function M.draw_pick(g, st)
  M.reset_hits()
  fill(g, 0, 0, W, H, WHITE)
  header(g, "bpick", "pg2")
  local gx, gy, cw, ch, gap = 20, 89, 142, 130, 12
  for i, t in ipairs(Data.TEAMS) do
    local col = (i - 1) % 5
    local row = math.floor((i - 1) / 5)
    local x = gx + col * (cw + gap)
    local y = gy + row * (ch + gap)
    local fid = "team-" .. (i - 1)
    local chosen = st.chosen == (i - 1)
    local foc = st.focus == fid
    local invert = chosen or foc
    box(g, x, y, cw, ch, invert and BLACK or WHITE)
    if foc then focus_ring(g, x, y, cw, ch) end
    fill(g, x + 37, y + 14, 68, 68, WHITE)
    team64(g, t.id, x + 39, y + 16)
    local nk = TEAM_TYPE[t.id] or "nt1"
    team_name(g, t.id, x + math.floor((cw - (Type.w[nk] or 0)) / 2), y + 88, invert)
    if chosen then
      fill(g, x, y, 36, 16, invert and WHITE or BLACK)
      label(g, "own", x + 7, y, not invert)
    end
    add_hit(fid, x, y, cw, ch)
  end
  btn(g, 20, 408, 190, 54, "kok", "primary", st.focus == "confirm")
  add_hit("confirm", 20, 408, 190, 54)
  btn(g, 222, 408, 140, 54, "kback", "ghost", st.focus == "back")
  add_hit("back", 222, 408, 140, 54)
end

local SIDE_W, BODY_H = 104, 426

local function draft_side(g, side, st)
  local x = side == "blue" and 0 or (W - SIDE_W)
  local is_turn = st.turn == side
  local team = side == "blue" and st.blue or st.red
  if is_turn then
    stroke(g, x, 0, SIDE_W, BODY_H)
    stroke(g, x + 1, 1, SIDE_W - 2, BODY_H - 2)
    stroke(g, x + 2, 2, SIDE_W - 4, BODY_H - 4)
  end
  local nk = DRAFT_NAME[team.id] or "tt1"
  local nw = Type.w[nk] or 21
  local row = 48 + 6 + nw
  local left = x + 6 + math.floor((SIDE_W - 12 - row) / 2)
  if side == "red" then
    draft_name(g, team.id, left, 16, false)
    team48(g, team.id, left + nw + 6, 4)
  else
    team48(g, team.id, left, 4)
    draft_name(g, team.id, left + 54, 16, false)
  end
  fill(g, x + 6, 54, SIDE_W - 12, 2, BLACK)
  local bans = st.bans and st.bans[side] or {}
  for i = 1, 5 do
    local bx = x + 4 + (i - 1) * 16
    if bans[i] then
      champ32(g, bans[i], bx, 56)
      ban_x(g, bx, 56, 32)
    else
      dash_box(g, bx + 8, 64, 14, 14)
    end
  end
  local picks = st.picks[side]
  local pick_top, pick_bot = 90, BODY_H
  local pick_h = math.floor((pick_bot - pick_top) / 5)
  for i = 1, 5 do
    local py = pick_top + (i - 1) * pick_h
    fill(g, x + 6, py + pick_h - 1, SIDE_W - 12, 1, BLACK)
    local k = picks[i]
    local role = Data.ROLES[i]
    local rk = ROLE_TYPE[role] or "rjg"
    local cy = py + math.floor((pick_h - 56) / 2)
    if side == "blue" then
      label(g, rk, x + 6, py + math.floor((pick_h - 18) / 2), false)
      if k then
        champ56(g, k, x + 24, cy)
      else
        dash_box(g, x + 24, cy, 56, 56)
      end
    else
      if k then
        champ56(g, k, x + 24, cy)
      else
        dash_box(g, x + 24, cy, 56, 56)
      end
      label(g, rk, x + SIDE_W - 20, py + math.floor((pick_h - 18) / 2), false)
    end
  end
end

local function qnum(g, n, x, y)
  local s = tostring(n)
  local cx = x
  for i = 1, #s do
    local ch = s:sub(i, i)
    if ch >= "0" and ch <= "9" then
      cx = cx + Type.draw(g, "q" .. ch, cx, y)
    end
  end
  return cx - x
end

local function qnum_w(n)
  local s = tostring(n)
  local w = 0
  for i = 1, #s do
    local ch = s:sub(i, i)
    if ch >= "0" and ch <= "9" then
      w = w + (Type.w["q" .. ch] or 29)
    end
  end
  return w
end

local function draft_pool(g, st)
  local mid_x, mid_w = SIDE_W, W - SIDE_W * 2
  local tabs = Data.ROLE_TABS
  -- 原型 .dr-rolebtn：高 44、最小 52、字号 22、间距 6
  local tab_w, tab_h, tab_gap = 52, 44, 6
  local tabs_w = #tabs * tab_w + (#tabs - 1) * tab_gap
  local tx0 = mid_x + math.floor((mid_w - tabs_w) / 2)
  local interactive = st.turn == "blue" and not st.pending
  for i, tab in ipairs(tabs) do
    local x = tx0 + (i - 1) * (tab_w + tab_gap)
    local y = 8
    local on = (st.role_filter or "") == tab.role
    local foc = st.focus == ("role-" .. tab.id)
    box(g, x, y, tab_w, tab_h, (on or foc) and BLACK or WHITE)
    if foc then focus_out(g, x, y, tab_w, tab_h) end
    local gw = Type.w[tab.glyph] or 22
    label(g, tab.glyph, x + math.floor((tab_w - gw) / 2), y + 8, on or foc)
    if interactive then add_hit("role-" .. tab.id, x, y, tab_w, tab_h) end
  end

  local cell, gap, cols = 82, 3, Data.DRAFT_COLS or 7
  local grid_w = cols * cell + (cols - 1) * gap
  local gx = mid_x + math.floor((mid_w - grid_w) / 2)
  local gy = 62
  for i, k in ipairs(st.pool or {}) do
    local col = (i - 1) % cols
    local row = math.floor((i - 1) / cols)
    local x = gx + col * (cell + gap)
    local y = gy + row * (cell + gap)
    local used = st.used and st.used[k]
    local banned = st.banned and st.banned[k]
    local pending = st.pending == k
    local foc = st.focus == ("cand-" .. k) and not used and st.turn == "blue" and not st.pending
    -- 原型 .dr-cell：1px 实线格。源图只有 72，居中不缩放。
    stroke(g, x, y, cell, cell)
    if pending or foc then
      stroke(g, x - 1, y - 1, cell + 2, cell + 2)
    end
    champ72(g, k, x + 5, y + 5)
    if banned then
      ban_x(g, x, y, cell)
    end
    if interactive and not used then
      add_hit("cand-" .. k, x, y, cell, cell)
    end
  end

  if st.turn == "red" then
    box(g, mid_x + 8, 62, mid_w - 16, BODY_H - 70, WHITE)
    local tw = Type.w.kred or 95
    label(g, "kred", 400 - math.floor(tw / 2), 220, false)
  end
end

local function draft_card(g, st)
  local k = st.pending
  if not k then return end
  fill(g, 0, 0, W, H, WHITE)
  M.reset_hits()
  champ_confirm(g, k)
  fill(g, 478, 0, 2, H, BLACK)
  fill(g, 480, 0, 320, H, WHITE)

  local c = Data.champ(k)
  local x, inner = 502, 276
  local btn_h, gap = 52, 10
  local has_w = c.w and c.w > 0
  local play = c.pl or 0
  local vs_h = (st.vs and st.vs.kind == "wr") and 28 or 0
  local s_h = (c.s and #c.s > 0) and 78 or 0
  local w_h = (c.wk and #c.wk > 0) and 78 or 0
  local top_h = 44 + 52 + 26 + vs_h + s_h + w_h
  local act_h = btn_h + gap + btn_h
  local total = top_h + 16 + act_h
  local y = math.floor((H - total) / 2)
  if y < 16 then y = 16 end

  local nk = Type.w["fn" .. k] and ("fn" .. k) or ("nm" .. k)
  local name_w = Type.w[nk] or 44
  face_name(g, k, x, y, false)
  role_badge_lg(g, c.p, x + name_w + 10, y + 8)
  y = y + 44

  do
    local sx = x
    sx = sx + label(g, "wrbig", sx, y + 12, false) + 10
    if has_w then
      sx = sx + qnum(g, c.w, sx, y)
      Type.draw(g, "qpct", sx, y)
    else
      label(g, "wna", sx, y + 12, false)
    end
  end
  y = y + 52

  do
    local sx = x
    sx = sx + label(g, "pkr", sx, y, false) + 4
    sx = sx + Type.num(g, c.pk or 0, sx, y)
    sx = sx + Type.draw(g, "pct", sx, y)
    sx = sx + label(g, "mdot", sx, y, false)
    sx = sx + label(g, "bnr", sx, y, false) + 4
    sx = sx + Type.num(g, c.bn or 0, sx, y)
    sx = sx + Type.draw(g, "pct", sx, y)
    if play > 0 then
      sx = sx + label(g, "mdot", sx, y, false)
      sx = sx + label(g, "plays", sx, y, false) + 4
      Type.num(g, play, sx, y)
    end
  end
  y = y + 26

  if vs_h > 0 then
    vsline(g, st.vs, x, y)
    y = y + vs_h
  end
  y = y + match_row(g, "strong", c.s, x, y)
  y = y + match_row(g, "wklab", c.wk, x, y)
  y = y + 16

  local verb = st.type == "ban" and "kokban" or "kokuse"
  if y + act_h > 468 then y = 468 - act_h end
  btn(g, x, y, inner, btn_h, verb, "primary", st.focus == "confirm")
  add_hit("confirm", x, y, inner, btn_h)
  btn(g, x, y + btn_h + gap, inner, btn_h, "kcancel", "ghost", st.focus == "cancel")
  add_hit("cancel", x, y + btn_h + gap, inner, btn_h)
end

local function draft_foot_meta(g, st, x, y)
  local cx = x
  if st.bar then cx = cx + label(g, st.bar, cx, y, false) end
  if st.mode ~= "easy" then
    cx = cx + label(g, "mdot", cx, y, false)
    cx = cx + label(g, "s28", cx, y, false)
  end
  cx = cx + Type.draw(g, "sp", cx, y) + 8
  cx = cx + Type.num(g, st.pool_n or 0, cx, y)
  if (st.pool_pages or 1) > 1 then
    cx = cx + label(g, "mdot", cx, y, false)
    cx = cx + Type.num(g, (st.pool_page or 0) + 1, cx, y)
    cx = cx + Type.draw(g, "sl", cx, y)
    cx = cx + Type.num(g, st.pool_pages, cx, y)
  else
    cx = cx + 4
    cx = cx + label(g, "nhero", cx, y, false)
  end
  return cx - x
end

function M.draw_draft(g, st)
  M.reset_hits()
  fill(g, 0, 0, W, H, WHITE)
  draft_side(g, "blue", st)
  draft_side(g, "red", st)
  fill(g, SIDE_W - 2, 0, 2, BODY_H, BLACK)
  fill(g, W - SIDE_W, 0, 2, BODY_H, BLACK)
  draft_pool(g, st)

  fill(g, 0, BODY_H, W, H - BODY_H, WHITE)
  rule(g, 0, BODY_H, W)
  local pages = st.pool_pages or 1
  local page = st.pool_page or 0
  local interactive = not st.pending
  local x = 16
  if pages > 1 then
    local prev_on = page > 0
    btn(g, x, 429, 100, 42, "kprev", "ghost", st.focus == "page-prev" and prev_on)
    if interactive and prev_on then add_hit("page-prev", x, 429, 100, 42) end
    x = x + 112
  end
  draft_foot_meta(g, st, x, 440)
  btn(g, 644, 429, 140, 42, "kpathb", "ghost", st.focus == "back")
  if interactive then add_hit("back", 644, 429, 140, 42) end
  if pages > 1 then
    local next_on = page < pages - 1
    btn(g, 532, 429, 100, 42, "knext", "ghost", st.focus == "page-next" and next_on)
    if interactive and next_on then add_hit("page-next", 532, 429, 100, 42) end
  end

  if st.pending then draft_card(g, st) end
end

local function path_mark(stn)
  if stn == "done" then return "mkwin" end
  if stn == "lose" then return "mklose" end
  if stn == "now" then return "mkfight" end
  if stn == "champ" then return "mkcup" end
  return nil
end

local function br_team(g, id, x, y, ink, compact)
  local face = compact and 32 or 48
  if not id then
    local box_s = compact and 32 or 40
    dash_box(g, x, y + (compact and 0 or 4), box_s, box_s)
    label(g, "pq", x + math.floor((box_s - 14) / 2), y + (compact and 4 or 10), ink)
    return box_s
  end
  fill(g, x, y, face, face, WHITE)
  if compact then
    team32(g, id, x, y)
    lead_name(g, id, x + face + 4, y + 7, ink)
  else
    team48(g, id, x, y)
    draft_name(g, id, x + face + 4, y + 14, ink)
  end
  local name_w = compact
    and (Type.w[LEAD_NAME[id] or "lt1"] or 16)
    or (Type.w[DRAFT_NAME[id] or "tt1"] or 21)
  return face + 4 + name_w
end

local function br_pair(g, m, x, y, w, h, slot)
  local now = m.st == "now"
  local lose = m.st == "lose"
  if now then
    fill(g, x, y, w, h, BLACK)
  elseif lose then
    dash_box(g, x, y, w, h)
  end
  local a, b = m.a, m.b
  if slot and m.st ~= "now" and m.st ~= "lose" then
    a, b = m.w, nil
  end
  local ink = now
  local compact = w < 110
  local face = compact and 32 or 48
  if b then
    br_team(g, a, x + 8, y + 8, ink, compact)
    br_team(g, b, x + 8, y + math.floor(h / 2) + 2, ink, compact)
  else
    br_team(g, a, x + math.floor((w - face) / 2), y + math.floor((h - face) / 2), ink, compact)
  end
end

function M.draw_path(g, st)
  M.reset_hits()
  fill(g, 0, 0, W, H, WHITE)
  local me = Data.team((st.chosen or 2) + 1)
  local ladder = Data.path_schedule(me.id)
  local path_round = st.path_round or 0
  local outcome = st.path_outcome
  local champ = outcome == "champ" or path_round >= #ladder
  local round = math.min(path_round, #ladder - 1)
  local cur = ladder[math.min(round + 1, #ladder)]
  local br = Data.path_bracket(me.id, path_round, champ and "champ" or outcome)

  fill(g, 0, 0, W, 40, WHITE)
  label(g, "bpath", 16, 6, false)
  add_hit("settings", 744, 0, 56, 40)
  label(g, "kset", 756, 11, st.focus == "settings")
  do
    local keys = {TEAM_TYPE[me.id] or "nt1", "mdot"}
    if champ then
      keys[#keys + 1] = "tagcup"
    else
      keys[#keys + 1] = cur.rn
      if outcome == "win" then
        keys[#keys + 1] = "mdot"
        keys[#keys + 1] = "tagprom"
      elseif outcome == "lose" then
        keys[#keys + 1] = "mdot"
        keys[#keys + 1] = "mklose"
      end
    end
    local tw = 0
    for _, k in ipairs(keys) do tw = tw + (Type.w[k] or 0) end
    Type.span(g, keys, 736 - tw, 11)
  end
  rule(g, 0, 38, W)

  local chip_w = math.floor(W / 3)
  for i, n in ipairs(br.swiss) do
    local x = (i - 1) * chip_w
    local now = n.st == "now"
    if now then fill(g, x, 40, chip_w, 56, BLACK) end
    if n.st == "lose" then dash_box(g, x + 2, 42, chip_w - 4, 52) end
    if i < 3 then fill(g, x + chip_w - 2, 40, 2, 56, BLACK) end
    local ink = now
    local cx = x + 8
    cx = cx + label(g, n.rn, cx, 59, ink)
    if n.st == "soon" then
      label(g, "pq", x + chip_w - 22, 52, ink)
    else
      cx = cx + 8
      fill(g, cx, 52, 32, 32, WHITE)
      team32(g, me.id, cx, 52)
      cx = cx + 36
      cx = cx + lead_name(g, me.id, cx, 59, ink) + 6
      cx = cx + label(g, "svs", cx, 59, ink) + 6
      fill(g, cx, 52, 32, 32, WHITE)
      team32(g, n.opp, cx, 52)
      cx = cx + 36
      lead_name(g, n.opp, cx, 59, ink)
      local mk = path_mark(n.st)
      if mk then
        local mw = (Type.w[mk] or 14) + 8
        box(g, x + chip_w - mw - 8, 55, mw, 26, now and WHITE or nil)
        label(g, mk, x + chip_w - mw - 4, 59, false)
      end
    end
  end
  rule(g, 0, 96, W)

  local tree_y, tree_h = 98, 316
  local qf_w, mid_w, join_w = 200, 288, 16
  local left_x = 12
  local join_l = left_x + qf_w + 8
  local mid_x = join_l + join_w + 8
  local join_r = mid_x + mid_w + 8
  local right_x = join_r + join_w + 8
  local ph = math.floor((tree_h - 16) / 2)
  local qf_y1 = tree_y + 8
  local qf_y2 = qf_y1 + ph + 8

  local function qf_col(pairs, x)
    br_pair(g, pairs[1], x, qf_y1, qf_w, ph)
    br_pair(g, pairs[2], x, qf_y2, qf_w, ph)
  end
  qf_col({br.qf[1], br.qf[2]}, left_x)
  qf_col({br.qf[3], br.qf[4]}, right_x)

  -- 原型 .br-join.left 开口朝八强，.right 开口朝右侧八强
  local function join(x, open_right)
    local c1 = qf_y1 + math.floor(ph / 2)
    local c2 = qf_y2 + math.floor(ph / 2)
    local mid = tree_y + math.floor(tree_h / 2)
    fill(g, x, c1, join_w, 2, BLACK)
    fill(g, x, c2, join_w, 2, BLACK)
    fill(g, x, mid, join_w, 2, BLACK)
    if open_right then
      fill(g, x, c1, 2, c2 - c1, BLACK)
    else
      fill(g, x + join_w - 2, c1, 2, c2 - c1, BLACK)
    end
  end
  join(join_l, false)
  join(join_r, true)

  local sf_w, sf_h = 116, 128
  local cup_w, cup_h = 48, 36
  local sf_y = tree_y + math.floor((tree_h - sf_h) / 2)
  br_pair(g, br.sf[1], mid_x, sf_y, sf_w, sf_h, true)
  local cup_x = mid_x + math.floor((mid_w - cup_w) / 2)
  local cup_y = tree_y + math.floor((tree_h - cup_h) / 2)
  local fi_now = br.fi.st == "now" or br.fi.st == "lose" or champ
  box(g, cup_x, cup_y, cup_w, cup_h, (champ or br.fi.st == "now") and BLACK or WHITE)
  Type.center(g, champ and "tagcup" or (fi_now and "rn6" or "mkcup"), cup_x + math.floor(cup_w / 2), cup_y + 8, (champ or br.fi.st == "now") and {color = 0} or nil)
  br_pair(g, br.sf[2], mid_x + mid_w - sf_w, sf_y, sf_w, sf_h, true)

  fill(g, 0, 416, W, 64, WHITE)
  rule(g, 0, 416, W)
  local started = path_round > 0 or outcome == "win"
  if champ then
    btn(g, 210, 421, 190, 54, "krew", "primary", st.focus == "again")
    add_hit("again", 210, 421, 190, 54)
    btn(g, 416, 421, 160, 54, "kside", "ghost", st.focus == "back")
    add_hit("back", 416, 421, 160, 54)
  elseif outcome == "lose" then
    btn(g, 230, 421, 160, 54, "kretry", "primary", st.focus == "retry")
    add_hit("retry", 230, 421, 160, 54)
    btn(g, 406, 421, 140, 54, "kfail", "ghost", st.focus == "fail")
    add_hit("fail", 406, 421, 140, 54)
  else
    btn(g, 210, 421, 160, 54, "kfight", "primary", st.focus == "fight")
    add_hit("fight", 210, 421, 160, 54)
    if started then
      btn(g, 386, 421, 190, 54, "kquit", "ghost", st.focus == "settings")
      add_hit("settings", 386, 421, 190, 54)
    else
      btn(g, 386, 421, 160, 54, "kside", "ghost", st.focus == "back")
      add_hit("back", 386, 421, 160, 54)
    end
  end
end

function M.draw_score(g, st)
  M.reset_hits()
  fill(g, 0, 0, W, H, WHITE)
  header(g, "bscore", "pg5")
  local rate = st.rate or {blue = 50, red = 50, items = {}, comment = ""}
  local function col(side, x)
    local team = side == "blue" and st.blue or st.red
    local total = side == "blue" and rate.blue or rate.red
    local items = (rate.items and rate.items[side]) or {}
    box(g, x, 49, 376, 315, WHITE)
    team56(g, team.id, x + 12, 58)
    team_name(g, team.id, x + 76, 72, false)
    qnum(g, total, x + 364 - qnum_w(total), 58)
    fill(g, x + 12, 118, 352, 2, BLACK)
    local picks = st.picks and st.picks[side] or {}
    for i = 1, 5 do
      local px = x + 16 + (i - 1) * 72
      if picks[i] then
        champ56(g, picks[i], px, 128)
      else
        dash_box(g, px, 128, 56, 56)
      end
    end
    for i, it in ipairs(items) do
      local y = 196 + (i - 1) * 32
      label(g, it[1], x + 16, y, false)
      local on = math.floor((it[2] + 5) / 10)
      local bar_x, bar_w = x + 68, 246
      for t = 1, 10 do
        local tx = bar_x + math.floor((t - 1) * bar_w / 10)
        local tw = math.floor(t * bar_w / 10) - math.floor((t - 1) * bar_w / 10) - 2
        box(g, tx, y + 4, tw, 11, t <= on and BLACK or WHITE)
      end
      Type.num(g, it[2], x + 330, y)
    end
  end
  col("blue", 16)
  col("red", 408)
  box(g, 16, 372, 768, 40, WHITE)
  local comment = rate.comment
  if type(comment) == "string" and comment ~= "" and comment ~= "cmt" then
    g:text(26, 386, comment, { color = 15 })
  else
    label(g, "cmt", 26, 382, false)
  end
  fill(g, 0, 420, W, 60, WHITE)
  rule(g, 0, 420, W)
  btn(g, 16, 426, 190, 42, "kenter", "primary", st.focus == "enter")
  add_hit("enter", 16, 426, 190, 42)
  btn(g, 218, 426, 160, 42, "kpathb", "ghost", st.focus == "back")
  add_hit("back", 218, 426, 160, 42)
end

local function remap_key(key)
  return key
end

local function map_tag(g, id, x, y, ink)
  local nk = TEAM_TYPE[id] or "nt1"
  local tw = (Type.w[nk] or 27) + 12
  box(g, x, y, tw, 20, ink and BLACK or WHITE)
  team_name(g, id, x + 6, y + 1, ink)
end

local function clock_draw(g, min, right, y, white)
  local m = math.max(0, math.floor(min or 0))
  local text = string.format("%02d:00", m)
  local opts = white and { color = 0 } or nil
  local w = 0
  for i = 1, #text do
    local ch = text:sub(i, i)
    if ch == ":" then
      w = w + (Type.w.ecln or 6)
    elseif ch >= "0" and ch <= "9" then
      w = w + (Type.w["e" .. ch] or 12)
    end
  end
  local x = right - w
  for i = 1, #text do
    local ch = text:sub(i, i)
    if ch == ":" then
      x = x + Type.draw(g, "ecln", x, y, opts)
    elseif ch >= "0" and ch <= "9" then
      x = x + Type.draw(g, "e" .. ch, x, y, opts)
    end
  end
end

local function clock_inline(g, min, x, y)
  local m = math.max(0, math.floor(min or 0))
  local text = string.format("%02d:00", m)
  local cx = x
  for i = 1, #text do
    local ch = text:sub(i, i)
    if ch == ":" then
      cx = cx + Type.draw(g, "cln", cx, y)
    elseif ch >= "0" and ch <= "9" then
      cx = cx + Type.draw(g, "d" .. ch, cx, y)
    end
  end
  return cx - x
end

local function scnum(g, n, x, y)
  local s = tostring(n)
  local cx = x
  for i = 1, #s do
    local ch = s:sub(i, i)
    if ch >= "0" and ch <= "9" then
      cx = cx + Type.draw(g, "sc" .. ch, cx, y)
    end
  end
  return cx - x
end

local function scnum_w(n)
  local s = tostring(n)
  local w = 0
  for i = 1, #s do
    local ch = s:sub(i, i)
    if ch >= "0" and ch <= "9" then
      w = w + (Type.w["sc" .. ch] or 22)
    end
  end
  return w
end

-- 原型 .sb-score：36px 比分，em 左右各 6px
local function rail_score(g, a, b, cx, y)
  local aw, bw = scnum_w(a), scnum_w(b)
  local dash = Type.w.scd or 16
  local total = aw + 6 + dash + 6 + bw
  local x = cx - math.floor(total / 2)
  x = x + scnum(g, a, x, y) + 6
  x = x + label(g, "scd", x, y, false) + 6
  scnum(g, b, x, y)
end

local function stat_pair(g, prefix, a, b, x, y)
  local cx = x + label(g, prefix, x, y, false)
  cx = cx + Type.num(g, a, cx, y)
  cx = cx + label(g, "smdash", cx, y, false)
  Type.num(g, b, cx, y)
end

function M.draw_sandbox(g, st)
  M.reset_hits()
  fill(g, 0, 0, W, H, WHITE)
  img(g, "rift-light", 0, 0, false)
  local d = st.match or Data.match_state_at(st.match_min or 0)
  local picks = st.picks or {blue = {}, red = {}}
  map_tag(g, st.blue.id, 8, 446, true)
  local rw = (Type.w[TEAM_TYPE[st.red.id]] or 27) + 12
  map_tag(g, st.red.id, 472 - rw, 6, false)
  for _, o in ipairs(d.objs or {}) do
    img(g, o[1], o[2], o[3], false)
  end
  for _, p in ipairs(d.pieces or {}) do
    local side, key, x, y = p[1], p[2], p[3], p[4]
    if side == "blue" then
      fill(g, x - 3, y - 3, 54, 54, BLACK)
      fill(g, x, y, 48, 48, WHITE)
    else
      box(g, x - 2, y - 2, 52, 52, WHITE)
    end
    champ48(g, key, x, y)
  end
  for _, c in ipairs(d.clash or {}) do
    fill(g, c[1] - 12, c[2] - 12, 24, 24, WHITE)
    g:circle(c[1], c[2], 11, "stroke", BLACK)
    g:line(c[1] - 5, c[2] - 5, c[1] + 5, c[2] + 5, BLACK)
    g:line(c[1] - 5, c[2] + 5, c[1] + 5, c[2] - 5, BLACK)
  end

  -- 原型 .sb-rail：padding 6/10/8、gap 4；头 / 一行比分 / 塔龙经济 / 金条 / 下一 / 事件
  fill(g, 480, 0, 320, H, WHITE)
  fill(g, 480, 0, 2, H, BLACK)
  local rx, rw = 490, 300
  local hot = d.hot
  if hot then
    fill(g, 482, 0, 318, 26, BLACK)
  end
  label(g, d.label or "ph1", rx, hot and 4 or 6, hot)
  clock_draw(g, d.min or 0, rx + rw, hot and 1 or 3, hot)

  -- 头 26 + gap 4 → 比分 36px 行高 40
  local by = 30
  team32(g, st.blue.id, rx, by + 4)
  draft_name(g, st.blue.id, rx + 36, by + 11, false)
  rail_score(g, d.blue or 0, d.red or 0, rx + math.floor(rw / 2), by)
  local rnk = DRAFT_NAME[st.red.id] or "tt1"
  local rnw = Type.w[rnk] or 21
  draft_name(g, st.red.id, rx + rw - 36 - rnw, by + 11, false)
  team32(g, st.red.id, rx + rw - 32, by + 4)

  local my = 74
  local function pair_w(prefix, a, b)
    local aw, bw = 0, 0
    local as, bs = tostring(a), tostring(b)
    for i = 1, #as do aw = aw + (Type.w["d" .. as:sub(i, i)] or 9) end
    for i = 1, #bs do bw = bw + (Type.w["d" .. bs:sub(i, i)] or 9) end
    return (Type.w[prefix] or 16) + aw + (Type.w.smdash or 5) + bw
  end
  stat_pair(g, "sttw", d.towers_b or 0, d.towers_r or 0, rx, my)
  local dw = pair_w("stdg", d.drag_b or 0, d.drag_r or 0)
  stat_pair(g, "stdg", d.drag_b or 0, d.drag_r or 0, rx + math.floor((rw - dw) / 2), my)
  local lead_id = (d.gold_side == "b") and st.blue.id or st.red.id
  local lead_k = LEAD_NAME[lead_id] or "lt1"
  local absn = tostring(d.gold_lead_abs or 0)
  local lead_w = (Type.w[lead_k] or 16) + (Type.w.gplus or 7)
  for i = 1, #absn do lead_w = lead_w + (Type.w["d" .. absn:sub(i, i)] or 9) end
  local lx = rx + rw - lead_w
  lx = lx + lead_name(g, lead_id, lx, my, false)
  lx = lx + label(g, "gplus", lx, my, false)
  Type.num(g, d.gold_lead_abs or 0, lx, my)

  local gy = 94
  box(g, rx, gy, rw, 12, WHITE)
  fill(g, rx + 2, gy + 2, math.floor((rw - 4) * ((d.gold_pct or 50) / 100)), 8, BLACK)

  local ny = 110
  box(g, rx, ny, rw, 22, WHITE)
  label(g, "nxlab", rx + 6, ny + 3, false)
  do
    local right = rx + rw - 6
    if d.next_at then
      local nk = d.next_key or "nxpush"
      local clock_w = 42
      local nw = (Type.w[nk] or 26) + 4 + clock_w
      local vx = right - nw
      label(g, nk, vx, ny + 3, false)
      clock_inline(g, d.next_at, vx + (Type.w[nk] or 26) + 4, ny + 3)
    else
      label(g, "nxpush", right - (Type.w.nxpush or 26), ny + 3, false)
    end
  end

  local ev_h, ev_y = 40, 136
  local rail_face = {
    leesin = true, kindred = true, locke = true, ornn = true, jayce = true,
    ahri = true, kaisa = true, yunara = true, thresh = true, braum = true,
    tower = true, dragon = true, riftherald = true, baron = true, i6692 = true,
  }
  local function ev_icon(key, ix, iy)
    if rail_face[key] then
      img(g, "a" .. key, ix, iy, false)
    elseif Data.CHAMP[key] then
      champ32(g, key, ix, iy + 4)
    else
      img(g, key, ix, iy + 4, false)
    end
  end
  for _, ev in ipairs(d.events or {}) do
    if ev_y + ev_h > 476 then break end
    local icon = ev.icon
    if Data.CHAMP[icon] then icon = remap_key(icon, picks) end
    local victim = ev.victim and remap_key(ev.victim, picks) or nil
    local ty = ev_y + 11
    ev_icon(icon, rx, ev_y)
    local tx = rx + 46
    tx = tx + clock_inline(g, ev.t or 0, tx, ty)
    tx = tx + 6
    if ev.text then
      g:text(tx, ty, ev.text, { color = 15 })
    elseif ev.ev then
      label(g, ev.ev, tx, ty, false)
    end
    if victim then ev_icon(victim, rx + rw - 40, ev_y) end
    ev_y = ev_y + ev_h + 2
    if ev_y + ev_h > 418 then break end
  end
  btn(g, rx, 426, 160, 42, "kscb", "ghost", st.focus == "back")
  add_hit("back", rx, 426, 160, 42)
end

local WIN_TYPE = {
  hle = "whle", gen = "wgen", t1 = "wt1", dk = "wdk", blg = "wblg",
  tsw = "wtsw", cfo = "wcfo", mvk = "wmvk", g2 = "wg2", kc = "wkc",
}

local function big_num(g, n, x, y)
  local s = tostring(n)
  local cx = x
  for i = 1, #s do
    local ch = s:sub(i, i)
    if ch >= "0" and ch <= "9" then
      cx = cx + Type.draw(g, "k" .. ch, cx, y)
    end
  end
  return cx - x
end

local function big_score(g, a, b, cx, y)
  local as, bs = tostring(a), tostring(b)
  local aw, bw = 0, 0
  for i = 1, #as do aw = aw + (Type.w["k" .. as:sub(i, i)] or 42) end
  for i = 1, #bs do bw = bw + (Type.w["k" .. bs:sub(i, i)] or 42) end
  local dash = Type.w.kdash or 39
  local total = aw + 28 + dash + 28 + bw
  local x = cx - math.floor(total / 2)
  x = x + big_num(g, a, x, y) + 28
  x = x + Type.draw(g, "kdash", x, y) + 28
  big_num(g, b, x, y)
end

-- 原型 end-body：14px 边距、72 | 10 | 1fr | 10 | 72，中间 gap 10 竖向居中
function M.draw_end(g, st)
  M.reset_hits()
  fill(g, 0, 0, W, H, WHITE)
  local won = st.match_won
  if won == nil then won = Data.match_won_from(st) end
  header(g, "bend", won and "mkwin" or "mklose")
  local picks = st.picks or {blue = {}, red = {}}
  local fin = st.match or Data.match_state_at(28)
  local winner = won and st.blue or st.red
  local CX = 400
  local COL = 72

  local function side_col(side, col_x)
    local team = side == "blue" and st.blue or st.red
    local nk = DRAFT_NAME[team.id] or "tt1"
    local tw = (Type.w[nk] or 21) + 14
    if tw > COL then tw = COL end
    local tag_x = col_x + math.floor((COL - tw) / 2)
    local col_h = 22 + 6 + 5 * 56 + 4 * 4
    local y0 = 50 + math.floor((416 - col_h) / 2)
    box(g, tag_x, y0, tw, 22, side == "blue" and BLACK or WHITE)
    draft_name(g, team.id, tag_x + 7, y0 + 2, side == "blue")
    local champ_x = col_x + math.floor((COL - 56) / 2)
    local list = picks[side] or {}
    for i = 1, 5 do
      local y = y0 + 28 + (i - 1) * 60
      if list[i] then
        champ56(g, list[i], champ_x, y)
      else
        dash_box(g, champ_x, y, 56, 56)
      end
    end
  end
  side_col("blue", 14)
  side_col("red", 714)

  local win_key = WIN_TYPE[winner.id] or "wt1"
  local win_w = Type.w[win_key] or 48
  local tag_w = (Type.w.win or 14) + 16
  local win_row = 64 + 14 + win_w + 14 + tag_w
  local main_h = 64 + 10 + 76 + 10 + 28 + 10 + 48 + 10 + 54
  local y = 50 + math.floor((416 - main_h) / 2)

  local win_x = CX - math.floor(win_row / 2)
  team64(g, winner.id, win_x, y)
  label(g, win_key, win_x + 64 + 14, y + 8, false)
  local tag_x = win_x + 64 + 14 + win_w + 14
  box(g, tag_x, y + 18, tag_w, 26, WHITE)
  label(g, "win", tag_x + 8, y + 22, false)
  y = y + 74

  local kb, kr = fin.blue or 0, fin.red or 0
  big_score(g, kb, kr, CX, y)
  y = y + 86

  Type.center(g, "t2800", CX, y)
  y = y + 38

  local stat = st.end_stat
  team48(g, winner.id, CX - 90, y)
  if type(stat) == "string" and stat ~= "" then
    g:text(CX - 34, y + 16, stat, { color = 15 })
  else
    label(g, "endstat", CX - 34, y + 13, false)
  end
  y = y + 58

  btn(g, CX - 95, y, 190, 54, "kcont", "primary", st.focus == "continue")
  add_hit("continue", CX - 95, y, 190, 54)
end

return M
