-- Snowy village at night: snow-roofed houses with warm windows, a church steeple, pines, and falling snow.
local U = require("scenes.util")
local floor, sin, abs, max, min, exp = math.floor, math.sin, math.abs, math.max, math.min, math.exp
local hex, mix, clamp, hash = U.hex, U.mix, U.clamp, U.hash

local C = {
  sky = { { 0, hex("#000000") }, { 0.5, hex("#040a1c") }, { 1, hex("#16244c") } },
  glow = hex("#34466e"),
  hill_far = hex("#1c2a50"),
  hill_far_lit = hex("#2a3a68"),
  hill = hex("#3a4c7e"),
  hill_lit = hex("#56699c"),
  ground_top = hex("#8c9dc6"),
  ground_mid = hex("#5a6c9c"),
  ground_low = hex("#1e2a50"),
  ground_deep = hex("#0a1028"),
  drift = hex("#b4c3e2"),
  roof = hex("#e9effa"),
  roof_shade = hex("#9fb0d4"),
  eave = hex("#6a7aa6"),
  walls = { hex("#3c2630"), hex("#2c3048"), hex("#3a2c24"), hex("#32283c") },
  win = hex("#ffd27a"),
  win_edge = hex("#f0a048"),
  win_off = hex("#141a30"),
  door = hex("#1a0f12"),
  brick = hex("#5c3434"),
  pine = hex("#0b1f26"),
  pine_snow = hex("#a6b8da"),
  trunk = hex("#24161a"),
  smoke = hex("#a4b0cc"),
  warm = hex("#ffb45a"),
  flake = hex("#e4ecff"),
  cross = hex("#9c8458"),
  post = hex("#1c1a26"),
}

return function(PW, PH, seed)
  local big = PH >= 24
  local gy = floor(PH * 0.75) -- first row of the village's snowy ground
  local moon_right = hash(1, 1, seed) < 0.5
  local mx = PW * (moon_right and (0.76 + 0.14 * hash(1, 2, seed)) or (0.10 + 0.14 * hash(1, 2, seed)))
  local R = max(2.4, PH * 0.085)
  local my = max(R + 0.2, gy * 0.18)
  local lit_dir = moon_right and 1 or -1 -- roofs are lit on the side facing the moon
  local wind = hash(2, 9, seed) < 0.5 and 1 or -1 -- smoke drift direction

  -- Pixel buffer and per-pixel flags (snow catches window light; windows block snowflakes).
  -- In a dry run, put() only records the highest drawn row per column (used to place the moon).
  local img, snowy, solid = {}, {}, {}
  local dry, sky_top = false, {}
  local function idx(x, y)
    return y * PW + x + 1
  end
  local function put(x, y, c, is_snow)
    if x >= 0 and x < PW and y >= 0 and y < PH then
      if dry then
        if y < (sky_top[x] or PH) then
          sky_top[x] = y
        end
        return
      end
      local i = idx(x, y)
      img[i], snowy[i], solid[i] = c, is_snow or false, true
    end
  end

  -- Ground line of the village (a gentle undulation around gy) and the foreground snowbank crest,
  -- which rolls along and swells into drifts at both corners.
  local ground, bank = {}, {}
  local depth = PH - gy
  for x = 0, PW - 1 do
    ground[x] = gy + floor((U.fbm(x * 0.06, seed + 41, 2) - 0.5) * (big and 3 or 1.6) + 0.5)
    local edge = 1 - U.smooth(clamp(min(x, PW - 1 - x) / max(5, PW * 0.18), 0, 1))
    local b = gy + depth * (0.55 + 0.75 * (U.fbm(x * 0.08 + 3.1, seed + 45, 3) - 0.5)) - depth * 0.62 * edge
    bank[x] = max(ground[x] + (edge > 0.3 and 0 or 1), floor(b + 0.5))
  end

  local function backdrop()
    -- Sky: gradient, stars, moon.
    for y = 0, PH - 1 do
      local base = U.gradient(C.sky, clamp(y / gy, 0, 1))
      for x = 0, PW - 1 do
        local d = U.dist(x, y, mx, my)
        local c = U.stars(base, x, y, seed, 0.035 * clamp(1 - y / (gy * 0.8), 0, 1), clamp((d - R * 2.2) / R, 0, 1))
        img[idx(x, y)] = (U.moon(c, x, y, mx, my, R, seed, C.glow))
      end
    end

    -- Rolling snowy hills behind the village, lit on the slopes facing the moon.
    local function hills(top, amp, freq, s, col, lit)
      local prev, hs = nil, {}
      for x = -1, PW - 1 do
        local h = top - amp * U.fbm(x * freq + s * 0.37, seed + s, 3)
        if x >= 0 then
          hs[x] = h
          local slope = (h - prev) * lit_dir -- positive = falling away toward the moon
          for y = max(0, floor(h + 0.5)), gy do
            local t = clamp((y - h) / max(1, gy - h), 0, 1)
            img[idx(x, y)] = mix(slope > 0.05 and lit or col, C.ground_low, t * 0.5)
          end
        end
        prev = h
      end
      return hs
    end
    hills(gy - PH * 0.12, PH * 0.30, 0.05, 3, C.hill_far, C.hill_far_lit)
    local near_hill = hills(gy - PH * 0.02, PH * 0.16, 0.08, 9, C.hill, C.hill_lit)
    -- tiny distant firs dotting the near hill: a 1 px tip over a 3 px base
    if big then
      for x = 2, PW - 3 do
        if hash(x, 21, seed) < 0.16 and hash(x - 1, 21, seed) >= 0.16 then
          local y = floor(near_hill[x] + 0.5)
          if y < gy - 1 then
            img[idx(x, y - 1)] = mix(C.pine, C.hill, 0.25)
            for dx = -1, 1 do
              img[idx(x + dx, y)] = mix(C.pine, C.hill, 0.25)
            end
          end
        end
      end
    end

    -- Snowy village ground, then the snowbank: a moonlit crest over a face that sinks into shadow.
    for x = 0, PW - 1 do
      local b = bank[x]
      local fall = (bank[min(PW - 1, x + 1)] - bank[max(0, x - 1)]) * lit_dir -- > 0: facing the moon
      for y = ground[x], PH - 1 do
        local c
        if y < b then
          c = mix(C.ground_top, C.ground_mid, clamp((y - ground[x]) / max(1, b - ground[x]), 0, 1) * 0.8)
        elseif y == b then
          c = fall > 0 and C.drift or (fall < 0 and mix(C.drift, C.ground_mid, 0.45) or mix(C.drift, C.ground_top, 0.4))
        else
          local t = clamp((y - b) / max(1, PH - 1 - b), 0, 1)
          c = U.gradient({ { 0, C.ground_top }, { 0.45, C.ground_mid }, { 1, C.ground_deep } }, t)
          c = mix(c, C.ground_deep, fall < 0 and 0.15 or 0)
          if big and y <= b + 2 and hash(x, y, seed + 71) < 0.03 then
            c = mix(c, C.flake, 0.55) -- frost glint
          end
        end
        put(x, y, c, true)
      end
    end
  end

  -- Pine tree with snow on the tips of each tier.
  local function pine(tx, base, h)
    local prev_half = -1
    for r = 0, h - 1 do
      local half = (r == 0) and 0 or floor(r * 0.5 + 0.5)
      local y = base - h + r
      for x = tx - half, tx + half do
        local edge = (x - tx) * lit_dir == half
        local c = C.pine
        if half > prev_half and (abs(x - tx) == half) then
          c = edge and C.roof or C.pine_snow
        elseif r == 0 then
          c = C.pine_snow
        end
        put(x, y, c, false)
      end
      prev_half = half
    end
    put(tx, base, C.trunk, false)
  end

  -- Lights: window positions with strength, used to warm the snow afterwards.
  local lights, smokes, lamps = {}, {}, {}

  -- House: body w (odd) x bh, a snow roof with 1 px overhang, windows, a door, maybe a chimney.
  local function house(x0, w, bh, s, opts)
    opts = opts or {}
    local xc = x0 + (w - 1) / 2
    local base = ground[clamp(floor(xc), 0, PW - 1)] - 1 -- bottom row of the body
    local top = base - bh + 1
    local wall = C.walls[1 + floor(hash(s, 5, seed) * #C.walls)]
    local wall_shade = mix(wall, { 0, 0, 0 }, 0.35)
    for x = x0, x0 + w - 1 do
      local lit = (x - xc) * lit_dir > 0
      local bottom = max(base, (ground[clamp(x, 0, PW - 1)] or base) - 1)
      for y = top, bottom do
        put(x, y, lit and wall or wall_shade, false)
      end
    end
    -- roof rows: widths w+2, w, ..., 1 from the eave up
    local rows = floor((w + 1) / 2) + 1
    for r = 0, rows - 1 do
      local half = (w + 1) / 2 - r
      local y = top - 1 - r
      for x = floor(xc - half + 0.5), floor(xc + half + 0.5) do
        local dx = (x - xc) * lit_dir
        local c = dx >= 0 and C.roof or C.roof_shade
        if r == 0 and big and abs(x - xc) < half then
          c = mix(c, C.eave, 0.55) -- shaded underside of the snow along the eave
        end
        put(x, y, c, true)
      end
    end
    -- chimney on the shaded slope, poking 2 px above the roof line
    if opts.chimney then
      local cx = floor(xc - lit_dir * floor((w - 1) / 4 + 0.5) + 0.5)
      local roof_y = top - 1 - ((w + 1) / 2 - abs(cx - xc)) -- row of the roof surface at cx
      local ctop = floor(roof_y) - 1
      for y = ctop + 1, floor(roof_y) + 1 do
        put(cx, y, C.brick, false)
      end
      put(cx, ctop, C.roof, true)
      smokes[#smokes + 1] = { x = cx, y = ctop - 1, s = s }
      -- reserve the sky the smoke will fill
    end
    -- windows and door
    local function window(x, y, tall, on)
      for yy = y, y + tall - 1 do
        if on then
          put(x, yy, yy == y and C.win or C.win_edge, false)
        else
          put(x, yy, C.win_off, false)
        end
      end
      if on then
        lights[#lights + 1] = { x = x, y = y + tall - 1, k = opts.k or 1 }
      end
    end
    local tall = (bh >= 4) and 2 or 1
    local wy = top + 1
    if w >= 7 then
      local any = false
      for _, wx in ipairs({ x0 + 1, x0 + w - 2 }) do
        local on = hash(wx, s, seed + 3) < 0.82
        any = any or on
        window(wx, wy, tall, on)
      end
      if not any then
        window(x0 + 1, wy, tall, true)
      end
      if not opts.no_door then
        local door_x = floor(xc + 0.5)
        for y = base - 1, base do
          put(door_x, y, C.door, false)
        end
      end
    else
      -- small house: one window beside a door, or a single centered window
      if opts.no_door or hash(s, 9, seed) < 0.35 then
        window(floor(xc + 0.5), wy, tall, true)
      else
        local side = hash(s, 8, seed) < 0.5 and -1 or 1
        window(floor(xc + 0.5) + side, wy, 1, true)
        put(floor(xc + 0.5) - side, base, C.door, false)
        put(floor(xc + 0.5) - side, base - 1, C.door, false)
      end
    end
    return base
  end

  -- Church: a nave plus a tower with a belfry light and a needle spire.
  local function church(x0, s)
    local nw = big and 7 or 5
    local tower_left = hash(s, 11, seed) < 0.5
    local tx = tower_left and x0 + 1 or x0 + nw + 1 -- tower column center (3 wide)
    local nx = tower_left and x0 + 3 or x0
    local base = house(nx, nw, big and 4 or 3, s, { no_door = true, k = 1.2 })
    local body_h = big and (nw + 4) or (nw + 2)
    local top = max(4, base - body_h + 1)
    local wall = C.walls[2]
    for x = tx - 1, tx + 1 do
      local lit = (x - tx) * lit_dir > 0
      for y = top, max(base, ground[clamp(x, 0, PW - 1)] - 1) do
        put(x, y, lit and wall or mix(wall, { 0, 0, 0 }, 0.35), false)
      end
    end
    -- belfry window and a lit door
    put(tx, top + 1, C.win, false)
    lights[#lights + 1] = { x = tx, y = top + 1, k = 0.6 }
    put(tx, base, C.win_edge, false)
    put(tx, base - 1, C.win, false)
    lights[#lights + 1] = { x = tx, y = base, k = 1.3 }
    -- snow ledge and spire
    for x = tx - 1, tx + 1 do
      put(x, top - 1, (x - tx) * lit_dir >= 0 and C.roof or C.roof_shade, true)
    end
    local spire = big and 4 or 3
    for r = 1, spire do
      local y = top - 1 - r
      if y >= 0 then
        put(tx, y, r == spire and C.cross or C.roof, true)
      end
    end
    if big and top - 2 - spire >= 0 then
      put(tx - 1, top - 1 - spire, C.cross, false)
      put(tx + 1, top - 1 - spire, C.cross, false)
      put(tx, top - 2 - spire, C.cross, false)
    end
    return nw + 4
  end

  -- Street lamp: a thin post with a warm lantern under a cap of snow.
  local function lamp(x)
    local base = ground[clamp(x, 0, PW - 1)] - 1
    local h = big and 4 or 3
    for y = base - h + 2, base do
      put(x, y, C.post, false)
    end
    put(x, base - h + 1, C.win, false)
    put(x, base - h, C.roof, true)
    lamps[#lamps + 1] = { x = x, y = base - h + 1 }
    lights[#lights + 1] = { x = x, y = base, k = 0.9 }
  end

  -- Lay out the village left to right: houses with gaps holding pines or a lamp, one church.
  local margin = big and 2 or 1
  local hw = big and 7 or 5
  local foot = hw + 2
  -- church sits on the side away from the moon
  local church_at = PW * (moon_right and (0.22 + 0.2 * hash(3, 3, seed)) or (0.5 + 0.2 * hash(3, 3, seed)))
  local has_church = PW >= 40
  local back_pines, houses, posts = {}, {}, {}
  local x = margin + floor(hash(4, 4, seed) * 3)
  local n = 0
  while true do
    n = n + 1
    local s = n * 17 + 3
    local kind = "house"
    if has_church and x + foot >= church_at then
      kind, has_church = "church", false
    end
    local w = kind == "church" and (hw + 4) or ((big and hash(s, 1, seed) < 0.3) and 5 or hw)
    if x + w + 1 > PW - margin then
      break
    end
    houses[#houses + 1] = { kind = kind, x = x + 1, w = w, s = s }
    x = x + w + 2
    -- gaps: narrow, or wide with a pine (or now and then a street lamp)
    local gap = 1 + floor(hash(s, 2, seed) * 2.5)
    if hash(s, 3, seed) < 0.4 then
      gap = gap + (big and 4 or 3)
    end
    if gap >= 3 then
      if PW >= 56 and #posts < 2 and hash(s, 13, seed) < 0.3 then
        posts[#posts + 1] = { x = x + floor(gap / 2) }
      else
        back_pines[#back_pines + 1] = { x = x + floor(gap / 2) - 1, s = s }
      end
    end
    x = x + gap
  end
  -- center the row in the frame
  local used = x
  local shift = floor((PW - used) / 2)
  for _, h in ipairs(houses) do
    h.x = h.x + shift
  end
  for _, p in ipairs(back_pines) do
    p.x = p.x + shift
  end
  for _, p in ipairs(posts) do
    p.x = p.x + shift
  end
  -- fill the open snow beyond the ends of the row with a small grove
  if #houses > 0 then
    local first, last = houses[1], houses[#houses]
    for px = first.x - 4, 2, -4 do
      back_pines[#back_pines + 1] = { x = px, s = 200 + px }
    end
    for px = last.x + last.w + 3, PW - 3, 4 do
      back_pines[#back_pines + 1] = { x = px, s = 200 + px }
    end
  end

  local fp = big and 9 or 6
  local fl, fr = fp + floor(hash(5, 5, seed) * 3), fp - 1 + floor(hash(6, 6, seed) * 3)
  -- keep the corner pines' tips below the moon's row
  fl = min(fl, floor(bank[0] + 1 - (my + R + 2)))
  fr = min(fr, floor(bank[PW - 1] + 1 - (my + R + 2)))
  local function scenery()
    for _, p in ipairs(back_pines) do
      local ph = big and (6 + floor(hash(p.s, 4, seed) * 4)) or (p.low or (4 + floor(hash(p.s, 4, seed) * 2)))
      pine(clamp(p.x, 1, PW - 2), ground[clamp(p.x, 0, PW - 1)] - 1, ph)
    end
    for _, h in ipairs(houses) do
      if h.kind == "church" then
        church(h.x, h.s)
      else
        local bh = big and (hash(h.s, 6, seed) < 0.5 and 4 or 3) or 3
        house(h.x, h.w, bh, h.s, { chimney = hash(h.s, 10, seed) < 0.75 })
      end
    end
    for _, p in ipairs(posts) do
      lamp(p.x)
    end
    -- framing pines growing out of the corner drifts
    pine(0, bank[0] + 1, fl)
    pine(PW - 1, bank[PW - 1] + 1, fr)
  end

  -- Place the moon: a dry run maps the skyline (for both lighting sides, since chimneys move with it),
  -- then the moon takes the free spot nearest its preferred place, clear of roofs and spires.
  local function skyline()
    sky_top, dry = {}, true
    for _, d in ipairs({ 1, -1 }) do
      lit_dir = d
      scenery()
    end
    dry = false
  end
  -- headroom between the moon's disc and the highest roof/tree under it (with 1.5 px side margin)
  local function headroom(cx)
    local m = PH
    for xx = floor(cx - R - 1.5), floor(cx + R + 1.5 + 0.999) do
      m = min(m, sky_top[clamp(xx, 0, PW - 1)] or PH)
    end
    return m - math.ceil(my + R) -- blank rows between the moon's lowest row and the skyline
  end
  -- nearest spot with full clearance, else the spot with the most headroom
  local need = big and 2 or 1
  local best, best_h
  for attempt = 1, 2 do
    skyline()
    local best_d
    best, best_d, best_h = nil, math.huge, -math.huge
    -- small moons sit at x + 0.25, where the crescent rasterizes cleanly
    for cx = floor(R + 1.5) + (big and 0 or 0.25), PW - R - 2.5, big and 0.5 or 1 do
      local d = abs(cx - mx) + ((cx > PW / 2) == moon_right and 0 or PW * 0.15)
      local h = min(need, headroom(cx))
      if h > best_h or (h == best_h and d < best_d) then
        best, best_d, best_h = cx, d, h
      end
    end
    if best_h >= 1 or attempt == 2 then
      break
    end
    -- tiny frame with no room: swap the house nearest the moon for a pair of low pines
    local pick, pick_d = nil, math.huge
    for i, h in ipairs(houses) do
      local d = abs(h.x + h.w / 2 - best)
      if h.kind == "house" and d < pick_d then
        pick, pick_d = i, d
      end
    end
    local swapped = pick ~= nil
    if pick then
      local h = table.remove(houses, pick)
      back_pines[#back_pines + 1] = { x = h.x + 1, s = h.s, low = 4 }
      back_pines[#back_pines + 1] = { x = h.x + h.w - 1, s = h.s + 1, low = 3 }
    end
    if not swapped then
      break
    end
  end
  mx = best or mx
  lit_dir = mx > PW / 2 and 1 or -1
  lights, smokes, lamps = {}, {}, {}

  backdrop()
  scenery()

  -- Smoke: soft puffs that swell, drift downwind and fade as they rise. They pass behind other roofs.
  local haze = {}
  local len = big and 7 or 4
  for _, sm in ipairs(smokes) do
    local ph = hash(sm.s, 12, seed) * 6
    for j = 0, len - 1 do
      local t = j / len
      local cx = sm.x + wind * (t ^ 1.6) * len * 0.55 + sin(j * 0.9 + ph) * 0.25
      local hw = 0.2 + t * 1.1 -- the plume widens as it rises
      local a = 0.62 * (1 - t) ^ 1.2 * (0.78 + 0.22 * math.cos(j * 2.1 + ph)) -- gentle puffy rhythm
      local y = sm.y - j
      for x = floor(cx - hw - 1), floor(cx + hw + 1) + 1 do
        if x >= 0 and x < PW and y >= 0 then
          local w = a * clamp(1 - (abs(x - cx) - hw), 0, 1)
          w = w * clamp((U.dist(x, y, mx, my) - R - 0.5) / 2, 0, 1) -- never over the moon
          local i = idx(x, y)
          if w > 0.06 and w > (haze[i] or 0) then
            haze[i] = w
          end
        end
      end
    end
  end
  for i, w in pairs(haze) do
    if not solid[i] then
      img[i] = mix(img[i], C.smoke, min(0.7, w))
    end
  end

  -- Lantern halos in the air around each street lamp.
  for _, l in ipairs(lamps) do
    for y = l.y - 3, l.y + 3 do
      for x = l.x - 3, l.x + 3 do
        if x >= 0 and x < PW and y >= 0 and y < PH then
          local i = idx(x, y)
          if not solid[i] then
            local d2 = (x - l.x) ^ 2 + (y - l.y) ^ 2
            img[i] = mix(img[i], C.warm, 0.4 * exp(-d2 / 2.2))
          end
        end
      end
    end
  end

  -- Window light pooling on nearby snow (ground and roofs below the window).
  local warmth = {}
  local rx, ry = big and 3.2 or 2.2, big and 2.2 or 1.4
  for _, l in ipairs(lights) do
    local gx = clamp(l.x, 0, PW - 1)
    local cy = ground[gx]
    for y = l.y + 1, min(PH - 1, cy + floor(ry * 2)) do
      for x = max(0, l.x - 5), min(PW - 1, l.x + 5) do
        local i = idx(x, y)
        if snowy[i] then
          local dx, dy = (x - l.x) / rx, (y - cy) / ry
          warmth[i] = (warmth[i] or 0) + l.k * exp(-(dx * dx + dy * dy))
        end
      end
    end
  end
  for i, w in pairs(warmth) do
    img[i] = mix(img[i], C.warm, min(0.65, w * 0.55))
  end

  -- Falling snow: at most one flake per small cell, so flakes never clump.
  local cw, ch = 5, 3
  local density = 0.16 + 0.16 * hash(7, 7, seed)
  for cy = 0, floor(PH / ch) do
    for cx = 0, floor(PW / cw) do
      if hash(cx, cy, seed + 61) < density then
        local fx = cx * cw + floor(hash(cx, cy, seed + 62) * cw)
        local fy = cy * ch + floor(hash(cx, cy, seed + 63) * ch)
        if fx < PW and fy < PH then
          local i = idx(fx, fy)
          local near_moon = U.dist(fx, fy, mx, my) < R + 0.5
          if not near_moon and not solid[i] then
            img[i] = mix(img[i], C.flake, 0.35 + 0.4 * hash(cx, cy, seed + 64))
          end
        end
      end
    end
  end

  return function(px, py)
    return img[idx(px, py)]
  end
end
