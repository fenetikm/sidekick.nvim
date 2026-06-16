---@module 'luassert'

local Config = require("sidekick.config")
local Tmux = require("sidekick.cli.session.tmux")
local Util = require("sidekick.util")

describe("cli auto toggle", function()
  local original_exec
  local original_tools
  local original_procs_new
  local original_procs_pids

  before_each(function()
    original_exec = Util.exec
    original_tools = Config.tools
    local Procs = require("sidekick.cli.procs")
    original_procs_new = Procs.new
    original_procs_pids = Procs.pids
  end)

  after_each(function()
    Util.exec = original_exec
    Config.tools = original_tools
    local Procs = require("sidekick.cli.procs")
    Procs.new = original_procs_new
    Procs.pids = original_procs_pids
  end)

  describe("tmux current_window_sessions", function()
    it("returns sessions in current window pane order", function()
      local exec_calls = {}
      Util.exec = function(cmd)
        table.insert(exec_calls, cmd)
        return {
          "$1:%10:101:work:/repo",
          "$1:%11:202:work:/repo",
        }
      end

      local tools = {
        claude = {
          name = "claude",
          is_proc = function(_, proc)
            return proc.cmd == "claude"
          end,
        },
        opencode = {
          name = "opencode",
          is_proc = function(_, proc)
            return proc.cmd == "opencode"
          end,
        },
      }
      Config.tools = function()
        return tools
      end

      local Procs = require("sidekick.cli.procs")
      Procs.pids = function(pid)
        return { pid }
      end
      Procs.new = function()
        return {
          walk = function(_, pid, cb)
            if pid == 101 then
              cb({ cmd = "claude", cwd = "/repo" })
            elseif pid == 202 then
              cb({ cmd = "opencode", cwd = "/repo" })
            end
          end,
        }
      end

      local sessions = Tmux.current_window_sessions()

      assert.are.same({ "tmux", "list-panes", "-F" }, vim.list_slice(exec_calls[1], 1, 3))
      assert.are.same(2, #sessions)
      assert.are.same("tmux 101", sessions[1].id)
      assert.are.same("claude", sessions[1].tool.name)
      assert.are.same("%10", sessions[1].tmux_pane_id)
      assert.are.same({ 101 }, sessions[1].pids)
      assert.are.same("tmux 202", sessions[2].id)
      assert.are.same("opencode", sessions[2].tool.name)
      assert.are.same("%11", sessions[2].tmux_pane_id)
      assert.are.same({ 202 }, sessions[2].pids)
    end)
  end)

  describe("toggle strategy auto", function()
    local Cli
    local Session
    local State
    local TmuxModule
    local original_session_backends
    local original_session_did_setup
    local original_state_get
    local original_state_attach
    local original_state_with
    local original_tmux_sessions
    local original_tmux_env

    before_each(function()
      Cli = require("sidekick.cli")
      Session = require("sidekick.cli.session")
      State = require("sidekick.cli.state")
      TmuxModule = require("sidekick.cli.session.tmux")
      original_session_backends = Session.backends
      original_session_did_setup = Session.did_setup
      original_state_get = State.get
      original_state_attach = State.attach
      original_state_with = State.with
      original_tmux_sessions = TmuxModule.current_window_sessions
      original_tmux_env = vim.env.TMUX
      Session.backends = { tmux = TmuxModule }
      Session.did_setup = true
      vim.env.TMUX = "/tmp/tmux-501/default,1,0"
    end)

    after_each(function()
      Session.backends = original_session_backends
      Session.did_setup = original_session_did_setup
      State.get = original_state_get
      State.attach = original_state_attach
      State.with = original_state_with
      TmuxModule.current_window_sessions = original_tmux_sessions
      vim.env.TMUX = original_tmux_env
    end)

    it("attaches to first same-window tmux agent before opening picker", function()
      local attached = {}
      local with_calls = {}
      local tmux_state = {
        id = "tmux 101",
        tool = { name = "claude" },
      }

      State.get = function(filter)
        assert.are.same({ attached = true }, filter)
        return {}
      end
      TmuxModule.current_window_sessions = function()
        return { tmux_state }
      end
      State.attach = function(state, opts)
        table.insert(attached, { state = state, opts = opts })
        return {}, true
      end
      State.with = function()
        table.insert(with_calls, true)
      end

      Cli.toggle({ strategy = "auto" })
      vim.wait(100, function()
        return #attached == 1
      end)

      assert.are.same(tmux_state.id, attached[1].state.session.id)
      assert.are.same(tmux_state.tool.name, attached[1].state.session.tool.name)
      assert.are.same({}, attached[1].opts)
      assert.are.same({}, with_calls)
    end)

    it("falls back to existing State.with path when auto finds no tmux agent", function()
      local with_opts
      State.get = function()
        return {}
      end
      TmuxModule.current_window_sessions = function()
        return {}
      end
      State.attach = function()
        error("State.attach should not be called")
      end
      State.with = function(_, opts)
        with_opts = opts
      end

      Cli.toggle({ strategy = "auto", focus = false })

      assert.are.same({ attach = true, filter = {} }, with_opts)
    end)

    it("does not call tmux discovery without auto strategy", function()
      local tmux_called = false
      local with_called = false
      TmuxModule.current_window_sessions = function()
        tmux_called = true
        return {}
      end
      State.with = function()
        with_called = true
      end

      Cli.toggle()

      assert.is_false(tmux_called)
      assert.is_true(with_called)
    end)
  end)
end)
