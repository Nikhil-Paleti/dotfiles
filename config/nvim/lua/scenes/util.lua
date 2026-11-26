-- Shared helpers for the start-screen scenes: color math, deterministic noise, sky, stars, moon.
local M = {}

local floor, sin, sqrt, abs, max, exp = math.floor, math.sin, math.sqrt, math.abs, math.max, math.exp

function M.clamp(v, a, b)
  return v < a and a or (v > b and b or v)
end
function M.mix(a, b, t)
  return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end
function M.hex(h)
  return { tonumber(h:sub(2, 3), 16), tonumber(h:sub(4, 5), 16), tonumber(h:sub(6, 7), 16) }
end
function M.smooth(t)
  return t * t * (3 - 2 * t)
end

-- Deterministic hash -> [0, 1).
function M.hash(x, y, s)
  local n = sin(x * 127.1 + y * 311.7 + (s or 0) * 74.7) * 43758.5453
  return n - floor(n)
end

-- 1D value noise and its fractal sum.
function M.noise1(x, s)
  local i = floor(x)
  local f = x - i
  local t = M.smooth(f)
  return M.hash(i, 0, s) * (1 - t) + M.hash(i + 1, 0, s) * t
end
function M.fbm(x, s, oct)
  local v, a, fr = 0, 0.5, 1
  for o = 1, oct do
    v = v + a * M.noise1(x * fr, s + o * 13)
    a = a * 0.5
    fr = fr * 2.03
  end
  return v
end

-- Vertical gradient through a list of {stop, color} pairs, t in [0, 1].
function M.gradient(stops, t)
  for i = 2, #stops do
    if t <= stops[i][1] then
      local a, b = stops[i - 1], stops[i]
      return M.mix(a[2], b[2], (t - a[1]) / (b[1] - a[1]))
    end
  end
  return stops[#stops][2]
end

-- Blend a sparse, tinted star field into c. `fade` (0..1) scales the density.
function M.stars(c, x, y, seed, density, fade)
  if M.hash(x, y, seed + 11) < density * fade then
    local b = 0.45 + 0.55 * M.hash(x, y, seed + 17)
    local tint = M.hash(x, y, seed + 19)
    local star = tint < 0.2 and { 255, 236, 200 } or (tint < 0.45 and { 200, 220, 255 } or { 255, 255, 255 })
    return M.mix(c, star, b)
  end
  return c
end

-- Crescent moon with a soft glow. Returns the color and whether (x, y) is on the moon.
function M.moon(c, x, y, mx, my, R, seed, glow_color)
  local dx, dy = x - mx, y - my
  local d = sqrt(dx * dx + dy * dy)
  c = M.mix(c, glow_color, exp(-max(0, d - R) / (R * 1.6)) * 0.5)
  if d <= R then
    local dx2, dy2 = x - (mx + R * 0.48), y - (my - R * 0.22)
    if sqrt(dx2 * dx2 + dy2 * dy2) >= R * 0.92 then
      local shade = M.clamp((dx + R) / (2 * R), 0, 1)
      local col = M.mix({ 243, 231, 196 }, { 201, 185, 143 }, shade * 0.6)
      if M.hash(floor(x / 2), floor(y / 2), seed + 23) < 0.12 then
        col = M.mix(col, { 201, 185, 143 }, 0.5)
      end
      return col, true
    end
  end
  return c, false
end

-- Distance from the moon center, for keeping stars out of its glow.
function M.dist(x, y, mx, my)
  return sqrt((x - mx) ^ 2 + (y - my) ^ 2)
end

-- Water below `horizon` that mirrors scene(x, y), with ripple lines and a light path at lx.
function M.water(scene, x, y, horizon, PH, PW, seed, water, highlight, light, lx, lw)
  local depth = y - horizon
  local ry = math.max(0, horizon - 1 - depth)
  local ripple = (depth % 2 == 1) and sin(x * 0.45 + depth) * (0.4 + depth * 0.10) or 0
  local sx = M.clamp(x + ripple, 0, PW - 1)
  local c = M.mix(water, scene(sx, ry), 0.62 * (1 - depth / max(1, PH - horizon) * 0.55))
  if depth > 0 and M.hash(floor(x / 6), y, seed + 37) < 0.12 then
    c = M.mix(c, highlight, 0.30)
  end
  if light and lx then
    -- light path: short horizontal glints on alternating rows, widening toward the viewer
    if depth % 2 == 1 then
      local half = lw * (0.5 + depth * 0.12)
      local off = (M.hash(depth, 1, seed + 31) - 0.5) * lw * 0.6 -- each glint shifts a little
      local dx = abs(x - (lx + off))
      if dx <= half then
        c = M.mix(c, light, 0.80 * (1 - dx / (half + 1)) * (1 - depth / max(1, PH - horizon) * 0.4))
      end
    end
  end
  if depth == 0 then
    c = M.mix(c, { 1, 3, 9 }, 0.6)
  end
  return c
end

-- Pine silhouette test: is (x, hgt) inside a pine of height h whose base is at `base`?
function M.pine(xi, hgt, tx, base, h)
  local from_top = (base + h) - hgt
  if from_top < 0 or from_top > h then
    return false
  end
  local half = (from_top == h) and 0 or floor(from_top * 0.55 + 0.25)
  return abs(xi - tx) <= half
end

return M
