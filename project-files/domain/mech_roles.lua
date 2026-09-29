-- 分路：上野中下辅。征召落位、空位、按路筛人只走这里。
local Data = require("domain.rift_data")

local M = {}

M.ORDER = Data.ROLES

function M.index(role)
  for i, name in ipairs(Data.ROLES) do
    if name == role then return i end
  end
  return nil
end

function M.of(key)
  local c = Data.champ(key)
  return c and c.p or nil
end

function M.empty(slots)
  local out = {}
  for i, role in ipairs(Data.ROLES) do
    if not slots[i] then out[#out + 1] = {i = i, role = role} end
  end
  return out
end

function M.filled(slots)
  local n = 0
  for i = 1, 5 do
    if slots[i] then n = n + 1 end
  end
  return n
end

-- 先入本分路空位，再补任意空位。满员返回 nil。
function M.place(slots, key)
  if not key then return nil end
  local i = M.index(M.of(key))
  if i and not slots[i] then
    slots[i] = key
    return i
  end
  for j = 1, 5 do
    if not slots[j] then
      slots[j] = key
      return j
    end
  end
  return nil
end

function M.keys_for(role, used)
  local out = {}
  for _, key in ipairs(Data.CHAMP_KEYS) do
    if (not used or not used[key]) and M.of(key) == role then
      out[#out + 1] = key
    end
  end
  return out
end

return M
