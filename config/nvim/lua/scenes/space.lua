-- Deep space: a banded, ringed gas giant lit from one side, a small moon, a nebula wash and a dense starfield.
local U = require("scenes.util")
-- The per-pixel code here is branchy and runs only ~2.5k times; the interpreter beats trace compilation.
if jit then
  jit.off(true, true)
end
local floor, sin, cos, sqrt, abs, max, min, exp =
  math.floor, math.sin, math.cos, math.sqrt, math.abs, math.max, math.min, math.exp
local hex, mix, clamp, hash = U.hex, U.mix, U.clamp, U.hash

-- Planet palettes: band colors (dark to light), atmospheric rim, ring dark/light, night side.
local function pal(bands, rim, ring_dark, ring_light, night)
  local b = {}
  for i, h in ipairs(bands) do
    b[i] = { (i - 1) / (#bands - 1), hex(h) }
  end
  return { bands = b, rim = hex(rim), ring_dark = hex(ring_dark), ring_light = hex(ring_light), night = hex(night) }
end
local PALETTES = {
  pal({ "#6a3f1f", "#b4773f", "#dcae74", "#f3dcb0", "#fff3dc" }, "#ffd59a", "#6b5640", "#eedcb8", "#1c120c"),
  pal({ "#123656", "#2a6e92", "#5fb0c2", "#b9e6e4", "#eafbf6" }, "#9de9ff", "#3b5361", "#d2e8ea", "#08141c"),
  pal({ "#3b1a4a", "#7a3d7c", "#c07aa6", "#efc3d3", "#fff0f4" }, "#ffb0d8", "#574360", "#efd6e0", "#170c1c"),
  pal({ "#4a1816", "#93402c", "#d27a50", "#f2bf92", "#fde6cc" }, "#ffb98a", "#5e4a44", "#ecd8c8", "#1c0c0a"),
}
local NEBULAE = {
  { hex("#7a3cc8"), hex("#2ab3c0") }, -- violet into teal
  { hex("#c23c8c"), hex("#5a48d0") }, -- magenta into indigo
  { hex("#2a8ac8"), hex("#8a3cc0") }, -- blue into purple
}
local TINTS = { { 255, 255, 255 }, { 200, 216, 255 }, { 255, 232, 196 }, { 255, 204, 176 }, { 196, 240, 255 } }

-- 2D value noise and its fractal sum, for the nebula.
local function noise2(x, y, s)
  local ix, iy = floor(x), floor(y)
  local fx, fy = x - ix, y - iy
  fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
  local a, b = hash(ix, iy, s), hash(ix + 1, iy, s)
  local c, d = hash(ix, iy + 1, s), hash(ix + 1, iy + 1, s)
  return (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy
end
local function fbm2(x, y, s)
  return 0.5 * noise2(x, y, s) + 0.3 * noise2(x * 2.1, y * 2.1, s + 7) + 0.2 * noise2(x * 4.3, y * 4.3, s + 13)
end

local function norm(x, y, z)
  local l = sqrt(x * x + y * y + z * z)
  return x / l, y / l, z / l
end

return function(PW, PH, seed)
  local P = PALETTES[1 + floor(hash(3, 1, seed) * #PALETTES)]
  local neb = NEBULAE[1 + floor(hash(3, 2, seed) * #NEBULAE)]
  local side = hash(1, 1, seed) < 0.5 and -1 or 1 -- which side is open sky; the planet sits toward the other

  -- Ring geometry (in planet radii) and orientation: spin axis tipped toward us (asin sin_i), then rolled.
  local r1, r2 = 1.28 + 0.1 * hash(4, 1, seed), 2.05 + 0.25 * hash(4, 2, seed)
  local sin_i = 0.30 + 0.16 * hash(4, 3, seed)
  local cos_i = sqrt(1 - sin_i * sin_i)
  local roll = (hash(4, 4, seed) - 0.5) * 0.6
  local nx, ny, nz = cos_i * sin(roll), -cos_i * cos(roll), sin_i
  local gap = 0.55 + 0.15 * hash(4, 5, seed) -- Cassini-like gap position across the ring

  -- Planet size and position: fit the planet vertically and the rings horizontally.
  local R = min(PH * (0.27 + 0.04 * hash(5, 1, seed)), PW * 0.5 / (r2 + 0.35), PH * 0.5 - 1.5)
  -- Projected half-extents (in radii) of the outer ring ellipse and the planet with its halo.
  local ex = max(1.1, r2 * sqrt(1 - nx * nx))
  local ey = max(1.1, r2 * sqrt(1 - ny * ny))
  R = min(R, (PW * 0.5 - 2) / ex, (PH * 0.5 - 1) / ey)
  R = max(R, 5)
  -- Shift the planet toward one side, but keep the whole ring system inside the frame.
  local cx = PW * 0.5 - side * PW * (0.10 + 0.04 * hash(5, 2, seed))
  cx = clamp(cx, ex * R + 2, PW - ex * R - 2)
  local cy = PH * (0.5 + 0.06 * (hash(5, 3, seed) - 0.5))
  cy = clamp(cy, ey * R + 1, PH - ey * R - 1)
  local ext = r2 * R + 1.5 -- radius of the planet-and-ring bounding circle

  -- Light from the open side, slightly above, and some from the front so the lit face reads well.
  local lx, ly, lz =
    norm(side * (0.75 + 0.2 * hash(6, 1, seed)), -0.45 - 0.2 * hash(6, 2, seed), 0.3 + 0.25 * hash(6, 3, seed))
  local ln = lx * nx + ly * ny + lz * nz
  local band_phase = hash(6, 4, seed) * 10
  local band_freq = 2.6 + 1.4 * hash(6, 5, seed)

  local ring_freq = clamp(R * 1.1, 5, 13) -- fewer ringlets when small, so they don't alias into noise
  local band_oct = R < 8 and 2 or 3
  local ring_shadow = R < 8 and 0.3 or 0.6
  local function ring_density(rr)
    local s = (rr - r1) / (r2 - r1)
    if s <= 0 or s >= 1 then
      return 0
    end
    local d = 0.55 + 0.45 * U.noise1(s * ring_freq, seed + 51)
    d = d * (0.45 + 0.55 * clamp(s / 0.25, 0, 1)) -- faint inner ring
    d = d * clamp(abs(s - gap) / 0.05 - 0.2, 0.08, 1) -- the gap
    return d * clamp((1 - s) / 0.08, 0, 1) * clamp(s / 0.04, 0, 1)
  end
  local function ring_color(rr, x, y, z)
    local d = ring_density(rr)
    if d <= 0 then
      return nil, 0
    end
    local c = mix(P.ring_dark, P.ring_light, clamp(d * 1.1, 0, 1))
    -- planet shadow: does the ray from this ring point toward the light hit the planet?
    local pl = x * lx + y * ly + z * lz
    if pl < 0 and x * x + y * y + z * z - pl * pl < 1 then
      c = mix(c, { 0, 0, 0 }, 0.85)
    end
    return c, min(1, d * 1.15)
  end

  -- One sample of the planet system at offset (x, y) in planet radii. Returns color, alpha.
  local function sample(x, y)
    local d2 = x * x + y * y
    local rz = -(x * nx + y * ny) / nz -- depth of the ring plane under this pixel
    local rr = sqrt(d2 + rz * rz)
    local rc, ra = nil, 0
    if rr > r1 and rr < r2 then
      rc, ra = ring_color(rr, x, y, rz)
    end
    if d2 >= 1 then
      -- a thin atmospheric halo just outside the lit limb
      local d = sqrt(d2)
      local h = 1 - (d - 1) * R / 1.1
      if h > 0 then
        h = h * clamp(((x * lx + y * ly) / d) * 1.6 + 0.2, 0, 1) * 0.55
        if ra > 0 then
          return mix(rc, P.rim, h), max(ra, h)
        end
        return P.rim, h
      end
      return rc, ra
    end
    local z = sqrt(1 - d2)
    if ra > 0 and rz <= z then
      ra = 0 -- the planet hides the ring behind it
    end
    -- banded atmosphere: latitude along the spin axis, with a little turbulence
    local lat = x * nx + y * ny + z * nz
    local u = x * ny - y * nx
    local t = lat * band_freq + 0.06 * sin(u * 7 + lat * 23 + band_phase)
    local b = U.fbm(t + band_phase, seed + 61, band_oct)
    b = clamp((b - 0.25) * 1.8 + 0.12 * sin(t * 9.4), 0, 1)
    local col = U.gradient(P.bands, 0.3 + 0.7 * b)
    col = mix(col, P.bands[2][2], abs(lat) ^ 3 * 0.6) -- darker polar haze
    -- lighting: soft terminator, limb darkening, ring shadow across the disk
    local lam = x * lx + y * ly + z * lz
    local lit = U.smooth(clamp(lam * 1.8 + 0.18, 0, 1))
    lit = lit * (0.6 + 0.4 * z)
    if ln ~= 0 then
      local tt = -lat / ln
      if tt > 0 then
        local qx, qy, qz = x + tt * lx, y + tt * ly, z + tt * lz
        lit = lit * (1 - ring_shadow * ring_density(sqrt(qx * qx + qy * qy + qz * qz)))
      end
    end
    col = mix(P.night, col, lit)
    -- thin bright atmospheric rim on the lit limb
    local limb = clamp(1 - (1 - sqrt(d2)) * R / 1.3, 0, 1)
    local rim = limb * clamp(lam * 2 + 0.6, 0, 1)
    col = mix(col, P.rim, rim * 0.75)
    if ra > 0 then
      col = mix(col, rc, ra * 0.9)
    end
    return col, 1
  end

  -- Moon: on the open side, away from the ring tip.
  local tip_y = r2 * R * sin(roll) * side
  local mr = max(2.2, R * 0.28)
  local moon_col = mix({ 232, 226, 214 }, { 206, 220, 238 }, hash(7, 3, seed))
  local ring_edge = cx + side * r2 * R * cos(roll)
  local far = side > 0 and PW or 0
  local mx = ring_edge + (far - ring_edge) * (0.45 + 0.2 * hash(7, 1, seed))
  local my = cy + (tip_y > 0 and -1 or 1) * PH * (0.18 + 0.12 * hash(7, 2, seed))
  my = clamp(my, mr + 1, PH - mr - 2)
  mx = clamp(mx, mr + 1, PW - mr - 2)

  -- Nebula: a soft elongated cloud on the open side.
  local ncx = PW * (0.5 + side * (0.25 + 0.15 * hash(8, 1, seed)))
  local ncy = PH * (0.2 + 0.6 * hash(8, 2, seed))
  local nang = (hash(8, 3, seed) - 0.5) * 1.6
  local nca, nsa = cos(nang), sin(nang)
  local nrx, nry = PW * 0.32, PH * 0.32
  local function nebula(x, y)
    local dx, dy = x - ncx, y - ncy
    local u, v = (dx * nca + dy * nsa) / nrx, (-dx * nsa + dy * nca) / nry
    local fall = exp(-(u * u + v * v) * 1.4)
    if fall < 0.02 then
      return nil, 0
    end
    local n = fbm2(x / PH * 3, y / PH * 3, seed + 71)
    local a = clamp((n - 0.35) * 2.2, 0, 1) * fall
    local hue = noise2(x / PH * 1.6 + 5, y / PH * 1.6, seed + 73)
    return mix(neb[1], neb[2], hue), a * 0.6
  end

  -- A few bright stars with tiny cross glints, kept clear of the planet and moon.
  local glints = {}
  local ng = 2 + floor(PW / 24)
  for i = 1, ng * 6 do
    if #glints >= ng then
      break
    end
    local gx = 1 + floor(hash(i, 9, seed) * (PW - 2))
    local gy = 1 + floor(hash(i, 10, seed) * (PH - 2))
    local ok = U.dist(gx, gy, cx, cy) > ext + 1 and U.dist(gx, gy, mx, my) > mr + 6
    for _, g in ipairs(glints) do
      ok = ok and U.dist(gx, gy, g.x, g.y) > PW * 0.15
    end
    if ok then
      glints[#glints + 1] = { x = gx, y = gy, big = hash(i, 11, seed) < 0.5 and PH >= 24, tint = TINTS[1 + i % #TINTS] }
    end
  end

  local function background(x, y)
    local c = { 0, 0, 0 }
    local nc, na = nebula(x, y)
    if na > 0 then
      c = mix(c, nc, na)
    end
    -- starfield: mostly faint, a few brighter; denser inside the nebula
    local md = U.dist(x, y, mx, my)
    if md > mr + 1.5 and hash(x, y, seed + 11) < 0.038 + na * 0.1 then
      local b = hash(x, y, seed + 17) ^ 2.2
      local tint = TINTS[1 + floor(hash(x, y, seed + 19) * #TINTS)]
      c = mix(c, tint, 0.14 + 0.66 * b)
    end
    for _, g in ipairs(glints) do
      local dx, dy = abs(x - g.x), abs(y - g.y)
      if dx + dy == 0 then
        return mix(g.tint, { 255, 255, 255 }, 0.6)
      elseif (dx == 0 or dy == 0) and dx + dy <= (g.big and 2 or 1) then
        c = mix(c, g.tint, (dx + dy == 1) and 0.5 or 0.2)
      end
    end
    return c
  end

  -- Moon: a small sphere lit from the same direction, with a couple of craters.
  local function moon(c, x, y)
    local dx, dy = (x - mx) / mr, (y - my) / mr
    local d2 = dx * dx + dy * dy
    if d2 > 1.15 then
      return c
    end
    local cov = clamp((1.08 - sqrt(d2)) * mr, 0, 1)
    local z = sqrt(max(0, 1 - d2))
    local lam = dx * lx + dy * ly + z * lz
    local lit = U.smooth(clamp(lam * 2 + 0.15, 0, 1))
    local col = mix({ 8, 8, 12 }, moon_col, lit)
    if mr >= 3 then -- soft maria, only when the moon is big enough to show them
      col = mix(col, { 0, 0, 0 }, 0.3 * lit * clamp(noise2(dx * 1.4 + 3, dy * 1.4, seed + 81) * 2 - 0.9, 0, 1))
    end
    return mix(c, col, cov)
  end

  -- Cheap region code (empty, planet, ring, ring over planet, halo) to find pixels that need supersampling.
  local halo2 = (1 + 1.1 / R) ^ 2
  local function region(x, y)
    local d2 = x * x + y * y
    local rz = -(x * nx + y * ny) / nz
    local rr = sqrt(d2 + rz * rz)
    local ring = rr > r1 and rr < r2
    if d2 < 1 then
      return (ring and rz > sqrt(1 - d2)) and 3 or 1
    end
    return ring and 2 or (d2 < halo2 and 4 or 0)
  end

  local OFF = { { -0.5, -0.5 }, { 0.5, -0.5 }, { -0.5, 0.5 }, { 0.5, 0.5 } }
  local SUB = { { -0.25, -0.25 }, { 0.25, -0.25 }, { -0.25, 0.25 }, { 0.25, 0.25 } }
  return function(px, py)
    local fx, fy = px - cx, py - cy
    if fx * fx + fy * fy > ext * ext then
      return moon(background(px, py), px, py)
    end
    -- 2x2 supersampling only where the pixel straddles an edge of the planet or rings
    local k = region((fx + OFF[1][1]) / R, (fy + OFF[1][2]) / R)
    local uniform = k == 0 or k == 1 -- ringlets and the halo always get supersampled
    for i = 2, 4 do
      uniform = uniform and region((fx + OFF[i][1]) / R, (fy + OFF[i][2]) / R) == k
    end
    local r, g, b, a = 0, 0, 0, 0
    if uniform then
      if k == 0 then
        return moon(background(px, py), px, py)
      end
      local sc, sa = sample(fx / R, fy / R)
      if sa >= 1 then
        return sc
      end
      r, g, b, a = sc[1] * sa, sc[2] * sa, sc[3] * sa, sa
    else
      for i = 1, 4 do
        local sc, sa = sample((fx + SUB[i][1]) / R, (fy + SUB[i][2]) / R)
        if sa > 0 then
          r, g, b, a = r + sc[1] * sa / 4, g + sc[2] * sa / 4, b + sc[3] * sa / 4, a + sa / 4
        end
      end
    end
    local c = moon(background(px, py), px, py)
    local inv = 1 - a
    return { c[1] * inv + r, c[2] * inv + g, c[3] * inv + b }
  end
end
