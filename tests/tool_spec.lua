---@module 'luassert'

local Tool = require("sidekick.cli.tool")

describe("cli tool", function()
  describe("is_proc", function()
    it("matches a string pattern against the process command", function()
      local tool = setmetatable({
        config = { is_proc = "\\<claude\\>" },
      }, Tool)

      assert.is_true(tool:is_proc({ cmd = "node /bin/claude" }))
      assert.is_false(tool:is_proc({ cmd = "node /bin/codex" }))
    end)

    it("delegates function matching to the configured function", function()
      local tool = setmetatable({
        name = "claude",
        config = {
          is_proc = function(self, proc)
            return self.name == "claude" and proc.cmd == "sbx run claude-docker"
          end,
        },
      }, Tool)

      assert.is_true(tool:is_proc({ cmd = "sbx run claude-docker" }))
      assert.is_false(tool:is_proc({ cmd = "sbx run codex-docker" }))
    end)

    it("matches when any table pattern matches the process command", function()
      local tool = setmetatable({
        config = {
          is_proc = {
            "\\<claude\\>",
            "sbx run sidekick-docker",
          },
        },
      }, Tool)

      assert.is_true(tool:is_proc({ cmd = "sbx run sidekick-docker" }))
      assert.is_true(tool:is_proc({ cmd = "node /bin/claude" }))
    end)

    it("does not match when no table pattern matches the process command", function()
      local tool = setmetatable({
        config = {
          is_proc = {
            "\\<claude\\>",
            "sbx run sidekick-docker",
          },
        },
      }, Tool)

      assert.is_false(tool:is_proc({ cmd = "sbx run codex-docker" }))
    end)
  end)
end)
