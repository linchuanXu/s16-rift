-- 征召/评分入口。算法在 mech_draft_ai / mech_score，这里只转发。
local DraftAI = require("domain.mech_draft_ai")
local Score = require("domain.mech_score")

local M = {}

function M.choose(board)
  return DraftAI.choose(board)
end

function M.rate(board)
  return Score.rate(board)
end

return M
