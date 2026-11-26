-- Northern lights: rayed green-to-purple aurora curtains over a distant range, a pine forest and snow drifts.
local U = require("scenes.util")
local floor, sin, abs, max, min, exp, sqrt = math.floor, math.sin, math.abs, math.max, math.min, math.exp, math.sqrt
local hex, mix, clamp, hash, noise = U.hex, U.mix, U.clamp, U.hash, U.noise1

local C = {
  sky = { { 0, hex("#000000") }, { 0.55, hex("#020716") }, { 1, hex("#081a2c") } },
  -- aurora color by height above the curtain's lower edge
  aur = {
    { 0, hex("#c8ffe4") },
    { 0.12, hex("#3dff9a") },
    { 0.45, hex("#22d6a6") },
    { 0.72, hex("#7d5cff") },
    { 1, hex("#b24fe0") },
  },
  range = hex("#111c3e"),
  range_dark = hex("#0b1330"),
  range_cap = hex("#4a6196"),
  range_cap_dark = hex("#27375f"),
  forest = hex("#030b12"),
  forest_snow = hex("#16243c"),
  near = hex("#010407"),
  near_snow = hex("#4c6290"),
  snow_lit = hex("#5f75a8"),
  snow_mid = hex("#2f3f68"),
  snow_dark = hex("#141d38"),
}

-- Tiered pine: is a pixel `f` rows below the tip and `dx` columns from the trunk inside a pine of height h?
local function pine(dx, f, h)
  if f < 0 or f > h then
    return false
  end
  if h >= 5 and f == h then
    return dx == 0 -- trunk
  end
  if h < 5 then
    return dx <= floor(f * 0.5 + 0.25)
  end
  local half = floor(f * 0.36 + 0.2) + ((f >= 2 and f % 2 == 0) and 1 or 0)
  return dx <= half
end

return function(PW, PH, seed)
  local ground = floor(PH * 0.72)
  local sky_h = ground
  local snow_h = PH - ground
  local sc = math.pow(76 / PW, 0.4) -- small screens show a bit more of the curtain, not a blown-up slice
  -- with few rows, rays get more contrast and the curtain more brightness so it still reads
  local small = clamp((24 - sky_h) / 13, 0, 1)
  local rc, fe, gain = 2 + 0.8 * small, 1.4 - 0.5 * small, 1 + 0.4 * small

  -- Aurora curtains: a wavy lower edge with vertical rays of varying height rising from it.
  local curtains = {
    { y = 0.60 + 0.06 * (hash(2, 1, seed) - 0.5), amp = 0.12 * sc, freq = 0.085, top = 0.46, b = 1.0, s = seed },
    { y = 0.40 + 0.06 * (hash(3, 1, seed) - 0.5), amp = 0.07 * sc, freq = 0.13, top = 0.30, b = 0.55, s = seed + 9 },
  }
  if sky_h < 16 then
    -- too few rows for two curtains: one taller curtain reads better
    curtains[2] = nil
    curtains[1].top, curtains[1].y = 0.62, curtains[1].y + 0.04
  end
  for _, c in ipairs(curtains) do
    c.phase = hash(4, 1, c.s) * 6.28
  end
  local function aurora(x, y)
    local total, hue, haze = 0, 0, 0
    for _, c in ipairs(curtains) do
      local u = x * sc
      local edge = sky_h * (c.y + c.amp * sin(u * c.freq + c.phase) + 0.06 * (noise(u * 0.22, c.s) - 0.5))
      local above = edge - y
      haze = haze + c.b * exp(-abs(above + sky_h * 0.08) / (sky_h * 0.18))
      local ray = 0.5 * noise(u * 0.32, c.s + 3) + 0.5 * noise(u * 0.85, c.s + 5)
      local top = sky_h * c.top * (0.45 + 0.9 * noise(u * 0.3, c.s + 7))
      local v = 0
      if above >= 0 and above < top then
        local t = above / top
        v = (1 - t) ^ fe * (0.2 + 1.1 * ray ^ rc) * gain
        if above < 1 then
          v = v + 0.3 * ray -- bright lower hem
        end
        hue = max(hue, t)
      elseif above < 0 and above > -1.5 then
        v = 0.3 * (1 + above / 1.5) * ray
      end
      total = total + v * c.b
    end
    return min(1, total), hue, min(1, haze)
  end
  local function aurora_col(a, hue, haze, base)
    local c = mix(base, C.aur[3][2], haze * 0.10)
    return mix(c, U.gradient(C.aur, hue), a * 0.92)
  end

  -- Per-column aurora light, used to tint snow caps and the snowfield.
  local glow = {}
  for x = 0, PW - 1 do
    local r, g, b, n = 0, 0, 0, 0
    for y = 0, sky_h - 1 do
      local a, hue = aurora(x, y)
      local col = U.gradient(C.aur, hue)
      r, g, b, n = r + col[1] * a, g + col[2] * a, b + col[3] * a, n + a
    end
    local k = min(1, n / (sky_h * 0.25))
    glow[x] = n > 0 and { r / n, g / n, b / n, k } or { 0, 0, 0, 0 }
  end
  local function lit(c, x, amt)
    local gl = glow[clamp(x, 0, PW - 1)]
    return mix(c, gl, gl[4] * amt)
  end

  -- Distant range: a few broad, low peaks.
  local peaks, np = {}, 2 + floor(PW / 28)
  for i = 1, np do
    peaks[i] = {
      x = PW * ((i - 1 + 0.2 + 0.6 * hash(i, 2, seed)) / np),
      h = sky_h * (0.24 + 0.14 * hash(i, 3, seed)),
      sl = 0.45 + 0.25 * hash(i, 4, seed),
    }
  end
  local range, face = {}, {}
  for x = 0, PW - 1 do
    local best, f = sky_h * 0.08, 0
    for _, p in ipairs(peaks) do
      local h = p.h - abs(x - p.x) * p.sl
      if h > best then
        best, f = h, (x < p.x) and 1 or -1
      end
    end
    range[x] = best + 0.8 * (noise(x * 0.5, seed + 21) - 0.5)
    face[x] = f
  end

  -- Pixel layers: 0 sky, 1 range, 2 forest, 3 near pine.
  local layer = {}
  for i = 0, PW * PH - 1 do
    layer[i] = 0
  end
  local function plant(tx, base, h, id)
    for f = 0, h do
      local py = base - h + f
      if py >= 0 and py < PH then
        for dx = -h, h do
          local xx = tx + dx
          if xx >= 0 and xx < PW and pine(abs(dx), f, h) and layer[py * PW + xx] < id then
            layer[py * PW + xx] = id
          end
        end
      end
    end
  end
  for x = 0, PW - 1 do
    for py = 0, ground - 1 do
      if ground - py <= range[x] then
        layer[py * PW + x] = 1
      end
    end
  end
  -- Mid forest on a low rolling hill; trees vary in height in clumps.
  local hill = {}
  for x = 0, PW - 1 do
    hill[x] = floor(sky_h * (0.02 + 0.06 * U.fbm(x * 0.06, seed + 30, 2)))
    for py = ground - hill[x], ground - 1 do
      layer[py * PW + x] = 2
    end
  end
  local x = 0
  while x < PW do
    local clump = noise(x * 0.12, seed + 31)
    if hash(x, 3, seed) < 0.55 + 0.4 * clump then
      local h = floor(sky_h * (0.05 + 0.14 * clump + 0.06 * hash(x, 5, seed)) + 0.5)
      plant(x, ground - 1 - hill[x] + 1, max(2, h), 2)
    end
    x = x + 1 + floor(hash(x, 7, seed) * 2.5)
  end
  -- A few big foreground pines standing in the snow, framing the scene from the sides.
  local side = hash(5, 1, seed) < 0.5
  for i = 0, 2 + floor(PW / 30) do
    local left = (i % 2 == 0) == side
    local k = floor(i / 2)
    local off = floor(PW * (0.02 + 0.07 * k + 0.04 * hash(i, 9, seed)))
    local tx = left and off or PW - 1 - off
    local base = ground + floor(snow_h * (0.45 + 0.35 * hash(i, 10, seed)) - k)
    local h = floor(sky_h * (0.50 - 0.12 * k + 0.12 * hash(i, 11, seed))) + (base - ground)
    plant(tx, base, h, 3)
  end

  -- Snow drifts: wavy crest lines, nearer ones lower and further apart.
  local drifts = {}
  local nd = max(2, floor(snow_h / 2.5))
  for k = 1, nd do
    local d = (k - 1) / nd
    drifts[k] =
      { d = d * d * 0.35 + d * 0.65, amp = 1.2 + 2.0 * d, f = 0.06 + 0.05 * hash(k, 12, seed), s = seed + 40 + k }
  end
  local function crest(dr, px)
    return ground + dr.d * snow_h + dr.amp * (noise(px * dr.f, dr.s) - 0.5) * 2
  end

  return function(px, py)
    local xi = clamp(floor(px + 0.5), 0, PW - 1)
    local id = layer[py * PW + xi]
    local above = py > 0 and layer[(py - 1) * PW + xi] or 0
    if id == 3 then
      -- snow resting on the top of each bough
      -- snow resting on the bough tips
      local l = xi > 0 and layer[py * PW + xi - 1] or 0
      local r = xi < PW - 1 and layer[py * PW + xi + 1] or 0
      if sky_h >= 16 and above ~= 3 and (l ~= 3 or r ~= 3) and py < PH - 1 and layer[(py + 1) * PW + xi] == 3 then
        return lit(C.near_snow, xi, 0.35)
      end
      return C.near
    end
    if py >= ground then
      local dist, dep, dr = 99, 0, nil
      for k = nd, 1, -1 do
        local c = crest(drifts[k], px)
        if py >= floor(c) then
          dist, dep, dr = py - floor(c), drifts[k].d, drifts[k]
          break
        end
      end
      if dist == 99 then
        dist = py - ground
      end
      local l = exp(-dist / (1.0 + dep * 2.0))
      if dr then
        -- slopes facing the aurora catch more light; lee slopes fall into shadow
        local slope = crest(dr, px + 1) - crest(dr, px - 1)
        l = clamp(l * (1 - slope * 0.35), 0, 1)
      end
      local c = l > 0.5 and mix(C.snow_mid, C.snow_lit, (l - 0.5) * 2) or mix(C.snow_dark, C.snow_mid, l * 2)
      local depth = (py - ground) / max(1, snow_h)
      c = mix(c, C.snow_dark, depth * (0.25 + 0.25 * small))
      -- the aurora's glow on the snow, strongest on crests and toward the horizon
      return lit(c, xi, (0.22 + 0.4 * l) * (1 - depth * 0.6) * (1 - 0.35 * small))
    end
    if id == 2 then
      if above < 2 and hash(xi, py, seed + 51) < 0.35 then
        return lit(C.forest_snow, xi, 0.15)
      end
      return C.forest
    end
    if id == 1 then
      local hgt = ground - py
      local cap = range[xi] - hgt < 1 + 0.2 * range[xi]
      local dark = face[xi] < 0
      if cap then
        return lit(dark and C.range_cap_dark or C.range_cap, xi, 0.4)
      end
      local c = dark and C.range_dark or C.range
      c = mix(c, C.forest, clamp(1 - hgt / max(1, range[xi]), 0, 1) * 0.5)
      return lit(c, xi, 0.12)
    end
    local base = U.gradient(C.sky, py / sky_h)
    local a, hue, haze = aurora(px, py)
    base = U.stars(base, px, py, seed, 0.05 * clamp(1 - py / (sky_h * 0.7), 0, 1), clamp(1 - a * 2 - haze * 1.5, 0, 1))
    return aurora_col(a, hue, haze, base)
  end
end
