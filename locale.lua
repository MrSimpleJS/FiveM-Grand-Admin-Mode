-- Locale Loader & Helper
local cfg = Config

local Locales = {}

local function loadLocale(resName, fileName)
  local chunk = LoadResourceFile(resName, ('locales/%s'):format(fileName))
  if not chunk then return nil end
  local ok, fn = pcall(load, chunk)
  if not ok or not fn then return nil end
  local ok2, data = pcall(fn)
  if not ok2 or type(data) ~= 'table' then return nil end
  return data
end

local function discoverLocaleFiles(resName)
  -- fxmanifest doesn't give directory listing directly; use a predefined list attempt for common two-letter codes
  -- plus attempt to parse an index file listing (optional). For flexibility we try a broad set; missing ones are ignored.
  local codes = { 'en','de','fr','es','pt','it','pl','ru','dk','sv','tr','cs','hu','nl','fi','no','bg','ro','sk','sl','hr','zh','jp','ko' }
  local files = {}
  for _, code in ipairs(codes) do
    local fname = code..'.lua'
    local chunk = LoadResourceFile(resName, 'locales/'..fname)
    if chunk then
      files[#files+1] = fname
    end
  end
  return files
end

local tried = { cfg.ResourceName }
local currentRes = GetCurrentResourceName()
if currentRes ~= cfg.ResourceName then table.insert(tried, currentRes) end

local loadedAny = false
for _, res in ipairs(tried) do
  local localeFiles = discoverLocaleFiles(res)
  for _, file in ipairs(localeFiles) do
    local code = file:gsub('%.lua','')
    if not Locales[code] then
      Locales[code] = loadLocale(res, file)
      if Locales[code] then loadedAny = true end
    end
  end
end

-- Guarantee at least an empty english table to avoid nil indexing
Locales['en'] = Locales['en'] or {}

-- Optional: if no locales loaded at all, warn once server side (client prints too often otherwise)
if not loadedAny and IsDuplicityVersion() then
  print('[AdminMode][Locale] Warning: No locale files loaded. Check locales/*.lua')
end

local function L(key, ...)
  -- Sanitize accidental double underscores or wrong key style
  if key:find('__') then
    key = key:gsub('__+', '_')
  end
  local primary = (cfg.Locale or 'en')
  local chain = { primary }
  if cfg.LocaleFallback and type(cfg.LocaleFallback) == 'table' then
    for _, code in ipairs(cfg.LocaleFallback) do
      if code ~= primary then
        chain[#chain+1] = code
      end
    end
  end
  -- always ensure 'en' at end for safety
  local hasEn = false
  for _, c in ipairs(chain) do if c == 'en' then hasEn = true break end end
  if not hasEn then chain[#chain+1] = 'en' end
  local value
  for _, code in ipairs(chain) do
    local pack = Locales[code]
    if pack and pack[key] then
      value = pack[key]
      break
    end
  end
  value = value or key
  if select('#', ...) > 0 then
    local ok, formatted = pcall(string.format, value, ...)
    if ok then return formatted end
  end
  return value
end

_G.L = L -- global for client & server scripts

return L
