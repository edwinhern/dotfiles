return {
  {
    "nickjvandyke/opencode.nvim",
    version = "*",
    lazy = false,
    dependencies = {
      {
        "folke/snacks.nvim",
        optional = true,
        opts = {
          input = {},
          picker = {
            actions = {
              opencode_send = function(...)
                return require("opencode").snacks_picker_send(...)
              end,
            },
            win = {
              input = {
                keys = {
                  ["<a-a>"] = { "opencode_send", mode = { "n", "i" } },
                },
              },
            },
          },
        },
      },
    },
    keys = {
      {
        "<leader>oa",
        function()
          require("opencode").ask("@this: ", { submit = true })
        end,
        mode = { "n", "x" },
        desc = "Ask OpenCode about this",
      },
      {
        "<leader>os",
        function()
          require("opencode").select()
        end,
        mode = { "n", "x" },
        desc = "Select OpenCode action",
      },
      {
        "<leader>oS",
        function()
          require("opencode").select_server()
        end,
        desc = "Select OpenCode server",
      },
      {
        "<leader>on",
        function()
          require("opencode").command("session.new")
        end,
        desc = "New OpenCode session",
      },
    },
    config = function()
      vim.g.opencode_opts = {
        server = {
          port = nil,
          start = false,
          stop = false,
          toggle = false,
        },
        select = {
          server = false,
        },
      }

      vim.o.autoread = true
    end,
  },
}
