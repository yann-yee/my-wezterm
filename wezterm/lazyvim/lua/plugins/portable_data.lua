local paths = require("config.portable_paths")

paths.ensure_data_dirs()

return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts = opts or {}
      opts.install_root_dir = paths.mason_root()
      return opts
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts = opts or {}
      opts.parser_install_dir = paths.parser_root()
      return opts
    end,
  },
}
