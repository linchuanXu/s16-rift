-- 一分钟一个真相。站位只读 region / roles，不再按 act 拉人。
local Pose = require("domain.mech_pose")

local M = {}

local function role_of(picks, key)
  if not picks or not key then return nil end
  for i = 1, 5 do
    if picks.blue and picks.blue[i] == key then return i end
    if picks.red and picks.red[i] == key then return i end
  end
  return nil
end

function M.idle()
  return {
    act = "idle",
    region = nil,
    roles = {},
    keys = {},
    hide = {},
  }
end

function M.build(opts)
  opts = opts or {}
  local act = opts.act or "idle"
  if act == "idle" then return M.idle() end
  local region = opts.region
  local roles = {}
  if opts.roles then
    for k, v in pairs(opts.roles) do
      roles[k] = v
    end
  end
  if not next(roles) then
    for _, key in ipairs(opts.keys or {}) do
      local i = role_of(opts.picks, key)
      if i then roles[i] = true end
    end
  end
  -- 上不进下路 / 龙区，除非人已经在那格。
  if (region == "bot" or region == "drag") and not opts.keep_top then
    if not opts.roles or not opts.roles[1] then
      roles[1] = nil
    end
  end
  local spot = opts.spot or (region and Pose.region_clash(region))
  local spot_r = opts.spot_r
  return {
    act = act,
    region = region,
    spot = spot,
    where = spot,
    spot_r = spot_r,
    split = spot_r ~= nil,
    roles = roles,
    keys = opts.keys or {},
    hide = {},
    only = opts.only,
    ev = opts.ev,
    who = opts.who,
  }
end

function M.role_of(picks, key)
  return role_of(picks, key)
end

return M
