-- Start-screen scenes: pixel-art landscapes drawn procedurally. Each scene module returns
-- build(width, height, seed) -> pixel(x, y) -> {r, g, b}.
local M = {}

M.names = { "mountains", "aurora", "desert", "city", "lighthouse", "rain", "village", "space" }

-- Render scene `name` at width x height pixels into a grid of {r, g, b}, indexed [y][x] from 0.
function M.render(name, PW, PH, seed)
  local pixel = require("scenes." .. name)(PW, PH, seed)
  local floor, clamp = math.floor, require("scenes.util").clamp
  local px = {}
  for y = 0, PH - 1 do
    local row = {}
    for x = 0, PW - 1 do
      local c = pixel(x, y)
      row[x] = {
        clamp(floor(c[1] + 0.5), 0, 255),
        clamp(floor(c[2] + 0.5), 0, 255),
        clamp(floor(c[3] + 0.5), 0, 255),
      }
    end
    px[y] = row
  end
  return px
end

return M
