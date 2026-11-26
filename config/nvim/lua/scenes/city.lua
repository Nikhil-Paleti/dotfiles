-- City at night: a skyline with lit windows, spires, water towers and a billboard over a reflecting river.
local U = require("scenes.util")
-- Short, branchy per-pixel code: the interpreter beats trace compilation here.
if jit then
  jit.off(true, true)
end
local floor, abs, max, min = math.floor, math.abs, math.max, math.min
local hex, mix, clamp, hash = U.hex, U.mix, U.clamp, U.hash

local C = {
  sky = { { 0, hex("#000000") }, { 0.45, hex("#0a0820") }, { 0.8, hex("#2c1650") }, { 1, hex("#5a2a6e") } },
  glow = hex("#2a2d55"),
  far = hex("#2a3058"),
  near = hex("#07081a"),
  edge = hex("#3a4478"),
  win_warm = hex("#ffd27a"),
  win_cool = hex("#7ad7ff"),
  win_dim = hex("#a07a4a"),
  red = hex("#ff4f5e"),
  water = hex("#04061a"),
  moonlight = hex("#e8dcb8"),
}
local BOARDS = { hex("#ff4fa8"), hex("#4fe0ff"), hex("#ffb14f") }

return function(PW, PH, seed)
  local shore = floor(PH * 0.74)
  local sky_h = shore
  local R = max(2.7, sky_h * 0.11) -- below ~2.7 px the crescent collapses into a line
  local mx, my = PW * (0.12 + 0.2 * hash(1, 1, seed)), max(R + 1, sky_h * 0.20)
  local top = sky_h - 2 -- nothing on a roof rises above this height, so the top row stays sky

  -- Buildings left to right: two layers (far skyline, near towers).
  local function layer(s, wmin, wmax, hmin, hmax)
    local list, x = {}, -1
    while x < PW do
      local w = wmin + floor(hash(x, 1, s) * (wmax - wmin + 1))
      local h = floor(sky_h * (hmin + (hmax - hmin) * hash(x, 2, s) ^ 1.4))
      list[#list + 1] = { x0 = x, x1 = x + w - 1, w = w, h = h, s = x * 7 + s, kind = "flat" }
      list[#list].antenna = hash(x, 3, s) < 0.25 and h + 3 <= top
      x = x + w + (hash(x, 4, s) < 0.3 and 1 or 0)
    end
    return list
  end
  local far = layer(seed, 3, 6, 0.30, 0.55)
  local near = layer(seed + 50, 4, 8, 0.20, 0.80)

  -- Rooftop variety. The tallest near tower gets a spire (or a stepped crown); a few others get
  -- stepped tops or water towers, and one mid-height building carries a lit billboard.
  local tall
  for _, b in ipairs(near) do
    if b.x0 >= 1 and b.x1 <= PW - 2 and b.w >= 4 and (not tall or b.h > tall.h) then
      tall = b
    end
  end
  local function room(b, need)
    return b.h + need <= top
  end
  for i, b in ipairs(near) do
    local r = hash(i, 5, seed)
    if b == tall then
      if hash(2, 5, seed) < 0.6 and room(b, 5) then
        b.kind, b.sp, b.antenna = "spire", min(top - b.h - 2, max(3, floor(sky_h * 0.2))), false
      elseif b.w >= 5 and room(b, 5) then
        b.kind, b.antenna = "step", true
      end
    elseif r < 0.22 and b.w >= 5 and room(b, 3) then
      b.kind = "step"
      b.antenna = b.antenna and room(b, 6)
    elseif r < 0.40 and room(b, 4) and b.h >= sky_h * 0.3 then
      b.kind, b.antenna = "tower", false
    end
  end
  for i, b in ipairs(far) do
    if hash(i, 6, seed) < 0.3 and b.w >= 5 and room(b, 2) then
      b.kind = "step"
    end
  end
  local board
  local want = PW * hash(3, 5, seed)
  for _, b in ipairs(near) do
    local ok = sky_h >= 14
      and b ~= tall
      and b.w >= 5
      and abs((b.x0 + b.x1) / 2 - mx) > R + 4
      and b.x0 >= 1
      and b.x1 <= PW - 2
      and room(b, 4)
      and b.h >= sky_h * 0.25
      and b.h <= sky_h * 0.55
    if ok and (not board or abs(b.x0 - want) < abs(board.x0 - want)) then
      board = b
    end
  end
  local board_col
  if board then
    board.kind, board.antenna = "board", false
    for _, f in ipairs(far) do -- no far antenna poking up behind the sign
      if f.x1 >= board.x0 and f.x0 <= board.x1 then
        f.antenna = false
      end
    end
    board_col = BOARDS[1 + floor(hash(3, 6, seed) * #BOARDS)]
  end

  -- Column lookup so each pixel finds its building directly.
  local function index(list)
    local at = {}
    for _, b in ipairs(list) do
      for x = max(0, b.x0), min(PW - 1, b.x1) do
        at[x] = b
      end
    end
    return at
  end
  local near_at, far_at = index(near), index(far)

  -- Roof shapes above the main body. Returns a color (or "lit" for the billboard face) or nil.
  local function roof(b, x, hgt, base_col)
    local k = hgt - b.h
    local mid = floor((b.x0 + b.x1) / 2)
    if b.kind == "step" then
      -- one or two setbacks; the antenna (if any) stands on the crown
      local t = k <= 2 and 1 or (k == 3 and b.w >= 7 and 2 or nil)
      if t and x >= b.x0 + t and x <= b.x1 - t then
        return (x == b.x0 + t and mx < x) and mix(base_col, C.edge, 0.6) or base_col
      end
      k = k - (b.w >= 7 and 3 or 2)
    elseif b.kind == "spire" then
      local midf = (b.x0 + b.x1) / 2
      local hw = max(b.w % 2 == 0 and 0.5 or 0, ((b.w - 1) / 2 - 1) * (1 - (k - 1) / b.sp))
      if k <= b.sp and abs(x - midf) <= hw then
        if k == 1 and (x - b.x0) % 2 == 1 then
          return "crown" -- a band of lights at the foot of the spire
        end
        if abs(x - midf) > hw - 1 then
          return mix(base_col, C.edge, (x < midf) == (mx < midf) and 0.75 or 0.4) -- both edges, moon side brighter
        end
        return base_col
      end
      if x == mid and k <= b.sp + 2 then
        return k == b.sp + 2 and C.red or base_col
      end
    elseif b.kind == "tower" then
      local tx = b.x0 + 1 + floor(hash(b.s, 7, seed) * (b.w - 3))
      if k == 1 and (x == tx - 1 or x == tx + 1) then
        return base_col
      elseif (k == 2 or k == 3) and abs(x - tx) <= 1 then
        return (x == tx - 1 and mx < x) and mix(base_col, C.edge, 0.7) or mix(base_col, C.edge, 0.25)
      elseif k == 4 and x == tx then
        return mix(base_col, C.edge, 0.25)
      end
    elseif b.kind == "board" then
      if k == 1 and x > b.x0 and x < b.x1 then
        return base_col
      elseif (k == 2 or k == 3) and x >= b.x0 and x <= b.x1 then
        return "lit"
      end
    end
    if b.antenna and x == mid and k >= 1 and k <= 3 then
      return k == 3 and C.red or base_col
    end
    return nil
  end

  -- Building pixel: color plus whether it is a lit window (for the river streaks).
  local function building(b, x, hgt, base_col, lit_prob)
    if not b then
      return nil
    end
    if hgt > b.h then
      local c = roof(b, x, hgt, base_col)
      if c == "crown" then
        return C.win_cool, true
      elseif c == base_col and not roof(b, x, hgt + 1, base_col) then
        return mix(base_col, C.edge, 0.3), false -- faint rim along the roofline
      elseif c == "lit" then
        -- billboard: a glowing panel with a darker row of "lettering"
        local k = hgt - b.h
        local lc = board_col
        if k == 2 and x > b.x0 and x < b.x1 and hash(x, 8, seed) < 0.55 then
          lc = mix(board_col, C.near, 0.55)
        end
        return lc, true
      end
      return c, false
    end
    -- windows on a 2x2 grid, inset from the walls
    local wx, wy = x - b.x0, b.h - hgt
    if wx >= 1 and wx <= b.w - 2 and wy >= 1 and wx % 2 == 1 and wy % 2 == 1 then
      if hash(x, hgt, b.s) < lit_prob then
        local t = hash(x, hgt, b.s + 1)
        return t < 0.65 and C.win_warm or (t < 0.85 and C.win_cool or C.win_dim), true
      end
    end
    -- a faint lit edge on the side facing the moon, and along the roofline
    if hgt == b.h and not roof(b, x, hgt + 1, base_col) then
      return mix(base_col, C.edge, 0.3), false
    end
    if x == b.x0 and mx < x then
      return mix(base_col, C.edge, 0.6), false
    end
    return base_col, false
  end

  -- Billboard glow spills a little into the sky around it.
  local bx0, bx1, by0, by1
  if board then
    bx0, bx1, by0, by1 = board.x0, board.x1, shore - board.h - 3, shore - board.h - 2
  end
  local function sky(x, y)
    local c = U.gradient(C.sky, clamp(y / sky_h, 0, 1))
    c =
      U.stars(c, x, y, seed, 0.04 * clamp(1 - y / (sky_h * 0.6), 0, 1), clamp((U.dist(x, y, mx, my) - R * 2) / R, 0, 1))
    if board then
      local dx = max(bx0 - x, 0, x - bx1)
      local dy = max(by0 - y, 0, y - by1)
      local d = dx + dy
      if d == 1 then
        c = mix(c, board_col, 0.14)
      end
    end
    return (U.moon(c, x, y, mx, my, R, seed, C.glow))
  end

  local function scene(x, y)
    local hgt = shore - y
    local c, lit = building(near_at[x], x, hgt, C.near, 0.45)
    if c then
      return c, lit
    end
    c, lit = building(far_at[x], x, hgt, C.far, 0.30)
    if c then
      return mix(c, C.sky[4][2], 0.10), lit
    end
    return sky(x, y), false
  end

  -- Per-column light for the river: the average color of the lit windows above, and how many.
  local col_light = {}
  for x = 0, PW - 1 do
    local r, g, bl, n = 0, 0, 0, 0
    for y = 0, shore - 1 do
      local hgt = shore - y
      local c, lit = building(near_at[x], x, hgt, C.near, 0.45)
      if not c then
        c, lit = building(far_at[x], x, hgt, C.far, 0.30)
      end
      if lit then
        local w = 0.5 + 0.5 * y / shore -- lower windows sit closer to the water
        r, g, bl, n = r + c[1] * w, g + c[2] * w, bl + c[3] * w, n + w
      end
    end
    -- only some columns cast a streak, so they read as separate lines rather than a comb
    if n >= 1.2 and hash(x, 9, seed) < 0.6 then
      col_light[x] = { { r / n, g / n, bl / n }, min(1, 0.2 + n * 0.15) }
    end
  end

  local water_h = max(1, PH - shore)
  return function(px, py)
    if py < shore then
      return (scene(px, py))
    end
    local depth = py - shore
    local fade = depth / water_h
    -- dark mirror of the skyline (windows left to the streaks below)
    local ry = max(0, shore - 1 - depth)
    local m = scene(px, ry)
    local c = mix(C.water, m, 0.38 * (1 - fade * 0.6))
    if depth == 0 then
      c = mix(c, { 1, 3, 9 }, 0.55)
    end
    -- lit windows smear into vertical, broken, gently wobbling streaks
    local L = col_light[px]
    if L and depth > 0 then
      -- each streak breaks up into dashes of varying length further out
      local on = U.noise1(depth * 0.9 + px * 3.7, seed + 60)
      if on > 0.25 + fade * 0.3 then
        c = mix(c, L[1], L[2] * (0.85 - 0.5 * fade) * (0.6 + 0.4 * on))
      end
    end
    -- moonlight: a few short glints under the moon
    if depth > 0 and hash(depth, 3, seed + 31) < 0.55 then
      local x0 = floor(mx + (hash(depth, 2, seed + 31) - 0.5) * (2 + depth * 0.5))
      local len = 1 + floor(hash(depth, 4, seed + 31) * (1.5 + depth * 0.25))
      if px >= x0 and px < x0 + len then
        c = mix(c, C.moonlight, 0.5 * (1 - fade * 0.5))
      end
    end
    return c
  end
end
