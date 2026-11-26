-- Rainy forest at night: misty layers of firs under storm clouds, a lit cabin, puddles, slanted rain.
local U = require("scenes.util")
local floor, abs, max, min, exp, sqrt = math.floor, math.abs, math.max, math.min, math.exp, math.sqrt
local hex, mix, clamp, hash = U.hex, U.mix, U.clamp, U.hash

local C = {
  sky = { { 0, hex("#0a1220") }, { 0.3, hex("#1a2a3c") }, { 0.6, hex("#3b5266") }, { 1, hex("#62798a") } },
  cloud = hex("#243547"),
  cloud_lit = hex("#4a6078"),
  cloud_dark = hex("#141f2b"),
  flash = hex("#9aa8d8"),
  bolt = hex("#f2f5ff"),
  bolt_halo = hex("#8a9ad0"),
  mist = hex("#64808f"),
  firs = { hex("#26384a"), hex("#172532"), hex("#0c161c") },
  front = hex("#03070a"),
  ground = hex("#080e12"),
  water = hex("#0a1620"),
  wall = hex("#5a3a22"),
  wall_dark = hex("#432a18"),
  roof = hex("#2e3a46"),
  roof_wet = hex("#7c94a8"),
  door = hex("#1a100a"),
  window = hex("#ffd486"),
  window_edge = hex("#f09a40"),
  warm = hex("#ff9a3c"),
  rain = hex("#9fb4c8"),
}

-- 2D value noise from U.hash, for the cloud shapes.
local function noise2(x, y, s)
  local ix, iy = floor(x), floor(y)
  local fx, fy = U.smooth(x - ix), U.smooth(y - iy)
  local h00, h10, h01, h11 = hash(ix, iy, s), hash(ix + 1, iy, s), hash(ix, iy + 1, s), hash(ix + 1, iy + 1, s)
  local a = h00 + (h10 - h00) * fx
  local b = h01 + (h11 - h01) * fx
  return a + (b - a) * fy
end

-- Half-width of a fir `ft` rows below its tip: a narrow cone with notched branch tiers on taller trees.
local function fir_half(ft, h)
  local w = ft * 0.5 + 0.3
  if h >= 7 and ft >= 4 and ft < h - 1 and ft % 3 == 1 then
    w = w - 1 -- tier notch
  end
  return floor(w)
end

return function(PW, PH, seed)
  local ground = floor(PH * 0.80) -- first row of the forest floor
  local sky_h = ground
  local buf = {}
  local function put(x, y, c)
    if x >= 0 and x < PW and y >= 0 and y < ground then
      buf[y * PW + x] = c
    end
  end

  -- Lightning flash position (most seeds) and its strength.
  local has_flash = hash(3, 4, seed) < 0.7
  local cab_left = hash(4, 1, seed) < 0.5
  local fl_x = PW * (0.5 + 0.34 * hash(3, 1, seed)) -- on the side away from the cabin
  if not cab_left then
    fl_x = PW - 1 - fl_x
  end
  local fl_y = sky_h * 0.18
  local fl_r = max(8, PW * 0.22)
  local fl_k = has_flash and (0.45 + 0.35 * hash(3, 3, seed)) or 0

  -- Sky: gradient under a deck of lumpy storm clouds with lit tops and dark bellies.
  local cs = max(7, PW * 0.13) -- cloud cell width
  local cloud_bot = sky_h * 0.5
  local function density(x, y)
    local n = noise2(x / cs, y / (cs * 0.35), seed + 40) * 0.65 + noise2(x / cs * 2.2, y / (cs * 0.3), seed + 41) * 0.35
    return n - 0.35 - 0.55 * (y / cloud_bot) ^ 2
  end
  for y = 0, ground - 1 do
    local t = y / sky_h
    for x = 0, PW - 1 do
      local c = U.gradient(C.sky, t)
      local d = density(x, y)
      local dx, dy = (x - fl_x) / fl_r, (y - fl_y) / (fl_r * 0.45)
      local g = exp(-(dx * dx + dy * dy) * 1.6) * fl_k
      if d > 0 then
        local cc = C.cloud
        if density(x, y - 1) <= 0 then
          cc = C.cloud_lit -- rim on the cloud tops
        elseif density(x, y + 1) <= 0 then
          cc = C.cloud_dark -- shadowed belly
        end
        c = mix(cc, C.flash, g)
      else
        c = mix(c, C.flash, g * 0.35)
      end
      buf[y * PW + x] = c
    end
  end

  -- Lightning bolt: a jagged random walk down from the cloud base, with one short side fork.
  if has_flash and PH >= 24 then
    local function plot(x, y, k)
      if x >= 0 and x < PW and y >= 0 and y < ground then
        local i = y * PW + x
        buf[i] = mix(buf[i], C.bolt, k)
        for _, o in ipairs({ -1, 1 }) do
          if x + o >= 0 and x + o < PW then
            buf[i + o] = mix(buf[i + o], C.bolt_halo, 0.22 * k)
          end
        end
      end
    end
    local path = {}
    -- zigzag of straight segments with sharp kinks; `drift` pulls the walk to one side
    local function strike(x, y, y_end, k, s, drift)
      local i, dir = 0, hash(0, 3, s) < 0.5 and -1 or 1
      while y < y_end do
        i = i + 1
        if hash(i, 2, s) < 0.55 then
          dir = -dir
        end
        local dy = min(1 + floor(hash(i, 1, s) * 4), y_end - y)
        local dx = dir * (1 + floor(hash(i, 4, s) * 1.7)) + drift
        dx = clamp(dx, -max(1, dy), max(1, dy)) -- never flatter than 45 degrees
        local n = max(abs(dx), dy)
        for j = 1, n do
          local xx, yy = floor(x + dx * j / n + 0.5), floor(y + dy * j / n + 0.5)
          plot(xx, yy, k)
          path[yy] = path[yy] or xx
        end
        x, y = x + dx, y + dy
      end
    end
    local bx, by = floor(fl_x), floor(fl_y + 1)
    local s = seed + 80
    local lean = hash(3, 5, s) < 0.5 and -1 or 1
    strike(bx, by, ground - 2, 0.95, s, 0)
    -- fork: leaves the main channel near the cloud base and dies out sideways
    local fy = floor(by + (ground - by) * (0.15 + 0.15 * hash(3, 6, s)))
    strike(path[fy] or bx, fy, fy + max(3, floor((ground - fy) * 0.3)), 0.55, s + 7, lean)
  end

  -- Cabin, standing in a clearing of the nearest fir layer on one side of the scene.
  local cab_w = clamp(floor(PW * 0.1 + 0.5), 5, 8)
  local cab_h = clamp(floor(sky_h * 0.15 + 0.5), 2, 4)
  local cab_x = floor(PW * (0.22 + 0.12 * hash(4, 2, seed))) -- left placement, mirrored for the right
  if not cab_left then
    cab_x = PW - cab_x - cab_w
  end
  local roof_rows = cab_w >= 7 and 3 or 2

  -- Fir layers, far to near, each fading into a band of mist at its foot.
  local specs = {
    { base = 0.20, hmin = 0.12, hmax = 0.24, gap = 2.0, col = C.firs[1] },
    { base = 0.11, hmin = 0.18, hmax = 0.32, gap = 3.0, col = C.firs[2] },
    { base = 0.03, hmin = 0.24, hmax = 0.42, gap = 3.8, col = C.firs[3] },
  }
  if PH < 24 then
    -- too few rows for three layers: two taller ones read better
    specs = {
      { base = 0.16, hmin = 0.22, hmax = 0.36, gap = 3.0, col = C.firs[1] },
      { base = 0.03, hmin = 0.30, hmax = 0.46, gap = 4.0, col = C.firs[3] },
    }
  end
  for li, sp in ipairs(specs) do
    local s = seed + li * 31
    local col = sp.col
    local base = {}
    for x = 0, PW - 1 do
      base[x] = ground - 1 - floor(sky_h * sp.base * (0.75 + 0.5 * U.noise1(x * 0.1, s)))
      for y = base[x] + 1, ground - 1 do
        put(x, y, col)
      end
    end
    local x = -floor(hash(0, 1, s) * sp.gap)
    while x < PW + 4 do
      local clear = li == #specs and x > cab_x - 4 and x < cab_x + cab_w + 3
      if not clear then
        local h = max(li + 1, floor(sky_h * (sp.hmin + (sp.hmax - sp.hmin) * hash(x, 3, s))))
        local b = base[clamp(x, 0, PW - 1)]
        for ft = 0, h do
          local half = fir_half(ft, h)
          for xx = x - half, x + half do
            put(xx, b - h + ft, col)
          end
        end
      end
      x = x + max(2, floor(sp.gap * (0.7 + 0.6 * hash(x, 4, s)) + 0.5))
    end
    -- this layer's foot dissolves into mist, so the next layer's tops stand out against it
    if li < #specs then
      local nx = specs[li + 1]
      local top = ground - 1 - sky_h * (nx.base + nx.hmax * 0.7)
      local mh = max(2, sky_h * (nx.hmax * 0.6))
      for y = max(0, floor(top)), ground - 1 do
        local m = clamp((y - top) / mh, 0, 1) * 0.7
        for xx = 0, PW - 1 do
          buf[y * PW + xx] = mix(buf[y * PW + xx], C.mist, m)
        end
      end
    end
  end

  -- Low ground fog over the foot of the nearest layer.
  local fog_h = max(2, floor(sky_h * 0.14))
  for y = ground - fog_h, ground - 1 do
    local m = 0.32 * ((y - (ground - fog_h - 1)) / fog_h) ^ 1.5
    for x = 0, PW - 1 do
      local f = m * (0.7 + 0.3 * U.noise1(x * 0.15, seed + 90))
      buf[y * PW + x] = mix(buf[y * PW + x], C.mist, f)
    end
  end

  -- Window position, then its warm glow spilling onto the mist and trees.
  local cy1 = ground - 1
  local cy0 = cy1 - cab_h + 1
  local cx1 = cab_x + cab_w - 1
  local wy = cy1 - floor((cab_h - 1) / 2)
  local wx = cab_left and (cab_x + 1) or (cx1 - 1)
  local wx2 = cab_w >= 6 and (wx + (cab_left and 1 or -1)) or wx
  local gx, gy = (wx + wx2) / 2, wy
  local gr = max(5, PW * 0.11)
  local function glow(x, y)
    local ex, ey = (x - gx) / 1.6, (y - gy) * 1.1
    local d = sqrt(ex * ex + ey * ey) / gr
    return d < 1 and (1 - d) ^ 2 or 0
  end
  for y = max(0, floor(gy - gr)), ground - 1 do
    for x = max(0, floor(gx - gr * 1.6)), min(PW - 1, floor(gx + gr * 1.6)) do
      local i = y * PW + x
      local g, c = glow(x, y), buf[i]
      -- additive warm light, so lit mist turns amber instead of a dull tan
      buf[i] = { c[1] + 150 * g, c[2] + 70 * g, c[3] + 8 * g - c[3] * 0.3 * g }
    end
  end

  -- The cabin: log walls, a gabled roof with overhang and wet ridge, a chimney, and lit windows.
  for y = cy0, cy1 do
    for x = cab_x, cx1 do
      put(x, y, (y - cy0) % 2 == 1 and C.wall_dark or C.wall)
    end
  end
  for r = 1, roof_rows do
    for x = cab_x - 2 + r, cx1 + 2 - r do
      put(x, cy0 - r, r == roof_rows and C.roof_wet or C.roof)
    end
  end
  local chx = cab_left and cx1 - 1 or cab_x + 1
  put(chx, cy0 - roof_rows, C.wall_dark)
  put(chx, cy0 - roof_rows - 1, C.wall_dark)
  put(wx, wy, C.window)
  put(wx2, wy, C.window)
  if cab_h >= 3 then
    put(wx, wy - 1, C.window_edge)
    put(wx2, wy - 1, C.window_edge)
  end
  -- dark door on the other side, with a sliver of light at its edge
  local dx = cab_left and (cx1 - 1) or (cab_x + 1)
  if cab_h >= 3 then
    put(dx, cy1, C.door)
    put(dx, cy1 - 1, C.door)
  end

  -- Near firs framing the edges, in front of everything.
  local fs = seed + 97
  for side = 0, 1 do
    local n = PW >= 56 and 2 or 1
    for i = 1, n do
      local off = floor(PW * (0.015 + 0.06 * (i - 1)) + hash(i, side, fs) * 2)
      local fx = side == 0 and off or (PW - 1 - off)
      local h = floor(sky_h * (0.80 - 0.2 * (i - 1) + 0.12 * hash(i, side + 2, fs)))
      for ft = 0, h do
        local half = fir_half(ft, h)
        for xx = fx - half, fx + half do
          put(xx, ground - 1 - h + ft, C.front)
        end
      end
    end
  end

  -- Forest floor: dark wet ground with oval puddles that mirror the scene above.
  local fh = PH - ground
  local puddles = { { x = gx, y = ground + fh * 0.5, w = max(4, PW * 0.10), h = max(1.3, fh * 0.42) } }
  local np = PW >= 56 and 2 or 1
  for i = 1, np do
    local px = PW * ((i - 0.5 + 0.5 * (hash(i, 2, seed + 50) - 0.5)) / np)
    if abs(px - gx) > PW * 0.22 then
      puddles[#puddles + 1] = {
        x = px,
        y = ground + fh * (0.4 + 0.3 * hash(i, 4, seed + 50)),
        w = PW * (0.06 + 0.05 * hash(i, 3, seed + 50)),
        h = max(1.0, fh * 0.28),
      }
    end
  end
  for y = ground, PH - 1 do
    local depth = y - ground
    for x = 0, PW - 1 do
      local wet = false
      for _, p in ipairs(puddles) do
        local ex, ey = (x - p.x) / p.w, (y + 0.5 - p.y) / p.h
        if ex * ex + ey * ey < 1 then
          wet = true
        end
      end
      local c
      if wet then
        local ry = clamp(ground - 1 - depth, 0, ground - 1)
        local sx = x
        if depth % 2 == 1 then
          sx = clamp(x + ((hash(floor(x / 3), y, seed + 60) < 0.5) and 1 or -1), 0, PW - 1)
        end
        c = mix(C.water, buf[ry * PW + sx], 0.7)
      else
        c = C.ground
        if hash(x, y, seed + 61) < 0.07 then
          c = mix(c, C.mist, 0.18) -- wet glints
        end
      end
      c = mix(c, C.warm, glow(x, ground - 1 + depth * 2) * 0.25)
      buf[y * PW + x] = c
    end
  end

  -- Rain: sparse slanted streaks; near ones are longer and brighter, and warm up near the window.
  local slant = (hash(6, 1, seed) < 0.5) and 0.5 or -0.5
  local small = PH < 24
  local sets = {
    { period = 9, len = 2, dens = small and 0 or 0.10, a = 0.10, s = seed + 70 },
    { period = small and 10 or 15, len = small and 2 or 4, dens = 0.07, a = 0.30, s = seed + 71 },
  }
  local out = {}
  for y = 0, PH - 1 do
    for x = 0, PW - 1 do
      local c = buf[y * PW + x]
      local u = floor(x + y * slant)
      for _, r in ipairs(sets) do
        if hash(u, 0, r.s) < r.dens then
          local ph = floor(hash(u, 1, r.s) * r.period)
          local k = (y + ph) % r.period
          if k < r.len then
            local a = r.a * (0.55 + 0.45 * (k + 1) / r.len) -- brighter toward the falling head
            local rc = mix(C.rain, C.window, glow(x, y) * 0.8)
            c = mix(c, rc, y >= ground and a * 0.5 or a)
          end
        end
      end
      out[y * PW + x] = c
    end
  end

  return function(px, py)
    return out[py * PW + px]
  end
end
