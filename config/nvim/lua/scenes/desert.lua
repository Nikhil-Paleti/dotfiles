-- Desert dusk: a striped retro sun over distant mesas, rim-lit dunes, and saguaro cacti.
local U = require("scenes.util")
local floor, sin, abs, max, min, sqrt, exp = math.floor, math.sin, math.abs, math.max, math.min, math.sqrt, math.exp
local hex, mix, clamp, hash = U.hex, U.mix, U.clamp, U.hash

local C = {
  sky = {
    { 0, hex("#04020c") },
    { 0.35, hex("#1a0b30") },
    { 0.68, hex("#561d52") },
    { 0.87, hex("#b03e5c") },
    { 1, hex("#ff7a45") },
  },
  glow = hex("#ff6a4a"),
  sun_top = hex("#ffe48a"),
  sun_bottom = hex("#ff4f6d"),
  mesa = hex("#4a1848"),
  mesa_rim = hex("#d0587a"),
  -- dunes: body (shadowed), lit face, and crest rim per layer
  far = { hex("#6a2456"), hex("#843060"), hex("#ffa070"), rim0 = 0.15 },
  mid = { hex("#330f37"), hex("#5c1e54"), hex("#f06a6e"), rim0 = 0.3 },
  near = { hex("#10040f"), hex("#2c0c30"), hex("#b04462"), rim0 = 0.3 },
  cactus = hex("#08020a"),
  cactus_far = hex("#3a1238"),
}

-- Asymmetric dune profile in [0, 1]: a long windward rise, then a steeper lee drop.
local function dune_shape(p)
  p = p - floor(p)
  if p < 0.68 then
    return U.smooth(p / 0.68)
  end
  return U.smooth((1 - p) / 0.32)
end

return function(PW, PH, seed)
  local small = PH < 24
  local horizon = floor(PH * (small and 0.66 or 0.62))
  local sky_h = horizon
  local sx = floor(PW * (0.36 + 0.28 * hash(1, 1, seed))) + 0.5
  local sR = max(4.2, sky_h * 0.38)
  local sy = horizon - sR * 0.72 -- low over the dunes, about to set

  -- Column heights of each dune layer (y of the top surface).
  local function layer(base, amp, crests, s)
    local raw, h = {}, {}
    local period = PW / crests
    for x = -2, PW + 1 do
      local warp = (U.noise1(x / period * 0.8, s + 3) - 0.5) * 0.3
      local p = x / period + hash(s, 5, seed) + warp
      local v = 0.8 * dune_shape(p) + 0.2 * (0.5 + 0.5 * sin(x / PW * 5 + s))
      raw[x] = base - amp * v
    end
    -- round the crest cusps so they never read as one-pixel spikes
    for x = -1, PW do
      h[x] = 0.25 * raw[x - 1] + 0.5 * raw[x] + 0.25 * raw[x + 1]
    end
    return h
  end
  local far = layer(horizon + 0.5, max(1.2, PH * 0.045), 2.2, seed + 1)
  local mid = layer(horizon + PH * 0.15, max(2, PH * 0.13), 1.4, seed + 2)
  local near = layer(PH - PH * 0.03, max(2.5, PH * (small and 0.26 or 0.2)), 1.0, seed + 3)
  if small then
    mid = near -- too few rows for three ridges: keep just the far band and the near dune
  end

  -- Distant mesas on the horizon, kept clear of the sun.
  local mesa = {}
  for x = 0, PW - 1 do
    mesa[x] = horizon + 1
  end
  local nm = PW >= 56 and 2 or 1
  for i = 1, nm do
    local hw = PW * (0.035 + 0.035 * hash(i, 21, seed))
    local H = max(2, sky_h * (0.26 + 0.1 * hash(i, 23, seed)))
    local steep = 2.2 + hash(i, 24, seed)
    local side = hash(i, 25, seed) < 0.5 and -1 or 1
    local cx
    for try = 0, 6 do
      local c = PW * (0.08 + 0.84 * hash(i, 22 + try, seed))
      if abs(c - sx) > sR * 0.9 + hw * 1.7 + H * 0.3 then
        cx = c
        break
      end
    end
    for x = 0, cx and PW - 1 or -1 do
      local d = abs(x + 0.5 - cx)
      -- flat top with a lower ledge on one side
      local top = H - max(0, d - hw) * steep
      local ledge = (x + 0.5 - cx) * side > 0 and H * 0.55 - max(0, d - hw * 1.7) * steep or 0
      local y = horizon - max(top, ledge)
      if y < mesa[x] then
        mesa[x] = floor(y + 0.5)
      end
    end
  end

  -- Saguaros: a trunk with arms that go out then up, softened at the elbows and tips.
  local k = small and 1 or 2
  local cacti, used = {}, {}
  local n_cacti = PW >= 64 and 3 or 2
  for i = 1, n_cacti do
    local x
    for try = 0, 8 do
      x = floor(PW * ((i - 1 + 0.15 + 0.7 * hash(i, 9 + try, seed)) / n_cacti))
      local ok = x > 2 and x < PW - 3 - k
      for _, u in ipairs(used) do
        ok = ok and abs(u - x) > max(8, PW * 0.28)
      end
      if ok then
        break
      end
    end
    used[#used + 1] = x
    local base = floor(near[x] + 1.5)
    local h = floor(PH * ((small and 0.4 or (PH < 30 and 0.36 or 0.32)) + 0.12 * hash(i, 8, seed)))
    local arms = {}
    local r = hash(i, 7, seed)
    local na = r < 0.15 and 1 or ((r < 0.85 or small) and 2 or 3)
    local side0 = hash(i, 6, seed) < 0.5 and -1 or 1
    for a = 1, na do
      local side = (a % 2 == 1) and side0 or -side0
      local j = (a == 3) and 0.72 or (0.42 + 0.18 * hash(i, 30 + a, seed))
      local up = small and 3 - a or max(2, floor(h * (0.34 + 0.14 * hash(i, 40 + a, seed))))
      local jy = max(3, floor(h * j), small and 0 or up + 1) + (small and a - 1 or 0) -- joint depth below the top
      arms[a] = { side = side, jy = jy, up = min(up, jy - 1), out = 1 }
    end
    cacti[i] = { x = x, base = base, top = base - h, arms = arms }
  end
  -- one small far cactus on the mid dune for depth
  local fx = floor(PW * (0.1 + 0.8 * hash(3, 50, seed)))
  local far_cactus = not small and abs(fx - sx) > sR and { x = fx, top = floor(mid[fx]) - floor(PH * 0.12) }

  -- Coverage (0..1) of a saguaro at (px, py); 0.5 marks soft, rounded corners.
  local function saguaro(c, px, py)
    if py > c.base or py < c.top - 1 then
      return 0
    end
    local x0, x1 = c.x, c.x + k - 1
    if px >= x0 and px <= x1 then
      return py >= c.top and 1 or 0
    end
    for _, a in ipairs(c.arms) do
      local jy = c.top + a.jy
      local ux0 = a.side > 0 and x1 + a.out + 1 or x0 - a.out - k
      local ux1 = ux0 + k - 1
      local hx0 = a.side > 0 and x1 + 1 or ux1 + 1
      local hx1 = a.side > 0 and ux0 - 1 or x0 - 1
      -- horizontal stub
      if px >= hx0 and px <= hx1 and py >= jy - k + 1 and py <= jy then
        return 1
      end
      -- upright, rounded at the elbow and tip
      if px >= ux0 and px <= ux1 and py >= jy - a.up and py <= jy then
        local outer = (a.side > 0 and px == ux1) or (a.side < 0 and px == ux0)
        if k == 2 and outer and py == jy then
          return 0.5
        end
        if k == 2 and py == jy - a.up then
          return 0.55
        end
        return 1
      end
    end
    return 0
  end

  -- Shade a dune layer pixel: rim on the crest, lit faces toward the sun, darker with depth.
  local function dune_px(L, h, px, py)
    local top = h[px]
    local d = py - top
    -- sample the slope a little off-column with depth, so the lit/shadow edge leans like a dune face
    local dir = (px + 0.5 < sx) and 1 or -1
    local xs = clamp(px + dir * floor(d * 0.7), 0, PW - 1)
    local s = h[xs + 1] - h[xs - 1] -- > 0: surface faces right
    local toward = dir * s
    local lit = toward > 0.3 and 1 or 0
    local near_sun = exp(-abs(px + 0.5 - sx) / (PW * 0.22))
    local c = mix(L[1], L[2], lit * (0.25 + 0.75 * near_sun))
    -- darker lower down, so each ridge stands out against the one behind it
    c = mix(c, { 8, 2, 12 }, clamp((d - 1) / (PH * 0.2), 0, 0.6))
    local rim = (L.rim0 + 0.65 * near_sun) * (0.6 + 0.4 * lit)
    if d < 1 then
      c = mix(c, L[3], rim)
    elseif d < 2 then
      c = mix(c, L[3], rim * 0.25)
    end
    return c
  end

  local function sky(px, py)
    local t = clamp(py / sky_h, 0, 1)
    local c = U.gradient(C.sky, t)
    local dx, dy = px + 0.5 - sx, py + 0.5 - sy
    local d = sqrt(dx * dx + dy * dy)
    if d > sR * 1.6 then
      c = U.stars(c, px, py, seed, 0.05 * clamp(1 - py / (sky_h * 0.5), 0, 1), 1)
    end
    c = mix(c, C.glow, exp(-max(0, d - sR) / (sR * 0.6)) * 0.32)
    -- heat haze: faint warm shimmer rows just above the horizon
    local hz = horizon - py
    if hz >= 0 and hz < 3 and (py + floor(px / 5)) % 2 == 0 then
      c = mix(c, C.glow, 0.10 * (3 - hz) / 3 * exp(-abs(dx) / (PW * 0.35)))
    end
    -- sun, with heat-haze wobble on its lowest rows
    local wob = (hz >= 0 and hz < 3) and floor(sin(py * 2.1 + seed) * 1.2 + 0.5) or 0
    dx = px + 0.5 - wob - sx
    d = sqrt(dx * dx + dy * dy)
    if d <= sR then
      local yy = py + 0.5 - (sy - sR)
      local t2 = clamp(yy / (2 * sR), 0, 1)
      -- stripe gaps that widen toward the bottom of the sun
      local period = small and 2 or 3
      local gap = t2 > (small and 0.45 or 0.3) and (floor(yy) % period) < (t2 - 0.3) * (small and 1.6 or 4)
      local col = mix(C.sun_top, C.sun_bottom, U.smooth(t2))
      if gap then
        return mix(c, col, 0.12)
      end
      -- soft antialiased limb
      return mix(c, col, clamp((sR - d) * 1.6 + 0.2, 0, 1))
    end
    return c
  end

  -- Paint everything once into a buffer.
  local img = {}
  for py = 0, PH - 1 do
    local row = {}
    for px = 0, PW - 1 do
      local c
      if py >= near[px] then
        c = dune_px(C.near, near, px, py)
      elseif py >= mid[px] then
        c = dune_px(C.mid, mid, px, py)
      elseif py >= far[px] then
        c = dune_px(C.far, far, px, py)
        c = mix(c, C.glow, 0.12)
      else
        c = sky(px, py)
        if py >= mesa[px] then
          local m = C.mesa
          if py == mesa[px] then
            m = mix(m, C.mesa_rim, 0.4 * exp(-abs(px - sx) / (PW * 0.3)) + 0.12)
          end
          -- haze: mesas fade into the glow near their base
          c = mix(m, c, 0.12 + 0.3 * clamp((py - mesa[px]) / max(1, horizon - mesa[px]), 0, 1))
        end
      end
      if far_cactus and py >= far_cactus.top and py <= mid[px] + 1 then
        local fxc = far_cactus.x
        local ah = far_cactus.top + 2
        if
          px == fxc
          or (px == fxc - 1 and py == ah + 1)
          or (px == fxc - 2 and py >= ah - 1 and py <= ah + 1)
          or (px == fxc + 1 and py == ah)
          or (px == fxc + 2 and py >= ah - 2 and py <= ah)
        then
          if py >= mid[px] - 0.5 or px == fxc or py < mid[px] then
            c = mix(c, C.cactus_far, 0.85)
          end
        end
      end
      for _, cc in ipairs(cacti) do
        local a = saguaro(cc, px, py)
        if a > 0 then
          c = mix(c, C.cactus, a)
        end
      end
      row[px] = c
    end
    img[py] = row
  end

  return function(px, py)
    return img[py][px]
  end
end
