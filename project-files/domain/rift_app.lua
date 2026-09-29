local Data = require("domain.rift_data")
local View = require("domain.rift_view")
local Draft = require("domain.rift_draft")
local Brain = require("domain.rift_brain")
local Sim = require("domain.mech_sim")
local Book = require("domain.mech_book")
local Gacha = require("domain.mech_gacha")

local M = {}

local function state(ctx)
  ctx.state.rift = ctx.state.rift or {}
  return ctx.state.rift
end

local function sides(st)
  local me = Data.team((st.chosen or 2) + 1)
  local foe = Data.team_by_id(Data.path_opp(me.id, st.path_round or 0))
  return me, foe
end

local function now_ms(ctx)
  if not ctx or not ctx.sys then return nil end
  if ctx.sys.millis then
    local v = ctx.sys:millis()
    if type(v) == "number" and v >= 0 then return v end
  end
  if ctx.sys.uptime_ms then
    local v = ctx.sys:uptime_ms()
    if type(v) == "number" and v >= 0 then return v end
  end
  return nil
end

local function go(ctx, screen, focus)
  local st = state(ctx)
  st.screen = screen
  st.focus = focus
  st.wait = 0
  if screen == "sandbox" then
    if st.match_min == nil or st.match_min >= Data.MATCH_END_MIN then
      st.match_min = 0
    end
    st.match_t0 = nil
    st.match_pulses = 0
    ctx:set_tick_rate("realtime")
  elseif screen == "draft" then
    st.wait_t0 = now_ms(ctx)
    st.wait_pulses = 0
    ctx:set_tick_rate("realtime")
  else
    ctx:set_tick_rate("low")
  end
  ctx:invalidate()
end

local function reset_run(st)
  st.path_round = 0
  st.path_outcome = nil
  st.match_won = nil
  st.match_min = 0
  st.roster = nil
  st.match_log = nil
  st.rate = nil
  st.series_used = {}
  st.match_t0 = nil
end

local function enter_path(ctx, opts)
  local st = state(ctx)
  if opts and opts.reset then
    reset_run(st)
  end
  local focus = "fight"
  if st.path_outcome == "lose" then
    focus = "retry"
  elseif st.path_outcome == "champ" then
    focus = "again"
  end
  go(ctx, "path", focus)
end

local function go_title(ctx)
  reset_run(state(ctx))
  go(ctx, "title", "start")
end

local function apply_advance(ctx)
  local st = state(ctx)
  if (st.path_round or 0) >= #Data.PATH_LADDER - 1 then
    st.path_outcome = "champ"
  else
    st.path_round = (st.path_round or 0) + 1
    st.path_outcome = "win"
  end
  enter_path(ctx)
end

local function apply_match_to_path(ctx)
  local st = state(ctx)
  if st.screen ~= "end" then
    enter_path(ctx)
    return
  end
  local won = Data.match_won_from(st)
  local blue, red = sides(st)
  local snap = Draft.view_model(st, blue, red)
  st.series_used = st.series_used or {}
  for i = 1, 5 do
    local key = snap.picks.blue[i]
    if key then st.series_used[key] = true end
  end
  if won then
    Gacha.award_win(st)
  end
  st.match_won = nil
  st.match_min = 0
  st.match_log = nil
  if won then
    apply_advance(ctx)
  else
    st.path_outcome = "lose"
    enter_path(ctx)
  end
end

local function abort_match(st)
  st.match_min = 0
  st.match_won = nil
  st.roster = nil
  st.match_log = nil
  st.rate = nil
  st.match_paid = nil
end

local function commit_match(st)
  local blue, red = sides(st)
  local snap = Draft.view_model(st, blue, red)
  st.roster = snap.picks
  local board = Draft.board(st)
  board.starters = st.starters
  board.blue_id = blue.id
  board.red_id = red.id
  st.rate = Brain.rate(board)
  st.match_log = Sim.play({
    picks = snap.picks,
    bans = snap.bans,
    blue_id = blue.id,
    red_id = red.id,
    round = st.path_round or 0,
    starters = st.starters,
  })
end

local function after_lock(ctx, result)
  local st = state(ctx)
  if result == "done" then
    st.match_min = 0
    st.match_won = nil
    commit_match(st)
    go(ctx, "score", "enter")
    return
  end
  st.wait = 0
  st.wait_t0 = now_ms(ctx)
  st.wait_pulses = 0
  ctx:invalidate()
end

local function start_draft(ctx)
  local st = state(ctx)
  st.path_outcome = nil
  st.match_won = nil
  st.match_min = 0
  st.roster = nil
  st.match_log = nil
  st.rate = nil
  st.match_paid = nil
  Draft.start(st)
  go(ctx, "draft", st.focus)
end

local function lock_red(ctx)
  local st = state(ctx)
  local key = Brain.choose(Draft.board(st))
  after_lock(ctx, Draft.lock(st, key))
end

function M.enter(ctx)
  local st = state(ctx)
  Book.ensure(st)
  st.screen = st.screen or "title"
  st.focus = st.focus or "start"
  st.chosen = st.chosen or 2
  st.mode = st.mode or "easy"
  st.path_round = st.path_round or 0
  st.path_outcome = st.path_outcome
  st.phase = st.phase or 0
  st.wait = 0
  ctx:set_tick_rate("low")
  ctx:invalidate()
end

function M.tick(ctx, dt)
  local st = state(ctx)
  local now = now_ms(ctx)
  if st.screen == "draft" and (st.mode or "easy") == "pro" then
    local step = Draft.step(st)
    if step and step.side == "red" then
      if now then
        if not st.wait_t0 then st.wait_t0 = now end
        if (now - st.wait_t0) >= 900 then
          lock_red(ctx)
        end
      else
        st.wait_pulses = (st.wait_pulses or 0) + 1
        if st.wait_pulses >= 28 then
          st.wait_pulses = 0
          lock_red(ctx)
        end
      end
    end
  elseif st.screen == "sandbox" then
    local tick_ms = math.floor((Data.MATCH_TICK or 0.75) * 1000 + 0.5)
    if now then
      if not st.match_t0 then
        st.match_t0 = now
        ctx:invalidate()
        return
      end
      local next_due = st.match_t0 + ((st.match_min or 0) + 1) * tick_ms
      if now >= next_due then
        if (now - next_due) > tick_ms then
          st.match_t0 = now - (st.match_min or 0) * tick_ms
        else
          st.match_min = (st.match_min or 0) + 1
          if st.match_min >= Data.MATCH_END_MIN then
            st.match_won = st.match_log and st.match_log.won
            go(ctx, "end", "continue")
          else
            ctx:invalidate()
          end
        end
      end
    else
      st.match_pulses = (st.match_pulses or 0) + 1
      if st.match_pulses >= 40 then
        st.match_pulses = 0
        st.match_min = (st.match_min or 0) + 1
        if st.match_min >= Data.MATCH_END_MIN then
          st.match_won = st.match_log and st.match_log.won
          go(ctx, "end", "continue")
        else
          ctx:invalidate()
        end
      end
    end
  end
end

local function back(ctx)
  local st = state(ctx)
  if st.screen == "draft" and Draft.consume_back(st) then
    ctx:invalidate()
    return
  end
  if st.screen == "pick" or st.screen == "gacha" or st.screen == "prep" then
    st.hold = nil
    go(ctx, "title", "start")
  elseif st.screen == "path" then
    reset_run(st)
    go(ctx, "pick", "team-" .. (st.chosen or 2))
  elseif st.screen == "draft" or st.screen == "score" then
    abort_match(st)
    enter_path(ctx)
  elseif st.screen == "sandbox" then
    go(ctx, "score", "enter")
  elseif st.screen == "end" then
    apply_match_to_path(ctx)
  end
end

local function activate_draft(ctx, fid)
  local st = state(ctx)
  if fid == "cancel" then
    Draft.cancel(st)
    ctx:invalidate()
    return
  end
  if string.sub(fid, 1, 5) == "role-" then
    Draft.set_role(st, string.sub(fid, 6))
    ctx:invalidate()
    return
  end
  if fid == "page-prev" then
    Draft.turn_page(st, -1)
    ctx:invalidate()
    return
  end
  if fid == "page-next" then
    Draft.turn_page(st, 1)
    ctx:invalidate()
    return
  end
  local step = Draft.step(st)
  if not step or step.side ~= "blue" then return end
  if string.sub(fid, 1, 5) == "cand-" then
    local key = string.sub(fid, 6)
    if (st.mode or "easy") ~= "pro" then
      after_lock(ctx, Draft.lock(st, key))
    else
      Draft.set_pending(st, key)
      ctx:invalidate()
    end
  elseif fid == "confirm" and st.pending then
    after_lock(ctx, Draft.lock(st, st.pending))
  end
end

local function activate(ctx, fid)
  local st = state(ctx)
  if not fid then return end
  if fid == "back" then
    back(ctx)
    return
  end
  if st.screen == "title" then
    if fid == "hold-close" then
      st.hold = nil
      st.focus = "start"
      ctx:invalidate()
    elseif string.sub(fid, 1, 5) == "book-" then
      local id = string.sub(fid, 6)
      local p = Book.get(id)
      st.hold = nil
      if p then
        for i, role in ipairs(Data.ROLES) do
          if role == p.role then st.prep_slot = i - 1 end
        end
        go(ctx, "prep", Book.owns(st, id) and ("own-" .. id) or "ok")
      else
        st.focus = "start"
        ctx:invalidate()
      end
    elseif fid == "dock-roster" or fid == "roster" then
      st.hold = "roster"
      st.focus = "hold-close"
      ctx:invalidate()
    elseif fid == "gacha" then
      st.hold = nil
      go(ctx, "gacha", Gacha.can_draw(st) and "draw" or "back")
    elseif fid == "prep" or fid == "dock-prep" then
      st.hold = nil
      st.prep_slot = nil
      go(ctx, "prep", "ok")
    elseif fid == "start" or fid == "dock-play" then
      if Book.ready(st) then
        st.hold = nil
        go(ctx, "pick", "team-2")
      end
    elseif fid == "dock-home" then
      st.hold = nil
      st.focus = "start"
      ctx:invalidate()
    elseif fid == "mode-easy" or fid == "mode-pro" then
      st.mode = fid == "mode-easy" and "easy" or "pro"
      st.focus = fid
      ctx:invalidate()
    end
  elseif st.screen == "gacha" then
    if fid == "draw" then
      Gacha.draw(st)
      st.focus = Gacha.can_draw(st) and "draw" or "back"
      ctx:invalidate()
    end
  elseif st.screen == "prep" then
    if string.sub(fid, 1, 5) == "slot-" then
      st.prep_slot = tonumber(string.sub(fid, 6))
      st.focus = fid
      ctx:invalidate()
    elseif string.sub(fid, 1, 4) == "own-" then
      local id = string.sub(fid, 5)
      if Book.set_starter(st, (st.prep_slot or 0) + 1, id) then
        st.focus = "ok"
        ctx:invalidate()
      end
    elseif fid == "ok" then
      go(ctx, "title", "start")
    end
  elseif st.screen == "pick" then
    if string.sub(fid, 1, 5) == "team-" then
      st.chosen = tonumber(string.sub(fid, 6))
      st.focus = "confirm"
      ctx:invalidate()
    elseif fid == "confirm" then
      enter_path(ctx, {reset = true})
    end
  elseif st.screen == "path" then
    if fid == "settings" or fid == "fail" then
      go_title(ctx)
    elseif fid == "fight" then
      start_draft(ctx)
    elseif fid == "retry" then
      st.path_outcome = nil
      start_draft(ctx)
    elseif fid == "again" then
      reset_run(st)
      enter_path(ctx)
    end
  elseif st.screen == "draft" then
    activate_draft(ctx, fid)
  elseif st.screen == "score" then
    if fid == "enter" then
      st.wait = 0
      go(ctx, "sandbox", "back")
    end
  elseif st.screen == "end" then
    if fid == "continue" or fid == "advance" then
      apply_match_to_path(ctx)
    end
  end
end

local TITLE_RAIL = {"gacha", "prep", "start"}
local TITLE_DOCK = {"dock-home", "dock-roster", "dock-prep", "dock-play"}

local function move_title(st, key)
  if st.hold == "roster" then
    st.focus = "hold-close"
    return
  end
  local f = st.focus or "start"
  if f == "mode-easy" then
    if key == "right" then st.focus = "mode-pro"
    elseif key == "down" then st.focus = "gacha"
    end
  elseif f == "mode-pro" then
    if key == "left" then st.focus = "mode-easy"
    elseif key == "down" then st.focus = "gacha"
    end
  elseif f == "gacha" or f == "prep" or f == "start" then
    local i = 1
    for n, id in ipairs(TITLE_RAIL) do
      if id == f then i = n end
    end
    if key == "up" then
      st.focus = i == 1 and ((st.mode or "easy") == "pro" and "mode-pro" or "mode-easy") or TITLE_RAIL[i - 1]
    elseif key == "down" then
      st.focus = i == #TITLE_RAIL and "dock-play" or TITLE_RAIL[i + 1]
    end
  elseif string.sub(f, 1, 5) == "dock-" then
    local i = 1
    for n, id in ipairs(TITLE_DOCK) do
      if id == f then i = n end
    end
    if key == "left" then
      st.focus = TITLE_DOCK[i == 1 and #TITLE_DOCK or i - 1]
    elseif key == "right" then
      st.focus = TITLE_DOCK[i == #TITLE_DOCK and 1 or i + 1]
    elseif key == "up" then
      st.focus = "start"
    end
  end
end

local function move_gacha(st, key)
  if key == "left" or key == "right" or key == "up" or key == "down" then
    st.focus = st.focus == "draw" and "back" or "draw"
  end
end

local function move_prep(st, key)
  local f = st.focus or "ok"
  if string.sub(f, 1, 5) == "slot-" then
    local i = tonumber(string.sub(f, 6)) or 0
    if key == "right" then st.focus = "slot-" .. ((i + 1) % 5)
    elseif key == "left" then st.focus = "slot-" .. ((i + 4) % 5)
    elseif key == "down" then st.focus = "ok"
    end
  elseif string.sub(f, 1, 4) == "own-" then
    if key == "up" then st.focus = "slot-" .. (st.prep_slot or 0)
    elseif key == "down" then st.focus = "ok"
    end
  elseif f == "ok" then
    if key == "right" then st.focus = "back"
    elseif key == "up" then st.focus = "slot-" .. (st.prep_slot or 0)
    end
  elseif f == "back" then
    if key == "left" then st.focus = "ok"
    elseif key == "up" then st.focus = "slot-" .. (st.prep_slot or 0)
    end
  else
    st.focus = "ok"
  end
end

local function move_pick(st, key)
  local f = st.focus or "team-2"
  if string.sub(f, 1, 5) == "team-" then
    local i = tonumber(string.sub(f, 6)) or 0
    if key == "right" then i = (i + 1) % 10
    elseif key == "left" then i = (i + 9) % 10
    elseif key == "down" then
      if i < 5 then i = i + 5 else st.focus = "confirm"; return end
    elseif key == "up" then
      if i >= 5 then i = i - 5 end
    end
    st.focus = "team-" .. i
  elseif f == "confirm" then
    if key == "right" then st.focus = "back"
    elseif key == "up" then st.focus = "team-" .. (st.chosen or 2)
    end
  elseif f == "back" then
    if key == "left" then st.focus = "confirm"
    elseif key == "up" then st.focus = "team-" .. (st.chosen or 2)
    end
  end
end

local function move_path(st, key)
  local outcome = st.path_outcome
  local started = (st.path_round or 0) > 0 or outcome == "win"
  if outcome == "lose" then
    if key == "left" or key == "right" then
      st.focus = st.focus == "retry" and "fail" or "retry"
    end
  elseif outcome == "champ" then
    if key == "left" or key == "right" then
      st.focus = st.focus == "again" and "back" or "again"
    end
  else
    local alt = started and "settings" or "back"
    if key == "left" or key == "right" then
      st.focus = st.focus == "fight" and alt or "fight"
    end
  end
end

function M.input(ctx, ev)
  local st = state(ctx)
  if ev.type == "key" and ev.state == "down" then
    if ev.key == "back" then
      back(ctx)
      return true
    end
    if ev.key == "ok" then
      if (st.screen == "draft" or st.screen == "path") and st.focus == "back" then
        back(ctx)
      else
        activate(ctx, st.focus)
      end
      return true
    end
    if st.screen == "title" then
      move_title(st, ev.key)
      ctx:invalidate()
      return true
    elseif st.screen == "gacha" then
      move_gacha(st, ev.key)
      ctx:invalidate()
      return true
    elseif st.screen == "prep" then
      move_prep(st, ev.key)
      ctx:invalidate()
      return true
    elseif st.screen == "pick" then
      move_pick(st, ev.key)
      ctx:invalidate()
      return true
    elseif st.screen == "path" then
      move_path(st, ev.key)
      ctx:invalidate()
      return true
    elseif st.screen == "draft" then
      Draft.move(st, ev.key)
      ctx:invalidate()
      return true
    elseif st.screen == "score" then
      if ev.key == "left" or ev.key == "right" then
        st.focus = st.focus == "enter" and "back" or "enter"
        ctx:invalidate()
        return true
      end
    elseif st.screen == "end" then
      st.focus = "continue"
      ctx:invalidate()
      return true
    end
    return false
  end
  if ev.type == "touch" and ev.gesture == "tap" then
    local id = View.hit_at(ev.x, ev.y)
    if id then
      activate(ctx, id)
      return true
    end
  end
  return false
end

function M.draw(ctx, g)
  local st = state(ctx)
  local blue, red = sides(st)
  st.blue, st.red = blue, red
  local screen = st.screen or "title"
  local snap = Draft.view_model(st, blue, red)
  local match = Sim.at(st.match_log, st.match_min or 0)
  if screen == "title" then
    View.draw_title(g, st)
  elseif screen == "gacha" then
    View.draw_gacha(g, st)
  elseif screen == "prep" then
    View.draw_prep(g, st)
  elseif screen == "pick" then
    View.draw_pick(g, st)
  elseif screen == "path" then
    View.draw_path(g, st)
  elseif screen == "draft" then
    View.draw_draft(g, snap)
  elseif screen == "score" then
    View.draw_score(g, {
      focus = st.focus,
      blue = blue,
      red = red,
      picks = snap.picks,
      rate = st.rate or Brain.rate(Draft.board(st)),
    })
  elseif screen == "sandbox" then
    View.draw_sandbox(g, {
      match_min = st.match_min or 0,
      match = match,
      blue = blue,
      red = red,
      picks = snap.picks,
    })
  else
    View.draw_end(g, {
      focus = st.focus,
      blue = blue,
      red = red,
      picks = snap.picks,
      match = Sim.at(st.match_log, 28) or match,
      match_won = Data.match_won_from(st),
      end_stat = st.match_log and st.match_log.end_stat,
      rate = st.rate,
    })
  end
end

return M
