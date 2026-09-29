-- 确定性随机。同一种子同一序列，对局可复盘。不读系统时钟。
local M = {}

function M.hash(...)
  local n = 2166136261
  for i = 1, select("#", ...) do
    local s = tostring(select(i, ...) or "")
    for j = 1, #s do
      n = (n * 16777619 + string.byte(s, j)) % 2147483647
    end
    n = (n * 31 + i) % 2147483647
  end
  return n
end

function M.new(seed)
  local x = (tonumber(seed) or 1) % 2147483647
  if x <= 0 then x = 1 end
  local self = {}
  function self:next()
    -- MINSTD：乘数够小，Lua number 不会丢低位。
    x = (48271 * x) % 2147483647
    return x
  end
  function self:float()
    return (self:next() - 1) / 2147483646
  end
  function self:int(a, b)
    if not b then
      b = a
      a = 1
    end
    if b < a then a, b = b, a end
    return a + self:next() % (b - a + 1)
  end
  function self:chance(p)
    return self:float() < (p or 0)
  end
  function self:pick(list)
    if not list or #list == 0 then return nil end
    return list[self:int(1, #list)]
  end
  return self
end

return M
