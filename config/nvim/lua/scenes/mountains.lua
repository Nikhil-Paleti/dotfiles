-- Moonlit mountain lake: snowy peaks, a misty mid range, pine forests on the shore, and a reflecting lake.
local U = require("scenes.util")
local floor, abs, max, min, exp = math.floor, math.abs, math.max, math.min, math.exp
local hex, mix, clamp, hash = U.hex, U.mix, U.clamp, U.hash

local C = {
  sky = { { 0, hex("#000000") }, { 0.55, hex("#050a1c") }, { 1, hex("#13224a") } },
  glow = hex("#3a4a78"),
  far = hex("#5470a8"),
  far_dark = hex("#344a7e"),
  snow = hex("#e6edf9"),
  snow_shade = hex("#9fb2d6"),
  mid = hex("#20316a"),
  mid_dark = hex("#17234c"),
  mid_rim = hex("#5a74ae"),
  mist = hex("#4a5f94"),
  near = hex("#070c1c"),
  tree = hex("#01030a"),
  tree_back = hex("#0f1a3a"),
  water = hex("#060d22"),
  ripple = hex("#1c2b57"),
  sky_low = hex("#13224a"),
  moonlight = { 243, 231, 196 },
}

-- Conifer silhouette: is the pixel `f` rows below the tip, `dx` columns from the trunk, inside a pine of height h?
local function conifer(dx, f, h)
  if f < 0 or f > h then
    return false
  end
  if h >= 5 and f == h then
    return dx == 0 -- trunk
  end
  if h < 5 then
    return dx <= floor(f * 0.5 + 0.25)
  end
  -- tiered boughs: each tier flares out a little wider than the one above
  local half = floor(f * 0.34 + 0.2) + ((f >= 2 and f % 2 == 0) and 1 or 0)
  return dx <= half
end

return function(PW, PH, seed)
  local horizon = floor(PH * 0.66)
  local sky_h = horizon
  local mx = PW * (0.68 + 0.2 * hash(1, 1, seed))
  local R = max(2.7, sky_h * 0.15)
  local my = max(R + 1, sky_h * 0.22) -- never clipped by the top edge
  mx = floor(min(mx, PW - R - 1.5) + 0.5) -- whole-pixel center gives the cleanest crescent

  -- Peaks at jittered positions; heights vary per seed. Short screens get steeper slopes so peaks stay distinct.
  local steep = 1 + max(0, 18 - sky_h) * 0.07
  local function peaks(n, hmin, hmax, slope, s)
    local list = {}
    for i = 1, n do
      list[i] = {
        x = PW * ((i - 1 + 0.25 + 0.5 * hash(i, 2, s)) / n),
        h = sky_h * (hmin + (hmax - hmin) * hash(i, 3, s)),
        slope = sky_h * slope * steep * (0.85 + 0.3 * hash(i, 4, s)),
      }
    end
    return list
  end
  local function range(list, rough, s, base)
    local h, owner = {}, {}
    for x = 0, PW - 1 do
      -- a low rolling floor so the range never drops out at the screen edges
      local best, bi = sky_h * base * (0.8 + 0.4 * U.noise1(x * 0.15, s + 50)), 0
      for i, p in ipairs(list) do
        local v = p.h - abs(x - p.x) * p.slope + (U.noise1(x * 0.55, s + i) - 0.5) * rough
        if v > best then
          best, bi = v, i
        end
      end
      -- keep the moon clear: the range dips into a soft V beneath it
      best = min(best, horizon - (my + R + 1) + max(0, abs(x - mx) - R - 0.5) * 0.9)
      h[x], owner[x] = best, bi
    end
    return h, owner
  end
  local far_peaks = peaks(max(3, floor(PW / 15)), 0.55, 0.85, 0.032, seed)
  local mid_peaks = peaks(max(3, floor(PW / 12)), 0.34, 0.54, 0.036, seed + 5)
  local far_h, far_owner = range(far_peaks, sky_h * 0.06, seed, 0.34)
  local mid_h, mid_owner = range(mid_peaks, sky_h * 0.05, seed + 5, 0.20)
  local near_h, wisp, fog_y = {}, {}, {}
  for x = 0, PW - 1 do
    near_h[x] = floor(sky_h * (0.03 + 0.05 * U.fbm(x / PW * 7 + 4.2, seed + 7, 3)) + 0.5)
    wisp[x] = 0.5 + 0.9 * U.fbm(x * 0.11, seed + 41, 2) -- uneven fog density
    fog_y[x] = sky_h * (0.22 + 0.10 * U.fbm(x * 0.05, seed + 43, 2))
  end

  -- Pine forests: dense stands at both edges thinning to a few saplings mid-shore.
  -- forest[hgt][x] is 1 for a front pine, 2 for a hazier one behind it (hgt = rows above the horizon).
  local forest = {}
  local tmax = max(3, floor(sky_h * 0.50))
  for hh = 0, sky_h do
    forest[hh] = {}
  end
  local x = -1
  while x < PW + 1 do
    local u = clamp(x / PW, 0, 1)
    local edge = clamp(1 - min(u, 1 - u) / 0.30, 0, 1)
    if edge > 0.1 and hash(x, 3, seed) < 0.05 + 0.95 * edge then
      local h = sky_h * (0.16 + 0.36 * edge * edge) * (0.65 + 0.35 * hash(x, 5, seed))
      local cx0 = clamp(x, 0, PW - 1)
      local base = near_h[cx0]
      local back = hash(x, 11, seed) < 0.6 - 0.4 * edge and h > 3 -- the outermost pines stand in front
      -- keep the tip in front of the mountains, not up against the black sky where it would vanish
      h = min(floor(h + 0.5), floor(far_h[cx0] + (sky_h >= 18 and 1 or 0)) - base, tmax)
      for dx = -h, h do
        local cx = x + dx
        if cx >= 0 and cx < PW then
          for f = 0, h do
            if h >= 3 and conifer(abs(dx), f, h) then
              local row = forest[base + h - f]
              row[cx] = back and (row[cx] or 2) or 1
            end
          end
        end
      end
      x = x + max(2, floor(h * 0.45)) + floor(hash(x, 9, seed) * (2 + 3 * (1 - edge)))
    else
      x = x + 2 + floor(hash(x, 7, seed) * 3)
    end
  end

  local sx0, sy0 = PW * (0.1 + 0.25 * hash(2, 2, seed)), sky_h * 0.10
  local slen = max(4, PW * 0.09)

  local function sky(x, y)
    local c = U.gradient(C.sky, y / sky_h)
    local d = U.dist(x, y, mx, my)
    c = U.stars(c, x, y, seed, 0.05 * (1 - y / sky_h) ^ 1.2, clamp((d - R * 2.2) / R, 0, 1))
    local along = x - sx0
    if along >= 0 and along <= slen and abs((y - sy0) - along * 0.32) < 0.55 then
      c = mix(c, { 255, 255, 255 }, 1 - along / slen * 0.85)
    end
    return (U.moon(c, x, y, mx, my, R, seed, C.glow))
  end

  -- Valley fog: a soft band at a wavering altitude that the mid ridges poke through,
  -- plus a thin haze on the shore so the pines stand out against it.
  local fog_w = max(1.1, sky_h * 0.08)
  local function mist(c, x, hgt, amount)
    local d = (hgt - fog_y[x]) / fog_w
    local a = exp(-d * d) * amount * wisp[x] + exp(-max(0, hgt - near_h[x] - 1) / (fog_w * 2.4)) * 0.55
    return mix(c, C.mist, min(a, 0.75))
  end

  local function pixel(x, y)
    local hgt = horizon - y
    local t = forest[hgt] and forest[hgt][x]
    if t then
      return t == 2 and C.tree_back or C.tree
    end
    if hgt <= near_h[x] then
      return C.near
    end
    if hgt <= mid_h[x] then
      local p = mid_peaks[mid_owner[x]]
      local lit = (p and x >= p.x) or (not p and mid_h[min(x + 1, PW - 1)] <= mid_h[x])
      local c = lit and C.mid or C.mid_dark
      if lit and hgt > mid_h[x] - 1 then
        c = C.mid_rim -- moonlit ridge line
      end
      return mist(c, x, hgt, 0.25)
    end
    if hgt <= far_h[x] then
      local p = far_peaks[far_owner[x]]
      local lit = (p and x >= p.x) or (not p and far_h[min(x + 1, PW - 1)] <= far_h[x])
      local c = lit and C.far or C.far_dark
      if p then
        local cap = p.h * 0.28 + (hash(x, 1, seed + 29) - 0.5) * sky_h * 0.08
        if hgt > p.h - cap then
          c = lit and C.snow or C.snow_shade
        end
      end
      c = mix(c, C.sky_low, clamp(1 - hgt / max(far_h[x], 1), 0, 1) * 0.12)
      return mist(c, x, hgt, 0.55)
    end
    return sky(x, y)
  end

  -- Everything above the horizon is drawn once; the lake samples this buffer for its reflection.
  local buf = {}
  for y = 0, horizon - 1 do
    local row = {}
    for xx = 0, PW - 1 do
      row[xx] = pixel(xx, y)
    end
    buf[y] = row
  end
  -- The reflection samples a softened copy: blurred sideways and dimmed, so it reads as water, not a mirror.
  local rbuf = {}
  for y = 0, horizon - 1 do
    local row, src = {}, buf[y]
    for xx = 0, PW - 1 do
      local a, b, c = src[max(xx - 1, 0)], src[xx], src[min(xx + 1, PW - 1)]
      local k = 0.85 / 4
      row[xx] = { (a[1] + 2 * b[1] + c[1]) * k, (a[2] + 2 * b[2] + c[2]) * k, (a[3] + 2 * b[3] + c[3]) * k }
    end
    rbuf[y] = row
  end
  local function scene(sx, sy)
    return rbuf[clamp(floor(sy), 0, horizon - 1)][clamp(floor(sx + 0.5), 0, PW - 1)]
  end

  return function(px, py)
    if py < horizon then
      return buf[py][px]
    end
    return U.water(scene, px, py, horizon, PH, PW, seed, C.water, C.ripple, C.moonlight, mx, R)
  end
end
