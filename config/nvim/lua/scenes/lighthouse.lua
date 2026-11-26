-- Lighthouse: a striped tower on a moonlit headland, its beam sweeping over a rolling sea.
local U = require("scenes.util")
local floor, abs, max, min, exp, sqrt = math.floor, math.abs, math.max, math.min, math.exp, math.sqrt
local hex, mix, clamp, hash = U.hex, U.mix, U.clamp, U.hash

local C = {
  sky = { { 0, hex("#000000") }, { 0.6, hex("#040b1e") }, { 1, hex("#0f2344") } },
  glow = hex("#33476f"),
  beam = hex("#fff1b0"),
  halo = hex("#ffd27a"),
  lamp = hex("#fffbe2"),
  glass = hex("#ffc85e"),
  tip = hex("#c9cfdc"),
  roof = hex("#b23c4c"),
  roof_shade = hex("#6e2433"),
  gallery = hex("#3a3f50"),
  rail = hex("#8d96ab"),
  red = { hex("#ec5a62"), hex("#bd3c4a"), hex("#7c2535") }, -- lit, mid, shade
  white = { hex("#f1f4f9"), hex("#c3cad8"), hex("#7d889f") },
  plinth = { hex("#8790a6"), hex("#5d667c"), hex("#3c4356") },
  window = hex("#ffc46a"),
  wall = hex("#6b7692"),
  wall_shade = hex("#454e66"),
  house_roof = hex("#2c3244"),
  house_rim = hex("#7487ab"),
  rim = hex("#4a6585"), -- moonlit grass along the cliff top
  rock_hi = hex("#26334c"),
  rock = hex("#161e33"),
  rock_dark = hex("#080c17"),
  rock_lit = hex("#3a4e74"),
  sea = hex("#06142c"),
  wave = hex("#9cb2da"),
  foam = hex("#d2def2"),
  moonlight = { 243, 231, 196 },
}

return function(PW, PH, seed)
  local horizon = floor(PH * 0.62 + 0.5)
  local sky_h = horizon
  local sea_h = PH - horizon
  local big = PH >= 24
  local flip = hash(1, 1, seed) < 0.5 -- lighthouse on the left or the right
  local function fx(x)
    return flip and (PW - 1 - x) or x
  end

  -- moon on the far side from the lighthouse
  local R = max(3.1, sky_h * 0.16)
  local mx, my = PW * (0.70 + 0.1 * hash(2, 1, seed)), max(R + 1.2, sky_h * 0.28)
  mx = min(mx, PW - R - 2)
  if flip then
    mx = PW - 1 - mx
  end

  -- Headland (unflipped coords): a flat top, then a rugged slope down to the sea.
  local cliff_w = max(11, floor(PW * 0.30))
  local ground = horizon - max(2, floor(sky_h * 0.25 + 0.5)) -- first rock row of the flat top
  local x0 = floor(cliff_w * 0.68) -- where the slope begins
  local tops = {} -- rock top row per column (nil past the cliff)
  for ux = 0, cliff_w do
    local t = max(0, ux - x0) / (cliff_w - x0)
    tops[ux] = floor(ground + (horizon - ground) * t ^ 1.8 + (U.noise1(ux * 0.9, seed + 5) - 0.5) * 1.2 * t + 0.5)
  end
  -- seaward edge of the slope per row, for the lit face
  local edges = {}
  for y = ground, horizon - 1 do
    local e = x0
    while e + 1 <= cliff_w and tops[e + 1] <= y do
      e = e + 1
    end
    edges[y] = e
  end
  -- shoreline below the horizon: juts toward the viewer with a ragged edge
  local shores = {}
  for depth = 0, PH - horizon do
    shores[depth] = cliff_w + depth * 0.45 + (U.noise1(depth * 0.8, seed + 9) - 0.5) * 2.2
  end

  -- Tower layout, top to bottom: tip, roof, lamp room, gallery, banded body (with a plinth when tall).
  local tx = max(5, floor(cliff_w * 0.48))
  local roof_h, lamp_h = big and 2 or 1, big and 2 or 1
  local stack = 1 + roof_h + lamp_h + 1
  local body_h = max(3, min(ground - stack - (big and 1 or 0), floor(sky_h * 0.46)))
  local body_top = ground - body_h
  local gallery_y = body_top - 1
  local lamp_top = gallery_y - lamp_h
  local roof_top = lamp_top - roof_h
  local tip_y = roof_top - 1
  local lamp_cy = lamp_top + (lamp_h - 1) / 2 -- the beam starts here
  local band_h = body_h >= 6 and 2 or 1
  local plinth = body_h >= 5
  -- a small lit window in the white band nearest the middle (tall towers only)
  local wb = floor(body_h / 2 / band_h)
  wb = wb % 2 == 1 and wb or wb - 1 -- odd bands are white
  local window_i = body_h >= 7 and wb * band_h + band_h - 1 or -1

  -- keeper's cottage on the land side, when there is room
  local hx = tx - 8
  local house = big and hx >= 1

  -- Three-tone cylinder shading; the side facing the moon is lit.
  local function tone(set, dx)
    return dx > 0 and set[1] or (dx == 0 and set[2] or set[3])
  end

  local function tower(ux, y)
    local dx = ux - tx
    local adx = abs(dx)
    if y == tip_y then
      return adx == 0 and C.tip or nil
    end
    if y >= roof_top and y < lamp_top then
      local hw = (roof_h == 2 and y == roof_top) and 0 or 1
      if adx <= hw then
        return dx > 0 and C.roof or C.roof_shade
      end
      return nil
    end
    if y >= lamp_top and y < gallery_y then
      if adx == 0 then
        return C.lamp
      elseif adx == 1 then
        return C.glass
      elseif adx == 2 and y == gallery_y - 1 then
        return C.rail -- railing posts
      end
      return nil
    end
    if y == gallery_y then
      return adx <= 2 and (adx == 2 and C.rail or C.gallery) or nil
    end
    if y >= body_top and y < ground then
      if plinth and y == ground - 1 then
        return adx <= 2 and tone(C.plinth, dx) or nil
      end
      if adx > 1 then
        return nil
      end
      local i = y - body_top
      if adx == 0 and i == window_i then
        return C.window -- a small lit window halfway up
      end
      return tone(floor(i / band_h) % 2 == 0 and C.red or C.white, dx)
    end
    return nil
  end

  local function cottage(ux, y)
    local dx = ux - hx -- 0..4 across
    if dx < 0 or dx > 4 then
      return nil
    end
    local h = ground - y -- 1 = lowest wall row
    if h == 1 or h == 2 then
      if h == 1 and dx == 2 then
        return C.window
      end
      return dx >= 3 and C.wall or C.wall_shade
    elseif h == 3 then
      return C.house_roof
    elseif h == 4 and dx >= 1 and dx <= 3 then
      return dx == 3 and C.house_rim or C.house_roof
    end
    return nil
  end

  -- Rock texture: short horizontal streaks (ledges and cracks), darker with depth below the top.
  local function rock(ux, y, top, edge)
    local d = y - top
    local c = mix(C.rock, C.rock_dark, clamp(d / (sky_h * 0.5 + sea_h * 0.6), 0, 1))
    local n = U.noise1(ux * 0.35 + y * 3.1, seed + 40)
    if n > 0.8 and d > 1 then
      c = mix(c, C.rock_hi, 0.4)
    elseif n < 0.18 then
      c = mix(c, C.rock_dark, 0.6)
    end
    if edge and edge - ux < 1.5 then
      c = mix(c, C.rock_lit, 0.55) -- moonlight catching the seaward face
    end
    return c
  end

  local function sky_at(x, y)
    local c = U.gradient(C.sky, clamp(y / sky_h, 0, 1))
    local ux = fx(x)
    local dx, dy = ux - tx, y - lamp_cy
    -- no stars in the moon's glow or crowding the lighthouse
    local fade = min(clamp((U.dist(x, y, mx, my) - R * 2) / R, 0, 1), clamp((abs(dx) - 4) / 3, 0, 1))
    c = U.stars(c, x, y, seed, 0.05 * (1 - y / sky_h), fade)
    local on_moon
    c, on_moon = U.moon(c, x, y, mx, my, R, seed, C.glow)
    -- warm halo around the lamp room
    local d = sqrt(dx * dx + dy * dy * 1.3)
    if d < 9 then
      c = mix(c, C.halo, exp(-d / 1.7) * 0.75)
    end
    -- beam: a widening cone from the lamp toward the sea, tilted slightly down
    if dx > 0 and not on_moon then -- the moon stays crisp where the beam crosses it
      local spread = 0.07 + dx * 0.0035
      local off = abs(dy / dx - 0.11)
      if off < spread then
        local k = 1 - off / spread
        c = mix(c, C.beam, k * k * 0.6 * max(0.2, 1 - dx / (PW * 0.95)))
      end
    elseif dx < 0 then
      -- a faint back beam toward the land side
      local off = abs(dy / -dx + 0.05)
      if off < 0.08 then
        c = mix(c, C.beam, (1 - off / 0.08) * 0.16 * max(0, 1 + dx / 14))
      end
    end
    return c
  end

  local function draw(x, y)
    local ux = fx(x)
    local t = tower(ux, y)
    if t then
      return t
    end
    if house then
      local h = cottage(ux, y)
      if h then
        return h
      end
    end
    local top = tops[ux]
    if top and y >= top then
      if y == top then
        return ux > x0 and C.rock_lit or C.rim -- moonlit rim along the top
      end
      return rock(ux, y, top, ux > x0 and edges[y] or nil)
    end
    return sky_at(x, y)
  end
  -- memoized, so the water's reflection reuses the pixels already drawn above it
  local memo = {}
  local function scene(x, y)
    x = floor(x + 0.5)
    local k = y * PW + x
    local c = memo[k]
    if not c then
      c = draw(x, y)
      memo[k] = c
    end
    return c
  end

  return function(px, py)
    if py < horizon then
      return scene(px, py)
    end
    local ux = fx(px)
    local depth = py - horizon
    local edge = shores[depth]
    if ux < edge then
      return rock(ux, py, ground, edge)
    end
    local c = U.water(scene, px, py, horizon, PH, PW, seed, C.sea, C.glow, C.moonlight, mx, R)
    local near = depth / max(1, sea_h - 1)
    -- rolling wave crests: short dashes on the rows between the moon glints
    if depth >= 1 and depth % 2 == 0 then
      local L = 8 + floor(near * 4)
      local s = px + floor(hash(depth, 3, seed) * L)
      local seg, p = floor(s / L), s % L
      local len = 2 + floor(near * 2.5)
      if p < len and hash(seg, depth, seed + 90) < 0.5 then
        -- brightest at the crest's leading pixel, fading along the tail
        c = mix(c, C.wave, (0.32 + 0.33 * near) * (p == 0 and 1 or 0.65))
      end
    end
    -- surf breaking along the rocks
    local f = ux - edge
    if f < 1.2 then
      local h = hash(px, py, seed + 70)
      c = mix(c, C.foam, h < 0.3 and 0.25 or (0.45 + 0.25 * h))
    elseif f < 2.8 and hash(px, py, seed + 71) < 0.4 then
      c = mix(c, C.foam, 0.25)
    end
    return c
  end
end
