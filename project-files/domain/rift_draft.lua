-- 征召会话：步序、占用、pending、分路筛选。不算分，不选人。
-- 轻松模式按分路落位；红方由 draft AI 补齐。征程只禁用己方已用英雄。
local Data = require("domain.rift_data")
local Roles = require("domain.mech_roles")
local DraftAI = require("domain.mech_draft_ai")

local M = {}

local function is_easy(st)
  return (st.mode or "easy") ~= "pro"
end

local function used_set(st)
  local used = {}
  for key, on in pairs(st.series_used or {}) do
    if on then used[key] = true end
  end
  if is_easy(st) then
    for i = 1, 5 do
      local a, b = st.easy and st.easy[i], st.easy_red and st.easy_red[i]
      if a then used[a] = true end
      if b then used[b] = true end
    end
    local bans = st.easy_bans or {}
    for _, key in ipairs(bans.blue or {}) do if key then used[key] = true end end
    for _, key in ipairs(bans.red or {}) do if key then used[key] = true end end
    return used
  end
  for i = 1, (st.draft_idx or 0) do
    local key = st.choices and st.choices[i]
    if key then used[key] = true end
  end
  return used
end

local function place_pick(picks, key)
  local c = Data.champ(key)
  for i, role in ipairs(Data.ROLES) do
    if role == c.p and not picks[i] then
      picks[i] = key
      return
    end
  end
  for i = 1, 5 do
    if not picks[i] then
      picks[i] = key
      return
    end
  end
end

local function taken_board(st)
  local bans = {blue = {}, red = {}}
  local picks = {blue = {}, red = {}}
  local used = used_set(st)
  if is_easy(st) then
    local src = st.easy_bans or {blue = {}, red = {}}
    for i, key in ipairs(src.blue or {}) do bans.blue[i] = key end
    for i, key in ipairs(src.red or {}) do bans.red[i] = key end
    local n = 0
    for i = 1, 5 do
      picks.blue[i] = st.easy and st.easy[i]
      picks.red[i] = st.easy_red and st.easy_red[i]
      if picks.blue[i] then n = n + 1 end
    end
    return bans, picks, used, n
  end
  local n = 0
  for i = 1, (st.draft_idx or 0) do
    local step = Data.STEPS[i]
    local key = st.choices and st.choices[i]
    if step and key then
      n = n + 1
      if step.t == "ban" then
        bans[step.side][#bans[step.side] + 1] = key
      else
        place_pick(picks[step.side], key)
      end
    end
  end
  return bans, picks, used, n
end

local function banned_keys(st)
  local bans = taken_board(st)
  local out = {}
  for _, key in ipairs(bans.blue) do out[#out + 1] = key end
  for _, key in ipairs(bans.red) do out[#out + 1] = key end
  return out
end

local function pool_keys(st)
  local role = st.role_filter or ""
  local out = {}
  local seen = {}
  -- 全英雄页、以及禁用英雄自己的分路页，都把已禁用提到最前。
  for _, key in ipairs(banned_keys(st)) do
    if not seen[key] then
      local c = Data.champ(key)
      if role == "" or (c and c.p == role) then
        seen[key] = true
        out[#out + 1] = key
      end
    end
  end
  for _, key in ipairs(Data.CHAMP_KEYS) do
    if not seen[key] then
      local c = Data.champ(key)
      if role == "" or c.p == role then
        out[#out + 1] = key
      end
    end
  end
  return out
end

local function page_slice(st)
  local keys = pool_keys(st)
  local size = Data.DRAFT_PAGE or 28
  local pages = math.max(1, math.ceil(#keys / size))
  local page = math.min(pages - 1, math.max(0, st.pool_page or 0))
  local a = page * size
  local out = {}
  for i = a + 1, math.min(a + size, #keys) do
    out[#out + 1] = keys[i]
  end
  return out, page, pages, #keys
end

local function first_free(st)
  local used = used_set(st)
  local slice = page_slice(st)
  for _, key in ipairs(slice) do
    if not used[key] then return "cand-" .. key end
  end
  return "back"
end

function M.used(st)
  return used_set(st)
end

function M.step(st)
  if is_easy(st) then
    local n = Roles.filled(st.easy or {})
    return {
      t = "pick",
      side = "blue",
      bar = "le" .. math.min(n + 1, 5),
    }
  end
  return Data.STEPS[(st.draft_idx or 0) + 1]
end

function M.board(st)
  local bans, picks, used, n = taken_board(st)
  return {
    bans = bans,
    picks = picks,
    used = used,
    used_n = n,
    step = M.step(st),
    idx = st.draft_idx or 0,
    starters = st.starters,
    blue_id = st.blue and st.blue.id,
    red_id = st.red and st.red.id,
  }
end

function M.matchup(st, key)
  if not key then return {kind = "none"} end
  local _, picks = taken_board(st)
  local c = Data.champ(key)
  local role_i
  for i, name in ipairs(Data.ROLES) do
    if name == c.p then role_i = i end
  end
  if not role_i then return {kind = "none"} end
  local step = M.step(st)
  local mine = picks.blue[role_i]
  local theirs = picks.red[role_i]
  local opp = theirs
  if key == theirs then
    opp = mine
  elseif key == mine then
    opp = theirs
  elseif step and step.side == "red" then
    opp = mine
  end
  if not opp then return {kind = "none"} end
  local wr = Data.vs_wr(key, opp)
  if wr then
    return {kind = "wr", a = key, b = opp, wr = wr}
  end
  return {kind = "na", a = key, b = opp}
end

function M.start(st)
  st.draft_idx = 0
  st.choices = {}
  st.easy = {}
  st.easy_red = {}
  st.easy_bans = nil
  st.pending = nil
  st.role_filter = ""
  st.pool_page = 0
  if is_easy(st) then
    local board = M.board(st)
    DraftAI.fill_bans(board, "blue", 5)
    DraftAI.fill_bans(board, "red", 5)
    st.easy_bans = board.bans
  end
  st.focus = first_free(st)
end

function M.set_role(st, role)
  if role == "all" then role = "" end
  st.role_filter = role or ""
  st.pool_page = 0
  if st.pending then return end
  st.focus = first_free(st)
end

function M.turn_page(st, dir)
  local _, page, pages = page_slice(st)
  local p = page + (dir or 0)
  if p < 0 then p = 0 end
  if p > pages - 1 then p = pages - 1 end
  st.pool_page = p
  if not st.pending then
    st.focus = first_free(st)
  end
end

function M.set_pending(st, key)
  if is_easy(st) then
    return false
  end
  local step = M.step(st)
  if not step or step.side ~= "blue" then return false end
  if not key or used_set(st)[key] then return false end
  st.pending = key
  st.focus = "confirm"
  return true
end

function M.cancel(st)
  st.pending = nil
  st.focus = first_free(st)
end

function M.lock_easy(st, key)
  local used = used_set(st)
  if not key or used[key] then return "cont" end
  st.easy = st.easy or {}
  if not Roles.place(st.easy, key) then return "cont" end
  st.pending = nil
  if Roles.filled(st.easy) >= 5 then
    local board = M.board(st)
    DraftAI.fill_side(board, "red")
    st.easy_red = board.picks.red
    return "done"
  end
  st.focus = first_free(st)
  return "cont"
end

function M.lock(st, key)
  if is_easy(st) then
    return M.lock_easy(st, key)
  end
  local step = M.step(st)
  if not step then return "done" end
  if not key or used_set(st)[key] then return "cont" end
  st.choices = st.choices or {}
  st.choices[(st.draft_idx or 0) + 1] = key
  st.pending = nil
  st.draft_idx = (st.draft_idx or 0) + 1
  if st.draft_idx >= #Data.STEPS then
    return "done"
  end
  st.focus = first_free(st)
  return "cont"
end

function M.consume_back(st)
  if st.pending then
    M.cancel(st)
    return true
  end
  return false
end

local function focus_list(st)
  if st.pending then
    return {"confirm", "cancel"}
  end
  local step = M.step(st)
  if step and step.side == "red" then
    return {"back"}
  end
  local used = used_set(st)
  local slice, page, pages = page_slice(st)
  local ids = {}
  for _, tab in ipairs(Data.ROLE_TABS) do
    ids[#ids + 1] = "role-" .. tab.id
  end
  for _, key in ipairs(slice) do
    if not used[key] then
      ids[#ids + 1] = "cand-" .. key
    end
  end
  if pages > 1 then
    if page > 0 then ids[#ids + 1] = "page-prev" end
    if page < pages - 1 then ids[#ids + 1] = "page-next" end
  end
  ids[#ids + 1] = "back"
  return ids
end

local function index_of(list, id)
  for i, v in ipairs(list) do
    if v == id then return i end
  end
  return 1
end

function M.move(st, key)
  local ids = focus_list(st)
  if #ids == 0 then return end
  local i = index_of(ids, st.focus)
  if key == "left" then
    i = i - 1
    if i < 1 then i = #ids end
  elseif key == "right" then
    i = i + 1
    if i > #ids then i = 1 end
  elseif key == "down" then
    if st.pending then
      i = i + 1
      if i > #ids then i = #ids end
    elseif string.sub(st.focus or "", 1, 5) == "role-" then
      local used = used_set(st)
      for _, k in ipairs(pool_keys(st)) do
        if not used[k] then
          st.focus = "cand-" .. k
          return
        end
      end
      st.focus = "back"
      return
    elseif string.sub(st.focus or "", 1, 5) == "cand-" then
      st.focus = "back"
      return
    end
  elseif key == "up" then
    if st.pending then
      i = i - 1
      if i < 1 then i = 1 end
    elseif st.focus == "back" then
      st.focus = first_free(st)
      return
    elseif string.sub(st.focus or "", 1, 5) == "cand-" then
      local role = st.role_filter or ""
      st.focus = "role-" .. (role == "" and "all" or role)
      return
    end
  end
  st.focus = ids[i] or ids[1]
end

function M.view_model(st, blue, red)
  local bans, picks, used, n = taken_board(st)
  local banned = {}
  for _, key in ipairs(bans.blue) do banned[key] = true end
  for _, key in ipairs(bans.red) do banned[key] = true end
  for key, on in pairs(st.series_used or {}) do
    if on then banned[key] = true end
  end
  local easy = is_easy(st)
  local step = M.step(st) or Data.STEPS[#Data.STEPS]
  local slice, page, pages, total = page_slice(st)
  local pending = easy and nil or st.pending
  return {
    mode = easy and "easy" or "pro",
    bar = step.bar,
    timer = easy and 0 or 28,
    turn = step.side,
    type = step.t,
    pending = pending,
    role_filter = st.role_filter or "",
    focus = st.focus,
    bans = bans,
    banned = banned,
    picks = picks,
    used = used,
    used_n = n,
    pool = slice,
    pool_n = total,
    pool_page = page,
    pool_pages = pages,
    vs = M.matchup(st, pending),
    blue = blue,
    red = red,
  }
end

return M
