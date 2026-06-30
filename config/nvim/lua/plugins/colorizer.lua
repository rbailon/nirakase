return {
	{
		"NvChad/nvim-colorizer.lua",
		event = { "BufReadPre", "BufNewFile" },
		opts = {
			filetypes = {
				"*", -- Highlight colors in all files
				css = {
					rgb_fn = true, -- CSS rgb() and rgba() functions
					hsl_fn = true, -- CSS hsl() and hsla() functions
					css = true, -- Enable all CSS features
					css_fn = true, -- Enable CSS functions
				},
			},
			user_default_opts = {
				RGB = true, -- #RGB hex codes
				RRGGBB = true, -- #RRGGBB hex codes
				names = true, -- "Name" codes like Blue or Red
				RRGGBBAA = true, -- #RRGGBBAA hex codes
				AARRGGBB = true, -- 0xAARRGGBB hex codes
				rgb_fn = true, -- CSS rgb() and rgba() functions
				hsl_fn = true, -- CSS hsl() and hsla() functions
				css = true, -- Enable all CSS features
				css_fn = true, -- Enable CSS functions
				mode = "background", -- Highlight mode: background, foreground, or virtualtext
				tailwind = true, -- Enable tailwind colors
				sass = { enable = true, parsers = { "css" } }, -- Enable SASS colors
				virtualtext = "■",
			},
		},
	},
}
