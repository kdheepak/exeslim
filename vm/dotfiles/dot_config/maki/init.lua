-- Personal settings; keys match https://maki.sh/docs/configuration/.
-- `maki.setup` only works in this global init.lua and may be called once.
maki.setup({
  -- Start every session in YOLO mode: skip permission prompts.
  -- Deny rules still apply.
  always_yolo = true,
  always_fast = true,
  agent = {
    compaction_buffer = "10%",
  },
  plugins = {
    completion = { enabled = true },
    memory = { enabled = false },
    question = { enabled = false },
  },
  ui = {
    notifications = "off",
    -- Color theme loaded at startup. Overrides the theme picked interactively,
    -- so restarts always come back to this one. Custom themes can be added
    -- as ~/.config/maki/themes/<name>.toml.
    theme = "rose_pine_tinted",
    -- Collapse model reasoning to its header plus the last N lines (default 3).
    -- 0 shows only the header, -1 never collapses. Click to toggle.
    thinking_lines = -1,
    -- Keep status bar messages up long enough to read (default 1500 ms).
    flash_duration_ms = 4000,
  },
})

-- maki-claude adds a `claude` provider that signs in with a Claude Pro/Max
-- subscription. maki clones it on first start.
maki.pack.add({ { src = "https://github.com/bzzimmy/maki-claude", version = "main" } })
