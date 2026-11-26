-- How much extra saturation Carbonfox's accent colors get (0 = stock Carbonfox, max 100).
local pop = 20

return {
  {
    "EdenEast/nightfox.nvim",
    opts = function(_, opts)
      local Color = require("nightfox.lib.color")
      local Shade = require("nightfox.lib.shade")
      -- Carbonfox's stock accent colors (white and black stay as they are).
      local accents = {
        red = "#EE5396",
        green = "#25be6a",
        yellow = "#08BDBA",
        blue = "#78A9FF",
        magenta = "#BE95FF",
        cyan = "#33B1FF",
        orange = "#3DDBD9",
        pink = "#FF7EB6",
      }
      local palette = {}
      for name, hex in pairs(accents) do
        -- More saturated base, and a "bright" variant that washes out less toward white.
        local shade = Shade.new(Color.from_hex(hex):saturate(pop), 0.08, -0.15)
        palette[name] = { base = shade.base, bright = shade.bright, dim = shade.dim }
      end
      -- Pure black background for OLED (stock Carbonfox: #161616). bg0 is floats and the
      -- status line, which stock Carbonfox draws slightly darker than the editor.
      palette.bg0 = "#000000"
      palette.bg1 = "#000000"
      opts.palettes = vim.tbl_deep_extend("force", opts.palettes or {}, { carbonfox = palette })
    end,
  },
  { "LazyVim/LazyVim", opts = { colorscheme = "carbonfox" } },
}
