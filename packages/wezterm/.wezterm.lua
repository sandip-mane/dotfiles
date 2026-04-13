local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- Font and Color Settings
config.front_end = 'WebGpu'
config.freetype_load_target = 'Light'
config.freetype_render_target = 'HorizontalLcd'
config.font_size = 14.0
config.line_height = 1.2
config.font = wezterm.font({ family = "MesloLGS Nerd Font", weight = "DemiLight" })
config.underline_position = '-4px'
config.underline_thickness = '1px'

local scheme = wezterm.color.get_builtin_schemes()['Monokai Vivid']
scheme.tab_bar = {
  background = '#333333',
  active_tab = {
    bg_color = '#111111',
    fg_color = '#ffffff',
    intensity = 'Bold',
  },
  inactive_tab = {
    bg_color = '#e0e0e0',
    fg_color = '#111111',
  },
  inactive_tab_hover = {
    bg_color = '#bbbbbb',
    fg_color = '#111111',
  },
}
config.color_schemes = { ['Monokai Vivid Custom'] = scheme }
config.color_scheme = 'Monokai Vivid Custom'

-- Dim inactive panes
config.inactive_pane_hsb = {
  brightness = 0.3,
}

-- Tabs
config.window_decorations = 'RESIZE'
config.use_fancy_tab_bar = true
config.show_new_tab_button_in_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_max_width = 32
config.window_frame = {
  font_size = 14.0,
}

-- Pad tab titles with spaces on both sides
wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local title = tab.tab_title
  if not title or #title == 0 then
    title = tab.active_pane.title
  end
  local text = string.format(' %d: %s ', tab.tab_index + 1, title)
  local min_width = 24
  if #text < min_width then
    local pad = min_width - #text
    local left = math.floor(pad / 2)
    local right = pad - left
    text = string.rep(' ', left) .. text .. string.rep(' ', right)
  end
  return text
end)


-- Mimic iTerm2 Word Movement (Option + Arrow Keys)
config.keys = {
  -- Navigate tabs: Cmd+Left/Right
  { key = 'LeftArrow', mods = 'CMD', action = act.ActivateTabRelative(-1) },
  { key = 'RightArrow', mods = 'CMD', action = act.ActivateTabRelative(1) },

  -- Navigate tabs: Cmd+Shift+[ and Cmd+Shift+]
  { key = '{', mods = 'CMD|SHIFT', action = act.ActivateTabRelative(-1) },
  { key = '}', mods = 'CMD|SHIFT', action = act.ActivateTabRelative(1) },

  -- Move tab: Cmd+Shift+Left/Right (iTerm2-style)
  { key = 'LeftArrow', mods = 'CMD|SHIFT', action = act.MoveTabRelative(-1) },
  { key = 'RightArrow', mods = 'CMD|SHIFT', action = act.MoveTabRelative(1) },

  -- Clear scrollback: Cmd+K (iTerm2-style)
  { key = 'k', mods = 'CMD', action = act.ClearScrollback 'ScrollbackAndViewport' },

  -- Split panes: Cmd+D vertical, Cmd+Shift+D horizontal (iTerm2-style)
  { key = 'd', mods = 'CMD', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'd', mods = 'CMD|SHIFT', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },

  -- Close current pane (or tab if last pane): Cmd+W
  { key = 'w', mods = 'CMD', action = act.CloseCurrentPane { confirm = true } },

  -- Split Editor Layout: Cmd+Shift+E
  { key = 'e', mods = 'CMD|SHIFT', action = act.EmitEvent 'trigger-split-editor-layout' },

  -- Navigate panes: Opt+Cmd+Arrow Keys (iTerm2-style)
  { key = 'LeftArrow', mods = 'CMD|OPT', action = act.ActivatePaneDirection 'Left' },
  { key = 'RightArrow', mods = 'CMD|OPT', action = act.ActivatePaneDirection 'Right' },
  { key = 'UpArrow', mods = 'CMD|OPT', action = act.ActivatePaneDirection 'Up' },
  { key = 'DownArrow', mods = 'CMD|OPT', action = act.ActivatePaneDirection 'Down' },
}

-- Split Editor Layout: left 40% (two horizontal panes), right 60% (full height)
-- Keybinding: Cmd+Shift+E
local function split_editor_layout(window, pane)
  local tab, left_pane, _ = window:mux_window():spawn_tab {}
  local right_pane = left_pane:split {
    direction = 'Right',
    size = 0.6,
  }
  left_pane:split {
    direction = 'Bottom',
    size = 0.5,
  }
  left_pane:activate()
  tab:set_title 'Server'
end

wezterm.on('trigger-split-editor-layout', function(window, pane)
  split_editor_layout(window, pane)
end)

-- Open file:line references in VS Code on click
-- Detects "path/to/file.ext:line" or "path/to/file.ext:line:col" in terminal
-- output and routes the click to `code -g <path>`.
config.hyperlink_rules = wezterm.default_hyperlink_rules()

table.insert(config.hyperlink_rules, {
  regex = [[\b[\w./~+-]+\.\w+:\d+(?::\d+)?\b]],
  format = 'vscode://file/$0',
})

wezterm.on('open-uri', function(window, pane, uri)
  local path = uri:match('^vscode://file/(.+)$')
  if not path then return end -- let WezTerm handle other URIs

  if not path:match('^/') and not path:match('^~') then
    local cwd_uri = pane:get_current_working_dir()
    if cwd_uri then
      local cwd
      if type(cwd_uri) == 'userdata' then
        cwd = cwd_uri.file_path
      else
        cwd = cwd_uri:gsub('^file://[^/]*', '')
      end
      path = cwd .. '/' .. path
    end
  end

  wezterm.background_child_process({ 'code', '-g', path })
  return false -- suppress WezTerm's default handling
end)

return config
