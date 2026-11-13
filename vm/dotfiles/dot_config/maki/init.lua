-- `maki.setup` only works in this global init.lua and may be called once.
maki.setup({
  -- Skip permission prompts; the VM is disposable. Deny rules still apply.
  always_yolo = true,
  plugins = {
    memory = { enabled = false },
  },
})

-- maki-claude adds a `claude` provider that signs in with a Claude Pro/Max
-- subscription. maki clones it on first start.
maki.pack.add({ { src = "https://github.com/bzzimmy/maki-claude", version = "main" } })
