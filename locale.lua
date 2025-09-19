-- Locale Loader & Helper
local cfg = Config

local Locales = {}
Locales['en'] = LoadResourceFile(cfg.ResourceName, 'locales/en.lua') and assert(load(LoadResourceFile(cfg.ResourceName, 'locales/en.lua')))()
Locales['de'] = LoadResourceFile(cfg.ResourceName, 'locales/de.lua') and assert(load(LoadResourceFile(cfg.ResourceName, 'locales/de.lua')))()

local function L(key, ...)
  local lang = (cfg.Locale or 'en')
  local pack = Locales[lang] or Locales['en'] or {}
  local value = pack[key] or (Locales['en'] and Locales['en'][key]) or key
  if select('#', ...) > 0 then
    local ok, formatted = pcall(string.format, value, ...)
    if ok then return formatted end
  end
  return value
end

_G.L = L -- global for client & server scripts

return L
