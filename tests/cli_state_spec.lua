---@module 'luassert'

local Session = require("sidekick.cli.session")
local State = require("sidekick.cli.state")
local Util = require("sidekick.util")

describe("cli state", function()
  local original_session_attach
  local original_info

  before_each(function()
    original_session_attach = Session.attach
    original_info = Util.info
    Util.info = function() end
  end)

  after_each(function()
    Session.attach = original_session_attach
    Util.info = original_info
  end)

  describe("attach", function()
    it("focuses an external session that supports focus", function()
      local focused = 0
      local session = {
        id = "tmux 101",
        backend = "tmux",
        tool = { name = "claude" },
        is_attached = function()
          return true
        end,
        focus = function()
          focused = focused + 1
        end,
      }

      Session.attach = function(current)
        return current
      end

      State.attach({ session = session, attached = false, tool = session.tool })

      assert.are.same(1, focused)
    end)

    it("does not focus an external session when focus is disabled", function()
      local focused = 0
      local session = {
        id = "tmux 101",
        backend = "tmux",
        tool = { name = "claude" },
        is_attached = function()
          return true
        end,
        focus = function()
          focused = focused + 1
        end,
      }

      Session.attach = function(current)
        return current
      end

      State.attach({ session = session, attached = false, tool = session.tool }, { focus = false })

      assert.are.same(0, focused)
    end)
  end)
end)
