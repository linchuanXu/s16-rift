local App = require("domain.rift_app")

function on_enter(ctx) App.enter(ctx) end
function on_tick(ctx, dt) App.tick(ctx, dt) end
function on_input(ctx, ev) return App.input(ctx, ev) end
function on_draw(ctx, g) App.draw(ctx, g) end
