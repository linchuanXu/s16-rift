local Champs = require("domain.rift_champs")

local M = {}
M.CHAMP = Champs.CHAMP
M.CHAMP_KEYS = Champs.CHAMP_KEYS

M.TEAMS = {
  {id = "hle", name = "HLE", region = "LCK"},
  {id = "gen", name = "GEN", region = "LCK"},
  {id = "t1", name = "T1", region = "LCK"},
  {id = "dk", name = "DK", region = "LCK"},
  {id = "blg", name = "BLG", region = "LPL"},
  {id = "tsw", name = "TSW", region = "LCP"},
  {id = "cfo", name = "CFO", region = "LCP"},
  {id = "mvk", name = "MVK", region = "LCP"},
  {id = "g2", name = "G2", region = "LEC"},
  {id = "kc", name = "KC", region = "LEC"},
}

-- 六关一路过：瑞士 1–3 出线 → 八强树 → 半决赛 → 决赛（不是 3 胜 3 负瑞士轮）
M.PATH_LADDER = {
  {id = "s1", rn = "rn1", bn = "bn1"},
  {id = "s2", rn = "rn2", bn = "bn2"},
  {id = "s3", rn = "rn3", bn = "bn3"},
  {id = "qf", rn = "rn4", bn = "bn4"},
  {id = "sf", rn = "rn5", bn = "bn5"},
  {id = "fi", rn = "rn6", bn = "bn6"},
}

function M.path_others(me_id)
  return require("domain.mech_bracket").others(me_id)
end

function M.path_schedule(me_id)
  return require("domain.mech_bracket").schedule(me_id)
end

function M.path_opp(me_id, round)
  return require("domain.mech_bracket").path_opp(me_id, round)
end

-- i 从 0 计，与原型 pathRoundSt 一致
function M.path_round_st(r, outcome, i, mine)
  local champ = outcome == "champ"
  local lose = outcome == "lose"
  if not mine then
    if champ or r > i then return "done" end
    return "soon"
  end
  if champ and i == 5 then return "champ" end
  if champ or r > i then return "done" end
  if r == i then return lose and "lose" or "now" end
  return "soon"
end

-- 己方固定左上。顶栏这场对手与树上你旁边是同一个人。
function M.path_bracket(me_id, path_round, outcome)
  return require("domain.mech_bracket").tree(me_id, path_round, outcome)
end

function M.match_won_from(st)
  if st and st.match_won ~= nil then
    return not not st.match_won
  end
  if st and st.match_log then
    return not not st.match_log.won
  end
  return true
end

M.ROLES = {"上", "野", "中", "下", "辅"}

M.DRAFT_PAGE = 28 -- 7 列 × 4 行
M.DRAFT_COLS = 7

M.ROLE_TABS = {
  {id = "all", glyph = "fall", role = ""},
  {id = "上", glyph = "ftop", role = "上"},
  {id = "野", glyph = "fjg", role = "野"},
  {id = "中", glyph = "fmid", role = "中"},
  {id = "下", glyph = "fadc", role = "下"},
  {id = "辅", glyph = "fsup", role = "辅"},
}

M.VS = {
  ["leesin|kindred"] = 92,
  ["leesin|locke"] = 55,
  ["jayce|ornn"] = 52,
  ["ahri|locke"] = 48,
}

M.STEPS = {
  {t = "ban", side = "blue", key = "qiyana", bar = "lb1"},
  {t = "ban", side = "red", key = "syndra", bar = "lb2"},
  {t = "ban", side = "blue", key = "yone", bar = "lb3"},
  {t = "ban", side = "red", key = "jhin", bar = "lb4"},
  {t = "ban", side = "blue", key = "bard", bar = "lb5"},
  {t = "ban", side = "red", key = "nautilus", bar = "lb6"},
  {t = "pick", side = "blue", key = "jayce", bar = "lb7"},
  {t = "pick", side = "red", key = "ornn", bar = "lb8"},
  {t = "pick", side = "red", key = "kindred", bar = "lb9"},
  {t = "pick", side = "blue", key = "leesin", bar = "lb10"},
  {t = "pick", side = "blue", key = "ahri", bar = "lb11"},
  {t = "pick", side = "red", key = "locke", bar = "lb12"},
  {t = "ban", side = "red", key = "shyvana", bar = "lb13"},
  {t = "ban", side = "blue", key = "olaf", bar = "lb14"},
  {t = "ban", side = "red", key = "hecarim", bar = "lb15"},
  {t = "ban", side = "blue", key = "nidalee", bar = "lb16"},
  {t = "pick", side = "red", key = "yunara", bar = "lb17"},
  {t = "pick", side = "blue", key = "kaisa", bar = "lb18"},
  {t = "pick", side = "blue", key = "thresh", bar = "lb19"},
  {t = "pick", side = "red", key = "braum", bar = "lb20"},
}

M.MATCH_END_MIN = 29
M.MATCH_TICK = 0.75 -- 真实秒 / 比赛分钟

function M.match_state_at(min)
  return {
    min = min or 0,
    label = "ph1",
    pose = "laning",
    blue = 0,
    red = 0,
    towers_b = 0,
    towers_r = 0,
    drag_b = 0,
    drag_r = 0,
    gold_b = 2500,
    gold_r = 2500,
    gold_lead = 0,
    gold_lead_abs = 0,
    gold_side = "b",
    gold_pct = 50,
    events = {},
    clash = {},
    objs = {},
    pieces = {},
    ended = false,
    hot = false,
    next_key = "nxpush",
    next_at = nil,
  }
end

function M.champ(key)
  return M.CHAMP[key] or {n = key, p = "?", w = 0, pk = 0, bn = 0, pl = 0, s = {}, wk = {}}
end

function M.vs_wr(a, b)
  if not a or not b then return nil end
  local hit = M.VS[a .. "|" .. b]
  if hit then return hit end
  local ca = M.CHAMP[a]
  if not ca then return nil end
  for _, row in ipairs(ca.s or {}) do
    if row[1] == b then return row[3] end
  end
  for _, row in ipairs(ca.wk or {}) do
    if row[1] == b then return row[3] end
  end
  return nil
end

function M.team_by_id(id)
  for _, t in ipairs(M.TEAMS) do
    if t.id == id then return t end
  end
  return M.TEAMS[1]
end

function M.team(i)
  return M.TEAMS[i]
end

return M
