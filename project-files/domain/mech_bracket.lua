-- 一张签表。顶栏这场对手 = 树上你旁边那个人，不再各写各的。
local Data = require("domain.rift_data")
local Match = require("domain.mech_matchup")

local M = {}

function M.others(me_id)
  local out = {}
  for _, t in ipairs(Data.TEAMS) do
    if t.id ~= me_id then
      out[#out + 1] = t.id
    end
  end
  return out
end

function M.winner(a, b)
  return Match.stronger(a, b)
end

-- 八人树：己方固定左上。旁位是第一场，其余六人三组，都在树上。
function M.seeds(me_id)
  local o = M.others(me_id)
  return {
    me_id,
    o[4],
    o[5],
    o[6],
    o[1],
    o[2],
    o[3],
    o[7],
  }
end

local function taken_pair(s, me, opp)
  local rest = {}
  for i = 1, 8 do
    local id = s[i]
    if id and id ~= me and id ~= opp then
      rest[#rest + 1] = id
    end
  end
  return {
    {a = rest[1], b = rest[2]},
    {a = rest[3], b = rest[4]},
    {a = rest[5], b = rest[6]},
  }
end

-- 六场对手：瑞士 1 就是树上你旁边；八强换人，避免重赛同一队。
function M.gauntlet(me_id)
  local s = M.seeds(me_id)
  local qf_pairs = taken_pair(s, s[1], s[7])
  return {
    s[2],
    s[5],
    s[6],
    s[7],
    M.winner(qf_pairs[1].a, qf_pairs[1].b),
    M.winner(
      M.winner(qf_pairs[2].a, qf_pairs[2].b),
      M.winner(qf_pairs[3].a, qf_pairs[3].b)
    ),
  }
end

function M.path_opp(me_id, round)
  local g = M.gauntlet(me_id)
  local r = math.min(math.max(round or 0, 0), 5)
  return g[r + 1]
end

function M.schedule(me_id)
  local out = {}
  for i, row in ipairs(Data.PATH_LADDER) do
    out[i] = {
      id = row.id,
      rn = row.rn,
      bn = row.bn,
      opp = M.path_opp(me_id, i - 1),
    }
  end
  return out
end

function M.tree(me_id, path_round, outcome)
  local s = M.seeds(me_id)
  local r = path_round or 0
  local champ = outcome == "champ"
  local show_r = math.min(r, 3)
  if champ then show_r = 3 end
  local beside = M.path_opp(me_id, show_r)
  local others = taken_pair(s, me_id, beside)
  local swiss = {}
  for i = 0, 2 do
    swiss[i + 1] = {
      rn = Data.PATH_LADDER[i + 1].rn,
      opp = M.path_opp(me_id, i),
      st = Data.path_round_st(r, outcome, i, true),
    }
  end
  local qf_mine_st
  if r <= 2 and not champ then
    qf_mine_st = Data.path_round_st(r, outcome, r, true)
  else
    qf_mine_st = Data.path_round_st(r, outcome, 3, true)
  end
  local qf_w = {
    (champ or r > 3) and me_id or nil,
    (champ or r >= 4) and M.winner(others[1].a, others[1].b) or nil,
    (champ or r >= 4) and M.winner(others[2].a, others[2].b) or nil,
    (champ or r >= 4) and M.winner(others[3].a, others[3].b) or nil,
  }
  local sf_w = {
    (champ or r > 4) and me_id or nil,
    (champ or r >= 5) and M.winner(qf_w[3], qf_w[4]) or nil,
  }
  return {
    swiss = swiss,
    qf = {
      {a = me_id, b = beside, w = qf_w[1], st = qf_mine_st, mine = true},
      {a = others[1].a, b = others[1].b, w = qf_w[2], st = Data.path_round_st(r, outcome, 3, false), mine = false},
      {a = others[2].a, b = others[2].b, w = qf_w[3], st = Data.path_round_st(r, outcome, 3, false), mine = false},
      {a = others[3].a, b = others[3].b, w = qf_w[4], st = Data.path_round_st(r, outcome, 3, false), mine = false},
    },
    sf = {
      {a = qf_w[1], b = qf_w[2], st = Data.path_round_st(r, outcome, 4, true), w = sf_w[1], mine = true},
      {a = qf_w[3], b = qf_w[4], st = Data.path_round_st(r, outcome, 4, false), w = sf_w[2], mine = false},
    },
    fi = {a = sf_w[1], b = sf_w[2], w = champ and me_id or nil, st = Data.path_round_st(r, outcome, 5, true), mine = true},
    champion = champ and me_id or nil,
  }
end

return M
