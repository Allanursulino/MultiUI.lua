--[[
	MULTI HUB · UI Library  v2.2
	Original by Dev - wendel · v2: languages (EN / PT-BR / ES), Roblox-language detection,
	tooltips, status indicators, profiles, fixes · v2.1: horizontal navigation (reference
	layout), Player and Performance pages, FPS display, Liquid Glass style, Unload. v2.2: solid
	dark-red look when Liquid Glass is off, glass rims / lens knobs / tab capsule, neutral edges.

	The v1 public API is unchanged; everything new is optional.

	  local Library = loadstring(game:HttpGet(URL))()
	  local Window  = Library:CreateWindow({ Title = "My Game" })
	  local Tab     = Window:Tab({ Title = "Main", Icon = "house", Desc = "Farm controls" })
	  local Section = Tab:Section({ Title = "Farm", Desc = "Automatic farming" })
	  Section:Toggle({ Title = "Auto Farm", Default = false, Callback = function(v) end })
	  Section:Button / Slider / Dropdown / MultiDropdown / Paragraph / InputBox (= TextBox)
	  Library:Build()   -- optional since v2: the UI also builds itself on the next frame
	  Library:Notify({ Title = "Hi", Content = "Text", Duration = 3 })

	Every Title / Desc / Text may be a string or a table per language:
	  { en = "Auto Farm", ["pt-br"] = "Farm automático", es = "Farm automático" }

	Full guide: "MultiHub Library - Docs.md".

	File map (search for the "== NAME ==" banners):
	  SERVICES · CONFIG · THEME · I18N · STRINGS · UTIL · ICONS · PREFS · STORE · STYLE
	  WINDOW · NAV · NOTIFY · TOOLTIP · DIALOGS · COMPONENTS · DROPDOWN PANEL · ROUTER
	  PAGES · PLAYER · PERFORMANCE · OPEN / CLOSE · INPUT · BUILD · STARTUP · LIBRARY API
	  EXAMPLE
]]

-- == SERVICES ==============================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Executor functions (writefile, setclipboard...) live in the thread environment.
-- Reading them through env keeps the script valid in Roblox Studio, where they are nil.
local env = getfenv()
local genv = (type(env.getgenv) == "function" and env.getgenv()) or _G

-- Phones/tablets: touch without a mouse. A touchscreen laptop keeps the desktop layout.
local IS_TOUCH = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

-- Running the script again replaces the previous window completely (GUI + input connections).
do
	local previous = genv.__MultiHubLibrary
	if type(previous) == "table" and type(previous.Destroy) == "function" then
		pcall(previous.Destroy, previous)
	end
	-- v1 left a Heartbeat connection behind on every execution.
	if genv.__MultiHubAnimConn then
		pcall(function()
			genv.__MultiHubAnimConn:Disconnect()
		end)
		genv.__MultiHubAnimConn = nil
	end
end

-- == CONFIG ================================================================

local CONFIG = {
	HubName = "MULTI HUB",
	Version = "1.0", -- saved-profile format; v1 profiles keep loading. Change it to invalidate old saves.
	LibraryVersion = "2.2",
	ToggleKey = Enum.KeyCode.RightShift, -- default; the user can change it in Settings
	QuickTabs = {}, -- tab ids shown on Home (filled automatically with the first tabs)

	-- lucide | solar | craft | geist | sfsymbols | gravity. Force a set per icon with "solar:home".
	IconSet = "lucide",
	LogoUrl = "https://i.ibb.co/jk7FCz3y/icone-ios26-liquid-glass-3.png",
	LogoFile = "Multihub_logo.png",
	LogoAsset = "", -- "rbxassetid://..." skips the download
	ProceduralBackdrop = true, -- red glow + dot grid drawn with Frames (no image assets)
	ExampleEnabled = true, -- demo tabs; removed automatically as soon as a script creates its own tab
	-- Built-in pages (a script can also hide them with CreateWindow({ Player = false, Performance = false })).
	BuiltinPlayer = true,
	BuiltinPerformance = true,

	ConfigFolder = "Multi Hub",
	Social = {
		{ Id = "youtube", Name = "YouTube", Url = "https://www.youtube.com/@MultiHub07", Icon = "lucide:youtube", Glyph = "▶" },
		{ Id = "tiktok", Name = "TikTok", Url = "https://www.tiktok.com/@multihub07", Icon = "lucide:music-2", Glyph = "♪" },
		{ Id = "discord", Name = "Discord", Url = "https://discord.gg/5USPd27zmu", Icon = "geist:logo-discord", Glyph = "D" },
	},
}

-- == THEME =================================================================
-- MultiHub identity: near-black graphite, red only on accents and active states.

local THEME = {
	Bg = Color3.fromRGB(14, 14, 16),
	Header = Color3.fromRGB(11, 11, 13),
	Surface = Color3.fromRGB(19, 19, 22),
	Row = Color3.fromRGB(25, 25, 29),
	RowHover = Color3.fromRGB(32, 32, 37),
	Input = Color3.fromRGB(12, 12, 14),
	Stroke = Color3.fromRGB(44, 44, 51),
	StrokeSoft = Color3.fromRGB(31, 31, 36),
	Accent = Color3.fromRGB(232, 36, 56),
	AccentHover = Color3.fromRGB(255, 66, 86),
	AccentDark = Color3.fromRGB(150, 16, 34),
	AccentSoft = Color3.fromRGB(48, 15, 21),
	Text = Color3.fromRGB(242, 242, 245),
	SubText = Color3.fromRGB(168, 168, 177),
	Muted = Color3.fromRGB(112, 112, 122),
	Track = Color3.fromRGB(46, 46, 53),
	Knob = Color3.fromRGB(205, 205, 212),
	Success = Color3.fromRGB(64, 201, 122),
	Warning = Color3.fromRGB(240, 168, 48),
	Shadow = Color3.fromRGB(0, 0, 0),
}

-- Radii and spacing in one place so every component lines up.
local RADIUS = { Window = 14, Card = 10, Row = 8, Small = 6, Pill = 999 }

local FONT
do
	local uiFamily = "rbxasset://fonts/families/GothamSSm.json"
	pcall(function()
		-- Builder Sans: Roblox's current UI font, full Latin accent support (ç, ã, ñ).
		uiFamily = Font.fromEnum(Enum.Font.BuilderSans).Family
	end)
	local display = "rbxasset://fonts/families/Montserrat.json"
	FONT = {
		Regular = Font.new(uiFamily, Enum.FontWeight.Regular),
		Medium = Font.new(uiFamily, Enum.FontWeight.Medium),
		SemiBold = Font.new(uiFamily, Enum.FontWeight.SemiBold),
		Bold = Font.new(uiFamily, Enum.FontWeight.Bold),
		Display = Font.new(display, Enum.FontWeight.ExtraBold),
		DisplayItalic = Font.new(display, Enum.FontWeight.ExtraBold, Enum.FontStyle.Italic),
		Mono = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium),
	}
end

-- == I18N ==================================================================
-- All interface text lives here. To add a language: add its code to Order/Names and a
-- table in Strings (missing keys fall back to English), or call Library:AddLanguage().

local I18n = {
	Current = "en",
	Default = "en",
	Order = { "en", "pt-br", "es" },
	Names = { en = "English", ["pt-br"] = "Português (Brasil)", es = "Español" },
	Strings = {},
	Listeners = {},
	Bound = {}, -- [Instance] = { getter, property }
	bindCount = 0,
	Internal = (nil :: any), -- UI hook run on every language change (set by the PAGES section)
	-- Script dictionary (Library:AddDictionary): plain English text -> translations.
	-- Any Title / Desc / Text / Tooltip / Placeholder / Content written as a plain string,
	-- and every dropdown option label, is looked up here, so a script written in English
	-- shows in the player's language without rewriting each control.
	Dictionary = {}, -- [text] = { ["pt-br"] = "...", es = "..." }
	DictionaryLower = {}, -- same entries keyed by lower-case trimmed text
}

-- (the dictionaries live in the STRINGS section right below this one)

-- "pt-BR", "pt_br", "pt" -> "pt-br" ; "es-mx" -> "es" ; unknown -> nil
function I18n.normalize(code)
	if type(code) ~= "string" or code == "" then
		return nil
	end
	code = string.gsub(string.lower(code), "_", "-")
	if I18n.Strings[code] then
		return code
	end
	local base = string.match(code, "^(%a+)")
	if not base then
		return nil
	end
	for _, known in I18n.Order do
		if known == base or string.match(known, "^(%a+)") == base then
			return known
		end
	end
	return nil
end

-- Documented Roblox APIs only:
--   Player.LocaleId                    -> language the player chose for Roblox (account setting)
--   LocalizationService.RobloxLocaleId -> language Roblox uses for its own interface
-- LocalizationService.SystemLocaleId (operating-system language) is deliberately NOT used.
function I18n.detect()
	local sources = {}
	pcall(function()
		table.insert(sources, player.LocaleId)
	end)
	pcall(function()
		table.insert(sources, LocalizationService.RobloxLocaleId)
	end)
	for _, localeId in sources do
		local code = I18n.normalize(localeId)
		if code then
			return code, localeId
		end
	end
	return nil, sources[1]
end

function I18n.t(key, ...)
	local pack = I18n.Strings[I18n.Current]
	local text = (pack and pack[key]) or I18n.Strings.en[key] or key
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, text, ...)
		if ok then
			return formatted
		end
	end
	return text
end

-- Script-provided text: a plain string, or { en = "...", ["pt-br"] = "...", es = "..." }.
function I18n.resolve(value)
	if type(value) == "function" then
		local ok, text = pcall(value)
		return ok and tostring(text or "") or ""
	end
	if type(value) == "table" then
		local current = I18n.Current
		local base = string.match(current, "^(%a+)")
		local text = value[current] or value[base] or value[string.upper(current)]
		if text == nil then
			for key, candidate in value do
				if type(key) == "string" and string.lower(key) == current then
					text = candidate
					break
				end
			end
		end
		if text == nil then
			text = value.en or value.En or value.EN or value[1]
		end
		if text == nil then
			local _, first = next(value)
			text = first
		end
		return tostring(text or "")
	end
	if value == nil then
		return ""
	end
	return I18n.lookup(tostring(value))
end

-- Translation of a plain string through the script dictionary (unchanged when missing).
function I18n.lookup(text)
	if next(I18n.Dictionary) == nil or text == "" then
		return text
	end
	local entry = I18n.Dictionary[text]
	if entry == nil then
		local trimmed = string.match(text, "^%s*(.-)%s*$") or text
		entry = I18n.DictionaryLower[string.lower(trimmed)]
	end
	if entry == nil then
		return text
	end
	local current = I18n.Current
	local translated = entry[current] or entry[string.match(current, "^(%a+)") or current]
	if translated == nil or translated == "" then
		return text
	end
	return tostring(translated)
end

-- Adds entries to the script dictionary. Accepts both shapes:
--   I18n.addDictionary({ ["Auto Mine"] = { ["pt-br"] = "...", es = "..." } })
--   I18n.addDictionary("pt-br", { ["Auto Mine"] = "..." })
function I18n.addDictionary(first, second)
	local function put(text, code, translated)
		if type(text) ~= "string" or text == "" or translated == nil then
			return
		end
		code = I18n.normalize(code) or string.lower(tostring(code))
		local entry = I18n.Dictionary[text]
		if entry == nil then
			entry = {}
			I18n.Dictionary[text] = entry
		end
		entry[code] = tostring(translated)
		local trimmed = string.match(text, "^%s*(.-)%s*$") or text
		I18n.DictionaryLower[string.lower(trimmed)] = entry
	end
	local count = 0
	if type(first) == "string" and type(second) == "table" then
		for text, translated in second do
			put(text, first, translated)
			count += 1
		end
	elseif type(first) == "table" then
		for text, languages in first do
			if type(languages) == "table" then
				for code, translated in languages do
					if type(code) == "string" then
						put(text, code, translated)
					end
				end
				count += 1
			end
		end
	end
	return count
end

-- Keeps a text property in sync with the language. source = key or function returning text.
function I18n.bind(instance, source, property)
	property = property or "Text"
	local getter = source
	if type(source) ~= "function" then
		getter = function()
			return I18n.t(source)
		end
	end
	I18n.Bound[instance] = { getter, property }
	instance[property] = getter()
	-- Pages re-render often: drop bindings of destroyed labels every 300 binds (no leak).
	I18n.bindCount = (I18n.bindCount or 0) + 1
	if I18n.bindCount % 300 == 0 then
		for bound in I18n.Bound do
			if bound.Parent == nil then
				I18n.Bound[bound] = nil
			end
		end
	end
	return instance
end

function I18n.refresh()
	for instance, binding in I18n.Bound do
		if instance.Parent == nil then
			I18n.Bound[instance] = nil -- destroyed or discarded
		else
			local ok, err = pcall(function()
				instance[binding[2]] = binding[1]()
			end)
			if not ok then
				warn("[MultiHub] i18n refresh failed: " .. tostring(err))
			end
		end
	end
	if I18n.Internal then
		local ok, err = pcall(I18n.Internal)
		if not ok then
			warn("[MultiHub] language refresh failed: " .. tostring(err))
		end
	end
	for _, listener in I18n.Listeners do
		task.spawn(listener, I18n.Current)
	end
end

function I18n.set(code)
	code = I18n.normalize(code) or I18n.Default
	if code == I18n.Current then
		return code
	end
	I18n.Current = code
	I18n.refresh()
	return code
end

-- == STRINGS ===============================================================
-- One table per language. Keys missing in a language fall back to English.

I18n.Strings.en = {
	["nav.home"] = "Home",
	["nav.pages"] = "Pages",
	["nav.player"] = "Player",
	["nav.performance"] = "Performance",
	["nav.settings"] = "Settings",
	["nav.about"] = "About",

	["top.active"] = "%d active",
	["top.hide"] = "Hide the window (%s)",
	["top.unload"] = "Unload MultiHub",
	["top.session"] = "Session time",

	["home.welcome"] = "WELCOME TO",
	["home.message"] = "Thanks for using our services. We are committed to bringing the greatest experience to our users!",
	["home.quick"] = "QUICK ACCESS",
	["home.stat.pages"] = "Pages",
	["home.stat.features"] = "Features",
	["home.stat.active"] = "Active now",
	["home.stat.session"] = "Session",

	["pages.eyebrow"] = "ALL TABS",
	["pages.title"] = "Pages",
	["pages.empty.title"] = "No pages yet",
	["pages.empty.hint"] = "Scripts add pages with Window:Tab().",
	["search.placeholder"] = "SEARCH ...",
	["search.count"] = "%d results",
	["search.none.title"] = "No results",
	["search.none.hint"] = "Nothing matches “%s”. Try another word.",
	["search.open"] = "Open",
	["sub.crumb"] = "PAGE",
	["sub.back"] = "Back to Pages",

	["tab.options"] = "%d options",
	["tab.empty"] = "This page has no options yet.",
	["tab.active"] = "%d active",

	["toggle.on"] = "Enabled",
	["toggle.off"] = "Disabled",
	["button.done"] = "Executed",
	["button.failed"] = "Something went wrong. Check the console (F9).",
	["callback.error"] = "Error in “%s”",

	["dropdown.one"] = "Select one",
	["dropdown.many"] = "Select multiple",
	["dropdown.none"] = "None",
	["dropdown.count"] = "%d selected",
	["dropdown.filter"] = "Filter options...",
	["dropdown.all"] = "Select all",
	["dropdown.clear"] = "Clear",
	["dropdown.empty"] = "No options available.",

	["input.placeholder"] = "Type here...",
	["slider.hint"] = "Drag, or click the value to type it",

	["player.eyebrow"] = "CHARACTER",
	["player.title"] = "Player",
	["player.desc"] = "Movement and character tools. The server of each game can override these values.",
	["player.movement"] = "Movement",
	["player.movement.desc"] = "Applied again after every respawn",
	["player.speed"] = "Custom WalkSpeed",
	["player.speed.desc"] = "Uses the WalkSpeed value below",
	["player.speed.value"] = "WalkSpeed",
	["player.jump"] = "Custom jump",
	["player.jump.desc"] = "Applies JumpPower or JumpHeight, whichever this game uses",
	["player.jumppower"] = "JumpPower",
	["player.jumpheight"] = "JumpHeight",
	["player.fly"] = "Fly",
	["player.fly.desc"] = "Move with WASD / stick, Space up, Ctrl down",
	["player.flyspeed"] = "Fly speed",
	["player.noclip"] = "Noclip",
	["player.noclip.desc"] = "Walk through walls and objects",
	["player.tools"] = "Tools",
	["player.tools.desc"] = "Session and character utilities",
	["player.afk"] = "Anti-AFK",
	["player.afk.desc"] = "Prevents the 20-minute idle kick (needs executor permission)",
	["player.afk.unavailable"] = "Anti-AFK is not available in this environment.",
	["player.afk.done"] = "Idle kick prevented.",
	["player.reset"] = "Reset character",
	["player.reset.desc"] = "Same as Esc > Reset",
	["player.respawn"] = "Respawn here",
	["player.respawn.desc"] = "Resets and brings you back to the same spot",
	["player.nochar"] = "Your character is not loaded yet.",
	["player.info"] = "Information",
	["player.info.desc"] = "Live data of your account and character",

	["info.user"] = "User",
	["info.id"] = "User ID",
	["info.age"] = "Account age",
	["info.days"] = "%d days",
	["info.team"] = "Team",
	["info.none"] = "None",
	["info.health"] = "Health",
	["info.speed"] = "WalkSpeed",
	["info.jump"] = "Jump",
	["info.position"] = "Position",
	["info.rig"] = "Rig",
	["info.ping"] = "Ping",

	["perf.eyebrow"] = "OPTIMIZATION",
	["perf.title"] = "Performance",
	["perf.desc"] = "Lighter interface and local graphics options for weaker devices.",
	["perf.library"] = "MultiHub interface",
	["perf.library.desc"] = "Affects only this window",
	["perf.mode"] = "Performance Mode",
	["perf.mode.desc"] = "One click: no animations, reduced effects and lightweight mode",
	["perf.animations"] = "UI animations",
	["perf.animations.desc"] = "Turn off for instant transitions",
	["perf.reduced"] = "Reduce UI effects",
	["perf.reduced.desc"] = "No shadows, glow, blur or transparency",
	["perf.light"] = "Lightweight mode",
	["perf.light.desc"] = "Skips the game thumbnail and slows live counters",
	["perf.hud"] = "FPS display",
	["perf.hud.desc"] = "Small counter on the screen (drag it to move)",
	["perf.graphics"] = "Roblox graphics (this game only)",
	["perf.graphics.desc"] = "Local and reversible: your Roblox settings are not modified",
	["perf.low"] = "Low graphics mode",
	["perf.low.desc"] = "Turns off shadows, post-processing and terrain decoration",
	["perf.particles"] = "Hide particles",
	["perf.particles.desc"] = "Particles, trails, beams, smoke, fire and sparkles",
	["perf.note.title"] = "Graphics quality",
	["perf.note"] = "Roblox does not let scripts change the quality level. Use Esc > Settings > Graphics Quality for that; the options above work together with it.",
	["perf.skipped"] = "%d settings are not allowed here and were skipped.",
	["perf.monitor"] = "Performance monitor",
	["perf.monitor.desc"] = "Live data from documented Roblox APIs",

	["metric.fps"] = "FPS",
	["metric.frame"] = "Frame time",
	["metric.physics"] = "Physics",
	["metric.ping"] = "Ping",
	["metric.memory"] = "Memory",
	["metric.instances"] = "Instances",
	["metric.network"] = "Network in",
	["metric.quality"] = "Graphics quality",
	["metric.auto"] = "Automatic",
	["metric.na"] = "n/a",

	["settings.eyebrow"] = "PREFERENCES",
	["settings.title"] = "Settings",
	["settings.desc"] = "Language, interface style, profiles and session.",
	["settings.interface"] = "Interface",
	["settings.interface.desc"] = "Language and window behavior",
	["settings.language"] = "Language",
	["settings.language.desc"] = "Automatic uses the language of your Roblox account",
	["settings.language.auto"] = "Automatic (%s)",
	["settings.language.changed"] = "Interface language: %s",
	["settings.notifications"] = "Notifications",
	["settings.notifications.desc"] = "Show pop-up messages in the corner",
	["settings.glass"] = "Liquid Glass",
	["settings.glass.desc"] = "Translucent glass with light edges and liquid controls. Off: solid dark-red style",
	["settings.blur"] = "Background blur",
	["settings.blur.desc"] = "Blurs the game behind the open window (uses more GPU)",
	["settings.scale"] = "Interface scale",
	["settings.scale.desc"] = "Size of the window (%)",
	["settings.key"] = "Toggle key",
	["settings.key.desc"] = "Key that shows or hides the window",
	["settings.key.press"] = "Press a key...",
	["settings.key.changed"] = "Toggle key: %s",
	["settings.profiles"] = "Profiles",
	["settings.profiles.desc"] = "Save, load, create or delete named profiles for this game",
	["settings.profile.name"] = "Profile name",
	["settings.profile.placeholder"] = "Default or a custom name",
	["settings.profile.save"] = "Save",
	["settings.profile.load"] = "Load",
	["settings.profile.create"] = "Create",
	["settings.profile.delete"] = "Delete",
	["settings.profile.reset"] = "Reset",
	["settings.profile.stored"] = "Profiles are saved automatically in %s.",
	["settings.profile.nofs"] = "This environment cannot write files: settings last until you leave.",
	["settings.session"] = "Session",
	["settings.session.desc"] = "Close MultiHub completely",
	["settings.unload.desc"] = "Stops every feature and frees all resources",

	["profile.saved"] = "Profile saved: %s",
	["profile.loaded"] = "Profile loaded: %s",
	["profile.created"] = "Profile created: %s",
	["profile.deleted"] = "Profile deleted: %s",
	["profile.reset"] = "Controls reset to their defaults and saved to Default.",
	["profile.err.nofunc"] = "This executor does not provide %s.",
	["profile.err.name"] = "Enter a valid profile name (letters, numbers, - and _).",
	["profile.err.reserved"] = "“Default” is reserved for the automatic profile.",
	["profile.err.nodelete"] = "The automatic Default profile cannot be deleted.",
	["profile.err.exists"] = "A profile with that name already exists.",
	["profile.err.missing"] = "Profile not found: %s",
	["profile.err.invalid"] = "This profile is invalid or from another version.",
	["profile.err.write"] = "Could not save: %s",
	["profile.title"] = "Profiles",
	["profile.error"] = "Profiles · error",

	["about.eyebrow"] = "CREDITS",
	["about.title"] = "About",
	["about.desc"] = "MultiHub community, version and credits.",
	["about.community"] = "Community",
	["about.community.desc"] = "Videos, updates and support",
	["about.credits"] = "Credits",
	["about.credits.text"] = "Original interface by Dev - wendel. Maintained by the MultiHub team. Icons: Lucide and Geist (via Footagesus/Icons).",
	["about.version"] = "Library v%s · %s",

	["link.title"] = "Open %s",
	["link.body"] = "Roblox does not let games open websites. Copy the link and paste it in your browser.",
	["link.copy"] = "Copy link",
	["link.copied"] = "Link copied to the clipboard!",
	["link.manual"] = "Select the link above and press Ctrl+C.",
	["link.close"] = "Close",

	["unload.title"] = "Unload MultiHub?",
	["unload.body"] = "This closes the interface, turns off every feature (fly, noclip, graphics changes...) and frees all resources. You can load it again at any time.",
	["unload.confirm"] = "Unload",
	["unload.cancel"] = "Cancel",

	["notify.loaded"] = "Loaded. Press %s to show or hide.",
	["notify.loaded.touch"] = "Loaded. Tap the floating button to show or hide.",
	["status.fps"] = "%s FPS",
}

I18n.Strings["pt-br"] = {
	["nav.home"] = "Início",
	["nav.pages"] = "Páginas",
	["nav.player"] = "Jogador",
	["nav.performance"] = "Desempenho",
	["nav.settings"] = "Configurações",
	["nav.about"] = "Sobre",

	["top.active"] = "%d ativos",
	["top.hide"] = "Esconder a janela (%s)",
	["top.unload"] = "Encerrar o MultiHub",
	["top.session"] = "Tempo de sessão",

	["home.welcome"] = "BEM-VINDO AO",
	["home.message"] = "Obrigado por usar nossos serviços. Estamos comprometidos em oferecer a melhor experiência aos nossos usuários!",
	["home.quick"] = "ACESSO RÁPIDO",
	["home.stat.pages"] = "Páginas",
	["home.stat.features"] = "Funções",
	["home.stat.active"] = "Ativas agora",
	["home.stat.session"] = "Sessão",

	["pages.eyebrow"] = "TODAS AS ABAS",
	["pages.title"] = "Páginas",
	["pages.empty.title"] = "Nenhuma página ainda",
	["pages.empty.hint"] = "Os scripts criam páginas com Window:Tab().",
	["search.placeholder"] = "BUSCAR ...",
	["search.count"] = "%d resultados",
	["search.none.title"] = "Nenhum resultado",
	["search.none.hint"] = "Nada corresponde a “%s”. Tente outra palavra.",
	["search.open"] = "Abrir",
	["sub.crumb"] = "PÁGINA",
	["sub.back"] = "Voltar para Páginas",

	["tab.options"] = "%d opções",
	["tab.empty"] = "Esta página ainda não tem opções.",
	["tab.active"] = "%d ativas",

	["toggle.on"] = "Ativado",
	["toggle.off"] = "Desativado",
	["button.done"] = "Executado",
	["button.failed"] = "Algo deu errado. Veja o console (F9).",
	["callback.error"] = "Erro em “%s”",

	["dropdown.one"] = "Selecione uma",
	["dropdown.many"] = "Selecione várias",
	["dropdown.none"] = "Nenhum",
	["dropdown.count"] = "%d selecionados",
	["dropdown.filter"] = "Filtrar opções...",
	["dropdown.all"] = "Selecionar tudo",
	["dropdown.clear"] = "Limpar",
	["dropdown.empty"] = "Nenhuma opção disponível.",

	["input.placeholder"] = "Digite aqui...",
	["slider.hint"] = "Arraste ou clique no valor para digitar",

	["player.eyebrow"] = "PERSONAGEM",
	["player.title"] = "Jogador",
	["player.desc"] = "Movimento e ferramentas do personagem. O servidor de cada jogo pode sobrescrever esses valores.",
	["player.movement"] = "Movimento",
	["player.movement.desc"] = "Reaplicado depois de cada respawn",
	["player.speed"] = "WalkSpeed personalizado",
	["player.speed.desc"] = "Usa o valor de WalkSpeed abaixo",
	["player.speed.value"] = "WalkSpeed",
	["player.jump"] = "Pulo personalizado",
	["player.jump.desc"] = "Aplica JumpPower ou JumpHeight, o que este jogo usar",
	["player.jumppower"] = "JumpPower",
	["player.jumpheight"] = "JumpHeight",
	["player.fly"] = "Voar",
	["player.fly.desc"] = "Mova com WASD / analógico, Espaço sobe, Ctrl desce",
	["player.flyspeed"] = "Velocidade de voo",
	["player.noclip"] = "Noclip",
	["player.noclip.desc"] = "Atravessar paredes e objetos",
	["player.tools"] = "Ferramentas",
	["player.tools.desc"] = "Utilidades de sessão e do personagem",
	["player.afk"] = "Anti-AFK",
	["player.afk.desc"] = "Evita a expulsão por inatividade de 20 minutos (precisa de permissão do executor)",
	["player.afk.unavailable"] = "O Anti-AFK não está disponível neste ambiente.",
	["player.afk.done"] = "Expulsão por inatividade evitada.",
	["player.reset"] = "Resetar personagem",
	["player.reset.desc"] = "O mesmo que Esc > Resetar",
	["player.respawn"] = "Renascer aqui",
	["player.respawn.desc"] = "Reseta e te traz de volta ao mesmo lugar",
	["player.nochar"] = "Seu personagem ainda não carregou.",
	["player.info"] = "Informações",
	["player.info.desc"] = "Dados ao vivo da sua conta e do personagem",

	["info.user"] = "Usuário",
	["info.id"] = "ID do usuário",
	["info.age"] = "Idade da conta",
	["info.days"] = "%d dias",
	["info.team"] = "Time",
	["info.none"] = "Nenhum",
	["info.health"] = "Vida",
	["info.speed"] = "WalkSpeed",
	["info.jump"] = "Pulo",
	["info.position"] = "Posição",
	["info.rig"] = "Rig",
	["info.ping"] = "Ping",

	["perf.eyebrow"] = "OTIMIZAÇÃO",
	["perf.title"] = "Desempenho",
	["perf.desc"] = "Interface mais leve e opções gráficas locais para aparelhos mais fracos.",
	["perf.library"] = "Interface do MultiHub",
	["perf.library.desc"] = "Afeta só esta janela",
	["perf.mode"] = "Modo Desempenho",
	["perf.mode.desc"] = "Um clique: sem animações, efeitos reduzidos e modo leve",
	["perf.animations"] = "Animações da interface",
	["perf.animations.desc"] = "Desative para transições instantâneas",
	["perf.reduced"] = "Reduzir efeitos da interface",
	["perf.reduced.desc"] = "Sem sombras, brilho, desfoque ou transparência",
	["perf.light"] = "Modo leve",
	["perf.light.desc"] = "Não carrega a miniatura do jogo e atualiza os contadores mais devagar",
	["perf.hud"] = "Mostrar FPS",
	["perf.hud.desc"] = "Contador pequeno na tela (arraste para mover)",
	["perf.graphics"] = "Gráficos do Roblox (só neste jogo)",
	["perf.graphics.desc"] = "Locais e reversíveis: suas configurações do Roblox não são alteradas",
	["perf.low"] = "Modo gráfico baixo",
	["perf.low.desc"] = "Desliga sombras, pós-processamento e decoração do terreno",
	["perf.particles"] = "Esconder partículas",
	["perf.particles.desc"] = "Partículas, rastros, feixes, fumaça, fogo e faíscas",
	["perf.note.title"] = "Qualidade gráfica",
	["perf.note"] = "O Roblox não deixa scripts mudarem o nível de qualidade. Para isso use Esc > Configurações > Qualidade gráfica; as opções acima funcionam junto com ela.",
	["perf.skipped"] = "%d configurações não são permitidas aqui e foram ignoradas.",
	["perf.monitor"] = "Monitor de desempenho",
	["perf.monitor.desc"] = "Dados ao vivo de APIs documentadas do Roblox",

	["metric.fps"] = "FPS",
	["metric.frame"] = "Tempo de quadro",
	["metric.physics"] = "Física",
	["metric.ping"] = "Ping",
	["metric.memory"] = "Memória",
	["metric.instances"] = "Instâncias",
	["metric.network"] = "Rede (entrada)",
	["metric.quality"] = "Qualidade gráfica",
	["metric.auto"] = "Automática",
	["metric.na"] = "n/d",

	["settings.eyebrow"] = "PREFERÊNCIAS",
	["settings.title"] = "Configurações",
	["settings.desc"] = "Idioma, estilo da interface, perfis e sessão.",
	["settings.interface"] = "Interface",
	["settings.interface.desc"] = "Idioma e comportamento da janela",
	["settings.language"] = "Idioma",
	["settings.language.desc"] = "Automático usa o idioma da sua conta Roblox",
	["settings.language.auto"] = "Automático (%s)",
	["settings.language.changed"] = "Idioma da interface: %s",
	["settings.notifications"] = "Notificações",
	["settings.notifications.desc"] = "Mostrar mensagens no canto da tela",
	["settings.glass"] = "Liquid Glass",
	["settings.glass.desc"] = "Vidro translúcido com bordas de luz e controles líquidos. Desligado: estilo sólido escuro e vermelho",
	["settings.blur"] = "Desfoque do fundo",
	["settings.blur.desc"] = "Desfoca o jogo atrás da janela aberta (usa mais GPU)",
	["settings.scale"] = "Escala da interface",
	["settings.scale.desc"] = "Tamanho da janela (%)",
	["settings.key"] = "Tecla de atalho",
	["settings.key.desc"] = "Tecla que mostra ou esconde a janela",
	["settings.key.press"] = "Pressione uma tecla...",
	["settings.key.changed"] = "Tecla de atalho: %s",
	["settings.profiles"] = "Perfis",
	["settings.profiles.desc"] = "Salve, carregue, crie ou apague perfis deste jogo",
	["settings.profile.name"] = "Nome do perfil",
	["settings.profile.placeholder"] = "Default ou um nome personalizado",
	["settings.profile.save"] = "Salvar",
	["settings.profile.load"] = "Carregar",
	["settings.profile.create"] = "Criar",
	["settings.profile.delete"] = "Apagar",
	["settings.profile.reset"] = "Redefinir",
	["settings.profile.stored"] = "Os perfis são salvos automaticamente em %s.",
	["settings.profile.nofs"] = "Este ambiente não grava arquivos: as configurações duram até você sair.",
	["settings.session"] = "Sessão",
	["settings.session.desc"] = "Fechar o MultiHub por completo",
	["settings.unload.desc"] = "Desliga todas as funções e libera todos os recursos",

	["profile.saved"] = "Perfil salvo: %s",
	["profile.loaded"] = "Perfil carregado: %s",
	["profile.created"] = "Perfil criado: %s",
	["profile.deleted"] = "Perfil apagado: %s",
	["profile.reset"] = "Controles voltaram ao padrão e foram salvos no Default.",
	["profile.err.nofunc"] = "Este executor não oferece %s.",
	["profile.err.name"] = "Digite um nome de perfil válido (letras, números, - e _).",
	["profile.err.reserved"] = "“Default” é reservado para o perfil automático.",
	["profile.err.nodelete"] = "O perfil automático Default não pode ser apagado.",
	["profile.err.exists"] = "Já existe um perfil com esse nome.",
	["profile.err.missing"] = "Perfil não encontrado: %s",
	["profile.err.invalid"] = "Este perfil é inválido ou de outra versão.",
	["profile.err.write"] = "Não foi possível salvar: %s",
	["profile.title"] = "Perfis",
	["profile.error"] = "Perfis · erro",

	["about.eyebrow"] = "CRÉDITOS",
	["about.title"] = "Sobre",
	["about.desc"] = "Comunidade MultiHub, versão e créditos.",
	["about.community"] = "Comunidade",
	["about.community.desc"] = "Vídeos, atualizações e suporte",
	["about.credits"] = "Créditos",
	["about.credits.text"] = "Interface original por Dev - wendel. Mantida pela equipe MultiHub. Ícones: Lucide e Geist (via Footagesus/Icons).",
	["about.version"] = "Library v%s · %s",

	["link.title"] = "Abrir %s",
	["link.body"] = "O Roblox não permite que jogos abram sites. Copie o link e cole no seu navegador.",
	["link.copy"] = "Copiar link",
	["link.copied"] = "Link copiado para a área de transferência!",
	["link.manual"] = "Selecione o link acima e pressione Ctrl+C.",
	["link.close"] = "Fechar",

	["unload.title"] = "Encerrar o MultiHub?",
	["unload.body"] = "Isso fecha a interface, desliga todas as funções (voo, noclip, mudanças gráficas...) e libera todos os recursos. Você pode carregar de novo quando quiser.",
	["unload.confirm"] = "Encerrar",
	["unload.cancel"] = "Cancelar",

	["notify.loaded"] = "Carregado. Pressione %s para mostrar ou esconder.",
	["notify.loaded.touch"] = "Carregado. Toque no botão flutuante para mostrar ou esconder.",
	["status.fps"] = "%s FPS",
}

I18n.Strings.es = {
	["nav.home"] = "Inicio",
	["nav.pages"] = "Páginas",
	["nav.player"] = "Jugador",
	["nav.performance"] = "Rendimiento",
	["nav.settings"] = "Ajustes",
	["nav.about"] = "Acerca de",

	["top.active"] = "%d activas",
	["top.hide"] = "Ocultar la ventana (%s)",
	["top.unload"] = "Cerrar MultiHub",
	["top.session"] = "Tiempo de sesión",

	["home.welcome"] = "BIENVENIDO A",
	["home.message"] = "Gracias por usar nuestros servicios. ¡Estamos comprometidos a ofrecer la mejor experiencia a nuestros usuarios!",
	["home.quick"] = "ACCESO RÁPIDO",
	["home.stat.pages"] = "Páginas",
	["home.stat.features"] = "Funciones",
	["home.stat.active"] = "Activas ahora",
	["home.stat.session"] = "Sesión",

	["pages.eyebrow"] = "TODAS LAS PESTAÑAS",
	["pages.title"] = "Páginas",
	["pages.empty.title"] = "Aún no hay páginas",
	["pages.empty.hint"] = "Los scripts crean páginas con Window:Tab().",
	["search.placeholder"] = "BUSCAR ...",
	["search.count"] = "%d resultados",
	["search.none.title"] = "Sin resultados",
	["search.none.hint"] = "Nada coincide con “%s”. Prueba otra palabra.",
	["search.open"] = "Abrir",
	["sub.crumb"] = "PÁGINA",
	["sub.back"] = "Volver a Páginas",

	["tab.options"] = "%d opciones",
	["tab.empty"] = "Esta página aún no tiene opciones.",
	["tab.active"] = "%d activas",

	["toggle.on"] = "Activado",
	["toggle.off"] = "Desactivado",
	["button.done"] = "Ejecutado",
	["button.failed"] = "Algo salió mal. Revisa la consola (F9).",
	["callback.error"] = "Error en “%s”",

	["dropdown.one"] = "Elige una",
	["dropdown.many"] = "Elige varias",
	["dropdown.none"] = "Ninguno",
	["dropdown.count"] = "%d seleccionados",
	["dropdown.filter"] = "Filtrar opciones...",
	["dropdown.all"] = "Seleccionar todo",
	["dropdown.clear"] = "Limpiar",
	["dropdown.empty"] = "No hay opciones disponibles.",

	["input.placeholder"] = "Escribe aquí...",
	["slider.hint"] = "Arrastra o haz clic en el valor para escribirlo",

	["player.eyebrow"] = "PERSONAJE",
	["player.title"] = "Jugador",
	["player.desc"] = "Movimiento y herramientas del personaje. El servidor de cada juego puede sobrescribir estos valores.",
	["player.movement"] = "Movimiento",
	["player.movement.desc"] = "Se vuelve a aplicar después de cada reaparición",
	["player.speed"] = "WalkSpeed personalizado",
	["player.speed.desc"] = "Usa el valor de WalkSpeed de abajo",
	["player.speed.value"] = "WalkSpeed",
	["player.jump"] = "Salto personalizado",
	["player.jump.desc"] = "Aplica JumpPower o JumpHeight, lo que use este juego",
	["player.jumppower"] = "JumpPower",
	["player.jumpheight"] = "JumpHeight",
	["player.fly"] = "Volar",
	["player.fly.desc"] = "Muévete con WASD / stick, Espacio sube, Ctrl baja",
	["player.flyspeed"] = "Velocidad de vuelo",
	["player.noclip"] = "Noclip",
	["player.noclip.desc"] = "Atravesar paredes y objetos",
	["player.tools"] = "Herramientas",
	["player.tools.desc"] = "Utilidades de sesión y del personaje",
	["player.afk"] = "Anti-AFK",
	["player.afk.desc"] = "Evita la expulsión por inactividad de 20 minutos (necesita permiso del ejecutor)",
	["player.afk.unavailable"] = "El Anti-AFK no está disponible en este entorno.",
	["player.afk.done"] = "Expulsión por inactividad evitada.",
	["player.reset"] = "Reiniciar personaje",
	["player.reset.desc"] = "Lo mismo que Esc > Reiniciar",
	["player.respawn"] = "Reaparecer aquí",
	["player.respawn.desc"] = "Reinicia y te devuelve al mismo lugar",
	["player.nochar"] = "Tu personaje aún no ha cargado.",
	["player.info"] = "Información",
	["player.info.desc"] = "Datos en vivo de tu cuenta y tu personaje",

	["info.user"] = "Usuario",
	["info.id"] = "ID de usuario",
	["info.age"] = "Antigüedad",
	["info.days"] = "%d días",
	["info.team"] = "Equipo",
	["info.none"] = "Ninguno",
	["info.health"] = "Vida",
	["info.speed"] = "WalkSpeed",
	["info.jump"] = "Salto",
	["info.position"] = "Posición",
	["info.rig"] = "Rig",
	["info.ping"] = "Ping",

	["perf.eyebrow"] = "OPTIMIZACIÓN",
	["perf.title"] = "Rendimiento",
	["perf.desc"] = "Interfaz más ligera y opciones gráficas locales para dispositivos más débiles.",
	["perf.library"] = "Interfaz de MultiHub",
	["perf.library.desc"] = "Solo afecta a esta ventana",
	["perf.mode"] = "Modo Rendimiento",
	["perf.mode.desc"] = "Un clic: sin animaciones, efectos reducidos y modo ligero",
	["perf.animations"] = "Animaciones de la interfaz",
	["perf.animations.desc"] = "Desactívalas para transiciones instantáneas",
	["perf.reduced"] = "Reducir efectos de la interfaz",
	["perf.reduced.desc"] = "Sin sombras, brillo, desenfoque ni transparencia",
	["perf.light"] = "Modo ligero",
	["perf.light.desc"] = "No carga la miniatura del juego y actualiza los contadores más despacio",
	["perf.hud"] = "Mostrar FPS",
	["perf.hud.desc"] = "Contador pequeño en la pantalla (arrástralo para moverlo)",
	["perf.graphics"] = "Gráficos de Roblox (solo en este juego)",
	["perf.graphics.desc"] = "Locales y reversibles: tu configuración de Roblox no se modifica",
	["perf.low"] = "Modo gráfico bajo",
	["perf.low.desc"] = "Desactiva sombras, posprocesado y decoración del terreno",
	["perf.particles"] = "Ocultar partículas",
	["perf.particles.desc"] = "Partículas, estelas, haces, humo, fuego y chispas",
	["perf.note.title"] = "Calidad gráfica",
	["perf.note"] = "Roblox no permite que los scripts cambien el nivel de calidad. Para eso usa Esc > Configuración > Calidad gráfica; las opciones de arriba funcionan junto con ella.",
	["perf.skipped"] = "%d ajustes no están permitidos aquí y se omitieron.",
	["perf.monitor"] = "Monitor de rendimiento",
	["perf.monitor.desc"] = "Datos en vivo de APIs documentadas de Roblox",

	["metric.fps"] = "FPS",
	["metric.frame"] = "Tiempo de fotograma",
	["metric.physics"] = "Física",
	["metric.ping"] = "Ping",
	["metric.memory"] = "Memoria",
	["metric.instances"] = "Instancias",
	["metric.network"] = "Red (entrada)",
	["metric.quality"] = "Calidad gráfica",
	["metric.auto"] = "Automática",
	["metric.na"] = "n/d",

	["settings.eyebrow"] = "PREFERENCIAS",
	["settings.title"] = "Ajustes",
	["settings.desc"] = "Idioma, estilo de la interfaz, perfiles y sesión.",
	["settings.interface"] = "Interfaz",
	["settings.interface.desc"] = "Idioma y comportamiento de la ventana",
	["settings.language"] = "Idioma",
	["settings.language.desc"] = "Automático usa el idioma de tu cuenta de Roblox",
	["settings.language.auto"] = "Automático (%s)",
	["settings.language.changed"] = "Idioma de la interfaz: %s",
	["settings.notifications"] = "Notificaciones",
	["settings.notifications.desc"] = "Mostrar mensajes en la esquina de la pantalla",
	["settings.glass"] = "Liquid Glass",
	["settings.glass.desc"] = "Vidrio translúcido con bordes de luz y controles líquidos. Apagado: estilo sólido oscuro y rojo",
	["settings.blur"] = "Desenfoque del fondo",
	["settings.blur.desc"] = "Desenfoca el juego detrás de la ventana abierta (usa más GPU)",
	["settings.scale"] = "Escala de la interfaz",
	["settings.scale.desc"] = "Tamaño de la ventana (%)",
	["settings.key"] = "Tecla de acceso",
	["settings.key.desc"] = "Tecla que muestra u oculta la ventana",
	["settings.key.press"] = "Pulsa una tecla...",
	["settings.key.changed"] = "Tecla de acceso: %s",
	["settings.profiles"] = "Perfiles",
	["settings.profiles.desc"] = "Guarda, carga, crea o elimina perfiles de este juego",
	["settings.profile.name"] = "Nombre del perfil",
	["settings.profile.placeholder"] = "Default o un nombre personalizado",
	["settings.profile.save"] = "Guardar",
	["settings.profile.load"] = "Cargar",
	["settings.profile.create"] = "Crear",
	["settings.profile.delete"] = "Eliminar",
	["settings.profile.reset"] = "Restablecer",
	["settings.profile.stored"] = "Los perfiles se guardan automáticamente en %s.",
	["settings.profile.nofs"] = "Este entorno no puede guardar archivos: los ajustes duran hasta que salgas.",
	["settings.session"] = "Sesión",
	["settings.session.desc"] = "Cerrar MultiHub por completo",
	["settings.unload.desc"] = "Desactiva todas las funciones y libera todos los recursos",

	["profile.saved"] = "Perfil guardado: %s",
	["profile.loaded"] = "Perfil cargado: %s",
	["profile.created"] = "Perfil creado: %s",
	["profile.deleted"] = "Perfil eliminado: %s",
	["profile.reset"] = "Los controles volvieron a sus valores por defecto y se guardaron en Default.",
	["profile.err.nofunc"] = "Este ejecutor no ofrece %s.",
	["profile.err.name"] = "Escribe un nombre de perfil válido (letras, números, - y _).",
	["profile.err.reserved"] = "“Default” está reservado para el perfil automático.",
	["profile.err.nodelete"] = "El perfil automático Default no se puede eliminar.",
	["profile.err.exists"] = "Ya existe un perfil con ese nombre.",
	["profile.err.missing"] = "Perfil no encontrado: %s",
	["profile.err.invalid"] = "Este perfil no es válido o es de otra versión.",
	["profile.err.write"] = "No se pudo guardar: %s",
	["profile.title"] = "Perfiles",
	["profile.error"] = "Perfiles · error",

	["about.eyebrow"] = "CRÉDITOS",
	["about.title"] = "Acerca de",
	["about.desc"] = "Comunidad MultiHub, versión y créditos.",
	["about.community"] = "Comunidad",
	["about.community.desc"] = "Videos, novedades y soporte",
	["about.credits"] = "Créditos",
	["about.credits.text"] = "Interfaz original de Dev - wendel. Mantenida por el equipo MultiHub. Iconos: Lucide y Geist (vía Footagesus/Icons).",
	["about.version"] = "Library v%s · %s",

	["link.title"] = "Abrir %s",
	["link.body"] = "Roblox no permite que los juegos abran sitios web. Copia el enlace y pégalo en tu navegador.",
	["link.copy"] = "Copiar enlace",
	["link.copied"] = "¡Enlace copiado al portapapeles!",
	["link.manual"] = "Selecciona el enlace de arriba y pulsa Ctrl+C.",
	["link.close"] = "Cerrar",

	["unload.title"] = "¿Cerrar MultiHub?",
	["unload.body"] = "Esto cierra la interfaz, desactiva todas las funciones (vuelo, noclip, cambios gráficos...) y libera todos los recursos. Puedes cargarlo de nuevo cuando quieras.",
	["unload.confirm"] = "Cerrar",
	["unload.cancel"] = "Cancelar",

	["notify.loaded"] = "Cargado. Pulsa %s para mostrar u ocultar.",
	["notify.loaded.touch"] = "Cargado. Toca el botón flotante para mostrar u ocultar.",
	["status.fps"] = "%s FPS",
}

-- == UTIL ==================================================================

local Util = {}
-- Every connection to a global signal goes through Util.track so Library:Destroy() can close it.
local Maid = { connections = {}, cleanups = {}, alive = true }

function Util.track(connection)
	table.insert(Maid.connections, connection)
	return connection
end

-- Functions run by Unload before the GUI is destroyed (undo character / graphics changes).
function Util.onCleanup(callback)
	table.insert(Maid.cleanups, callback)
end

function Util.merge(defaults, overrides)
	local result = table.clone(defaults)
	for key, value in overrides or {} do
		result[key] = value
	end
	return result
end

-- Parent is applied last so layout is not recalculated for every property.
function Util.create(className, props, children)
	local instance = Instance.new(className)
	if instance:IsA("GuiObject") and (instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")) then
		-- Our own translations replace Roblox's automatic translation ("Home" would become "Casa").
		instance.AutoLocalize = false
	end
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end
local create = Util.create

function Util.corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function Util.stroke(color, transparency, thickness)
	return create("UIStroke", {
		Color = color or THEME.StrokeSoft,
		Transparency = transparency or 0,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Util.padding(left, right, top, bottom)
	return create("UIPadding", {
		PaddingLeft = UDim.new(0, left or 0),
		PaddingRight = UDim.new(0, right or left or 0),
		PaddingTop = UDim.new(0, top or left or 0),
		PaddingBottom = UDim.new(0, bottom or top or left or 0),
	})
end

function Util.list(gap, direction, props)
	return create("UIListLayout", Util.merge({
		Padding = UDim.new(0, gap or 0),
		FillDirection = direction or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, props))
end

function Util.vgradient(transparencyTop, transparencyBottom, rotation)
	return create("UIGradient", {
		Rotation = rotation or 90,
		Transparency = NumberSequence.new(transparencyTop, transparencyBottom),
	})
end

-- Prefs is defined below; the animations switch makes every tween instant.
local Prefs
function Util.tween(instance, duration, goal, style, direction)
	if Prefs and not Prefs.animations then
		duration = 0
	end
	local tw = TweenService:Create(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
		goal
	)
	tw:Play()
	return tw
end
local tween = Util.tween

function Util.label(props)
	return create("TextLabel", Util.merge({
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = FONT.Medium,
		TextColor3 = THEME.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, props))
end
local label = Util.label

function Util.clear(container)
	for _, child in container:GetChildren() do
		if not child:IsA("UIBase") then -- keeps layouts, paddings, corners and constraints
			child:Destroy()
		end
	end
end

function Util.hex(color)
	return "#" .. color:ToHex()
end

function Util.isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- Slug used for stable config ids ("Auto Farm" -> "auto_farm").
function Util.slug(text)
	text = string.lower(tostring(text or ""))
	text = string.gsub(text, "[^%w]+", "_")
	text = string.gsub(text, "^_+", "")
	text = string.gsub(text, "_+$", "")
	return text ~= "" and text or "item"
end

function Util.keyName(keyCode)
	if typeof(keyCode) == "EnumItem" then
		return keyCode.Name
	end
	return tostring(keyCode)
end

-- Hover only on mouse: on touch, MouseLeave is unreliable and the state would get stuck.
function Util.hover(button, onEnter, onLeave)
	if IS_TOUCH then
		return
	end
	button.MouseEnter:Connect(onEnter)
	button.MouseLeave:Connect(onLeave)
end

-- Small press "squish" for any button.
function Util.pressScale(button, amount)
	local scale = button:FindFirstChild("Press") or create("UIScale", { Name = "Press", Parent = button })
	button.InputBegan:Connect(function(input)
		if Util.isPress(input) then
			tween(scale, 0.08, { Scale = amount or 0.97 })
		end
	end)
	button.InputEnded:Connect(function(input)
		if Util.isPress(input) then
			tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)
	return scale
end

function Util.httpGet(url)
	local ok, body = pcall(function()
		return (game :: any):HttpGet(url) -- executor API; Studio falls back to request()/nil
	end)
	if ok and type(body) == "string" and #body > 0 then
		return body
	end
	local request = (env.syn and env.syn.request) or env.request or env.http_request or (env.http and env.http.request)
	if type(request) == "function" then
		local reqOk, response = pcall(request, { Url = url, Method = "GET" })
		if reqOk and type(response) == "table" and type(response.Body) == "string" and #response.Body > 0 then
			return response.Body
		end
	end
	return nil
end

function Util.copy(text)
	local clipboard = env.setclipboard or env.toclipboard or env.set_clipboard
	if not clipboard and env.syn then
		clipboard = env.syn.setclipboard or env.syn.set_clipboard
	end
	if type(clipboard) == "function" then
		return (pcall(clipboard, tostring(text)))
	end
	return false
end

-- Game info (name + icon), fetched once. GetProductInfoAsync is the current API;
-- GetProductInfo (deprecated) is the fallback for older clients. Yields: call from a task.
local productInfo, productWaiters = nil, nil
function Util.productInfo()
	if productInfo ~= nil then
		return productInfo or nil
	end
	if productWaiters then
		table.insert(productWaiters, coroutine.running())
		return coroutine.yield()
	end
	productWaiters = {}
	local ok, info = pcall(function()
		return (MarketplaceService :: any):GetProductInfoAsync(game.PlaceId)
	end)
	if not ok or type(info) ~= "table" then
		ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(game.PlaceId)
		end)
	end
	productInfo = (ok and type(info) == "table") and info or false
	local waiters = productWaiters
	productWaiters = nil
	for _, thread in waiters do
		task.spawn(thread, productInfo or nil)
	end
	return productInfo or nil
end

function Util.fs(name)
	local fn = env[name]
	return type(fn) == "function" and fn or nil
end

-- == ICONS =================================================================
-- Icons come from github.com/Footagesus/Icons (only the sets actually used are downloaded).
-- Until a set arrives (or when HttpGet/loadstring are unavailable, e.g. Studio) a text glyph is shown.

local Icons = {
	Source = "https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/%s/dist/Icons.lua",
	Sets = { lucide = true, solar = true, craft = true, geist = true, sfsymbols = true, gravity = true },
	Libs = {}, -- set -> table | false
	Targets = {},
	Loading = false,
}

function Icons.parse(spec)
	spec = tostring(spec or "")
	if string.find(spec, "^rbxasset") or string.find(spec, "^https?://") then
		return "asset", spec
	end
	if string.match(spec, "^%d+$") then
		return "asset", "rbxassetid://" .. spec
	end
	local setName, name = string.match(spec, "^(%w+):(.+)$")
	if setName and Icons.Sets[setName] then
		return setName, name
	end
	return CONFIG.IconSet, spec
end

local function toVector2(value)
	if typeof(value) == "Vector2" then
		return value
	end
	if type(value) == "table" then
		return Vector2.new(value[1] or value.X or 0, value[2] or value.Y or 0)
	end
	return nil
end

-- Accepts both module shapes: { name = "rbxassetid://.." } and { Icons = {...}, Spritesheets = {...} }.
function Icons.resolve(setName, name)
	local lib = Icons.Libs[setName]
	if not lib then
		return nil
	end
	local entry = (type(lib.Icons) == "table" and lib.Icons[name]) or lib[name]
	if type(entry) == "string" then
		return { Image = entry }
	end
	if type(entry) ~= "table" then
		return nil
	end
	local image = entry.Image
	if type(image) == "number" and type(lib.Spritesheets) == "table" then
		image = lib.Spritesheets[tostring(image)] or lib.Spritesheets[image]
	end
	if type(image) == "number" then
		image = "rbxassetid://" .. image
	end
	if type(image) ~= "string" then
		return nil
	end
	return {
		Image = image,
		RectOffset = toVector2(entry.ImageRectPosition or entry.ImageRectOffset),
		RectSize = toVector2(entry.ImageRectSize),
	}
end

function Icons.apply(target)
	if target.applied or not target.image.Parent then
		return
	end
	local data
	if target.set == "asset" then
		data = { Image = target.name }
	else
		data = Icons.resolve(target.set, target.name)
	end
	if not data then
		return
	end
	target.applied = true
	target.image.Image = data.Image
	if data.RectOffset then
		target.image.ImageRectOffset = data.RectOffset
	end
	if data.RectSize then
		target.image.ImageRectSize = data.RectSize
	end
	target.fallback.Visible = false
	target.image.Visible = true
end

function Icons.load(setName)
	if Icons.Libs[setName] ~= nil then
		return Icons.Libs[setName]
	end
	Icons.Libs[setName] = false
	if not Icons.Sets[setName] or type(env.loadstring) ~= "function" then
		return false
	end
	local body = Util.httpGet(string.format(Icons.Source, setName))
	if not body then
		return false
	end
	local ok, lib = pcall(function()
		return env.loadstring(body)()
	end)
	if ok and type(lib) == "table" then
		Icons.Libs[setName] = lib
	else
		warn("[MultiHub] icon set '" .. setName .. "' failed to load: " .. tostring(lib))
	end
	return Icons.Libs[setName]
end

-- Returns holder, setColor(color). The glyph fallback keeps the layout identical without icons.
function Icons.make(parent, spec, size, color, props, glyph)
	local setName, name = Icons.parse(spec)
	local holder = create("Frame", Util.merge({
		Name = "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	}, props))
	local fallback = label({
		Text = glyph or string.upper(string.sub(name, 1, 1)),
		FontFace = FONT.Bold,
		TextSize = math.max(math.floor(size * 0.8), 8),
		TextColor3 = color or THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Size = UDim2.fromScale(1, 1),
		ZIndex = holder.ZIndex,
		Parent = holder,
	})
	local image = create("ImageLabel", {
		BackgroundTransparency = 1,
		ImageColor3 = color or THEME.Text,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = holder.ZIndex,
		Parent = holder,
	})
	local target = { set = setName, name = name, image = image, fallback = fallback, applied = false }
	if setName == "asset" or Icons.Libs[setName] then
		Icons.apply(target)
	end
	if not target.applied then
		table.insert(Icons.Targets, target)
		Icons.scheduleLoad()
	end
	local function setColor(newColor, animate)
		if animate then
			tween(image, 0.18, { ImageColor3 = newColor })
			tween(fallback, 0.18, { TextColor3 = newColor })
		else
			image.ImageColor3 = newColor
			fallback.TextColor3 = newColor
		end
	end
	return holder, setColor
end

-- One background job downloads the missing sets and applies every pending icon.
function Icons.scheduleLoad()
	if Icons.Loading then
		return
	end
	Icons.Loading = true
	task.defer(function()
		while Maid.alive do
			local pending = Icons.Targets
			Icons.Targets = {}
			if #pending == 0 then
				break
			end
			local needed = {}
			for _, target in pending do
				if target.set ~= "asset" then
					needed[target.set] = true
				end
			end
			for setName in needed do
				Icons.load(setName)
			end
			for _, target in pending do
				Icons.apply(target)
			end
		end
		Icons.Loading = false
	end)
end

-- == PREFS =================================================================
-- Interface preferences shared by every game: <ConfigFolder>/Settings.json

Prefs = {
	language = "auto", -- "auto" | "en" | "pt-br" | "es" | any added language
	notifications = true,
	animations = true, -- UI animations
	glass = true, -- Liquid Glass style
	blur = false, -- background blur while the window is open (BlurEffect in the camera)
	reduced = false, -- no shadows / glow / transparency
	lightweight = false, -- no thumbnail, slower live counters
	fpsHud = false, -- on-screen FPS counter
	perfMode = false, -- Performance Mode preset
	perfSnapshot = {}, -- values restored when Performance Mode is turned off
	scale = 100,
	toggleKey = CONFIG.ToggleKey.Name,
	_saved = {}, -- keys that came from the file (not written back)
}
local PREFS_FILE = CONFIG.ConfigFolder .. "/Settings.json"
local PREFS_TYPES = {
	language = "string",
	notifications = "boolean",
	animations = "boolean",
	glass = "boolean",
	blur = "boolean",
	reduced = "boolean",
	lightweight = "boolean",
	fpsHud = "boolean",
	perfMode = "boolean",
	perfSnapshot = "table",
	scale = "number",
	toggleKey = "string",
}

local function ensureFolder(path)
	local isfolder, makefolder = Util.fs("isfolder"), Util.fs("makefolder")
	if not (isfolder and makefolder) then
		return
	end
	local ok, exists = pcall(isfolder, path)
	if not ok or not exists then
		pcall(makefolder, path)
	end
end

local function loadPrefs()
	local isfile, readfile = Util.fs("isfile"), Util.fs("readfile")
	if not (isfile and readfile) then
		return false
	end
	local okExists, exists = pcall(isfile, PREFS_FILE)
	if not okExists or not exists then
		return false
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(PREFS_FILE))
	end)
	if not ok or type(data) ~= "table" then
		warn("[MultiHub] Settings.json is invalid and was ignored.")
		return false
	end
	for key, expected in PREFS_TYPES do
		if type(data[key]) == expected then
			Prefs[key] = data[key]
			Prefs._saved[key] = true
		end
	end
	Prefs.scale = math.clamp(math.floor(Prefs.scale + 0.5), 60, 140)
	return true
end

local prefsQueued = false
local function savePrefs()
	if prefsQueued then
		return
	end
	prefsQueued = true
	task.delay(0.4, function()
		prefsQueued = false
		local writefile = Util.fs("writefile")
		if not writefile or not Maid.alive then
			return
		end
		ensureFolder(CONFIG.ConfigFolder)
		local data = {}
		for key in PREFS_TYPES do
			data[key] = Prefs[key]
		end
		local ok, err = pcall(function()
			writefile(PREFS_FILE, HttpService:JSONEncode(data))
		end)
		if not ok then
			warn("[MultiHub] could not save Settings.json: " .. tostring(err))
		end
	end)
end

loadPrefs()

-- Saved choice > Roblox account language > English.
local function resolveLanguagePref()
	if Prefs.language ~= "auto" then
		local manual = I18n.normalize(Prefs.language)
		if manual then
			return manual
		end
	end
	return I18n.detect() or I18n.Default
end
I18n.Current = resolveLanguagePref()

local function toggleKeyCode()
	local ok, keyCode = pcall(function()
		return Enum.KeyCode[Prefs.toggleKey]
	end)
	return (ok and keyCode) or CONFIG.ToggleKey
end

-- == STORE =================================================================
-- Values of every control + named profiles: <ConfigFolder>/Config/MultiHub_<game>[__profile].json

local TABS = {} -- { id, title, desc, icon, sections = { { name, desc, items } }, example }
local State = {} -- id -> current value
local Handlers = {} -- id -> callback
local Elements = {} -- id -> element (public object returned to scripts)
local Live = {} -- id -> { [row Instance] = render }; strong keys, removed on Destroying
local Store = {
	ConfigData = {},
	Active = "Default",
	Loaded = false,
	Started = false,
	Path = nil,
	OnChange = nil, -- set by the UI (active counters)
}
local SAVEABLE = { toggle = true, slider = true, dropdown = true, multidropdown = true, inputbox = true }

-- Saved in profiles: every saveable control except internal settings and noSave items.
function Store.persistent(item)
	return SAVEABLE[item.type] == true and not item.internal and not item.noSave
end

local function inList(list, value)
	for _, entry in list do
		if entry == value then
			return true
		end
	end
	return false
end

-- Validates / normalizes a value for the item type; nil = invalid.
local function sanitize(item, value)
	local kind = item.type
	if kind == "toggle" then
		if type(value) == "boolean" then
			return value
		end
		return nil
	elseif kind == "inputbox" then
		if type(value) == "number" then
			value = tostring(value)
		end
		if type(value) ~= "string" then
			return nil
		end
		return string.sub(value, 1, item.maxLength or 150)
	elseif kind == "slider" then
		value = tonumber(value)
		if not value or value ~= value then -- NaN guard
			return nil
		end
		local step = item.step or 1
		value = item.min + math.floor((value - item.min) / step + 0.5) * step
		value = math.clamp(value, item.min, item.max)
		-- Removes float noise such as 0.30000000000000004 for decimal steps.
		local decimals = string.match(tostring(step), "%.(%d+)$")
		if decimals then
			local factor = 10 ^ #decimals
			value = math.floor(value * factor + 0.5) / factor
		end
		return value
	elseif kind == "dropdown" then
		return (type(value) == "string" and inList(item.options, value)) and value or nil
	elseif kind == "multidropdown" then
		if type(value) ~= "table" then
			return nil
		end
		local result = {}
		for _, option in item.options do -- keeps the order of the options
			if inList(value, option) then
				table.insert(result, option)
			end
		end
		return result
	end
	return nil
end

local function defaultValue(item)
	local kind = item.type
	if kind == "toggle" then
		return item.default == true
	elseif kind == "inputbox" then
		return sanitize(item, item.default) or ""
	elseif kind == "slider" then
		return sanitize(item, item.default) or item.min
	elseif kind == "dropdown" then
		return sanitize(item, item.default) or item.options[1]
	elseif kind == "multidropdown" then
		return sanitize(item, item.default or {}) or {}
	end
	return nil
end

local function refreshLive(id)
	local rows = Live[id]
	if not rows then
		return
	end
	for row, render in rows do
		if row.Parent == nil then
			rows[row] = nil
		else
			local ok, err = pcall(render, true)
			if not ok then
				warn("[MultiHub] render failed for '" .. tostring(id) .. "': " .. tostring(err))
			end
		end
	end
end

-- Each visible row registers its render function; it leaves automatically when destroyed.
local function bindLive(id, row, render)
	Live[id] = Live[id] or {}
	Live[id][row] = render
	row.Destroying:Connect(function()
		if Live[id] then
			Live[id][row] = nil
		end
	end)
end

-- Callback errors are reported (console with traceback + one toast every 5 s), never hidden.
local lastErrorToast = {}
local notify -- defined with the notification UI
local function fire(id, ...)
	local handler = Handlers[id]
	if type(handler) ~= "function" then
		return true
	end
	local ok, err = xpcall(handler, debug.traceback, ...)
	if not ok then
		warn(("[MultiHub] callback '%s' failed:\n%s"):format(tostring(id), tostring(err)))
		local element = Elements[id]
		local now = os.clock()
		if notify and (lastErrorToast[id] or 0) + 5 < now then
			lastErrorToast[id] = now
			local title = element and I18n.resolve(element.Item.labelRaw) or tostring(id)
			notify(I18n.t("callback.error", title), I18n.t("button.failed"), 4, "error")
		end
	end
	return ok
end

-- Files --------------------------------------------------------------------

local function normalizeProfile(value)
	if type(value) ~= "string" then
		return nil
	end
	local name = string.gsub(string.gsub(value, "^%s+", ""), "%s+$", "")
	name = string.gsub(string.gsub(string.gsub(name, "[^%w%s_%-]", ""), "%s+", "_"), "_+", "_")
	name = string.gsub(string.gsub(string.sub(name, 1, 32), "^_+", ""), "_+$", "")
	if name == "" then
		return nil
	end
	if string.lower(name) == "default" then
		return "Default"
	end
	return name
end

-- Resolving the game name yields (GetProductInfo), so it runs inside the loader thread.
local function configBasePath()
	if not Store.Path then
		local gameName = "Place_" .. tostring(game.PlaceId)
		local info = Util.productInfo()
		if info and type(info.Name) == "string" then
			local raw = string.gsub(string.gsub(info.Name, "[^%w_ ]", ""), "%s+", "_")
			if raw ~= "" then
				gameName = raw
			end
		end
		Store.Path = CONFIG.ConfigFolder .. "/Config/MultiHub_" .. gameName .. ".json"
	end
	return Store.Path
end

local function profileFile(name)
	local base = configBasePath()
	local profile = normalizeProfile(name)
	if not profile or profile == "Default" then
		return base
	end
	return (string.gsub(base, "%.json$", "")) .. "__" .. profile .. ".json"
end

local function ensureConfigFolders()
	ensureFolder(CONFIG.ConfigFolder)
	ensureFolder(CONFIG.ConfigFolder .. "/Config")
end

local function profileExists(path)
	local isfile = Util.fs("isfile")
	if not isfile then
		return false, I18n.t("profile.err.nofunc", "isfile")
	end
	local ok, exists = pcall(isfile, path)
	if not ok then
		return false, tostring(exists)
	end
	return exists == true, nil
end

-- Saved value of an element: stable id first, then the v1 counter id (old profiles).
local function savedValue(element)
	local data = Store.ConfigData
	local value = data[element.Id]
	if value == nil and element.Item.legacyId then
		value = data[element.Item.legacyId]
	end
	return value
end

function Store.save(name)
	local writefile = Util.fs("writefile")
	if not writefile then
		return false, I18n.t("profile.err.nofunc", "writefile")
	end
	local profile = normalizeProfile(name) or normalizeProfile(Store.Active) or "Default"
	ensureConfigFolders()
	local data = { _version = CONFIG.Version }
	for id, element in Elements do
		if Store.persistent(element.Item) then
			data[id] = State[id]
		end
	end
	local ok, err = pcall(function()
		writefile(profileFile(profile), HttpService:JSONEncode(data))
	end)
	if not ok then
		warn("[MultiHub] save failed: " .. tostring(err))
		return false, I18n.t("profile.err.write", tostring(err))
	end
	Store.ConfigData = data
	Store.Active = profile
	return true
end

function Store.read(name)
	local profile = normalizeProfile(name) or normalizeProfile(Store.Active) or "Default"
	local path = profileFile(profile)
	local exists, existsError = profileExists(path)
	if not exists then
		return false, existsError or I18n.t("profile.err.missing", profile)
	end
	local readfile = Util.fs("readfile")
	if not readfile then
		return false, I18n.t("profile.err.nofunc", "readfile")
	end
	local ok, result = pcall(function()
		return HttpService:JSONDecode(readfile(path))
	end)
	if not ok or type(result) ~= "table" or result._version ~= CONFIG.Version then
		return false, I18n.t("profile.err.invalid")
	end
	Store.ConfigData = result
	Store.Active = profile
	return true
end

function Store.create(name)
	local profile = normalizeProfile(name)
	if not profile then
		return false, I18n.t("profile.err.name")
	end
	if profile == "Default" then
		return false, I18n.t("profile.err.reserved")
	end
	ensureConfigFolders()
	local exists, existsError = profileExists(profileFile(profile))
	if existsError then
		return false, existsError
	end
	if exists then
		return false, I18n.t("profile.err.exists")
	end
	return Store.save(profile)
end

function Store.delete(name)
	local profile = normalizeProfile(name)
	if not profile then
		return false, I18n.t("profile.err.name")
	end
	if profile == "Default" then
		return false, I18n.t("profile.err.nodelete")
	end
	local delfile = Util.fs("delfile")
	if not delfile then
		return false, I18n.t("profile.err.nofunc", "delfile")
	end
	local path = profileFile(profile)
	local exists, existsError = profileExists(path)
	if existsError then
		return false, existsError
	end
	if not exists then
		return false, I18n.t("profile.err.missing", profile)
	end
	local ok, err = pcall(delfile, path)
	if not ok then
		return false, tostring(err)
	end
	if Store.Active == profile then
		Store.Active = "Default"
	end
	return true
end

-- Applies the loaded profile to every element (and fires callbacks, like v1 did on Load).
function Store.applyAll()
	for _, element in Elements do
		if Store.persistent(element.Item) then
			local value = savedValue(element)
			if value == nil then
				value = defaultValue(element.Item)
			end
			if value ~= nil then
				element:Set(value, true)
			end
		end
	end
end

function Store.reset()
	Store.Active = "Default"
	Store.ConfigData = { _version = CONFIG.Version }
	for _, element in Elements do
		if Store.persistent(element.Item) then
			local value = defaultValue(element.Item)
			if value ~= nil then
				element:Set(value, true)
			end
		end
	end
	return Store.save("Default")
end

-- Writes 0.6 s after the last change (dragging a slider does not hit the disk every pixel).
local saveQueued = false
function Store.queueSave()
	if saveQueued or not Store.Loaded then
		return -- before the profile is read, saving would overwrite it with defaults
	end
	saveQueued = true
	task.delay(0.6, function()
		saveQueued = false
		if Maid.alive then
			Store.save()
		end
	end)
end

-- Called once per element when its value comes from the profile on startup: same rules as v1.
local function applyStartupValue(element)
	local item = element.Item
	local saved = sanitize(item, savedValue(element))
	if saved ~= nil then
		State[element.Id] = saved
		element.Value = saved
	end
	local value = State[element.Id]
	local shouldFire
	if item.type == "toggle" then
		shouldFire = value == true
	elseif item.type == "multidropdown" then
		shouldFire = #value > 0
	else
		shouldFire = saved ~= nil or item.default ~= nil
	end
	refreshLive(element.Id)
	if shouldFire then
		task.defer(fire, element.Id, value)
	end
end

-- Reads the Default profile once, in the background (GetProductInfo yields).
function Store.start()
	if Store.Started then
		return
	end
	Store.Started = true
	task.spawn(function()
		local ok = Store.read("Default")
		if not ok then
			Store.ConfigData = { _version = CONFIG.Version }
		end
		Store.Loaded = true
		for _, element in Elements do
			if Store.persistent(element.Item) and not element._started then
				element._started = true
				applyStartupValue(element)
			end
		end
		if Store.OnChange then
			Store.OnChange()
		end
	end)
end

-- Elements registered after the profile was read still receive their saved value.
function Store.adopt(element)
	if Store.Loaded and not element._started and Store.persistent(element.Item) then
		element._started = true
		applyStartupValue(element)
	end
end

-- Creates the public element object for a saveable item.
local function newElement(item)
	local element = { Id = item.id, Item = item, Type = item.type }
	function element:Set(value, silent)
		value = sanitize(item, value)
		if value == nil then
			return
		end
		State[item.id] = value
		element.Value = value
		refreshLive(item.id)
		fire(item.id, value)
		if item.onSet then
			item.onSet(value)
		end
		if not silent and Store.persistent(item) then
			Store.queueSave()
		end
		if Store.OnChange then
			Store.OnChange()
		end
	end
	function element:Get()
		return State[item.id]
	end
	State[item.id] = defaultValue(item)
	element.Value = State[item.id]
	Elements[item.id] = element
	return element
end

-- == WINDOW ================================================================

-- Touch devices get a smaller base window: the fit scale shrinks it less, so text stays readable.
local LAYOUT = IS_TOUCH and { W = 660, H = 410, Head = 48, Nav = 40, Foot = 24, Row = 44 }
	or { W = 780, H = 500, Head = 54, Nav = 42, Foot = 26, Row = 40 }

for _, oldName in { "MultiHub", "NightZSeries" } do
	local existing = playerGui:FindFirstChild(oldName)
	if existing then
		existing:Destroy()
	end
end

local gui = create("ScreenGui", {
	Name = "MultiHub",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 999,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

local UI = {
	compact = false,
	isOpen = true,
	currentPage = nil,
	logoTargets = {},
	logoAsset = "",
	windowTitle = nil,
	gameName = (game.Name ~= "" and tostring(game.Name)) or "Roblox",
	-- assigned further down:
	onSecond = (nil :: any),
	updateLoops = (nil :: any),
	updateBlur = (nil :: any),
	setOpen = (nil :: any),
	blurEffect = (nil :: any),
	fps = 0,
	frameTime = 0,
	askUnload = (nil :: any),
	homeSecond = (nil :: any),
	setBuiltin = (nil :: any),
	formatElapsed = (nil :: any),
	sessionStart = os.clock(),
	heroFloat = (nil :: any),
	loops = {},
}

-- == STYLE =================================================================
-- Liquid Glass / Reduce UI effects / Lightweight are applied through one registry, so a
-- switch in Settings restyles every visible surface at once (no rebuild).
--
-- Liquid Glass in Roblox: UI cannot blur what is behind it (there is no backdrop filter),
-- so the effect is built from translucent layers, a soft top reflection and light edges.
-- The optional background blur uses a BlurEffect in the camera (blurs the 3D scene only).

local Style = { items = {}, count = 0, listeners = {} }
local GLASS_EDGE = Color3.fromRGB(255, 255, 255)
local GLASS_BG = Color3.fromRGB(10, 10, 13)

-- Solid look (Liquid Glass off): opaque near-black window, cards with a deep red tint that
-- fades to black, and dark red edges.
local SOLID = {
	Bg = Color3.fromRGB(8, 8, 10),
	Surface = Color3.fromRGB(40, 10, 15),
	SurfaceHover = Color3.fromRGB(56, 13, 20),
	Panel = Color3.fromRGB(24, 9, 12),
	Edge = Color3.fromRGB(122, 18, 30),
}

-- Vertical fade applied to cards (a UIGradient only affects its own parent, never the
-- children, so it is safe on frames that use layouts).
local SOLID_FADE = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(105, 105, 105))
local GLASS_FADE = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200))

local function setFade(object, s)
	local fade = object:FindFirstChild("StyleFade")
	if not fade then
		return
	end
	fade.Enabled = not s.reduced
	if s.glass then
		fade.Color = GLASS_FADE
		fade.Transparency = NumberSequence.new(0, 0.35)
	else
		fade.Color = SOLID_FADE
		fade.Transparency = NumberSequence.new(0)
	end
end

local function setRim(stroke, on)
	local rim = stroke:FindFirstChild("StyleRim")
	if rim then
		rim.Enabled = on
	end
end

local STYLE_KINDS = {
	window = function(object, s)
		object.BackgroundColor3 = s.glass and GLASS_BG or SOLID.Bg
		object.BackgroundTransparency = s.glass and 0.24 or 0
	end,
	surface = function(object, s)
		object.BackgroundColor3 = s.glass and THEME.Surface or SOLID.Surface
		object.BackgroundTransparency = s.glass and 0.5 or 0
		setFade(object, s)
	end,
	row = function(object, s)
		object.BackgroundTransparency = s.glass and 0.45 or 0
	end,
	input = function(object, s)
		object.BackgroundTransparency = s.glass and 0.35 or 0
	end,
	panel = function(object, s)
		object.BackgroundColor3 = s.glass and THEME.Surface or SOLID.Panel
		object.BackgroundTransparency = s.glass and 0.12 or 0
		setFade(object, s)
	end,
	decor = function(object, s) -- shadows, glow, dot grid
		object.Visible = not s.reduced
	end,
	glassOnly = function(object, s) -- reflections
		object.Visible = s.glass
	end,
	heavy = function(object, s) -- game thumbnail and other optional imagery
		object.Visible = not s.reduced and not s.light
	end,
	edge = function(object, s) -- UIStroke of the window border
		object.Color = s.glass and GLASS_EDGE or SOLID.Edge
		object.Transparency = s.glass and 0.1 or 0.2
		object.Thickness = s.glass and 1.5 or 1
		setRim(object, s.glass)
	end,
	cardEdge = function(object, s) -- UIStroke of static cards and sections
		object.Color = s.glass and GLASS_EDGE or SOLID.Edge
		object.Transparency = s.glass and 0.35 or 0.45
		setRim(object, s.glass)
	end,
	divider = function(object, s)
		object.BackgroundColor3 = s.glass and GLASS_EDGE or THEME.AccentDark
		object.BackgroundTransparency = s.glass and 0.88 or 0.25
	end,
}

-- Liquid Glass rim: light hits the top-left and bottom-right edges, the sides stay dim.
function Style.addRim(stroke)
	if stroke:FindFirstChild("StyleRim") then
		return
	end
	create("UIGradient", {
		Name = "StyleRim",
		Rotation = 45,
		Enabled = false,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 0.75),
			NumberSequenceKeypoint.new(0.7, 0.85),
			NumberSequenceKeypoint.new(1, 0.35),
		}),
		Parent = stroke,
	})
end

-- Colour a card rests at / hovers to in the current style (hover handlers use these).
function Style.baseColor(object)
	local kind = Style.items[object]
	local glass = Style.state().glass
	if kind == "surface" then
		return glass and THEME.Surface or SOLID.Surface
	elseif kind == "panel" then
		return glass and THEME.Surface or SOLID.Panel
	end
	return THEME.Surface
end

function Style.hoverColor(object)
	if Style.items[object] == "surface" and not Style.state().glass then
		return SOLID.SurfaceHover
	end
	return THEME.RowHover
end

-- Things that are more than one property (nav pill, page cards) re-paint through listeners.
function Style.onChange(callback)
	table.insert(Style.listeners, callback)
end

function Style.state()
	return {
		reduced = Prefs.reduced,
		light = Prefs.lightweight,
		glass = Prefs.glass and not Prefs.reduced and not Prefs.lightweight,
	}
end

function Style.register(object, kind)
	Style.items[object] = kind
	if (kind == "surface" or kind == "panel") and not object:FindFirstChildOfClass("UIGradient") then
		create("UIGradient", { Name = "StyleFade", Rotation = 90, Parent = object })
	end
	if kind == "surface" and not object:IsA("GuiButton") then
		-- Static cards (sections, Home/Settings blocks) get the styled edge; clickable
		-- cards keep a neutral edge and only light up when hovered or selected.
		local stroke = object:FindFirstChildOfClass("UIStroke")
		if stroke and not Style.items[stroke] then
			Style.addRim(stroke)
			Style.items[stroke] = "cardEdge"
			STYLE_KINDS.cardEdge(stroke, Style.state())
		end
	end
	STYLE_KINDS[kind](object, Style.state())
	Style.count += 1
	if Style.count % 300 == 0 then
		for item in Style.items do
			if item.Parent == nil then
				Style.items[item] = nil
			end
		end
	end
	return object
end

function Style.apply()
	local state = Style.state()
	for object, kind in Style.items do
		if object.Parent == nil then
			Style.items[object] = nil
		else
			STYLE_KINDS[kind](object, state)
		end
	end
	for _, callback in Style.listeners do
		pcall(callback, state)
	end
	if UI.updateBlur then
		UI.updateBlur()
	end
end

-- Holder = fixed design size + UIScale that fits it in any screen (phone, tablet, 4K).
local holder = create("Frame", {
	Name = "Holder",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(LAYOUT.W, LAYOUT.H),
	BackgroundTransparency = 1,
	Parent = gui,
})
local fitScale = create("UIScale", { Name = "Fit", Parent = holder })

-- Shell carries the open/close animation (a GuiObject only honors one UIScale).
local shell = create("Frame", {
	Name = "Shell",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Parent = holder,
})
local openScale = create("UIScale", { Name = "Open", Parent = shell })

-- Roblox has no drop shadow: stacked black frames, each larger and more transparent.
for index, spec in { { 4, 0.78 }, { 10, 0.88 }, { 20, 0.94 } } do
	local shadow = create("Frame", {
		Name = "Shadow" .. index,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 6),
		Size = UDim2.new(1, spec[1] * 2, 1, spec[1] * 2),
		BackgroundColor3 = THEME.Shadow,
		BackgroundTransparency = spec[2],
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = shell,
	}, { Util.corner(RADIUS.Window + spec[1]) })
	Style.register(shadow, "decor")
end

-- CanvasGroup clips everything to the rounded corners and lets the window fade as one piece.
local window = create("CanvasGroup", {
	Name = "Window",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = THEME.Bg,
	BorderSizePixel = 0,
	ZIndex = 1,
	Parent = shell,
}, { Util.corner(RADIUS.Window) })
Style.register(window, "window")

local borderStroke = Util.stroke(THEME.Stroke, 0.15)
Style.addRim(borderStroke)
create("Frame", {
	Name = "Border",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 5,
	Parent = shell,
}, { Util.corner(RADIUS.Window), borderStroke })
Style.register(borderStroke, "edge")

-- Liquid Glass reflection: a soft white sheen over the top of the window.
Style.register(create("Frame", {
	Name = "Sheen",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.86,
	BorderSizePixel = 0,
	ZIndex = 1,
	Parent = window,
}, {
	-- Diagonal light: bright in the top-left corner, a faint second band, clear elsewhere.
	create("UIGradient", {
		Rotation = 35,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.22, 0.8),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(0.78, 0.92),
			NumberSequenceKeypoint.new(1, 0.7),
		}),
	}),
}), "glassOnly")

function UI.updateFit()
	local viewport = gui.AbsoluteSize
	if viewport.X <= 0 or viewport.Y <= 0 then
		return
	end
	local fit = math.min(viewport.X * 0.94 / LAYOUT.W, viewport.Y * 0.9 / LAYOUT.H)
	local scale = math.min(fit, math.min(fit, 1) * Prefs.scale / 100)
	fitScale.Scale = math.max(scale, 0.4)
end
Util.track(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(UI.updateFit))
UI.updateFit()

-- Procedural backdrop: a soft red glow and a fading dot grid, all native UI (no image assets).
if CONFIG.ProceduralBackdrop then
	local backdrop = create("Frame", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 0,
		Parent = window,
	})
	Style.register(backdrop, "decor")
	create("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 120, 0, -160),
		Size = UDim2.fromOffset(460, 360),
		BackgroundColor3 = THEME.Accent,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = backdrop,
	}, {
		Util.corner(220),
		create("UIGradient", {
			Rotation = 135,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.4),
				NumberSequenceKeypoint.new(0.6, 0.9),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	for row = 0, 6 do
		for col = 0, 9 do
			local distance = (6 - row) * 0.13 + (9 - col) * 0.09
			create("Frame", {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -18 - col * 15, 1, -LAYOUT.Foot - 14 - row * 15),
				Size = UDim2.fromOffset(2, 2),
				BackgroundColor3 = THEME.Accent,
				BackgroundTransparency = math.clamp(0.55 + distance * 0.35, 0.55, 0.96),
				BorderSizePixel = 0,
				ZIndex = 0,
				Parent = backdrop,
			}, { Util.corner(1) })
		end
	end
end

-- Logo (brand + floating button): downloaded once, shown with a fade when it arrives.
function UI.buildLogo(parent, size, props)
	local box = create("Frame", Util.merge({
		Name = "Logo",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	}, props))
	local fallback = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.Accent,
		BorderSizePixel = 0,
		Parent = box,
	}, {
		Util.corner(math.floor(size * 0.28)),
		create("UIGradient", {
			Rotation = 135,
			Color = ColorSequence.new(THEME.AccentHover, THEME.AccentDark),
		}),
		label({
			Text = string.sub(CONFIG.HubName, 1, 1),
			FontFace = FONT.DisplayItalic,
			TextSize = math.floor(size * 0.56),
			TextColor3 = THEME.Text,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
		}),
	})
	local image = create("ImageLabel", {
		BackgroundTransparency = 1,
		ImageTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(1, 1),
		Parent = box,
	})
	local target = { image = image, fallback = fallback }
	table.insert(UI.logoTargets, target)
	if UI.logoAsset ~= "" then
		image.Image = UI.logoAsset
		image.ImageTransparency = 0
		fallback.Visible = false
	end
	return box
end

function UI.applyLogo(asset)
	UI.logoAsset = asset
	for _, target in UI.logoTargets do
		if target.image.Parent then
			target.image.Image = asset
			target.fallback.Visible = false
			tween(target.image, 0.4, { ImageTransparency = 0 })
		end
	end
end

-- Header (reference layout): logo · wordmark · session pill  ...  window title · hide · unload
local header = create("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, LAYOUT.Head),
	BackgroundTransparency = 1,
	Active = true,
	ZIndex = 2,
	Parent = window,
})
local headLeft = create("Frame", {
	Position = UDim2.fromOffset(18, 0),
	Size = UDim2.new(0, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	Parent = header,
}, { Util.list(12, Enum.FillDirection.Horizontal, { VerticalAlignment = Enum.VerticalAlignment.Center }) })
UI.buildLogo(headLeft, 26, { LayoutOrder = 1 })

local hubFirst, hubRest = string.match(CONFIG.HubName, "^(%S+)%s+(.+)$")
label({
	Name = "Wordmark",
	Text = CONFIG.HubName,
	FontFace = FONT.DisplayItalic,
	TextSize = 19,
	TextTruncate = Enum.TextTruncate.None,
	AutomaticSize = Enum.AutomaticSize.X,
	Size = UDim2.fromOffset(0, LAYOUT.Head),
	LayoutOrder = 2,
	Parent = headLeft,
})

-- Status pill: pulsing dot + session timer + number of active toggles.
local statusPill = create("Frame", {
	Name = "Status",
	Size = UDim2.fromOffset(0, 28),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = THEME.Input,
	BorderSizePixel = 0,
	LayoutOrder = 3,
	Parent = headLeft,
}, {
	Util.corner(RADIUS.Row),
	Util.stroke(THEME.AccentDark, 0.35),
	Util.padding(11, 12, 0, 0),
	Util.list(8, Enum.FillDirection.Horizontal, { VerticalAlignment = Enum.VerticalAlignment.Center }),
})
Style.register(statusPill, "input")
local statusDot = create("Frame", {
	Size = UDim2.fromOffset(6, 6),
	BackgroundColor3 = THEME.Accent,
	BorderSizePixel = 0,
	LayoutOrder = 1,
	Parent = statusPill,
}, { Util.corner(3) })
local pulse = TweenService:Create(statusDot, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
	BackgroundTransparency = 0.75,
})
pulse:Play()
local timerLabel = label({
	Text = "00:00",
	FontFace = FONT.Bold,
	TextSize = 13,
	TextTruncate = Enum.TextTruncate.None,
	AutomaticSize = Enum.AutomaticSize.X,
	Size = UDim2.fromOffset(0, 28),
	LayoutOrder = 2,
	Parent = statusPill,
})
local activeLabel = label({
	Text = "",
	FontFace = FONT.SemiBold,
	TextSize = 12,
	TextColor3 = THEME.Accent,
	TextTruncate = Enum.TextTruncate.None,
	AutomaticSize = Enum.AutomaticSize.X,
	Size = UDim2.fromOffset(0, 28),
	LayoutOrder = 3,
	Visible = false,
	Parent = statusPill,
})

local headRight = create("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 0),
	Size = UDim2.new(0, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	Parent = header,
}, { Util.list(4, Enum.FillDirection.Horizontal, { VerticalAlignment = Enum.VerticalAlignment.Center }) })

-- Square icon button used in the header and dialogs.
function UI.iconButton(parent, iconName, glyph, props, hoverColor)
	local button = create("TextButton", Util.merge({
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = THEME.Row,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = parent,
	}, props), { Util.corner(RADIUS.Row) })
	local _, setColor = Icons.make(button, iconName, 16, THEME.SubText, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	}, glyph)
	Util.hover(button, function()
		tween(button, 0.15, { BackgroundTransparency = 0 })
		setColor(hoverColor or THEME.Text, true)
	end, function()
		tween(button, 0.2, { BackgroundTransparency = 1 })
		setColor(THEME.SubText, true)
	end)
	Util.pressScale(button, 0.9)
	return button
end

-- Window title given by the script (CreateWindow Title), shown discreetly next to the buttons.
local windowTitleLabel = label({
	Text = "",
	FontFace = FONT.Medium,
	TextSize = 11,
	TextColor3 = THEME.Muted,
	TextXAlignment = Enum.TextXAlignment.Right,
	Size = UDim2.fromOffset(150, 30),
	LayoutOrder = 1,
	Visible = false,
	Parent = headRight,
})
local hideButton = UI.iconButton(headRight, "minus", "–", { LayoutOrder = 2 })
local unloadButton = UI.iconButton(headRight, "power", "⏻", { LayoutOrder = 3 }, THEME.Accent)

-- Horizontal navigation (second row). Scrolls sideways when the labels do not fit (phones).
local navBar = create("Frame", {
	Name = "Nav",
	Position = UDim2.fromOffset(0, LAYOUT.Head),
	Size = UDim2.new(1, 0, 0, LAYOUT.Nav),
	BackgroundTransparency = 1,
	ZIndex = 2,
	Parent = window,
})
local navScroll = create("ScrollingFrame", {
	Name = "Tabs",
	Position = UDim2.fromOffset(12, 0),
	Size = UDim2.new(1, -24, 1, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 0,
	ScrollingDirection = Enum.ScrollingDirection.X,
	CanvasSize = UDim2.fromScale(0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	Parent = navBar,
}, { Util.list(2, Enum.FillDirection.Horizontal, { VerticalAlignment = Enum.VerticalAlignment.Center }) })
Style.register(create("Frame", {
	Name = "Divider",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, 0),
	Size = UDim2.new(1, -32, 0, 1),
	BackgroundColor3 = THEME.StrokeSoft,
	BorderSizePixel = 0,
	Parent = navBar,
}), "divider")

local content = create("Frame", {
	Name = "Content",
	Position = UDim2.fromOffset(0, LAYOUT.Head + LAYOUT.Nav),
	Size = UDim2.new(1, 0, 1, -LAYOUT.Head - LAYOUT.Nav - LAYOUT.Foot),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	ZIndex = 2,
	Parent = window,
})

local footer = create("Frame", {
	Name = "Footer",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, LAYOUT.Foot),
	BackgroundTransparency = 1,
	ZIndex = 2,
	Parent = window,
})
create("Frame", {
	Position = UDim2.fromOffset(16, 0),
	Size = UDim2.new(1, -32, 0, 1),
	BackgroundColor3 = THEME.Accent,
	BackgroundTransparency = 0.55,
	BorderSizePixel = 0,
	Parent = footer,
}, {
	create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 0.6),
		}),
	}),
})
local footerLeft = label({
	FontFace = FONT.Medium,
	TextSize = 11,
	TextColor3 = THEME.Muted,
	Position = UDim2.fromOffset(18, 1),
	Size = UDim2.new(1, -130, 1, -1),
	Parent = footer,
})
local footerFps = label({
	FontFace = FONT.Mono,
	TextSize = 11,
	TextColor3 = THEME.Muted,
	TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -18, 0, 1),
	Size = UDim2.new(0, 100, 1, -1),
	Parent = footer,
})

UI.executorName = RunService:IsStudio() and "Roblox Studio" or "Roblox"
do
	local detector = (type(env.identifyexecutor) == "function" and env.identifyexecutor) or env.getexecutorname
	if type(detector) == "function" then
		local ok, name = pcall(detector)
		if ok and type(name) == "string" and name ~= "" then
			UI.executorName = name
		end
	end
end

function UI.updateFooter()
	footerLeft.Text = UI.gameName .. "   |   " .. UI.executorName
	windowTitleLabel.Text = UI.windowTitle or ""
	windowTitleLabel.Visible = UI.windowTitle ~= nil and not IS_TOUCH
end
UI.updateFooter()

-- One RenderStepped connection drives the session timer and the FPS counter (v1 used two loops).
do
	local startClock = os.clock()
	local frames, elapsed, lastSecond = 0, 0, -1
	local fps = 0
	I18n.bind(footerFps, function()
		return I18n.t("status.fps", fps > 0 and tostring(fps) or "...")
	end)
	local function formatElapsed(total)
		local hours = total // 3600
		local minutes = (total % 3600) // 60
		local seconds = total % 60
		if hours > 0 then
			return string.format("%02d:%02d:%02d", hours, minutes, seconds)
		end
		return string.format("%02d:%02d", minutes, seconds)
	end
	UI.formatElapsed = formatElapsed
	UI.sessionStart = startClock
	Util.track(RunService.RenderStepped:Connect(function(dt)
		frames += 1
		elapsed += dt
		local second = math.floor(os.clock() - startClock)
		if second ~= lastSecond then
			lastSecond = second
			if holder.Visible then
				timerLabel.Text = formatElapsed(second)
			end
			if UI.onSecond then
				UI.onSecond(second) -- decides itself what to update (FPS display runs while hidden)
			end
		end
		if elapsed >= 1 then
			fps = math.floor(frames / elapsed + 0.5)
			UI.fps = fps
			UI.frameTime = elapsed / frames * 1000
			frames, elapsed = 0, 0
			if holder.Visible then
				footerFps.Text = I18n.t("status.fps", tostring(fps))
			end
		end
	end))
end

-- == NOTIFY ================================================================

local TOAST = { W = 280, H = 66, Max = 4, Order = 0 }
local KIND = {
	info = { icon = "info", glyph = "i", color = THEME.Accent },
	success = { icon = "circle-check", glyph = "✓", color = THEME.Success },
	warning = { icon = "triangle-alert", glyph = "!", color = THEME.Warning },
	error = { icon = "circle-x", glyph = "×", color = THEME.Accent },
}

local toastHolder = create("Frame", {
	Name = "Notifications",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 60),
	Size = UDim2.fromOffset(TOAST.W, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	ZIndex = 50,
	Parent = gui,
}, { Util.list(8, nil, { HorizontalAlignment = Enum.HorizontalAlignment.Right }) })

local function dismissToast(slot, card)
	if slot:GetAttribute("Closing") or not slot.Parent then
		return
	end
	slot:SetAttribute("Closing", true)
	task.spawn(function()
		tween(card, 0.28, { Position = UDim2.new(1.2, 0, 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In).Completed:Wait()
		if slot.Parent then
			tween(slot, 0.16, { Size = UDim2.new(1, 0, 0, 0) }).Completed:Wait()
			slot:Destroy()
		end
	end)
end

notify = function(title, message, duration, kind)
	if not Prefs.notifications or not Maid.alive then
		return
	end
	duration = tonumber(duration) or 3
	local style = KIND[kind or "info"] or KIND.info
	TOAST.Order += 1

	local slots = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") and not child:GetAttribute("Closing") then
			table.insert(slots, child)
		end
	end
	table.sort(slots, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #slots >= TOAST.Max do
		local oldest = table.remove(slots, 1)
		if oldest then
			oldest:Destroy()
		end
	end

	local slot = create("Frame", {
		Size = UDim2.new(1, 0, 0, TOAST.H),
		BackgroundTransparency = 1,
		LayoutOrder = TOAST.Order,
		Parent = toastHolder,
	})
	local card = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.new(1.2, 0, 0, 0),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.Surface,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = slot,
	}, { Util.corner(RADIUS.Card), Util.stroke(THEME.Stroke, 0.1) })
	Style.register(card, "panel")
	local badge = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, -2),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = style.color,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		Parent = card,
	}, { Util.corner(15) })
	Icons.make(badge, style.icon, 16, style.color, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	}, style.glyph)
	label({
		Text = tostring(title or ""),
		FontFace = FONT.Bold,
		TextSize = 13,
		Position = UDim2.fromOffset(52, 10),
		Size = UDim2.new(1, -62, 0, 16),
		Parent = card,
	})
	label({
		Text = tostring(message or ""),
		FontFace = FONT.Regular,
		TextSize = 12,
		TextColor3 = THEME.SubText,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(52, 28),
		Size = UDim2.new(1, -62, 0, 30),
		Parent = card,
	})
	local bar = create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = style.color,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Parent = card,
	})
	card.Activated:Connect(function()
		dismissToast(slot, card)
	end)
	tween(card, 0.35, { Position = UDim2.fromScale(0, 0) })
	-- The progress bar always runs (it is the timer), even with animations off.
	TweenService:Create(bar, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play()
	task.delay(duration, dismissToast, slot, card)
end

-- == TOOLTIP ===============================================================

local Tooltip = { token = 0 }
local tipFrame = create("Frame", {
	Name = "Tooltip",
	Size = UDim2.fromOffset(0, 0),
	AutomaticSize = Enum.AutomaticSize.XY,
	BackgroundColor3 = THEME.Surface,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 200,
	Parent = gui,
}, { Util.corner(RADIUS.Small), Util.stroke(THEME.Stroke, 0), Util.padding(9, 9, 6, 6) })
local tipText = label({
	FontFace = FONT.Medium,
	TextSize = 12,
	TextWrapped = true,
	TextTruncate = Enum.TextTruncate.None,
	AutomaticSize = Enum.AutomaticSize.XY,
	Size = UDim2.fromOffset(0, 0),
	ZIndex = 201,
	Parent = tipFrame,
}, nil)
create("UISizeConstraint", { MaxSize = Vector2.new(260, 400), Parent = tipText })

function Tooltip.place()
	local mouse = UserInputService:GetMouseLocation()
	local viewport = gui.AbsoluteSize
	local size = tipFrame.AbsoluteSize
	local x = math.clamp(mouse.X + 14, 4, math.max(4, viewport.X - size.X - 4))
	local y = math.clamp(mouse.Y + 18, 4, math.max(4, viewport.Y - size.Y - 4))
	tipFrame.Position = UDim2.fromOffset(x, y)
end

function Tooltip.hide()
	Tooltip.token += 1
	tipFrame.Visible = false
end

-- getter returns the text (or nil = no tooltip right now). Mouse only.
function Tooltip.attach(object, getter)
	if IS_TOUCH then
		return
	end
	object.MouseEnter:Connect(function()
		Tooltip.token += 1
		local token = Tooltip.token
		task.delay(0.4, function()
			if token ~= Tooltip.token or not object.Parent then
				return
			end
			local text = getter()
			if type(text) ~= "string" or text == "" then
				return
			end
			tipText.Text = text
			tipFrame.Visible = true
			Tooltip.place()
		end)
	end)
	object.MouseMoved:Connect(function()
		if tipFrame.Visible then
			Tooltip.place()
		end
	end)
	object.MouseLeave:Connect(Tooltip.hide)
	object.Destroying:Connect(Tooltip.hide)
end

Tooltip.attach(hideButton, function()
	return I18n.t("top.hide", Util.keyName(toggleKeyCode()))
end)
Tooltip.attach(unloadButton, function()
	return I18n.t("top.unload")
end)
Tooltip.attach(statusPill, function()
	return I18n.t("top.session")
end)

-- == LINK DIALOG ===========================================================
-- Roblox blocks opening websites from game scripts (GuiService:OpenBrowserWindow is not
-- available to them), so social buttons copy the link and show it in a selectable box.

local LinkDialog = {}
do
	local overlay = create("TextButton", {
		Name = "LinkDialog",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 40,
		Parent = window,
	})
	local card = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(360, 206),
		BackgroundColor3 = THEME.Surface,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 41,
		Parent = overlay,
	}, { Util.corner(RADIUS.Card + 2), Util.stroke(THEME.Stroke, 0) })
	Style.register(card, "panel")
	local cardScale = create("UIScale", { Parent = card })
	local iconBox = create("Frame", {
		Position = UDim2.fromOffset(18, 18),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = THEME.AccentSoft,
		BorderSizePixel = 0,
		ZIndex = 42,
		Parent = card,
	}, { Util.corner(RADIUS.Row) })
	local title = label({
		FontFace = FONT.Bold,
		TextSize = 16,
		Position = UDim2.fromOffset(66, 18),
		Size = UDim2.new(1, -84, 0, 20),
		ZIndex = 42,
		Parent = card,
	})
	local body = label({
		FontFace = FONT.Regular,
		TextSize = 12,
		TextColor3 = THEME.SubText,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(66, 40),
		Size = UDim2.new(1, -84, 0, 32),
		ZIndex = 42,
		Parent = card,
	})
	I18n.bind(body, "link.body")
	local urlBox = create("TextBox", {
		Text = "",
		ClearTextOnFocus = false,
		FontFace = FONT.Mono,
		TextSize = 12,
		TextColor3 = THEME.AccentHover,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		BackgroundColor3 = THEME.Input,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(18, 86),
		Size = UDim2.new(1, -36, 0, 32),
		ZIndex = 42,
		Parent = card,
	}, { Util.corner(RADIUS.Small), Util.stroke(THEME.StrokeSoft), Util.padding(10, 10, 0, 0) })
	local status = label({
		FontFace = FONT.Medium,
		TextSize = 11,
		TextColor3 = THEME.Muted,
		Position = UDim2.fromOffset(18, 124),
		Size = UDim2.new(1, -36, 0, 14),
		ZIndex = 42,
		Parent = card,
	})
	local currentUrl = ""
	-- Selectable but read-only: edits are reverted so the link cannot be broken by accident.
	urlBox:GetPropertyChangedSignal("Text"):Connect(function()
		if urlBox.Text ~= currentUrl then
			urlBox.Text = currentUrl
		end
	end)

	local function dialogButton(order, key, primary)
		local button = create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -18 - (order - 1) * 128, 1, -16),
			Size = UDim2.fromOffset(120, 34),
			BackgroundColor3 = primary and THEME.Accent or THEME.Row,
			BorderSizePixel = 0,
			ZIndex = 42,
			Parent = card,
		}, { Util.corner(RADIUS.Row) })
		local text = label({
			FontFace = FONT.SemiBold,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 43,
			Parent = button,
		})
		I18n.bind(text, key)
		local base = button.BackgroundColor3
		Util.hover(button, function()
			tween(button, 0.15, { BackgroundColor3 = primary and THEME.AccentHover or THEME.RowHover })
		end, function()
			tween(button, 0.2, { BackgroundColor3 = base })
		end)
		Util.pressScale(button, 0.95)
		return button
	end
	local copyButton = dialogButton(1, "link.copy", true)
	local closeButton = dialogButton(2, "link.close", false)

	local iconHolder
	local function setStatus(copied)
		status.Text = copied and I18n.t("link.copied") or I18n.t("link.manual")
		status.TextColor3 = copied and THEME.Success or THEME.Muted
	end

	function LinkDialog.close()
		if not overlay.Visible then
			return
		end
		tween(overlay, 0.2, { BackgroundTransparency = 1 })
		tween(cardScale, 0.2, { Scale = 0.92 })
		task.delay(0.2, function()
			overlay.Visible = false
		end)
	end

	function LinkDialog.open(social)
		currentUrl = social.Url
		urlBox.Text = currentUrl
		title.Text = I18n.t("link.title", social.Name)
		if iconHolder then
			iconHolder:Destroy()
		end
		iconHolder = Icons.make(iconBox, social.Icon, 18, THEME.Accent, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = 43,
		}, social.Glyph)
		setStatus(Util.copy(currentUrl))
		overlay.Visible = true
		overlay.BackgroundTransparency = 1
		cardScale.Scale = 0.92
		tween(overlay, 0.2, { BackgroundTransparency = 0.45 })
		tween(cardScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end

	LinkDialog.isOpen = function()
		return overlay.Visible
	end
	copyButton.Activated:Connect(function()
		local copied = Util.copy(currentUrl)
		setStatus(copied)
		if copied then
			notify("MultiHub", I18n.t("link.copied"), 2.5, "success")
		else
			urlBox:CaptureFocus()
			urlBox.SelectionStart = 1
			urlBox.CursorPosition = #currentUrl + 1
		end
	end)
	closeButton.Activated:Connect(LinkDialog.close)
	overlay.Activated:Connect(LinkDialog.close)
end

-- == DIALOGS ===============================================================
-- Confirmation dialog (used by Unload). Texts are I18n keys, so an open dialog follows
-- a language change like the rest of the window.

local Modal = {}
do
	local overlay = create("TextButton", {
		Name = "ConfirmDialog",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 45,
		Parent = window,
	})
	local card = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(370, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.Surface,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 46,
		Parent = overlay,
	}, {
		Util.corner(RADIUS.Card + 2),
		Util.stroke(THEME.AccentDark, 0.2),
		Util.padding(20, 20, 18, 16),
		Util.list(12),
	})
	Style.register(card, "panel")
	local cardScale = create("UIScale", { Parent = card })

	local top = create("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		ZIndex = 47,
		Parent = card,
	})
	local iconBox = create("Frame", {
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = THEME.AccentSoft,
		BorderSizePixel = 0,
		ZIndex = 47,
		Parent = top,
	}, { Util.corner(RADIUS.Row) })
	Icons.make(iconBox, "power", 18, THEME.Accent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 48,
	}, "⏻")
	local title = label({
		FontFace = FONT.Bold,
		TextSize = 16,
		Position = UDim2.fromOffset(48, 0),
		Size = UDim2.new(1, -48, 1, 0),
		ZIndex = 47,
		Parent = top,
	})
	local body = label({
		FontFace = FONT.Regular,
		TextSize = 12,
		TextColor3 = THEME.SubText,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		ZIndex = 47,
		Parent = card,
	})
	local buttons = create("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		ZIndex = 47,
		Parent = card,
	}, { Util.list(8, Enum.FillDirection.Horizontal, { HorizontalAlignment = Enum.HorizontalAlignment.Right }) })

	local function dialogButton(order, primary)
		local button = create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromOffset(120, 36),
			BackgroundColor3 = primary and THEME.Accent or THEME.Row,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 47,
			Parent = buttons,
		}, { Util.corner(RADIUS.Row) })
		local text = label({
			FontFace = FONT.SemiBold,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 48,
			Parent = button,
		})
		local base = button.BackgroundColor3
		Util.hover(button, function()
			tween(button, 0.15, { BackgroundColor3 = primary and THEME.AccentHover or THEME.RowHover })
		end, function()
			tween(button, 0.2, { BackgroundColor3 = base })
		end)
		Util.pressScale(button, 0.95)
		return button, text
	end
	local cancelButton, cancelText = dialogButton(1, false)
	local confirmButton, confirmText = dialogButton(2, true)

	local pending = nil
	function Modal.close()
		pending = nil
		if not overlay.Visible then
			return
		end
		tween(overlay, 0.18, { BackgroundTransparency = 1 })
		tween(cardScale, 0.18, { Scale = 0.92 })
		task.delay(Prefs.animations and 0.18 or 0, function()
			if not pending then
				overlay.Visible = false
			end
		end)
	end
	Modal.isOpen = function()
		return overlay.Visible
	end

	-- opts = { title = key, body = key, confirm = key, cancel = key, onConfirm = function }
	function Modal.confirm(opts)
		pending = opts
		I18n.bind(title, opts.title)
		I18n.bind(body, opts.body)
		I18n.bind(confirmText, opts.confirm)
		I18n.bind(cancelText, opts.cancel)
		overlay.Visible = true
		overlay.BackgroundTransparency = 1
		cardScale.Scale = 0.92
		tween(overlay, 0.2, { BackgroundTransparency = 0.4 })
		tween(cardScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end

	confirmButton.Activated:Connect(function()
		local opts = pending
		Modal.close()
		if opts and opts.onConfirm then
			task.spawn(opts.onConfirm)
		end
	end)
	cancelButton.Activated:Connect(Modal.close)
	overlay.Activated:Connect(Modal.close)
end

-- == COMPONENTS ============================================================
-- Every control is a "row": label (+ optional description) on the left, the control on the right.
-- Rows read State[item.id] and write through Elements[item.id]:Set(), so the same item can be
-- shown in its tab and in search results at the same time and both stay in sync (bindLive).

local Components = {
	scrollers = {},
	activeSlider = nil,
	activeKnob = nil,
	knobRelease = nil,
	keyCapture = nil,
	toggleTokens = setmetatable({}, { __mode = "k" }),
}

local function hasText(raw)
	if raw == nil then
		return false
	end
	if type(raw) == "table" then
		return next(raw) ~= nil
	end
	return tostring(raw) ~= ""
end

local function rowHeight(item, base)
	return (base or LAYOUT.Row) + (hasText(item.descRaw) and 13 or 0)
end

local function formatNumber(value)
	if value == math.floor(value) then
		return tostring(math.floor(value))
	end
	local text = string.format("%.3f", value)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return text
end

-- Locks list scrolling while a slider is dragged (otherwise the finger scrolls instead).
function Components.setActiveSlider(handler, knobScale, onRelease)
	if handler == nil and Components.activeKnob then
		tween(Components.activeKnob, 0.2, { Scale = 1 })
		Components.activeKnob = nil
		if Components.knobRelease then
			local release = Components.knobRelease
			Components.knobRelease = nil
			pcall(release)
		end
	end
	Components.activeSlider = handler
	for index = #Components.scrollers, 1, -1 do
		local scroller = Components.scrollers[index]
		if scroller.Parent == nil then
			table.remove(Components.scrollers, index)
		else
			scroller.ScrollingEnabled = handler == nil
		end
	end
	if handler ~= nil then
		Components.activeKnob = knobScale
		Components.knobRelease = onRelease
	end
end

-- Base row: surface, hover, press feedback and the red "active" bar on the left edge.
function Components.row(parent, height, clickable)
	local props = {
		Name = "Row",
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = THEME.Row,
		BorderSizePixel = 0,
		Parent = parent,
	}
	if clickable then
		props.Text = ""
		props.AutoButtonColor = false
	end
	local row = create(clickable and "TextButton" or "Frame", props, { Util.corner(RADIUS.Row) })
	Style.register(row, "row")
	local stroke = Util.stroke(THEME.StrokeSoft)
	stroke.Parent = row
	local bar = create("Frame", {
		Name = "ActiveBar",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 2, 0, 0),
		BackgroundColor3 = THEME.Accent,
		BorderSizePixel = 0,
		Parent = row,
	}, { Util.corner(1) })

	local kit = { row = row, stroke = stroke, active = false, hovered = false }
	local function paint(animate)
		local color = kit.hovered and THEME.RowHover or THEME.Row
		local strokeColor = kit.active and THEME.AccentDark or (kit.hovered and THEME.Stroke or THEME.StrokeSoft)
		if animate then
			tween(row, 0.15, { BackgroundColor3 = color })
			tween(stroke, 0.15, { Color = strokeColor })
		else
			row.BackgroundColor3 = color
			stroke.Color = strokeColor
		end
	end
	function kit.setActive(on, animate)
		kit.active = on
		local goal = { Size = UDim2.new(0, 2, on and 0.56 or 0, 0) }
		if animate then
			tween(bar, 0.25, goal)
		else
			bar.Size = goal.Size
		end
		paint(animate)
	end
	Util.hover(row, function()
		kit.hovered = true
		paint(true)
	end, function()
		kit.hovered = false
		paint(true)
	end)
	if clickable then
		Util.pressScale(row, 0.985)
	end
	return row, kit
end

-- Title + optional description on the left; reserve = space kept for the control on the right.
function Components.texts(row, item, reserveOffset, reserveScale, topAligned)
	local hasDesc = hasText(item.descRaw)
	local width = UDim2.new(1 - (reserveScale or 0), -(14 + reserveOffset), 0, 0)
	local title = label({
		Name = "Title",
		FontFace = FONT.SemiBold,
		TextSize = 13,
		Position = UDim2.fromOffset(14, 0),
		Size = width,
		Parent = row,
	})
	I18n.bind(title, function()
		return I18n.resolve(item.labelRaw)
	end)
	local desc
	if hasDesc then
		desc = label({
			Name = "Desc",
			FontFace = FONT.Regular,
			TextSize = 11,
			TextColor3 = THEME.Muted,
			Position = UDim2.fromOffset(14, 0),
			Size = width,
			Parent = row,
		})
		I18n.bind(desc, function()
			return I18n.resolve(item.descRaw)
		end)
	end
	if topAligned then
		title.Position = UDim2.fromOffset(14, 9)
		title.Size = UDim2.new(width.X.Scale, width.X.Offset, 0, 16)
		if desc then
			desc.Position = UDim2.fromOffset(14, 25)
			desc.Size = UDim2.new(width.X.Scale, width.X.Offset, 0, 13)
		end
	elseif desc then
		title.Position = UDim2.new(0, 14, 0.5, -15)
		title.Size = UDim2.new(width.X.Scale, width.X.Offset, 0, 16)
		desc.Position = UDim2.new(0, 14, 0.5, 2)
		desc.Size = UDim2.new(width.X.Scale, width.X.Offset, 0, 13)
	else
		title.Size = UDim2.new(width.X.Scale, width.X.Offset, 1, 0)
	end
	if hasText(item.tooltipRaw) then
		Tooltip.attach(row, function()
			return I18n.resolve(item.tooltipRaw)
		end)
	end
	return title, desc
end

function Components.toggle(item, parent)
	local row, kit = Components.row(parent, rowHeight(item), true)
	Components.texts(row, item, 58)
	local track = create("Frame", {
		Name = "Switch",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(36, 20),
		BackgroundColor3 = THEME.Track,
		BorderSizePixel = 0,
		Parent = row,
	}, { Util.corner(10) })
	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = THEME.Knob,
		BorderSizePixel = 0,
		Parent = track,
	}, { Util.corner(RADIUS.Pill) })
	local function render(animate)
		local on = State[item.id] == true
		local trackGoal = { BackgroundColor3 = on and THEME.Accent or THEME.Track }
		local knobGoal = {
			Position = UDim2.new(0, on and 19 or 3, 0.5, 0),
			BackgroundColor3 = on and Color3.new(1, 1, 1) or THEME.Knob,
		}
		kit.setActive(on, animate)
		if animate and Style.state().glass then
			-- Liquid: stretch toward the destination, then settle with a small bounce.
			tween(track, 0.2, trackGoal)
			local stretch = tween(knob, 0.12, {
				Size = UDim2.fromOffset(22, 14),
				Position = UDim2.new(0, on and 11 or 3, 0.5, 0),
				BackgroundColor3 = knobGoal.BackgroundColor3,
			})
			local token = {}
			Components.toggleTokens[knob] = token
			local function settle()
				if Components.toggleTokens[knob] ~= token then
					return
				end
				Components.toggleTokens[knob] = nil
				tween(knob, 0.3, { Size = UDim2.fromOffset(14, 14), Position = knobGoal.Position }, Enum.EasingStyle.Back)
			end
			if stretch then
				stretch.Completed:Once(settle)
			else
				settle()
			end
		elseif animate then
			tween(track, 0.2, trackGoal)
			tween(knob, 0.3, knobGoal, Enum.EasingStyle.Back)
		else
			track.BackgroundColor3 = trackGoal.BackgroundColor3
			knob.Position = knobGoal.Position
			knob.BackgroundColor3 = knobGoal.BackgroundColor3
			knob.Size = UDim2.fromOffset(14, 14)
		end
	end
	render(false)
	bindLive(item.id, row, render)
	row.Activated:Connect(function()
		local element = Elements[item.id]
		if not element then
			return
		end
		element:Set(not State[item.id])
		if not item.internal then
			local on = State[item.id] == true
			notify(I18n.resolve(item.labelRaw), I18n.t(on and "toggle.on" or "toggle.off"), 2, on and "success" or "info")
		end
	end)
	return row
end

function Components.button(item, parent)
	local row = Components.row(parent, rowHeight(item), true)
	Components.texts(row, item, 44)
	local chip = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = item.danger and THEME.AccentDark or THEME.AccentSoft,
		BorderSizePixel = 0,
		Parent = row,
	}, { Util.corner(RADIUS.Small) })
	Icons.make(chip, item.icon or "chevron-right", 14, THEME.Accent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	}, "›")
	local busy = false
	row.Activated:Connect(function()
		if busy then
			return -- ignores double clicks while the callback is still running
		end
		busy = true
		tween(chip, 0.1, { BackgroundColor3 = THEME.Accent })
		local ok = fire(item.id)
		tween(chip, 0.35, { BackgroundColor3 = THEME.AccentSoft })
		busy = false
		if ok and not item.internal then
			notify(I18n.resolve(item.labelRaw), I18n.t("button.done"), 2, "success")
		end
	end)
	return row
end

function Components.slider(item, parent)
	local row, kit = Components.row(parent, rowHeight(item, 58), false)
	Components.texts(row, item, 84, 0, true)
	local valueBox = create("TextBox", {
		Name = "Value",
		Text = "",
		ClearTextOnFocus = false,
		FontFace = FONT.Mono,
		TextSize = 12,
		TextColor3 = THEME.Text,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(62, 22),
		BackgroundColor3 = THEME.Input,
		BorderSizePixel = 0,
		Parent = row,
	}, { Util.corner(RADIUS.Small), Util.stroke(THEME.StrokeSoft) })
	Tooltip.attach(valueBox, function()
		return I18n.t("slider.hint") .. ("  [%s – %s]"):format(formatNumber(item.min), formatNumber(item.max))
	end)
	local hit = create("TextButton", {
		Name = "Track",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -4),
		Size = UDim2.new(1, -28, 0, 20),
		Parent = row,
	})
	local track = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = THEME.Track,
		BorderSizePixel = 0,
		Parent = hit,
	}, { Util.corner(2) })
	local fill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = track,
	}, {
		Util.corner(2),
		create("UIGradient", { Color = ColorSequence.new(THEME.AccentDark, THEME.Accent) }),
	})
	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = track,
	}, { Util.corner(RADIUS.Pill), Util.stroke(THEME.Accent, 0, 2) })
	local knobScale = create("UIScale", { Parent = knob })
	local knobStroke = knob:FindFirstChildOfClass("UIStroke")

	-- Liquid Glass: while dragged the knob becomes a clear glass capsule (a lens over the
	-- track); released, it springs back to the solid knob.
	local function lensOn()
		if not Style.state().glass then
			return false
		end
		tween(knob, 0.25, { Size = UDim2.fromOffset(26, 16), BackgroundTransparency = 0.8 }, Enum.EasingStyle.Back)
		if knobStroke then
			tween(knobStroke, 0.2, { Color = GLASS_EDGE, Transparency = 0.15, Thickness = 1.5 })
		end
		return true
	end
	local function lensOff()
		tween(knob, 0.3, { Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 0 }, Enum.EasingStyle.Back)
		if knobStroke then
			tween(knobStroke, 0.2, { Color = THEME.Accent, Transparency = 0, Thickness = 2 })
		end
	end

	local function render(animate)
		local value = State[item.id] or item.min
		if not valueBox:IsFocused() then
			valueBox.Text = formatNumber(value)
		end
		local range = item.max - item.min
		local alpha = range > 0 and math.clamp((value - item.min) / range, 0, 1) or 0
		kit.setActive(false, false)
		if animate then
			tween(fill, 0.1, { Size = UDim2.fromScale(alpha, 1) })
			tween(knob, 0.1, { Position = UDim2.fromScale(alpha, 0.5) })
		else
			fill.Size = UDim2.fromScale(alpha, 1)
			knob.Position = UDim2.fromScale(alpha, 0.5)
		end
	end

	local function setFromX(x)
		local width = hit.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local alpha = math.clamp((x - hit.AbsolutePosition.X) / width, 0, 1)
		local value = item.min + (item.max - item.min) * alpha
		local element = Elements[item.id]
		if element and sanitize(item, value) ~= State[item.id] then
			element:Set(value)
		end
	end

	render(false)
	bindLive(item.id, row, render)
	hit.InputBegan:Connect(function(input)
		if Util.isPress(input) then
			local lens = lensOn()
			Components.setActiveSlider(setFromX, knobScale, lens and lensOff or nil)
			tween(knobScale, 0.15, { Scale = lens and 1 or 1.35 }, Enum.EasingStyle.Back)
			setFromX(input.Position.X)
		end
	end)
	valueBox.Focused:Connect(function()
		tween(valueBox:FindFirstChildOfClass("UIStroke"), 0.15, { Color = THEME.Accent })
	end)
	valueBox.FocusLost:Connect(function()
		tween(valueBox:FindFirstChildOfClass("UIStroke"), 0.15, { Color = THEME.StrokeSoft })
		local number = tonumber((string.gsub(valueBox.Text, ",", ".")))
		local element = Elements[item.id]
		if number and element then
			element:Set(number)
		end
		render(true)
	end)
	return row
end

-- Display text of a dropdown value (format = optional function(option) -> label).
local function optionText(item, option)
	if item.format then
		return item.format(option)
	end
	-- Only the label is translated; the saved value stays the original option string.
	return I18n.lookup(tostring(option))
end

local function dropdownDisplay(item)
	local value = State[item.id]
	if item.type == "multidropdown" then
		value = value or {}
		if #value == 0 then
			return I18n.t("dropdown.none")
		elseif #value <= 2 then
			local names = {}
			for _, option in value do
				table.insert(names, optionText(item, option))
			end
			return table.concat(names, ", ")
		end
		return I18n.t("dropdown.count", #value)
	end
	if value == nil then
		return I18n.t("dropdown.none")
	end
	return optionText(item, value)
end

local DropPanel = { open = (nil :: any), close = (nil :: any), isOpen = (nil :: any) } -- defined below

function Components.dropdown(item, parent)
	local row, kit = Components.row(parent, rowHeight(item), true)
	Components.texts(row, item, 34, 0.42)
	local valueLabel = label({
		Name = "Value",
		FontFace = FONT.Medium,
		TextSize = 12,
		TextColor3 = THEME.SubText,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -32, 0.5, 0),
		Size = UDim2.new(0.42, -24, 0, 18),
		Parent = row,
	})
	Icons.make(row, "chevrons-up-down", 14, THEME.Muted, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
	}, "▾")
	local function render()
		valueLabel.Text = dropdownDisplay(item)
		if item.type == "multidropdown" then
			kit.setActive(#(State[item.id] or {}) > 0, true)
		end
	end
	render()
	bindLive(item.id, row, render)
	I18n.bind(valueLabel, function()
		return dropdownDisplay(item)
	end)
	row.Activated:Connect(function()
		DropPanel.open(item)
	end)
	return row
end

function Components.paragraph(item, parent)
	local card = create("Frame", {
		Name = "Paragraph",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.Row,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = parent,
	}, {
		Util.corner(RADIUS.Row),
		Util.stroke(THEME.StrokeSoft),
		Util.padding(14, 14, 10, 11),
		Util.list(4),
	})
	local title = label({
		Name = "Title",
		FontFace = FONT.Bold,
		TextSize = 12,
		TextColor3 = THEME.Accent,
		Size = UDim2.new(1, 0, 0, 15),
		LayoutOrder = 1,
		Parent = card,
	})
	local text = label({
		Name = "Text",
		FontFace = FONT.Regular,
		TextSize = 12,
		TextColor3 = THEME.SubText,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = card,
	})
	local function render()
		local titleText = I18n.resolve(item.labelRaw)
		title.Text = titleText
		title.Visible = titleText ~= ""
		text.Text = I18n.resolve(item.textRaw)
	end
	render()
	bindLive(item.id, card, render)
	I18n.bind(text, function()
		render()
		return text.Text
	end)
	return card
end

function Components.input(item, parent)
	local row = Components.row(parent, rowHeight(item, 66), false)
	Components.texts(row, item, 0, 0, true)
	local box = create("TextBox", {
		Name = "Input",
		Text = tostring(State[item.id] or ""),
		ClearTextOnFocus = false,
		FontFace = FONT.Medium,
		TextSize = 13,
		TextColor3 = THEME.Text,
		PlaceholderColor3 = THEME.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -9),
		Size = UDim2.new(1, -24, 0, 28),
		BackgroundColor3 = THEME.Input,
		BorderSizePixel = 0,
		Parent = row,
	}, { Util.corner(RADIUS.Small), Util.padding(10, 10, 0, 0) })
	local boxStroke = Util.stroke(THEME.StrokeSoft)
	boxStroke.Parent = box
	I18n.bind(box, function()
		return hasText(item.placeholderRaw) and I18n.resolve(item.placeholderRaw) or I18n.t("input.placeholder")
	end, "PlaceholderText")
	local function render()
		local value = tostring(State[item.id] or "")
		if not box:IsFocused() and box.Text ~= value then
			box.Text = value
		end
	end
	render()
	bindLive(item.id, row, render)
	box.Focused:Connect(function()
		tween(boxStroke, 0.15, { Color = THEME.Accent })
	end)
	box.FocusLost:Connect(function()
		tween(boxStroke, 0.15, { Color = THEME.StrokeSoft })
		local value = string.sub(box.Text, 1, item.maxLength or 150)
		if box.Text ~= value then
			box.Text = value
		end
		local element = Elements[item.id]
		if element and value ~= State[item.id] then
			element:Set(value)
		end
	end)
	row.Destroying:Connect(function()
		if box:IsFocused() then
			box:ReleaseFocus(false)
		end
	end)
	return row
end

-- Internal control (Settings): captures the next key press.
function Components.keybind(item, parent)
	local row = Components.row(parent, rowHeight(item), true)
	Components.texts(row, item, 112)
	local pill = label({
		Name = "Key",
		FontFace = FONT.Mono,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(100, 26),
		BackgroundColor3 = THEME.Input,
		BackgroundTransparency = 0,
		Parent = row,
	})
	Util.corner(RADIUS.Small).Parent = pill
	local pillStroke = Util.stroke(THEME.StrokeSoft)
	pillStroke.Parent = pill
	local function render()
		pill.Text = Util.keyName(toggleKeyCode())
		pillStroke.Color = THEME.StrokeSoft
	end
	render()
	row.Activated:Connect(function()
		pill.Text = I18n.t("settings.key.press")
		pillStroke.Color = THEME.Accent
		Components.keyCapture = function(keyCode)
			Components.keyCapture = nil
			if keyCode and keyCode ~= Enum.KeyCode.Escape then
				item.onKey(keyCode)
			end
			if pill.Parent then
				render()
			end
		end
	end)
	return row
end

-- Grid of small metric tiles (label + live value). entries = { { key, get = function } }.
-- Returns update(), which refreshes every value; used by the monitor and player info.
function Components.metrics(parent, entries, order, columns)
	local grid = create("Frame", {
		Name = "Metrics",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order or 1,
		Parent = parent,
	})
	create("UIGridLayout", {
		CellSize = UDim2.new(1 / (columns or 2), -6, 0, 46),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	local values = {}
	for index, entry in entries do
		local tile = create("Frame", {
			BackgroundColor3 = THEME.Row,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Parent = grid,
		}, { Util.corner(RADIUS.Row), Util.stroke(THEME.StrokeSoft) })
		Style.register(tile, "row")
		I18n.bind(label({
			FontFace = FONT.Medium,
			TextSize = 10,
			TextColor3 = THEME.Muted,
			Position = UDim2.fromOffset(12, 7),
			Size = UDim2.new(1, -20, 0, 13),
			Parent = tile,
		}), entry.key)
		values[index] = label({
			Text = "…",
			FontFace = FONT.Bold,
			TextSize = 14,
			Position = UDim2.fromOffset(12, 21),
			Size = UDim2.new(1, -20, 0, 18),
			Parent = tile,
		})
	end
	local function update()
		for index, entry in entries do
			local ok, text, color = pcall(entry.get)
			values[index].Text = ok and tostring(text) or I18n.t("metric.na")
			values[index].TextColor3 = (ok and color) or THEME.Text
		end
	end
	update()
	return update, grid
end

local BUILDERS = {
	toggle = Components.toggle,
	action = Components.button,
	slider = Components.slider,
	dropdown = Components.dropdown,
	multidropdown = Components.dropdown,
	paragraph = Components.paragraph,
	inputbox = Components.input,
	keybind = Components.keybind,
}

-- Estimated height, used to balance sections between the two columns.
local function estimateItem(item)
	local extra = hasText(item.descRaw) and 13 or 0
	if item.type == "slider" then
		return 58 + extra
	elseif item.type == "inputbox" then
		return 66 + extra
	elseif item.type == "paragraph" then
		return 40 + math.floor(#I18n.resolve(item.textRaw) / 45) * 15
	end
	return LAYOUT.Row + extra
end

function Components.sectionHeight(section)
	local total = hasText(section.descRaw) and 60 or 46
	for _, item in section.items do
		total += estimateItem(item) + 8
	end
	return total
end

-- Section card: title, description, number of options and the stacked rows.
function Components.section(parent, section, order)
	local card = create("Frame", {
		Name = "Section",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.Surface,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = parent,
	}, {
		Util.corner(RADIUS.Card),
		Util.stroke(THEME.StrokeSoft),
		Util.padding(12, 12, 12, 12),
		Util.list(8),
	})
	Style.register(card, "surface")
	local hasDesc = hasText(section.descRaw)
	local header = create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, hasDesc and 34 or 20),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Parent = card,
	})
	create("Frame", {
		Position = UDim2.fromOffset(0, 3),
		Size = UDim2.fromOffset(3, 14),
		BackgroundColor3 = THEME.Accent,
		BorderSizePixel = 0,
		Parent = header,
	}, { Util.corner(2) })
	local title = label({
		FontFace = FONT.Bold,
		TextSize = 14,
		Position = UDim2.fromOffset(11, 0),
		Size = UDim2.new(1, -50, 0, 20),
		Parent = header,
	})
	I18n.bind(title, function()
		return I18n.resolve(section.nameRaw)
	end)
	label({
		Text = tostring(#section.items),
		FontFace = FONT.Mono,
		TextSize = 11,
		TextColor3 = THEME.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(40, 20),
		Parent = header,
	})
	if hasDesc then
		local desc = label({
			FontFace = FONT.Regular,
			TextSize = 11,
			TextColor3 = THEME.Muted,
			Position = UDim2.fromOffset(11, 20),
			Size = UDim2.new(1, -11, 0, 14),
			Parent = header,
		})
		I18n.bind(desc, function()
			return I18n.resolve(section.descRaw)
		end)
	end
	for index, item in section.items do
		local build = BUILDERS[item.type]
		if build then
			local ok, rowOrErr = pcall(build, item, card)
			if ok then
				rowOrErr.LayoutOrder = index
			else
				warn("[MultiHub] could not build '" .. tostring(item.id) .. "': " .. tostring(rowOrErr))
			end
		end
	end
	return card
end

-- == DROPDOWN PANEL ========================================================
-- Slides in from the right over a dimmed window. Single = pick one and close.
-- Multi = mark several and stays open (close with the X, a click outside or Escape).

do
	local PANEL_W = 270
	local HIDDEN = UDim2.new(1, PANEL_W + 16, 0.5, 0)
	local SHOWN = UDim2.new(1, -10, 0.5, 0)

	local overlay = create("TextButton", {
		Name = "DropdownOverlay",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 30,
		Parent = window,
	})
	local panel = create("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = HIDDEN,
		Size = UDim2.new(0, PANEL_W, 1, -20),
		BackgroundColor3 = THEME.Surface,
		BorderSizePixel = 0,
		Active = true,
		ClipsDescendants = true,
		ZIndex = 31,
		Parent = overlay,
	}, { Util.corner(RADIUS.Card + 2), Util.stroke(THEME.Stroke, 0) })
	Style.register(panel, "panel")

	local title = label({
		FontFace = FONT.Bold,
		TextSize = 15,
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.new(1, -60, 0, 20),
		ZIndex = 32,
		Parent = panel,
	})
	local hint = label({
		FontFace = FONT.Regular,
		TextSize = 11,
		TextColor3 = THEME.Muted,
		Position = UDim2.fromOffset(16, 34),
		Size = UDim2.new(1, -60, 0, 14),
		ZIndex = 32,
		Parent = panel,
	})
	local closeButton = UI.iconButton(panel, "x", "×", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 12),
		ZIndex = 32,
	})

	local filterBox = create("TextBox", {
		Text = "",
		ClearTextOnFocus = false,
		FontFace = FONT.Medium,
		TextSize = 12,
		TextColor3 = THEME.Text,
		PlaceholderColor3 = THEME.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(12, 58),
		Size = UDim2.new(1, -24, 0, 30),
		BackgroundColor3 = THEME.Input,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 32,
		Parent = panel,
	}, { Util.corner(RADIUS.Small), Util.stroke(THEME.StrokeSoft), Util.padding(10, 10, 0, 0) })
	I18n.bind(filterBox, "dropdown.filter", "PlaceholderText")

	local toolbar = create("Frame", {
		Position = UDim2.fromOffset(12, 58),
		Size = UDim2.new(1, -24, 0, 26),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 32,
		Parent = panel,
	}, { Util.list(6, Enum.FillDirection.Horizontal) })
	local function toolbarButton(order, key)
		local button = create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.new(0.5, -3, 1, 0),
			BackgroundColor3 = THEME.Row,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 32,
			Parent = toolbar,
		}, { Util.corner(RADIUS.Small) })
		I18n.bind(label({
			FontFace = FONT.SemiBold,
			TextSize = 11,
			TextColor3 = THEME.SubText,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 33,
			Parent = button,
		}), key)
		Util.hover(button, function()
			tween(button, 0.15, { BackgroundColor3 = THEME.RowHover })
		end, function()
			tween(button, 0.2, { BackgroundColor3 = THEME.Row })
		end)
		return button
	end
	local allButton = toolbarButton(1, "dropdown.all")
	local clearButton = toolbarButton(2, "dropdown.clear")

	local list = create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 1, -58),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = THEME.Accent,
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 32,
		Parent = panel,
	}, { Util.list(4), Util.padding(12, 12, 2, 12) })

	local openItem = nil
	local optionRows = {} -- { row, option, update }

	local function isSelected(item, option)
		if item.type == "multidropdown" then
			return inList(State[item.id] or {}, option)
		end
		return State[item.id] == option
	end

	local function refreshMarks()
		for _, entry in optionRows do
			entry.update(true)
		end
	end

	function DropPanel.close()
		if not openItem then
			return
		end
		openItem = nil
		tween(overlay, 0.22, { BackgroundTransparency = 1 })
		tween(panel, 0.25, { Position = HIDDEN })
		task.delay(0.26, function()
			if not openItem then
				overlay.Visible = false
			end
		end)
	end
	DropPanel.isOpen = function()
		return openItem ~= nil
	end

	local function applyFilter()
		local query = string.lower(filterBox.Text)
		for _, entry in optionRows do
			entry.row.Visible = query == "" or string.find(string.lower(optionText(openItem, entry.option)), query, 1, true) ~= nil
		end
	end
	filterBox:GetPropertyChangedSignal("Text"):Connect(function()
		if openItem then
			applyFilter()
		end
	end)

	function DropPanel.open(item)
		local multi = item.type == "multidropdown"
		Util.clear(list)
		table.clear(optionRows)
		title.Text = I18n.resolve(item.labelRaw)
		hint.Text = I18n.t(multi and "dropdown.many" or "dropdown.one")
		filterBox.Text = ""
		local useFilter = #item.options > 6
		filterBox.Visible = useFilter
		toolbar.Visible = multi
		local top = 58
		if useFilter then
			top += 36
		end
		toolbar.Position = UDim2.fromOffset(12, top)
		if multi then
			top += 32
		end
		list.Position = UDim2.fromOffset(0, top)
		list.Size = UDim2.new(1, 0, 1, -top)
		list.CanvasPosition = Vector2.zero

		if #item.options == 0 then
			label({
				FontFace = FONT.Medium,
				TextSize = 12,
				TextColor3 = THEME.Muted,
				Size = UDim2.new(1, 0, 0, 30),
				ZIndex = 33,
				Text = I18n.t("dropdown.empty"),
				Parent = list,
			})
		end
		for index, option in item.options do
			local row = create("TextButton", {
				Text = "",
				AutoButtonColor = false,
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundColor3 = THEME.Row,
				BorderSizePixel = 0,
				LayoutOrder = index,
				ZIndex = 33,
				Parent = list,
			}, { Util.corner(RADIUS.Small) })
			local stroke = Util.stroke(THEME.StrokeSoft)
			stroke.Parent = row
			local text = label({
				Text = optionText(item, option),
				FontFace = FONT.Medium,
				TextSize = 13,
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -44, 1, 0),
				ZIndex = 34,
				Parent = row,
			})
			local check = Icons.make(row, "check", 14, THEME.Accent, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				ZIndex = 34,
			}, "✓")
			local hovered = false
			local function update(animate)
				local on = isSelected(item, option)
				check.Visible = on
				local goalRow = { BackgroundColor3 = on and THEME.AccentSoft or (hovered and THEME.RowHover or THEME.Row) }
				local goalStroke = { Color = on and THEME.AccentDark or THEME.StrokeSoft }
				text.TextColor3 = on and THEME.Text or THEME.SubText
				if animate then
					tween(row, 0.15, goalRow)
					tween(stroke, 0.15, goalStroke)
				else
					row.BackgroundColor3 = goalRow.BackgroundColor3
					stroke.Color = goalStroke.Color
				end
			end
			update(false)
			Util.hover(row, function()
				hovered = true
				update(true)
			end, function()
				hovered = false
				update(true)
			end)
			table.insert(optionRows, { row = row, option = option, update = update })
			row.Activated:Connect(function()
				local element = Elements[item.id]
				if not element then
					return
				end
				if multi then
					local selected = table.clone(State[item.id] or {})
					local at = table.find(selected, option)
					if at then
						table.remove(selected, at)
					else
						table.insert(selected, option)
					end
					element:Set(selected)
					refreshMarks()
				else
					element:Set(option)
					refreshMarks()
					task.delay(0.12, DropPanel.close)
				end
			end)
		end

		openItem = item
		overlay.Visible = true
		panel.Position = HIDDEN
		tween(overlay, 0.22, { BackgroundTransparency = 0.45 })
		tween(panel, 0.32, { Position = SHOWN })
	end

	allButton.Activated:Connect(function()
		if openItem and openItem.type == "multidropdown" then
			Elements[openItem.id]:Set(table.clone(openItem.options))
			refreshMarks()
		end
	end)
	clearButton.Activated:Connect(function()
		if openItem and openItem.type == "multidropdown" then
			Elements[openItem.id]:Set({})
			refreshMarks()
		end
	end)
	overlay.Activated:Connect(DropPanel.close)
	closeButton.Activated:Connect(DropPanel.close)
end

-- == ROUTER ================================================================

local Router = {
	pages = {},
	hooks = {},
	token = 0,
	current = (nil :: any),
	currentTab = (nil :: any),
	openTab = (nil :: any),
	refreshCurrent = (nil :: any),
	go = (nil :: any),
}
local Nav = { items = {}, active = (nil :: any) }
local Status = { queued = false, perTab = {}, total = 0, features = 0, categories = 0, player = 0 }
local Pages = {
	updateHomeStats = (nil :: any),
	rebuildHome = (nil :: any),
	rebuildGrid = (nil :: any),
	renderTab = (nil :: any),
	renderSearch = (nil :: any),
	subScroll = (nil :: any),
	gridBadges = {},
	cardPainters = {},
	paintCards = (nil :: any),
	quickBadges = {},
}

-- Shorthand for internal labels: T("key") is a getter that follows the language.
local function T(key)
	return function()
		return I18n.t(key)
	end
end

function Router.newPage(name, scrolling)
	local page = create("CanvasGroup", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Parent = content,
	})
	local scroll
	if scrolling then
		scroll = create("ScrollingFrame", {
			Name = "Scroll",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = THEME.Accent,
			ScrollBarImageTransparency = 0.3,
			CanvasSize = UDim2.fromScale(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Parent = page,
		}, { Util.list(12), Util.padding(18, 20, 12, 18) })
		table.insert(Components.scrollers, scroll)
	end
	Router.pages[name] = page
	return page, scroll
end

-- Width available for page content (design pixels), used to choose 1 or 2 columns.
function Router.contentWidth()
	return LAYOUT.W - 38
end

-- A token invalidates older transitions when the user clicks fast (no two pages animating).
function Router.show(name, navKey)
	local page = Router.pages[name]
	if not page then
		warn("[MultiHub] unknown page: " .. tostring(name))
		return
	end
	Nav.setActive(navKey or string.lower(name))
	Tooltip.hide()
	DropPanel.close()

	local previous = Router.current
	Router.current = name
	Router.token += 1
	local token = Router.token
	if previous == name then
		if Router.hooks[name] then
			task.spawn(Router.hooks[name])
		end
		return
	end
	task.spawn(function()
		if previous and Router.pages[previous] then
			local prevPage = Router.pages[previous]
			tween(prevPage, 0.12, { GroupTransparency = 1, Position = UDim2.fromOffset(0, -6) }).Completed:Wait()
			if Router.current ~= previous then
				prevPage.Visible = false
			end
		end
		if token ~= Router.token then
			return
		end
		page.Position = UDim2.fromOffset(0, 12)
		page.GroupTransparency = 1
		page.Visible = true
		if Router.hooks[name] then
			local ok, err = pcall(Router.hooks[name])
			if not ok then
				warn("[MultiHub] page hook '" .. name .. "' failed: " .. tostring(err))
			end
		end
		tween(page, 0.28, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })
	end)
end

-- == NAV ===================================================================
-- Horizontal tabs: icon + label + red counter; the active tab turns red and gets an underline.

function Nav.item(key, iconName, glyph, textKey, order, onClick)
	local button = create("TextButton", {
		Name = key,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = navScroll,
	})
	local inner = create("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = button,
	}, {
		Util.padding(12, 12, 0, 0),
		Util.list(7, Enum.FillDirection.Horizontal, { VerticalAlignment = Enum.VerticalAlignment.Center }),
	})
	local _, setIconColor = Icons.make(inner, iconName, 15, THEME.SubText, { LayoutOrder = 1 }, glyph)
	local text = label({
		FontFace = FONT.SemiBold,
		TextSize = 13,
		TextColor3 = THEME.SubText,
		TextTruncate = Enum.TextTruncate.None,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		LayoutOrder = 2,
		Parent = inner,
	})
	I18n.bind(text, textKey)
	local badge = label({
		Text = "0",
		FontFace = FONT.Bold,
		TextSize = 10,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Size = UDim2.fromOffset(18, 16),
		BackgroundColor3 = THEME.Accent,
		BackgroundTransparency = 0,
		LayoutOrder = 3,
		Visible = false,
		Parent = inner,
	})
	Util.corner(8).Parent = badge
	local underline = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(0, 0, 0, 2),
		BackgroundColor3 = THEME.Accent,
		BorderSizePixel = 0,
		Parent = button,
	}, { Util.corner(1) })
	-- Liquid Glass: the active tab sits in a glass capsule that grows out of the centre.
	local pillStroke = Util.stroke(GLASS_EDGE, 0.1, 1)
	Style.addRim(pillStroke)
	setRim(pillStroke, true)
	local pill = create("Frame", {
		Name = "GlassPill",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 0, 1, -10),
		BackgroundColor3 = GLASS_EDGE,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		ZIndex = 0,
		Visible = false,
		Parent = button,
	}, {
		Util.corner(RADIUS.Pill),
		pillStroke,
		create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new(0, 0.6),
		}),
	})

	local obj = { button = button, active = false, hovered = false }
	local function paint(animate)
		local on = obj.active
		local color = on and THEME.Accent or (obj.hovered and THEME.Text or THEME.SubText)
		local lineGoal = { Size = UDim2.new(on and 1 or (obj.hovered and 0.3 or 0), on and -20 or 0, 0, 2) }
		local glass = Style.state().glass
		local pillOn = glass and on
		local pillGoal = { Size = pillOn and UDim2.new(1, -4, 1, -10) or UDim2.new(0, 0, 1, -10) }
		if pillOn then
			pill.Visible = true
		end
		if animate then
			tween(text, 0.18, { TextColor3 = color })
			tween(underline, 0.28, lineGoal)
			local pillTween = tween(pill, pillOn and 0.45 or 0.2, pillGoal, pillOn and Enum.EasingStyle.Back or nil)
			if not pillOn and pillTween then
				pillTween.Completed:Once(function()
					if not (obj.active and Style.state().glass) then
						pill.Visible = false
					end
				end)
			end
		else
			text.TextColor3 = color
			underline.Size = lineGoal.Size
			pill.Size = pillGoal.Size
			pill.Visible = pillOn
		end
		setIconColor(color, animate)
	end
	function obj.setActive(on, animate)
		obj.active = on
		paint(animate)
	end
	function obj.setBadge(count)
		badge.Text = count > 99 and "99+" or tostring(count)
		badge.Size = UDim2.fromOffset(count > 9 and 24 or 18, 16)
		badge.Visible = count > 0
	end
	Util.hover(button, function()
		obj.hovered = true
		paint(true)
	end, function()
		obj.hovered = false
		paint(true)
	end)
	Util.pressScale(button, 0.95)
	button.Activated:Connect(onClick)
	paint(false)
	Style.onChange(function()
		paint(false)
	end)
	Nav.items[key] = obj
	return obj
end

function Nav.setActive(key)
	Nav.active = key
	for itemKey, item in Nav.items do
		item.setActive(itemKey == key, true)
	end
	-- Phones: keep the active tab inside the visible part of the scrolling bar.
	local item = Nav.items[key]
	local barWidth = navScroll.AbsoluteSize.X
	if item and barWidth > 0 then
		local left = item.button.AbsolutePosition.X - navScroll.AbsolutePosition.X
		local right = left + item.button.AbsoluteSize.X
		if left < 0 or right > barWidth then
			local pixelsPerUnit = barWidth / math.max(LAYOUT.W - 24, 1)
			local target = navScroll.CanvasPosition.X + left / math.max(pixelsPerUnit, 0.01) - 12
			tween(navScroll, 0.25, { CanvasPosition = Vector2.new(math.max(target, 0), 0) })
		end
	end
end

-- == STATUS ================================================================
-- Enabled toggles: counter per page card, red badges in the nav, "N active" pill, Home stats.

function Status.compute()
	local total, features, categories = 0, 0, 0
	table.clear(Status.perTab)
	for _, tab in TABS do
		local count, items = 0, 0
		for _, section in tab.sections do
			for _, item in section.items do
				if item.type ~= "paragraph" then
					items += 1
				end
				if item.type == "toggle" and State[item.id] == true then
					count += 1
				end
			end
		end
		Status.perTab[tab.id] = count
		total += count
		features += items
		if items > 0 then
			categories += 1
		end
	end
	local player = 0
	for _, element in Elements do
		if element.Item.group == "player" and element.Item.type == "toggle" and State[element.Id] == true then
			player += 1
		end
	end
	Status.total, Status.features, Status.categories, Status.player = total, features, categories, player
end

function Status.refresh()
	Status.compute()
	local all = Status.total + Status.player
	activeLabel.Visible = all > 0
	activeLabel.Text = I18n.t("top.active", all)
	if Nav.items.pages then
		Nav.items.pages.setBadge(Status.total)
	end
	if Nav.items.player then
		Nav.items.player.setBadge(Status.player)
	end
	for tabId, badge in Pages.gridBadges do
		local count = Status.perTab[tabId] or 0
		badge.Visible = count > 0
		badge.Text = I18n.t("tab.active", count)
	end
	if Pages.updateHomeStats then
		Pages.updateHomeStats()
	end
end

Store.OnChange = function()
	if Status.queued then
		return
	end
	Status.queued = true
	task.defer(function()
		Status.queued = false
		if Maid.alive then
			Status.refresh()
		end
	end)
end

-- == PAGES =================================================================

-- Page title block (reference style): small red eyebrow + bold title + optional description.
function Pages.header(parent, eyebrowKey, titleKey, descKey, order, props)
	local block = create("Frame", Util.merge({
		Name = "PageHeader",
		Size = UDim2.new(1, 0, 0, descKey and 56 or 40),
		BackgroundTransparency = 1,
		LayoutOrder = order or 0,
		Parent = parent,
	}, props))
	I18n.bind(label({
		FontFace = FONT.Bold,
		TextSize = 10,
		TextColor3 = THEME.Accent,
		Size = UDim2.new(1, 0, 0, 12),
		Parent = block,
	}), eyebrowKey)
	I18n.bind(label({
		FontFace = FONT.Bold,
		TextSize = 21,
		Position = UDim2.fromOffset(0, 13),
		Size = UDim2.new(1, 0, 0, 26),
		Parent = block,
	}), titleKey)
	if descKey then
		I18n.bind(label({
			FontFace = FONT.Regular,
			TextSize = 12,
			TextColor3 = THEME.Muted,
			Position = UDim2.fromOffset(0, 40),
			Size = UDim2.new(1, 0, 0, 15),
			Parent = block,
		}), descKey)
	end
	return block
end

local function emptyState(parent, iconName, titleText, hintText, order)
	local box = create("Frame", {
		Name = "Empty",
		Size = UDim2.new(1, 0, 0, 150),
		BackgroundTransparency = 1,
		LayoutOrder = order or 1,
		Parent = parent,
	})
	local circle = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = THEME.AccentSoft,
		BorderSizePixel = 0,
		Parent = box,
	}, { Util.corner(26) })
	Icons.make(circle, iconName, 22, THEME.Accent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	})
	label({
		Text = titleText,
		FontFace = FONT.Bold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = box,
	})
	label({
		Text = hintText,
		FontFace = FONT.Regular,
		TextSize = 12,
		TextColor3 = THEME.Muted,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.new(0.1, 0, 0, 104),
		Size = UDim2.new(0.8, 0, 0, 34),
		Parent = box,
	})
	return box
end

-- Sections in one or two columns; each new section goes to the shorter column.
local function buildSectionColumns(parent, sections, order)
	if Router.contentWidth() < 470 or #sections == 1 then
		local stack = create("Frame", {
			Name = "Stack",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = parent,
		}, { Util.list(12) })
		for index, section in sections do
			Components.section(stack, section, index)
		end
		return stack
	end
	local columns = create("Frame", {
		Name = "Columns",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	local cols, heights = {}, { 0, 0 }
	for index = 1, 2 do
		cols[index] = create("Frame", {
			Name = "Col" .. index,
			Position = UDim2.new(index == 1 and 0 or 0.5, index == 1 and 0 or 6, 0, 0),
			Size = UDim2.new(0.5, -6, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = columns,
		}, { Util.list(12) })
	end
	for index, section in sections do
		local target = heights[1] <= heights[2] and 1 or 2
		heights[target] += Components.sectionHeight(section) + 12
		Components.section(cols[target], section, index)
	end
	return columns
end
Pages.columns = buildSectionColumns

-- Entrance: cards rise one after another (skipped with animations off).
local function staggerIn(container)
	if not Prefs.animations then
		return
	end
	local cards = {}
	for _, child in container:GetDescendants() do
		if child.Name == "Section" or child.Name == "QuickCard" or child.Name == "Stat" or child.Name == "PageCard" then
			table.insert(cards, child)
		end
	end
	for index, card in cards do
		-- A GuiObject honors a single UIScale: reuse the press scale when the card has one.
		local scale = card:FindFirstChildOfClass("UIScale") or create("UIScale", { Name = "Enter", Parent = card })
		scale.Scale = 0.95
		task.delay(math.min(index - 1, 12) * 0.025, function()
			if scale.Parent then
				tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end)
	end
end
Pages.staggerIn = staggerIn

local function tabTitle(tab)
	return I18n.resolve(tab.titleRaw)
end

local function tabSubtitle(tab)
	local desc = I18n.resolve(tab.descRaw)
	if desc ~= "" then
		return desc
	end
	local count = 0
	for _, section in tab.sections do
		count += #section.items
	end
	return I18n.t("tab.options", count)
end

-- Home -------------------------------------------------------------------------

do
	local _, scroll = Router.newPage("Home", true)

	-- Hero: game thumbnail behind a dark gradient, welcome text and community buttons.
	local hero = create("Frame", {
		Name = "Hero",
		Size = UDim2.new(1, 0, 0, 160),
		BackgroundColor3 = THEME.Surface,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Parent = scroll,
	}, { Util.corner(RADIUS.Card + 2), Util.stroke(THEME.StrokeSoft) })
	Style.register(hero, "surface")
	local thumb = create("ImageLabel", {
		Name = "Thumbnail",
		BackgroundTransparency = 1,
		ImageTransparency = 1,
		ScaleType = Enum.ScaleType.Crop,
		Size = UDim2.fromScale(1, 1),
		Parent = hero,
	}, { Util.corner(RADIUS.Card + 2) })
	Style.register(thumb, "heavy")
	create("Frame", {
		Name = "Shade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.Bg,
		BorderSizePixel = 0,
		Parent = hero,
	}, {
		Util.corner(RADIUS.Card + 2),
		create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.04),
				NumberSequenceKeypoint.new(0.55, 0.3),
				NumberSequenceKeypoint.new(1, 0.62),
			}),
		}),
	})
	I18n.bind(label({
		FontFace = FONT.Bold,
		TextSize = 11,
		TextColor3 = THEME.Muted,
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.new(0.7, 0, 0, 14),
		Parent = hero,
	}), "home.welcome")
	label({
		RichText = true,
		Text = hubRest and (hubFirst .. ' <font color="' .. Util.hex(THEME.Accent) .. '">' .. hubRest .. "</font>") or CONFIG.HubName,
		FontFace = FONT.Display,
		TextSize = 32,
		TextTruncate = Enum.TextTruncate.None,
		Position = UDim2.fromOffset(19, 30),
		Size = UDim2.new(0.7, 0, 0, 38),
		Parent = hero,
	})
	create("Frame", {
		Position = UDim2.fromOffset(20, 71),
		Size = UDim2.fromOffset(34, 2),
		BackgroundColor3 = THEME.Accent,
		BorderSizePixel = 0,
		Parent = hero,
	}, { Util.corner(1) })
	I18n.bind(label({
		FontFace = FONT.Regular,
		TextSize = 12,
		TextColor3 = THEME.SubText,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(20, 81),
		Size = UDim2.new(0.62, -20, 0, 32),
		Parent = hero,
	}), "home.message")

	local socials = create("Frame", {
		Position = UDim2.fromOffset(20, 120),
		Size = UDim2.new(1, -40, 0, 26),
		BackgroundTransparency = 1,
		Parent = hero,
	}, { Util.list(8, Enum.FillDirection.Horizontal) })
	for order, social in CONFIG.Social do
		local pill = create("TextButton", {
			Name = social.Id,
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = THEME.Row,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = socials,
		}, {
			Util.corner(13),
			Util.stroke(THEME.Stroke, 0.3),
			Util.padding(10, 12, 0, 0),
			Util.list(6, Enum.FillDirection.Horizontal, { VerticalAlignment = Enum.VerticalAlignment.Center }),
		})
		local _, setColor = Icons.make(pill, social.Icon, 14, THEME.Text, { LayoutOrder = 1 }, social.Glyph)
		label({
			Text = social.Name,
			FontFace = FONT.SemiBold,
			TextSize = 12,
			TextTruncate = Enum.TextTruncate.None,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 26),
			LayoutOrder = 2,
			Parent = pill,
		})
		Util.hover(pill, function()
			tween(pill, 0.15, { BackgroundColor3 = THEME.AccentSoft })
			setColor(THEME.Accent, true)
		end, function()
			tween(pill, 0.2, { BackgroundColor3 = THEME.Row })
			setColor(THEME.Text, true)
		end)
		Util.pressScale(pill, 0.94)
		Tooltip.attach(pill, function()
			return social.Url
		end)
		pill.Activated:Connect(function()
			LinkDialog.open(social)
		end)
	end

	local floatBox = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -28, 0.5, 0),
		Size = UDim2.fromOffset(80, 80),
		BackgroundTransparency = 1,
		Parent = hero,
	})
	UI.buildLogo(floatBox, 80)
	UI.heroFloat = TweenService:Create(floatBox, TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = UDim2.new(1, -28, 0.5, -6),
	})

	-- Thumbnail + real game name (yields, so it runs in the background).
	task.spawn(function()
		local info = Util.productInfo()
		if not info or not Maid.alive then
			return
		end
		if type(info.Name) == "string" and info.Name ~= "" then
			UI.gameName = info.Name
			UI.updateFooter()
		end
		local assetId = info.IconImageAssetId
		if assetId and assetId ~= 0 then
			thumb.Image = "rbxassetid://" .. tostring(assetId)
			tween(thumb, 0.6, { ImageTransparency = 0.35 })
		end
	end)

	local stats = create("Frame", {
		Name = "Stats",
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = scroll,
	}, { Util.list(10, Enum.FillDirection.Horizontal) })
	local statValues = {}
	local function stat(order, key, iconName)
		local card = create("Frame", {
			Name = "Stat",
			Size = UDim2.new(0.25, -8, 1, 0),
			BackgroundColor3 = THEME.Surface,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = stats,
		}, { Util.corner(RADIUS.Card), Util.stroke(THEME.StrokeSoft) })
		Style.register(card, "surface")
		local tile = create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(32, 32),
			BackgroundColor3 = THEME.AccentSoft,
			BorderSizePixel = 0,
			Parent = card,
		}, { Util.corner(RADIUS.Row) })
		Icons.make(tile, iconName, 16, THEME.Accent, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		})
		statValues[key] = label({
			Text = "0",
			FontFace = FONT.Bold,
			TextSize = 17,
			Position = UDim2.fromOffset(54, 11),
			Size = UDim2.new(1, -60, 0, 20),
			Parent = card,
		})
		I18n.bind(label({
			FontFace = FONT.Medium,
			TextSize = 11,
			TextColor3 = THEME.Muted,
			Position = UDim2.fromOffset(54, 31),
			Size = UDim2.new(1, -60, 0, 14),
			Parent = card,
		}), key)
	end
	stat(1, "home.stat.pages", "layout-grid")
	stat(2, "home.stat.features", "sliders-horizontal")
	stat(3, "home.stat.active", "zap")
	stat(4, "home.stat.session", "timer")

	function Pages.updateHomeStats()
		statValues["home.stat.pages"].Text = tostring(Status.categories)
		statValues["home.stat.features"].Text = tostring(Status.features)
		local active = statValues["home.stat.active"]
		local all = Status.total + Status.player
		active.Text = tostring(all)
		active.TextColor3 = all > 0 and THEME.Accent or THEME.Text
		for tabId, badge in Pages.quickBadges do
			local count = Status.perTab[tabId] or 0
			badge.Visible = count > 0
			badge.Text = I18n.t("tab.active", count)
		end
	end
	UI.homeSecond = function(second)
		statValues["home.stat.session"].Text = UI.formatElapsed(second)
	end

	local quickHeader = label({
		FontFace = FONT.Bold,
		TextSize = 10,
		TextColor3 = THEME.Muted,
		Size = UDim2.new(1, 0, 0, 14),
		LayoutOrder = 3,
		Parent = scroll,
	})
	I18n.bind(quickHeader, "home.quick")

	local quickGrid = create("Frame", {
		Name = "Quick",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = scroll,
	})
	create("UIGridLayout", {
		CellSize = UDim2.new(1 / 3, -8, 0, 66),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = quickGrid,
	})

	local function quickCard(tab, index)
		local card = create("TextButton", {
			Name = "QuickCard",
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = THEME.Surface,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Parent = quickGrid,
		}, { Util.corner(RADIUS.Card) })
		Style.register(card, "surface")
		local stroke = Util.stroke(THEME.StrokeSoft)
		stroke.Parent = card
		local tile = create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(38, 38),
			BackgroundColor3 = THEME.AccentSoft,
			BorderSizePixel = 0,
			Parent = card,
		}, { Util.corner(RADIUS.Row + 1) })
		Icons.make(tile, tab.icon, 19, THEME.Accent, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		}, string.upper(string.sub(tabTitle(tab), 1, 1)))
		I18n.bind(label({
			FontFace = FONT.Bold,
			TextSize = 13,
			Position = UDim2.fromOffset(60, 14),
			Size = UDim2.new(1, -70, 0, 17),
			Parent = card,
		}), function()
			return tabTitle(tab)
		end)
		I18n.bind(label({
			FontFace = FONT.Regular,
			TextSize = 11,
			TextColor3 = THEME.Muted,
			Position = UDim2.fromOffset(60, 33),
			Size = UDim2.new(1, -70, 0, 14),
			Parent = card,
		}), function()
			return tabSubtitle(tab)
		end)
		Pages.quickBadges[tab.id] = label({
			FontFace = FONT.Bold,
			TextSize = 10,
			TextColor3 = THEME.Accent,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 7),
			Size = UDim2.fromOffset(80, 12),
			Visible = false,
			Parent = card,
		})
		Util.hover(card, function()
			tween(card, 0.15, { BackgroundColor3 = Style.hoverColor(card) })
			tween(stroke, 0.15, { Color = THEME.AccentDark })
		end, function()
			tween(card, 0.2, { BackgroundColor3 = Style.baseColor(card) })
			tween(stroke, 0.2, { Color = THEME.StrokeSoft })
		end)
		Util.pressScale(card, 0.97)
		card.Activated:Connect(function()
			Router.openTab(tab)
		end)
	end

	function Pages.rebuildHome()
		Util.clear(quickGrid)
		table.clear(Pages.quickBadges)
		local shown = {}
		for _, id in CONFIG.QuickTabs do
			for _, tab in TABS do
				if tab.id == id and #shown < 6 then
					table.insert(shown, tab)
				end
			end
		end
		if #shown == 0 then
			for _, tab in TABS do
				if #shown >= 6 then
					break
				end
				table.insert(shown, tab)
			end
		end
		quickHeader.Visible = #shown > 0
		quickGrid.Visible = #shown > 0
		for index, tab in shown do
			quickCard(tab, index)
		end
		Pages.updateHomeStats()
	end

	Router.hooks.Home = function()
		UI.homeSecond(math.floor(os.clock() - UI.sessionStart))
		staggerIn(scroll)
	end
end

-- Pages (grid of the script's tabs + search) ------------------------------------------------

do
	local page = Router.newPage("Pages", false)
	Pages.header(page, "pages.eyebrow", "pages.title", nil, 0, {
		Position = UDim2.fromOffset(18, 14),
		Size = UDim2.fromOffset(170, 40),
	})

	local boxFrame = create("Frame", {
		Position = UDim2.fromOffset(190, 14),
		Size = UDim2.new(1, -210, 0, 40),
		BackgroundColor3 = THEME.Input,
		BorderSizePixel = 0,
		Parent = page,
	}, { Util.corner(RADIUS.Card) })
	Style.register(boxFrame, "input")
	local boxStroke = Util.stroke(THEME.Stroke, 0.2)
	boxStroke.Parent = boxFrame
	local queryBox = create("TextBox", {
		Text = "",
		ClearTextOnFocus = false,
		BackgroundTransparency = 1,
		FontFace = FONT.DisplayItalic,
		TextSize = 14,
		TextColor3 = THEME.Text,
		PlaceholderColor3 = THEME.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -130, 1, 0),
		Parent = boxFrame,
	})
	I18n.bind(queryBox, "search.placeholder", "PlaceholderText")
	local countLabel = label({
		FontFace = FONT.Medium,
		TextSize = 11,
		TextColor3 = THEME.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -40, 0.5, 0),
		Size = UDim2.fromOffset(80, 14),
		Parent = boxFrame,
	})
	Icons.make(boxFrame, "search", 15, THEME.Muted, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
	}, "⌕")
	queryBox.Focused:Connect(function()
		tween(boxStroke, 0.15, { Color = THEME.Accent, Transparency = 0 })
	end)
	queryBox.FocusLost:Connect(function()
		tween(boxStroke, 0.15, { Color = THEME.Stroke, Transparency = 0.2 })
	end)

	local function listScroll(name)
		local scroll = create("ScrollingFrame", {
			Name = name,
			Position = UDim2.fromOffset(0, 64),
			Size = UDim2.new(1, 0, 1, -64),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = THEME.Accent,
			ScrollBarImageTransparency = 0.3,
			CanvasSize = UDim2.fromScale(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Parent = page,
		}, { Util.list(10), Util.padding(18, 20, 6, 18) })
		table.insert(Components.scrollers, scroll)
		return scroll
	end
	local gridScroll = listScroll("Grid")
	local results = listScroll("Results")
	results.Visible = false

	local grid = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gridScroll,
	})
	create("UIGridLayout", {
		CellSize = UDim2.new(1 / 3, -8, 0, 68),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	-- Card from the reference: red border, icon, UPPERCASE title, description, number.
	local function pageCard(tab, index)
		local card = create("TextButton", {
			Name = "PageCard",
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = THEME.Surface,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Parent = grid,
		}, { Util.corner(RADIUS.Card) })
		Style.register(card, "surface")
		local stroke = Util.stroke(THEME.Stroke, 0.2)
		stroke.Parent = card
		local visual = { hovered = false }
		-- Red edge only on the selected card (the page opened last) or under the mouse.
		local function paintCard(animate)
			local selected = Router.currentTab == tab
			local lit = selected or visual.hovered
			local goalCard = { BackgroundColor3 = visual.hovered and Style.hoverColor(card) or Style.baseColor(card) }
			local goalStroke = {
				Color = lit and THEME.Accent or THEME.Stroke,
				Transparency = lit and (selected and 0 or 0.15) or 0.2,
			}
			if animate then
				tween(card, 0.15, goalCard)
				tween(stroke, 0.15, goalStroke)
			else
				card.BackgroundColor3 = goalCard.BackgroundColor3
				stroke.Color = goalStroke.Color
				stroke.Transparency = goalStroke.Transparency
			end
		end
		Pages.cardPainters[card] = paintCard
		paintCard(false)
		Icons.make(card, tab.icon, 18, THEME.Accent, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 16, 0.5, 0),
		}, string.upper(string.sub(tabTitle(tab), 1, 1)))
		I18n.bind(label({
			FontFace = FONT.Bold,
			TextSize = 13,
			Position = UDim2.fromOffset(48, 16),
			Size = UDim2.new(1, -86, 0, 17),
			Parent = card,
		}), function()
			return string.upper(tabTitle(tab))
		end)
		I18n.bind(label({
			FontFace = FONT.Regular,
			TextSize = 11,
			TextColor3 = THEME.Muted,
			Position = UDim2.fromOffset(48, 34),
			Size = UDim2.new(1, -56, 0, 14),
			Parent = card,
		}), function()
			return tabSubtitle(tab)
		end)
		label({
			Text = string.format("%02d", index),
			FontFace = FONT.Medium,
			TextSize = 10,
			TextColor3 = THEME.Muted,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 8),
			Size = UDim2.fromOffset(30, 12),
			Parent = card,
		})
		Pages.gridBadges[tab.id] = label({
			FontFace = FONT.Bold,
			TextSize = 10,
			TextColor3 = THEME.Accent,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -10, 1, -7),
			Size = UDim2.fromOffset(80, 12),
			Visible = false,
			Parent = card,
		})
		Util.hover(card, function()
			visual.hovered = true
			paintCard(true)
		end, function()
			visual.hovered = false
			paintCard(true)
		end)
		Util.pressScale(card, 0.97)
		card.Activated:Connect(function()
			Router.openTab(tab)
		end)
	end

	function Pages.paintCards()
		for card, paint in Pages.cardPainters do
			if card.Parent == nil then
				Pages.cardPainters[card] = nil
			else
				paint(true)
			end
		end
	end
	Style.onChange(function()
		Pages.paintCards()
	end)

	function Pages.rebuildGrid()
		Util.clear(grid)
		table.clear(Pages.gridBadges)
		table.clear(Pages.cardPainters)
		local empty = gridScroll:FindFirstChild("Empty")
		if empty then
			empty:Destroy()
		end
		for index, tab in TABS do
			pageCard(tab, index)
		end
		if #TABS == 0 then
			emptyState(gridScroll, "layout-grid", I18n.t("pages.empty.title"), I18n.t("pages.empty.hint"), 2)
		end
	end

	-- Search: the matching controls themselves, grouped by page, fully working.
	local function matches(raw, query)
		if raw == nil then
			return false
		end
		if string.find(string.lower(I18n.resolve(raw)), query, 1, true) then
			return true
		end
		if type(raw) == "table" then
			for _, text in raw do
				if type(text) == "string" and string.find(string.lower(text), query, 1, true) then
					return true
				end
			end
		end
		return false
	end

	local function groupHeader(tab, count, order)
		local head = create("Frame", {
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = results,
		})
		Icons.make(head, tab.icon, 15, THEME.Accent, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 2, 0.5, 0),
		}, string.upper(string.sub(tabTitle(tab), 1, 1)))
		I18n.bind(label({
			FontFace = FONT.Bold,
			TextSize = 13,
			Position = UDim2.fromOffset(24, 0),
			Size = UDim2.new(1, -110, 1, 0),
			Parent = head,
		}), function()
			return tabTitle(tab) .. "  ·  " .. I18n.t("search.count", count)
		end)
		local open = create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(74, 24),
			BackgroundColor3 = THEME.AccentSoft,
			BorderSizePixel = 0,
			Parent = head,
		}, { Util.corner(12) })
		I18n.bind(label({
			FontFace = FONT.SemiBold,
			TextSize = 11,
			TextColor3 = THEME.Accent,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			Parent = open,
		}), "search.open")
		Util.pressScale(open, 0.94)
		open.Activated:Connect(function()
			Router.openTab(tab)
		end)
	end

	local function itemColumns(items, order)
		local holderFrame = create("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = results,
		})
		local cols = {}
		for index = 1, 2 do
			cols[index] = create("Frame", {
				Position = UDim2.new(index == 1 and 0 or 0.5, index == 1 and 0 or 5, 0, 0),
				Size = UDim2.new(0.5, -5, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Parent = holderFrame,
			}, { Util.list(8) })
		end
		for index, item in items do
			local build = BUILDERS[item.type]
			if build then
				local ok, row = pcall(build, item, cols[(index - 1) % 2 + 1])
				if ok then
					row.LayoutOrder = index
				end
			end
		end
	end

	function Pages.renderSearch()
		local query = string.lower(string.match(queryBox.Text, "^%s*(.-)%s*$") or "")
		local searching = query ~= ""
		gridScroll.Visible = not searching
		results.Visible = searching
		countLabel.Text = ""
		if not searching then
			return
		end
		Util.clear(results)
		Components.setActiveSlider(nil)
		local total, order = 0, 0
		for _, tab in TABS do
			local tabHit = matches(tab.titleRaw, query) or matches(tab.descRaw, query) or string.find(string.lower(tab.id), query, 1, true) ~= nil
			local found = {}
			for _, section in tab.sections do
				local sectionHit = matches(section.nameRaw, query)
				for _, item in section.items do
					if tabHit or sectionHit or matches(item.labelRaw, query) or matches(item.descRaw, query)
						or matches(item.tooltipRaw, query) or string.find(string.lower(tostring(item.id)), query, 1, true)
						or string.find(item.type, query, 1, true) then
						table.insert(found, item)
					end
				end
			end
			if #found > 0 then
				total += #found
				order += 2
				groupHeader(tab, #found, order - 1)
				itemColumns(found, order)
			end
		end
		countLabel.Text = I18n.t("search.count", total)
		if total == 0 then
			emptyState(results, "search", I18n.t("search.none.title"), I18n.t("search.none.hint", query), 1)
		end
	end

	local renderQueued = false
	queryBox:GetPropertyChangedSignal("Text"):Connect(function()
		if renderQueued then
			return
		end
		renderQueued = true
		task.defer(function()
			renderQueued = false
			Pages.renderSearch()
		end)
	end)

	Router.hooks.Pages = function()
		if gridScroll.Visible then
			staggerIn(grid)
		end
	end
end

-- Sub page (one page's sections) ------------------------------------------------------

do
	local page = Router.newPage("Sub", false)
	local back = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.fromOffset(18, 12),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = THEME.Row,
		BorderSizePixel = 0,
		Parent = page,
	}, { Util.corner(17), Util.stroke(THEME.AccentDark, 0.35) })
	Style.register(back, "row")
	local _, setBackColor = Icons.make(back, "arrow-left", 16, THEME.SubText, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	}, "←")
	Util.hover(back, function()
		setBackColor(THEME.Accent, true)
	end, function()
		setBackColor(THEME.SubText, true)
	end)
	Util.pressScale(back, 0.9)
	Tooltip.attach(back, T("sub.back"))
	local crumb = label({
		FontFace = FONT.Bold,
		TextSize = 10,
		TextColor3 = THEME.Accent,
		Position = UDim2.fromOffset(64, 12),
		Size = UDim2.new(1, -300, 0, 12),
		Parent = page,
	})
	local title = label({
		FontFace = FONT.Bold,
		TextSize = 19,
		Position = UDim2.fromOffset(64, 24),
		Size = UDim2.new(1, -300, 0, 24),
		Parent = page,
	})
	local subtitle = label({
		FontFace = FONT.Regular,
		TextSize = 11,
		TextColor3 = THEME.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 28),
		Size = UDim2.fromOffset(220, 14),
		Parent = page,
	})
	local scroll = create("ScrollingFrame", {
		Name = "Scroll",
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 1, -56),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = THEME.Accent,
		ScrollBarImageTransparency = 0.3,
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = page,
	}, { Util.list(12), Util.padding(18, 20, 6, 18) })
	table.insert(Components.scrollers, scroll)
	Pages.subScroll = scroll

	function Pages.renderTab(tab)
		Util.clear(scroll)
		Components.setActiveSlider(nil)
		I18n.bind(crumb, function()
			return I18n.t("sub.crumb") .. "  /  " .. string.upper(tabTitle(tab))
		end)
		I18n.bind(title, function()
			return tabTitle(tab)
		end)
		I18n.bind(subtitle, function()
			return tabSubtitle(tab)
		end)
		local sections = {}
		for _, section in tab.sections do
			if #section.items > 0 then
				table.insert(sections, section)
			end
		end
		if #sections == 0 then
			emptyState(scroll, "layers", tabTitle(tab), I18n.t("tab.empty"), 1)
			return
		end
		buildSectionColumns(scroll, sections, 1)
	end

	function Router.openTab(tab)
		Router.currentTab = tab
		Pages.paintCards()
		local ok, err = pcall(Pages.renderTab, tab)
		if not ok then
			warn("[MultiHub] could not render page '" .. tostring(tab.id) .. "': " .. tostring(err))
		end
		scroll.CanvasPosition = Vector2.zero
		Router.show("Sub", "pages")
	end

	back.Activated:Connect(function()
		Router.show("Pages", "pages")
	end)
	Router.hooks.Sub = function()
		staggerIn(scroll)
	end
end

-- Built-in pages helpers ---------------------------------------------------------------

local LANGUAGE_OPTIONS = { "auto" }
for _, code in I18n.Order do
	table.insert(LANGUAGE_OPTIONS, code)
end

-- Built-in controls use the same engine as script controls (Elements + Components).
local function internalItem(item)
	if item.internal == nil then
		item.internal = true
	end
	if item.type == "action" or item.type == "keybind" or item.type == "paragraph" then
		return item
	end
	return newElement(item)
end

local function builtinSection(titleKey, descKey, items)
	local section = { nameRaw = T(titleKey), descRaw = descKey and T(descKey) or nil, items = {} }
	for _, item in items do
		if item then
			internalItem(item)
			table.insert(section.items, item)
		end
	end
	return section
end
Pages.builtinSection = builtinSection

-- Settings ---------------------------------------------------------------------------

do
	local _, scroll = Router.newPage("Settings", true)
	Pages.header(scroll, "settings.eyebrow", "settings.title", "settings.desc", 0)

	local interfaceItems = {
		{
			type = "dropdown",
			id = "__ui_language",
			labelRaw = T("settings.language"),
			descRaw = T("settings.language.desc"),
			options = LANGUAGE_OPTIONS,
			default = Prefs.language,
			format = function(code)
				if code == "auto" then
					local detected = I18n.detect()
					return I18n.t("settings.language.auto", I18n.Names[detected or I18n.Default] or "English")
				end
				return I18n.Names[code] or code
			end,
			onSet = function(code)
				Prefs.language = code
				savePrefs()
				local before = I18n.Current
				I18n.set(resolveLanguagePref())
				if before ~= I18n.Current then
					notify("MultiHub", I18n.t("settings.language.changed", I18n.Names[I18n.Current] or I18n.Current), 2.5, "success")
				end
			end,
		},
		{
			type = "toggle",
			id = "__ui_notifications",
			labelRaw = T("settings.notifications"),
			descRaw = T("settings.notifications.desc"),
			default = Prefs.notifications,
			onSet = function(value)
				Prefs.notifications = value
				savePrefs()
			end,
		},
		{
			type = "toggle",
			id = "__ui_glass",
			labelRaw = T("settings.glass"),
			descRaw = T("settings.glass.desc"),
			default = Prefs.glass,
			onSet = function(value)
				Prefs.glass = value
				savePrefs()
				Style.apply()
			end,
		},
		{
			type = "toggle",
			id = "__ui_blur",
			labelRaw = T("settings.blur"),
			descRaw = T("settings.blur.desc"),
			default = Prefs.blur,
			onSet = function(value)
				Prefs.blur = value
				savePrefs()
				Style.apply()
			end,
		},
		{
			type = "slider",
			id = "__ui_scale",
			labelRaw = T("settings.scale"),
			descRaw = T("settings.scale.desc"),
			min = 60,
			max = 140,
			step = 5,
			default = Prefs.scale,
			onSet = function(value)
				Prefs.scale = value
				savePrefs()
				UI.updateFit()
			end,
		},
	}
	if not IS_TOUCH then
		table.insert(interfaceItems, {
			type = "keybind",
			id = "__ui_key",
			labelRaw = T("settings.key"),
			descRaw = T("settings.key.desc"),
			onKey = function(keyCode)
				Prefs.toggleKey = keyCode.Name
				savePrefs()
				notify("MultiHub", I18n.t("settings.key.changed", keyCode.Name), 2.5, "success")
			end,
		})
	end
	Components.section(scroll, builtinSection("settings.interface", "settings.interface.desc", interfaceItems), 1)

	-- Profiles (per game): a name field + five actions + status line.
	local profiles = create("Frame", {
		Name = "Section",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.Surface,
		BorderSizePixel = 0,
		LayoutOrder = 2,
		Parent = scroll,
	}, { Util.corner(RADIUS.Card), Util.stroke(THEME.StrokeSoft), Util.padding(12, 12, 12, 12), Util.list(10) })
	Style.register(profiles, "surface")
	local head = create("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = 0, Parent = profiles })
	create("Frame", {
		Position = UDim2.fromOffset(0, 3),
		Size = UDim2.fromOffset(3, 14),
		BackgroundColor3 = THEME.Accent,
		BorderSizePixel = 0,
		Parent = head,
	}, { Util.corner(2) })
	I18n.bind(label({ FontFace = FONT.Bold, TextSize = 14, Position = UDim2.fromOffset(11, 0), Size = UDim2.new(1, -11, 0, 20), Parent = head }), "settings.profiles")
	I18n.bind(label({
		FontFace = FONT.Regular,
		TextSize = 11,
		TextColor3 = THEME.Muted,
		Position = UDim2.fromOffset(11, 20),
		Size = UDim2.new(1, -11, 0, 14),
		Parent = head,
	}), "settings.profiles.desc")

	local nameRow = Components.row(profiles, 62, false)
	nameRow.LayoutOrder = 1
	Components.texts(nameRow, { labelRaw = T("settings.profile.name") }, 0, 0, true)
	local nameBox = create("TextBox", {
		Text = Store.Active,
		ClearTextOnFocus = false,
		FontFace = FONT.Medium,
		TextSize = 13,
		TextColor3 = THEME.Text,
		PlaceholderColor3 = THEME.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -8),
		Size = UDim2.new(1, -24, 0, 28),
		BackgroundColor3 = THEME.Input,
		BorderSizePixel = 0,
		Parent = nameRow,
	}, { Util.corner(RADIUS.Small), Util.stroke(THEME.StrokeSoft), Util.padding(10, 10, 0, 0) })
	I18n.bind(nameBox, "settings.profile.placeholder", "PlaceholderText")

	local actions = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = profiles,
	})
	create("UIGridLayout", {
		CellSize = UDim2.new(1 / 5, -8, 0, 38),
		CellPadding = UDim2.fromOffset(9, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = actions,
	})
	local statusLabel = label({
		FontFace = FONT.Medium,
		TextSize = 11,
		TextColor3 = THEME.Muted,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 3,
		Parent = profiles,
	})
	I18n.bind(statusLabel, function()
		if not Util.fs("writefile") then
			return I18n.t("settings.profile.nofs")
		end
		return I18n.t("settings.profile.stored", CONFIG.ConfigFolder .. "/Config")
	end)

	local function report(ok, message)
		statusLabel.Text = tostring(message)
		statusLabel.TextColor3 = ok and THEME.Success or THEME.Accent
		notify(I18n.t(ok and "profile.title" or "profile.error"), tostring(message), 3, ok and "success" or "error")
	end

	local function action(order, key, iconName, danger, callback)
		local button = create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = danger and THEME.AccentSoft or THEME.Row,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = actions,
		}, { Util.corner(RADIUS.Row) })
		local stroke = Util.stroke(danger and THEME.AccentDark or THEME.StrokeSoft, danger and 0.4 or 0)
		stroke.Parent = button
		Icons.make(button, iconName, 15, danger and THEME.Accent or THEME.SubText, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
		})
		I18n.bind(label({
			FontFace = FONT.SemiBold,
			TextSize = 12,
			Position = UDim2.fromOffset(32, 0),
			Size = UDim2.new(1, -36, 1, 0),
			Parent = button,
		}), key)
		local base = button.BackgroundColor3
		Util.hover(button, function()
			tween(button, 0.15, { BackgroundColor3 = danger and THEME.AccentDark or THEME.RowHover })
		end, function()
			tween(button, 0.2, { BackgroundColor3 = base })
		end)
		Util.pressScale(button, 0.96)
		button.Activated:Connect(callback)
	end

	action(1, "settings.profile.save", "save", false, function()
		local ok, err = Store.save(nameBox.Text)
		report(ok, ok and I18n.t("profile.saved", Store.Active) or err)
	end)
	action(2, "settings.profile.load", "folder-open", false, function()
		local ok, err = Store.read(nameBox.Text)
		if ok then
			Store.applyAll()
			nameBox.Text = Store.Active
			report(true, I18n.t("profile.loaded", Store.Active))
		else
			report(false, err)
		end
	end)
	action(3, "settings.profile.create", "file-plus", false, function()
		local ok, err = Store.create(nameBox.Text)
		if ok then
			nameBox.Text = Store.Active
		end
		report(ok, ok and I18n.t("profile.created", Store.Active) or err)
	end)
	action(4, "settings.profile.delete", "trash-2", true, function()
		local name = nameBox.Text
		local ok, err = Store.delete(name)
		if ok then
			nameBox.Text = Store.Active
		end
		report(ok, ok and I18n.t("profile.deleted", name) or err)
	end)
	action(5, "settings.profile.reset", "rotate-ccw", true, function()
		local ok, err = Store.reset()
		nameBox.Text = Store.Active
		report(ok, ok and I18n.t("profile.reset") or err)
	end)

	-- Session: Unload lives here too (same confirmation as the header button).
	Components.section(scroll, builtinSection("settings.session", "settings.session.desc", {
		{
			type = "action",
			id = "__ui_unload",
			icon = "power",
			danger = true,
			labelRaw = T("top.unload"),
			descRaw = T("settings.unload.desc"),
		},
	}), 3)
	Handlers.__ui_unload = function()
		UI.askUnload()
	end

	Router.hooks.Settings = function()
		nameBox.Text = Store.Active
		staggerIn(scroll)
	end
end

-- About ------------------------------------------------------------------------------

do
	local _, scroll = Router.newPage("About", true)
	Pages.header(scroll, "about.eyebrow", "about.title", "about.desc", 0)

	local brandCard = create("Frame", {
		Name = "Section",
		Size = UDim2.new(1, 0, 0, 92),
		BackgroundColor3 = THEME.Surface,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Parent = scroll,
	}, { Util.corner(RADIUS.Card), Util.stroke(THEME.AccentDark, 0.4) })
	Style.register(brandCard, "surface")
	UI.buildLogo(brandCard, 56, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 18, 0.5, 0) })
	label({
		RichText = true,
		Text = hubRest and (hubFirst .. ' <font color="' .. Util.hex(THEME.Accent) .. '">' .. hubRest .. "</font>") or CONFIG.HubName,
		FontFace = FONT.DisplayItalic,
		TextSize = 22,
		Position = UDim2.fromOffset(88, 20),
		Size = UDim2.new(1, -100, 0, 28),
		Parent = brandCard,
	})
	I18n.bind(label({
		FontFace = FONT.Mono,
		TextSize = 11,
		TextColor3 = THEME.Muted,
		Position = UDim2.fromOffset(88, 50),
		Size = UDim2.new(1, -100, 0, 14),
		Parent = brandCard,
	}), function()
		return I18n.t("about.version", CONFIG.LibraryVersion, UI.executorName)
	end)

	local community = create("Frame", {
		Name = "Section",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.Surface,
		BorderSizePixel = 0,
		LayoutOrder = 2,
		Parent = scroll,
	}, { Util.corner(RADIUS.Card), Util.stroke(THEME.StrokeSoft), Util.padding(12, 12, 12, 12), Util.list(8) })
	Style.register(community, "surface")
	local head = create("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = 0, Parent = community })
	create("Frame", {
		Position = UDim2.fromOffset(0, 3),
		Size = UDim2.fromOffset(3, 14),
		BackgroundColor3 = THEME.Accent,
		BorderSizePixel = 0,
		Parent = head,
	}, { Util.corner(2) })
	I18n.bind(label({ FontFace = FONT.Bold, TextSize = 14, Position = UDim2.fromOffset(11, 0), Size = UDim2.new(1, -11, 0, 20), Parent = head }), "about.community")
	I18n.bind(label({
		FontFace = FONT.Regular,
		TextSize = 11,
		TextColor3 = THEME.Muted,
		Position = UDim2.fromOffset(11, 20),
		Size = UDim2.new(1, -11, 0, 14),
		Parent = head,
	}), "about.community.desc")
	for order, social in CONFIG.Social do
		local row = Components.row(community, 46, true)
		row.LayoutOrder = order
		local tile = create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = THEME.AccentSoft,
			BorderSizePixel = 0,
			Parent = row,
		}, { Util.corner(RADIUS.Small) })
		Icons.make(tile, social.Icon, 15, THEME.Accent, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		}, social.Glyph)
		label({ Text = social.Name, FontFace = FONT.SemiBold, TextSize = 13, Position = UDim2.fromOffset(48, 7), Size = UDim2.new(1, -90, 0, 16), Parent = row })
		label({
			Text = social.Url,
			FontFace = FONT.Mono,
			TextSize = 11,
			TextColor3 = THEME.Muted,
			Position = UDim2.fromOffset(48, 24),
			Size = UDim2.new(1, -90, 0, 14),
			Parent = row,
		})
		Icons.make(row, "copy", 14, THEME.Muted, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
		}, "⧉")
		row.Activated:Connect(function()
			LinkDialog.open(social)
		end)
	end

	Components.section(scroll, builtinSection("about.credits", nil, {
		{ type = "paragraph", id = "__ui_credits", labelRaw = "", textRaw = T("about.credits.text") },
	}), 3)

	Router.hooks.About = function()
		staggerIn(scroll)
	end
end

local ROUTES = {
	home = "Home",
	pages = "Pages",
	player = "Player",
	performance = "Performance",
	settings = "Settings",
	about = "About",
}
function Router.go(key)
	local name = ROUTES[key]
	if name and Router.pages[name] then
		Router.show(name, key)
	end
end

-- Re-renders the visible dynamic page (after a build or element changes).
function Router.refreshCurrent()
	if Router.current == "Sub" and Router.currentTab then
		if table.find(TABS, Router.currentTab) then
			local position = Pages.subScroll.CanvasPosition
			Pages.renderTab(Router.currentTab)
			Pages.subScroll.CanvasPosition = position
		else
			Router.show("Pages", "pages")
		end
	elseif Router.current == "Pages" then
		Pages.renderSearch()
	end
end

-- Language changes: texts bound with I18n.bind update by themselves; this handles the rest.
I18n.Internal = function()
	DropPanel.close()
	Status.refresh()
	if Router.current == "Pages" then
		Pages.renderSearch()
	end
end

-- Card with the standard section header, for custom content (monitor, information).
local function infoCard(parent, titleKey, descKey, order)
	local card = create("Frame", {
		Name = "Section",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.Surface,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = parent,
	}, { Util.corner(RADIUS.Card), Util.stroke(THEME.StrokeSoft), Util.padding(12, 12, 12, 12), Util.list(10) })
	Style.register(card, "surface")
	local head = create("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = 0, Parent = card })
	create("Frame", {
		Position = UDim2.fromOffset(0, 3),
		Size = UDim2.fromOffset(3, 14),
		BackgroundColor3 = THEME.Accent,
		BorderSizePixel = 0,
		Parent = head,
	}, { Util.corner(2) })
	I18n.bind(label({ FontFace = FONT.Bold, TextSize = 14, Position = UDim2.fromOffset(11, 0), Size = UDim2.new(1, -11, 0, 20), Parent = head }), titleKey)
	I18n.bind(label({
		FontFace = FONT.Regular,
		TextSize = 11,
		TextColor3 = THEME.Muted,
		Position = UDim2.fromOffset(11, 20),
		Size = UDim2.new(1, -11, 0, 14),
		Parent = head,
	}), descKey)
	return card
end

-- == PLAYER ================================================================
-- Character tools built only on documented Humanoid / constraint APIs. Nothing here hides
-- itself or bypasses checks: if a game's server resets a value, the server wins.

local PlayerTools = {
	humanoid = (nil :: any),
	root = (nil :: any),
	defaults = {},
	changed = {},
	charConnections = {},
	fly = {},
	noclipParts = {},
	noclipConnection = (nil :: any),
	afkConnection = (nil :: any),
	updateInfo = (nil :: any),
}

local function flag(id)
	return State[id]
end

function PlayerTools.applyMovement()
	local humanoid = PlayerTools.humanoid
	if not humanoid or humanoid.Parent == nil then
		return
	end
	local defaults, changed = PlayerTools.defaults, PlayerTools.changed
	if flag("mh_player_speed_on") then
		humanoid.WalkSpeed = flag("mh_player_speed")
		changed.walk = true
	elseif changed.walk then
		humanoid.WalkSpeed = defaults.walk
		changed.walk = nil
	end
	if flag("mh_player_jump_on") then
		if humanoid.UseJumpPower then
			humanoid.JumpPower = flag("mh_player_jumppower")
			changed.jumpPower = true
		else
			humanoid.JumpHeight = flag("mh_player_jumpheight")
			changed.jumpHeight = true
		end
	else
		if changed.jumpPower then
			humanoid.JumpPower = defaults.jumpPower
			changed.jumpPower = nil
		end
		if changed.jumpHeight then
			humanoid.JumpHeight = defaults.jumpHeight
			changed.jumpHeight = nil
		end
	end
end

function PlayerTools.stopFly()
	local fly = PlayerTools.fly
	if fly.connection then
		fly.connection:Disconnect()
	end
	for _, object in { fly.velocity, fly.align, fly.attachment } do
		if object then
			object:Destroy()
		end
	end
	table.clear(fly)
	local humanoid = PlayerTools.humanoid
	if humanoid and humanoid.Parent then
		humanoid.PlatformStand = false
	end
end

-- LinearVelocity + AlignOrientation (current constraint API). Moves with the humanoid's
-- MoveDirection, so keyboard, gamepad and the mobile thumbstick all work.
function PlayerTools.startFly()
	PlayerTools.stopFly()
	local humanoid, root = PlayerTools.humanoid, PlayerTools.root
	if not humanoid or not root or humanoid.Health <= 0 then
		notify(I18n.t("player.fly"), I18n.t("player.nochar"), 3, "warning")
		task.defer(function()
			if Elements.mh_player_fly then
				Elements.mh_player_fly:Set(false)
			end
		end)
		return
	end
	local fly = PlayerTools.fly
	fly.attachment = create("Attachment", { Name = "MultiHubFly", Parent = root })
	fly.velocity = create("LinearVelocity", {
		Name = "MultiHubFlyVelocity",
		Attachment0 = fly.attachment,
		MaxForce = math.huge,
		VelocityConstraintMode = Enum.VelocityConstraintMode.Vector,
		RelativeTo = Enum.ActuatorRelativeTo.World,
		VectorVelocity = Vector3.zero,
		Parent = root,
	})
	fly.align = create("AlignOrientation", {
		Name = "MultiHubFlyAlign",
		Mode = Enum.OrientationAlignmentMode.OneAttachment,
		Attachment0 = fly.attachment,
		MaxTorque = math.huge,
		Responsiveness = 40,
		CFrame = root.CFrame.Rotation,
		Parent = root,
	})
	humanoid.PlatformStand = true
	fly.connection = RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera or not fly.velocity then
			return
		end
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.zAxis
		local move = humanoid.MoveDirection
		local vertical = 0
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) or humanoid.Jump then
			vertical += 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then
			vertical -= 1
		end
		-- Moving forward follows the camera pitch, like a free camera.
		local direction = move + Vector3.yAxis * (look.Y * move:Dot(flat) + vertical)
		if direction.Magnitude > 1 then
			direction = direction.Unit
		end
		fly.velocity.VectorVelocity = direction * (flag("mh_player_flyspeed") or 60)
		fly.align.CFrame = CFrame.lookAt(Vector3.zero, flat)
	end)
end

function PlayerTools.setNoclip(on)
	if PlayerTools.noclipConnection then
		PlayerTools.noclipConnection:Disconnect()
		PlayerTools.noclipConnection = nil
	end
	for part in PlayerTools.noclipParts do
		if part.Parent then
			part.CanCollide = true
		end
	end
	table.clear(PlayerTools.noclipParts)
	if not on then
		return
	end
	-- Stepped runs before physics; the Humanoid re-enables collisions every frame, so we follow it.
	PlayerTools.noclipConnection = RunService.Stepped:Connect(function()
		local character = player.Character
		if not character then
			return
		end
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") and part.CanCollide then
				PlayerTools.noclipParts[part] = true
				part.CanCollide = false
			end
		end
	end)
end

-- Player.Idled is documented; answering it needs VirtualUser, which only executors expose.
function PlayerTools.setAntiAfk(on)
	if PlayerTools.afkConnection then
		PlayerTools.afkConnection:Disconnect()
		PlayerTools.afkConnection = nil
	end
	if not on then
		return
	end
	local okService, virtualUser = pcall(game.GetService, game, "VirtualUser")
	local usable = okService and pcall(function()
		virtualUser:CaptureController()
	end)
	if not usable then
		notify(I18n.t("player.afk"), I18n.t("player.afk.unavailable"), 4, "warning")
		task.defer(function()
			if Elements.mh_player_afk then
				Elements.mh_player_afk:Set(false)
			end
		end)
		return
	end
	PlayerTools.afkConnection = player.Idled:Connect(function()
		local ok = pcall(function()
			virtualUser:CaptureController()
			virtualUser:ClickButton2(Vector2.zero)
		end)
		if ok then
			notify(I18n.t("player.afk"), I18n.t("player.afk.done"), 3, "success")
		end
	end)
end

function PlayerTools.reset()
	local humanoid = PlayerTools.humanoid
	if not humanoid or humanoid.Parent == nil then
		notify(I18n.t("player.reset"), I18n.t("player.nochar"), 3, "warning")
		return false
	end
	humanoid.Health = 0
	return true
end

function PlayerTools.respawnHere()
	local root = PlayerTools.root
	if not root or root.Parent == nil then
		notify(I18n.t("player.respawn"), I18n.t("player.nochar"), 3, "warning")
		return
	end
	local spot = root.CFrame
	if not PlayerTools.reset() then
		return
	end
	task.spawn(function()
		local character = player.CharacterAdded:Wait()
		local newRoot = character:WaitForChild("HumanoidRootPart", 10)
		if newRoot and Maid.alive then
			task.wait(0.15)
			newRoot.CFrame = spot
		end
	end)
end

local function bindCharacter(character)
	for _, connection in PlayerTools.charConnections do
		connection:Disconnect()
	end
	table.clear(PlayerTools.charConnections)
	PlayerTools.stopFly()
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not Maid.alive or not humanoid or player.Character ~= character then
		return
	end
	PlayerTools.humanoid, PlayerTools.root = humanoid, root
	PlayerTools.defaults = { walk = humanoid.WalkSpeed, jumpPower = humanoid.JumpPower, jumpHeight = humanoid.JumpHeight }
	table.clear(PlayerTools.changed)
	PlayerTools.applyMovement()
	table.insert(PlayerTools.charConnections, humanoid.Died:Connect(function()
		if flag("mh_player_fly") and Elements.mh_player_fly then
			Elements.mh_player_fly:Set(false)
		end
	end))
end

Util.track(player.CharacterAdded:Connect(function(character)
	task.spawn(bindCharacter, character)
end))
if player.Character then
	task.spawn(bindCharacter, player.Character)
end

-- Everything the Player page changed is undone by Unload.
Util.onCleanup(function()
	PlayerTools.stopFly()
	PlayerTools.setNoclip(false)
	PlayerTools.setAntiAfk(false)
	for _, connection in PlayerTools.charConnections do
		connection:Disconnect()
	end
	local humanoid = PlayerTools.humanoid
	if humanoid and humanoid.Parent then
		local defaults, changed = PlayerTools.defaults, PlayerTools.changed
		if changed.walk then
			humanoid.WalkSpeed = defaults.walk
		end
		if changed.jumpPower then
			humanoid.JumpPower = defaults.jumpPower
		end
		if changed.jumpHeight then
			humanoid.JumpHeight = defaults.jumpHeight
		end
	end
end)

do
	local page, scroll = Router.newPage("Player", true)
	page.Name = "Player"
	Pages.header(scroll, "player.eyebrow", "player.title", "player.desc", 0)

	local function playerItem(item)
		item.internal = false -- saved in the game profile
		item.group = "player"
		return item
	end
	local movement = builtinSection("player.movement", "player.movement.desc", {
		playerItem({ type = "toggle", id = "mh_player_speed_on", labelRaw = T("player.speed"), descRaw = T("player.speed.desc"), default = false }),
		playerItem({ type = "slider", id = "mh_player_speed", labelRaw = T("player.speed.value"), min = 0, max = 250, step = 1, default = 16 }),
		playerItem({ type = "toggle", id = "mh_player_jump_on", labelRaw = T("player.jump"), descRaw = T("player.jump.desc"), default = false }),
		playerItem({ type = "slider", id = "mh_player_jumppower", labelRaw = T("player.jumppower"), min = 0, max = 400, step = 1, default = 50 }),
		playerItem({ type = "slider", id = "mh_player_jumpheight", labelRaw = T("player.jumpheight"), min = 0, max = 150, step = 0.5, default = 7.2 }),
		playerItem({ type = "toggle", id = "mh_player_fly", labelRaw = T("player.fly"), descRaw = T("player.fly.desc"), default = false, noSave = true }),
		playerItem({ type = "slider", id = "mh_player_flyspeed", labelRaw = T("player.flyspeed"), min = 10, max = 300, step = 5, default = 60 }),
		playerItem({ type = "toggle", id = "mh_player_noclip", labelRaw = T("player.noclip"), descRaw = T("player.noclip.desc"), default = false, noSave = true }),
	})
	local tools = builtinSection("player.tools", "player.tools.desc", {
		playerItem({ type = "toggle", id = "mh_player_afk", labelRaw = T("player.afk"), descRaw = T("player.afk.desc"), default = false }),
		{ type = "action", id = "mh_player_reset", icon = "rotate-ccw", labelRaw = T("player.reset"), descRaw = T("player.reset.desc") },
		{ type = "action", id = "mh_player_respawn", icon = "map-pin", labelRaw = T("player.respawn"), descRaw = T("player.respawn.desc") },
	})

	-- Handlers (not onSet) so saved values are applied on startup like any script control.
	for _, id in { "mh_player_speed_on", "mh_player_speed", "mh_player_jump_on", "mh_player_jumppower", "mh_player_jumpheight" } do
		Handlers[id] = function()
			PlayerTools.applyMovement()
		end
	end
	Handlers.mh_player_fly = function(on)
		if on then
			PlayerTools.startFly()
		else
			PlayerTools.stopFly()
		end
	end
	Handlers.mh_player_noclip = PlayerTools.setNoclip
	Handlers.mh_player_afk = PlayerTools.setAntiAfk
	Handlers.mh_player_reset = PlayerTools.reset
	Handlers.mh_player_respawn = PlayerTools.respawnHere

	Pages.columns(scroll, { movement, tools }, 1)

	local info = infoCard(scroll, "player.info", "player.info.desc", 2)
	local function stat(getter)
		local humanoid = PlayerTools.humanoid
		if not humanoid or humanoid.Parent == nil then
			return "—"
		end
		return getter(humanoid)
	end
	PlayerTools.updateInfo = Components.metrics(info, {
		{ key = "info.user", get = function()
			return player.DisplayName .. " (@" .. player.Name .. ")"
		end },
		{ key = "info.id", get = function()
			return tostring(player.UserId)
		end },
		{ key = "info.age", get = function()
			return I18n.t("info.days", player.AccountAge)
		end },
		{ key = "info.team", get = function()
			return player.Team and player.Team.Name or I18n.t("info.none")
		end },
		{ key = "info.health", get = function()
			return stat(function(humanoid)
				local ratio = humanoid.MaxHealth > 0 and humanoid.Health / humanoid.MaxHealth or 0
				return ("%d / %d"):format(math.floor(humanoid.Health + 0.5), math.floor(humanoid.MaxHealth + 0.5)), ratio < 0.35 and THEME.Accent or nil
			end)
		end },
		{ key = "info.speed", get = function()
			return stat(function(humanoid)
				return formatNumber(humanoid.WalkSpeed)
			end)
		end },
		{ key = "info.jump", get = function()
			return stat(function(humanoid)
				if humanoid.UseJumpPower then
					return "JumpPower " .. formatNumber(humanoid.JumpPower)
				end
				return "JumpHeight " .. formatNumber(humanoid.JumpHeight)
			end)
		end },
		{ key = "info.rig", get = function()
			return stat(function(humanoid)
				return humanoid.RigType.Name
			end)
		end },
		{ key = "info.position", get = function()
			local root = PlayerTools.root
			if not root or root.Parent == nil then
				return "—"
			end
			local p = root.Position
			return ("%d, %d, %d"):format(math.floor(p.X), math.floor(p.Y), math.floor(p.Z))
		end },
		{ key = "info.ping", get = function()
			return ("%d ms"):format(math.floor(player:GetNetworkPing() * 1000 + 0.5))
		end },
	}, 1, 2)

	Router.hooks.Player = function()
		PlayerTools.updateInfo()
		Pages.staggerIn(scroll)
	end
end

-- == PERFORMANCE ===========================================================
-- Two clearly separated groups:
--   * MultiHub interface: only this window (animations, effects, lightweight, FPS display).
--   * Roblox graphics: local and reversible changes to what this client renders in this game.
-- The Roblox quality level itself is not scriptable (RenderSettings.QualityLevel is not
-- available to game scripts), and the user's saved Roblox setting is never written.

local Graphics = { changes = {}, particles = {}, particlesOn = false, particleConnection = (nil :: any) }
local PARTICLE_CLASSES = { ParticleEmitter = true, Trail = true, Beam = true, Smoke = true, Fire = true, Sparkles = true }

local function trySet(instance, property, value)
	local okRead, original = pcall(function()
		return instance[property]
	end)
	if not okRead then
		return false
	end
	local okWrite = pcall(function()
		instance[property] = value
	end)
	if okWrite then
		table.insert(Graphics.changes, { instance, property, original })
	end
	return okWrite
end

function Graphics.restoreLow()
	for index = #Graphics.changes, 1, -1 do
		local change = Graphics.changes[index]
		pcall(function()
			change[1][change[2]] = change[3]
		end)
	end
	table.clear(Graphics.changes)
end

function Graphics.setLow(on)
	Graphics.restoreLow()
	if not on then
		return
	end
	local skipped = 0
	local lighting = game:GetService("Lighting")
	if not trySet(lighting, "GlobalShadows", false) then
		skipped += 1
	end
	local effects = lighting:GetDescendants()
	local camera = workspace.CurrentCamera
	if camera then
		for _, child in camera:GetChildren() do
			table.insert(effects, child)
		end
	end
	for _, effect in effects do
		if effect:IsA("PostEffect") and effect.Enabled and effect ~= UI.blurEffect then
			if not trySet(effect, "Enabled", false) then
				skipped += 1
			end
		end
	end
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain and not trySet(terrain, "Decoration", false) then
		skipped += 1
	end
	if skipped > 0 then
		notify(I18n.t("perf.low"), I18n.t("perf.skipped", skipped), 4, "warning")
	end
end

function Graphics.setParticles(on)
	Graphics.particlesOn = on
	if Graphics.particleConnection then
		Graphics.particleConnection:Disconnect()
		Graphics.particleConnection = nil
	end
	for object in Graphics.particles do
		if object.Parent then
			pcall(function()
				object.Enabled = true
			end)
		end
	end
	table.clear(Graphics.particles)
	if not on then
		return
	end
	local function hide(object)
		if PARTICLE_CLASSES[object.ClassName] and object.Enabled then
			Graphics.particles[object] = true
			object.Enabled = false
		end
	end
	-- The first scan yields every 3000 objects so big maps do not freeze for a frame.
	task.spawn(function()
		for index, object in workspace:GetDescendants() do
			if not Graphics.particlesOn or not Maid.alive then
				return
			end
			hide(object)
			if index % 3000 == 0 then
				task.wait()
			end
		end
	end)
	Graphics.particleConnection = workspace.DescendantAdded:Connect(function(object)
		if PARTICLE_CLASSES[object.ClassName] then
			task.defer(function()
				if Graphics.particlesOn and object.Parent then
					hide(object)
				end
			end)
		end
	end)
end

Util.onCleanup(function()
	Graphics.setParticles(false)
	Graphics.restoreLow()
end)

-- FPS display: a small draggable pill on the screen, outside the window.
local Hud = {}
do
	local pill = create("TextButton", {
		Name = "FpsDisplay",
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = THEME.Bg,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	}, {
		Util.corner(13),
		Util.stroke(THEME.AccentDark, 0.3),
		Util.padding(10, 12, 0, 0),
		Util.list(7, Enum.FillDirection.Horizontal, { VerticalAlignment = Enum.VerticalAlignment.Center }),
	})
	local dot = create("Frame", {
		Size = UDim2.fromOffset(7, 7),
		BackgroundColor3 = THEME.Success,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Parent = pill,
	}, { Util.corner(4) })
	local text = label({
		Text = "",
		FontFace = FONT.Mono,
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.None,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 26),
		LayoutOrder = 2,
		Parent = pill,
	})

	function Hud.update()
		local fps = UI.fps
		dot.BackgroundColor3 = fps >= 50 and THEME.Success or (fps >= 30 and THEME.Warning or THEME.Accent)
		local parts = { ("%d FPS"):format(fps) }
		local okPing, ping = pcall(function()
			return player:GetNetworkPing() * 1000
		end)
		if okPing then
			table.insert(parts, ("%d ms"):format(math.floor(ping + 0.5)))
		end
		if not Prefs.lightweight then
			local okMemory, memory = pcall(function()
				return game:GetService("Stats"):GetTotalMemoryUsageMb()
			end)
			if okMemory then
				table.insert(parts, ("%d MB"):format(math.floor(memory)))
			end
		end
		text.Text = table.concat(parts, "  ·  ")
	end

	function Hud.setVisible(on)
		pill.Visible = on
		if on then
			Hud.update()
		end
	end

	-- Drag (mouse or finger that started on the pill).
	local dragging, dragInput, dragStart, startPosition = false, nil, nil, nil
	pill.InputBegan:Connect(function(input)
		if Util.isPress(input) then
			dragging, dragInput, dragStart, startPosition = true, input, input.Position, pill.Position
		end
	end)
	Util.track(UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		local moved = (dragInput.UserInputType == Enum.UserInputType.Touch and input == dragInput)
			or (dragInput.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType == Enum.UserInputType.MouseMovement)
		if moved then
			local delta = input.Position - dragStart
			pill.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
		end
	end))
	Util.track(UserInputService.InputEnded:Connect(function(input)
		if dragging and (input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1) then
			dragging = false
		end
	end))
	Hud.setVisible(Prefs.fpsHud)
end

local Perf = { updateMonitor = (nil :: any) }
do
	local _, scroll = Router.newPage("Performance", true)
	Pages.header(scroll, "perf.eyebrow", "perf.title", "perf.desc", 0)

	local function libraryToggle(id, key, prefKey, after)
		return {
			type = "toggle",
			id = id,
			labelRaw = T(key),
			descRaw = T(key .. ".desc"),
			default = Prefs[prefKey],
			onSet = function(value)
				local previous = Prefs[prefKey]
				Prefs[prefKey] = value
				savePrefs()
				if previous ~= value then -- Set() with the same value must not re-run the preset
					after(value)
				end
			end,
		}
	end
	local PRESET = { "animations", "reduced", "lightweight", "glass", "blur" }
	local PRESET_IDS = { animations = "__perf_animations", reduced = "__perf_reduced", lightweight = "__perf_light", glass = "__ui_glass", blur = "__ui_blur" }
	local PRESET_ON = { animations = false, reduced = true, lightweight = true, glass = false, blur = false }
	local PRESET_DEFAULT = { animations = true, reduced = false, lightweight = false, glass = true, blur = false }

	local library = builtinSection("perf.library", "perf.library.desc", {
		libraryToggle("__perf_mode", "perf.mode", "perfMode", function(on)
			-- Preset: remembers the previous values and restores them when turned off.
			if on then
				local snapshot = {}
				for _, key in PRESET do
					snapshot[key] = Prefs[key]
				end
				Prefs.perfSnapshot = snapshot
			end
			for _, key in PRESET do
				local element = Elements[PRESET_IDS[key]]
				local value = PRESET_ON[key]
				if not on then
					value = Prefs.perfSnapshot[key]
					if type(value) ~= "boolean" then
						value = PRESET_DEFAULT[key]
					end
				end
				if element then
					element:Set(value)
				end
			end
			savePrefs()
		end),
		libraryToggle("__perf_animations", "perf.animations", "animations", function()
			UI.updateLoops()
		end),
		libraryToggle("__perf_reduced", "perf.reduced", "reduced", function()
			Style.apply()
		end),
		libraryToggle("__perf_light", "perf.light", "lightweight", function()
			Style.apply()
			UI.updateLoops()
		end),
		libraryToggle("__perf_hud", "perf.hud", "fpsHud", function(on)
			Hud.setVisible(on)
		end),
	})

	local graphics = builtinSection("perf.graphics", "perf.graphics.desc", {
		{ type = "toggle", id = "mh_gfx_low", internal = false, labelRaw = T("perf.low"), descRaw = T("perf.low.desc"), default = false },
		{ type = "toggle", id = "mh_gfx_particles", internal = false, labelRaw = T("perf.particles"), descRaw = T("perf.particles.desc"), default = false },
		{ type = "paragraph", id = "mh_gfx_note", labelRaw = T("perf.note.title"), textRaw = T("perf.note") },
	})
	Handlers.mh_gfx_low = Graphics.setLow
	Handlers.mh_gfx_particles = Graphics.setParticles

	Pages.columns(scroll, { library, graphics }, 1)

	local monitor = infoCard(scroll, "perf.monitor", "perf.monitor.desc", 2)
	local stats = game:GetService("Stats")
	local function fpsColor(value)
		return value >= 50 and THEME.Success or (value >= 30 and THEME.Warning or THEME.Accent)
	end
	Perf.updateMonitor = Components.metrics(monitor, {
		{ key = "metric.fps", get = function()
			return tostring(UI.fps), fpsColor(UI.fps)
		end },
		{ key = "metric.frame", get = function()
			return ("%.1f ms"):format(UI.frameTime)
		end },
		{ key = "metric.physics", get = function()
			return ("%d FPS"):format(math.floor(workspace:GetRealPhysicsFPS() + 0.5))
		end },
		{ key = "metric.ping", get = function()
			return ("%d ms"):format(math.floor(player:GetNetworkPing() * 1000 + 0.5))
		end },
		{ key = "metric.memory", get = function()
			return ("%d MB"):format(math.floor(stats:GetTotalMemoryUsageMb()))
		end },
		{ key = "metric.instances", get = function()
			return tostring(stats.InstanceCount)
		end },
		{ key = "metric.network", get = function()
			return ("%.1f KB/s"):format(stats.DataReceiveKbps / 8)
		end },
		{ key = "metric.quality", get = function()
			local level = UserSettings():GetService("UserGameSettings").SavedQualityLevel
			if level == Enum.SavedQualitySetting.Automatic then
				return I18n.t("metric.auto")
			end
			return (string.gsub(level.Name, "QualityLevel", ""))
		end },
	}, 1, 4)

	Router.hooks.Performance = function()
		Perf.updateMonitor()
		Pages.staggerIn(scroll)
	end
end

-- Once per second (also while the window is hidden, for the FPS display).
UI.onSecond = function(second)
	if holder.Visible then
		if Router.current == "Home" and UI.homeSecond then
			UI.homeSecond(second)
		end
		local interval = Prefs.lightweight and 2 or 1
		if second % interval == 0 then
			if Router.current == "Performance" then
				Perf.updateMonitor()
			elseif Router.current == "Player" then
				PlayerTools.updateInfo()
			end
		end
	end
	if Prefs.fpsHud then
		Hud.update()
	end
end

-- Navigation tabs (order of the reference: Home · Pages · ...).
Nav.item("home", "house", "⌂", "nav.home", 1, function()
	Router.go("home")
end)
Nav.item("pages", "layout-grid", "▦", "nav.pages", 2, function()
	Router.go("pages")
end)
Nav.item("player", "user-round", "☺", "nav.player", 3, function()
	Router.go("player")
end)
Nav.item("performance", "gauge", "◔", "nav.performance", 4, function()
	Router.go("performance")
end)
Nav.item("settings", "settings", "⚙", "nav.settings", 5, function()
	Router.go("settings")
end)
Nav.item("about", "info", "i", "nav.about", 6, function()
	Router.go("about")
end)

-- Built-in pages can be hidden by a script: CreateWindow({ Player = false, Performance = false }).
function UI.setBuiltin(key, visible)
	local item = Nav.items[key]
	if item then
		item.button.Visible = visible
	end
	if not visible and Nav.active == key then
		Router.go("home")
	end
end
UI.setBuiltin("player", CONFIG.BuiltinPlayer)
UI.setBuiltin("performance", CONFIG.BuiltinPerformance)

-- == OPEN / CLOSE ==========================================================

UI.loops = { pulse, UI.heroFloat }

-- Looping animations only run while the window is open, animations are on and the
-- interface is not in lightweight mode.
function UI.updateLoops()
	local run = Prefs.animations and UI.isOpen and not Prefs.lightweight and Maid.alive
	for _, loop in UI.loops do
		if run then
			loop:Play()
		else
			loop:Pause()
		end
	end
end

-- Background blur (Liquid Glass): a BlurEffect in the camera only while the window is open.
-- It blurs the 3D scene behind the window; Roblox cannot blur UI layers themselves.
function UI.updateBlur()
	local want = Maid.alive and UI.isOpen and Prefs.blur and Style.state().glass
	if want then
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		if not UI.blurEffect or UI.blurEffect.Parent == nil then
			UI.blurEffect = create("BlurEffect", { Name = "MultiHubBlur", Size = 0, Parent = camera })
		end
		tween(UI.blurEffect, 0.3, { Size = 12 })
	elseif UI.blurEffect then
		local effect = UI.blurEffect
		UI.blurEffect = nil
		if Prefs.animations and Maid.alive then
			tween(effect, 0.2, { Size = 0 })
			task.delay(0.2, function()
				effect:Destroy()
			end)
		else
			effect:Destroy()
		end
	end
end

do
	local openToken = 0
	local decor = {}
	for _, child in shell:GetChildren() do
		if child ~= window and child:IsA("GuiObject") then
			table.insert(decor, child) -- shadows + border sit outside the CanvasGroup fade
		end
	end
	function UI.setOpen(open)
		if UI.isOpen == open then
			return
		end
		UI.isOpen = open
		openToken += 1
		local token = openToken
		Tooltip.hide()
		UI.updateLoops()
		UI.updateBlur()
		if open then
			holder.Visible = true
			window.GroupTransparency = 1
			openScale.Scale = 0.96
			tween(window, 0.2, { GroupTransparency = 0 })
			tween(openScale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
			task.delay(Prefs.animations and 0.12 or 0, function()
				if token == openToken then
					for _, object in decor do
						object.Visible = true
					end
					Style.apply() -- re-hides shadows when "Reduce UI effects" is on
				end
			end)
		else
			DropPanel.close()
			LinkDialog.close()
			Modal.close()
			for _, object in decor do
				object.Visible = false
			end
			tween(window, 0.16, { GroupTransparency = 1 })
			tween(openScale, 0.16, { Scale = 0.96 })
			task.delay(Prefs.animations and 0.16 or 0, function()
				if token == openToken then
					holder.Visible = false
				end
			end)
		end
	end
end

-- == INPUT =================================================================

-- Floating button: toggles the window, can be dragged and snaps to the nearest side.
local FAB = { size = 56, input = (nil :: any), moved = false, start = Vector2.zero, origin = Vector2.zero, tween = (nil :: any) }
do
	local fab = create("TextButton", {
		Name = "FloatingToggle",
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 44, 0.5, 0),
		Size = UDim2.fromOffset(FAB.size, FAB.size),
		BackgroundColor3 = THEME.Surface,
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = gui,
	}, { Util.corner(16), Util.stroke(THEME.AccentDark, 0.2, 1.5) })
	UI.buildLogo(fab, 44, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 11,
	})
	FAB.button = fab
	FAB.press = create("UIScale", { Name = "Press", Parent = fab })
	FAB.half = FAB.size / 2 + 6
	FAB.threshold = IS_TOUCH and 12 or 8
end

local function sameInput(input, tracked)
	if not tracked or input.UserInputType ~= tracked.UserInputType then
		return false
	end
	-- Touch: each finger has its own InputObject. Mouse: there is only one pointer.
	return input.UserInputType ~= Enum.UserInputType.Touch or input == tracked
end

local function fabLimits()
	local viewport = gui.AbsoluteSize
	local maxY = viewport.Y - FAB.half
	if IS_TOUCH then
		maxY = math.min(maxY, viewport.Y * 0.6) -- away from the thumbstick and jump button
	end
	return viewport, maxY
end

local function snapFab()
	local viewport, maxY = fabLimits()
	local center = FAB.button.AbsolutePosition + FAB.button.AbsoluteSize / 2
	local x = center.X < viewport.X / 2 and 44 or viewport.X - 44
	local y = math.clamp(center.Y, FAB.half + 40, math.max(FAB.half + 40, maxY))
	FAB.tween = tween(FAB.button, 0.4, { Position = UDim2.fromOffset(x, y) })
end

FAB.button.InputBegan:Connect(function(input)
	if FAB.input or not Util.isPress(input) then
		return
	end
	if FAB.tween then
		FAB.tween:Cancel()
	end
	FAB.input = input
	FAB.moved = false
	FAB.start = Vector2.new(input.Position.X, input.Position.Y)
	local viewport = gui.AbsoluteSize
	local pos = FAB.button.Position
	FAB.origin = Vector2.new(pos.X.Scale * viewport.X + pos.X.Offset, pos.Y.Scale * viewport.Y + pos.Y.Offset)
	tween(FAB.press, 0.1, { Scale = 0.9 })
end)

local drag = { active = false }
local function beginDrag(input)
	if drag.active or not Util.isPress(input) then
		return
	end
	drag.active = true
	drag.input = input
	drag.start = input.Position
	drag.position = holder.Position
end
header.InputBegan:Connect(beginDrag)

-- A pointer move belongs to the drag only if it comes from the same finger / the mouse.
local function owns(tracked, input)
	if tracked.UserInputType == Enum.UserInputType.Touch then
		return input == tracked
	end
	return input.UserInputType == Enum.UserInputType.MouseMovement
end

Util.track(UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	if Components.activeSlider then
		Components.activeSlider(input.Position.X)
	elseif FAB.input then
		if owns(FAB.input, input) then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - FAB.start
			if FAB.moved or delta.Magnitude > FAB.threshold then
				FAB.moved = true
				local viewport, maxY = fabLimits()
				FAB.button.Position = UDim2.fromOffset(
					math.clamp(FAB.origin.X + delta.X, FAB.half, viewport.X - FAB.half),
					math.clamp(FAB.origin.Y + delta.Y, FAB.half, math.max(FAB.half, maxY))
				)
			end
		end
	elseif drag.active and owns(drag.input, input) then
		-- Drag in screen pixels; the holder is scaled, so its Position offset is in screen pixels too.
		local delta = input.Position - drag.start
		holder.Position = UDim2.new(
			drag.position.X.Scale,
			drag.position.X.Offset + delta.X,
			drag.position.Y.Scale,
			drag.position.Y.Offset + delta.Y
		)
	end
end))

Util.track(UserInputService.InputEnded:Connect(function(input)
	if not Util.isPress(input) then
		return
	end
	if drag.active and sameInput(input, drag.input) then
		drag.active = false
		drag.input = nil
	end
	if Components.activeSlider then
		Components.setActiveSlider(nil)
	end
	-- Releasing another finger (thumbstick, camera) does not toggle or drop the button.
	if FAB.input and sameInput(input, FAB.input) then
		FAB.input = nil
		tween(FAB.press, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		if FAB.moved then
			snapFab()
		else
			UI.setOpen(not UI.isOpen)
		end
	end
end))

Util.track(UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	if Components.keyCapture then
		Components.keyCapture(input.KeyCode)
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape then
		if Modal.isOpen() then
			Modal.close()
		elseif LinkDialog.isOpen() then
			LinkDialog.close()
		elseif DropPanel.isOpen() then
			DropPanel.close()
		end
		return
	end
	if not processed and input.KeyCode == toggleKeyCode() then
		UI.setOpen(not UI.isOpen)
	end
end))

hideButton.Activated:Connect(function()
	UI.setOpen(false)
end)
unloadButton.Activated:Connect(function()
	UI.askUnload()
end)

-- == BUILD =================================================================
-- Scripts register tabs/sections/items; one deferred build per frame turns them into UI.

local Build = { queued = false, count = 0 }

function Build.run()
	Build.queued = false
	if not Maid.alive then
		return
	end
	Build.count += 1
	local ok, err = pcall(function()
		Pages.rebuildGrid()
		Pages.rebuildHome()
		Status.refresh()
		Router.refreshCurrent()
	end)
	if not ok then
		warn("[MultiHub] build failed: " .. tostring(err))
	end
	Store.start()
end

function Build.request(immediate)
	if immediate then
		Build.run()
		return
	end
	if Build.queued then
		return
	end
	Build.queued = true
	task.defer(function()
		if Build.queued then
			Build.run()
		end
	end)
end

-- == STARTUP ===============================================================

I18n.refresh()
Style.apply()
Router.go("home")
UI.updateLoops()

-- Logo download in the background: the window opens at once, the logo fades in when it arrives.
task.spawn(function()
	local asset = CONFIG.LogoAsset
	if asset == "" then
		local writefile = Util.fs("writefile")
		local getAsset = Util.fs("getcustomasset") or Util.fs("getsynasset")
		if writefile and getAsset then
			local body = Util.httpGet(CONFIG.LogoUrl)
			if body and #body > 200 then
				pcall(writefile, CONFIG.LogoFile, body)
			end
			local isfile = Util.fs("isfile")
			if not isfile or isfile(CONFIG.LogoFile) then
				local ok, result = pcall(getAsset, CONFIG.LogoFile)
				if ok and type(result) == "string" then
					asset = result
				end
			end
		end
	end
	if asset ~= "" and Maid.alive then
		UI.applyLogo(asset)
	end
end)

task.delay(0.25, function()
	if Maid.alive then
		notify(
			CONFIG.HubName,
			IS_TOUCH and I18n.t("notify.loaded.touch") or I18n.t("notify.loaded", Util.keyName(toggleKeyCode())),
			4,
			"info"
		)
	end
end)

-- == LIBRARY API ===========================================================
-- Same public surface as v1 (CreateWindow / Tab / Section / controls / Build / Notify / Toggle /
-- Destroy). New, optional: Desc/Tooltip on controls, translated texts, language functions,
-- dropdown SetOptions, SelectTab, GetValue/SetValue, SaveConfig/LoadConfig, OnLanguageChanged.

local Library = (function()
	local legacyCounter = 0
	local usedIds = {}
	local buildingExample = false

	-- v1 numbered ids ("toggle_3"); kept as legacyId so profiles saved by v1 still load.
	local function legacyUID(prefix)
		legacyCounter += 1
		return (prefix or "lib") .. "_" .. legacyCounter
	end

	-- English (or first) text of a translatable value, used for stable ids.
	local function baseText(value)
		if type(value) == "table" then
			return value.en or value.En or value.EN or value[1] or select(2, next(value)) or ""
		end
		return tostring(value or "")
	end

	-- Stable id from tab + section + title: survives adding/reordering controls in a script.
	local function stableId(tabId, sectionName, title, kind)
		local base = Util.slug(tabId) .. "." .. Util.slug(baseText(sectionName)) .. "." .. Util.slug(baseText(title) ~= "" and baseText(title) or kind)
		local id, n = base, 1
		while usedIds[id] or Elements[id] or Handlers[id] do
			n += 1
			id = base .. "_" .. n
		end
		usedIds[id] = true
		return id
	end

	local function pick(opts, ...)
		for _, key in { ... } do
			if opts[key] ~= nil then
				return opts[key]
			end
		end
		return nil
	end

	local function makeItem(ctx, kind, legacyPrefix, opts, fallbackTitle)
		local explicit = pick(opts, "Id", "id", "Flag", "flag")
		local title = pick(opts, "Title", "title", "Name", "name") or fallbackTitle
		local item = {
			type = kind,
			labelRaw = title,
			descRaw = pick(opts, "Desc", "desc", "Description", "description"),
			tooltipRaw = pick(opts, "Tooltip", "tooltip"),
		}
		if explicit ~= nil then
			item.id = tostring(explicit)
		else
			item.legacyId = legacyUID(legacyPrefix)
			item.id = stableId(ctx.tab.id, ctx.section.nameRaw, title, kind)
		end
		return item
	end

	local function register(ctx, item, callback)
		table.insert(ctx.section.items, item)
		item.tabId = ctx.tab.id
		if type(callback) == "function" then
			Handlers[item.id] = callback
		end
		local element
		if SAVEABLE[item.type] then
			element = newElement(item)
			Store.adopt(element)
		else
			element = { Id = item.id, Item = item, Type = item.type }
		end
		function element:SetTitle(title)
			item.labelRaw = title
			Build.request()
		end
		function element:SetDesc(desc)
			item.descRaw = desc
			Build.request()
		end
		Build.request()
		return element
	end

	-- Section --------------------------------------------------------------------

	local LibSection = {}
	LibSection.__index = LibSection

	function LibSection:Toggle(opts)
		opts = opts or {}
		local item = makeItem(self, "toggle", "toggle", opts, "Toggle")
		local default = pick(opts, "Default", "default", "Value")
		item.default = default ~= nil and default or false
		return register(self, item, pick(opts, "Callback", "callback"))
	end

	function LibSection:Button(opts)
		opts = opts or {}
		local item = makeItem(self, "action", "action", opts, "Button")
		item.icon = pick(opts, "Icon", "icon")
		local element = register(self, item, pick(opts, "Callback", "callback"))
		local id = item.id
		-- v1 returned { Fire = function }; both Button.Fire() and Button:Fire() work.
		element.Fire = function()
			return fire(id)
		end
		return element
	end

	function LibSection:Slider(opts)
		opts = opts or {}
		local item = makeItem(self, "slider", "slider", opts, "Slider")
		local valueTable = type(opts.Value) == "table" and opts.Value or {} -- WindUI-style { Min, Max, Default }
		item.min = tonumber(pick(opts, "Min", "min") or valueTable.Min) or 0
		item.max = tonumber(pick(opts, "Max", "max") or valueTable.Max) or 100
		if item.max < item.min then
			item.min, item.max = item.max, item.min
		end
		local step = tonumber(pick(opts, "Step", "step", "Increment", "Rounding"))
		item.step = (step and step > 0) and step or 1
		local default = pick(opts, "Default", "default") or valueTable.Default
		item.default = tonumber(default) or item.min
		return register(self, item, pick(opts, "Callback", "callback"))
	end

	local function dropdownItem(ctx, opts, multi)
		local kind = multi and "multidropdown" or "dropdown"
		local item = makeItem(ctx, kind, kind, opts, multi and "MultiDropdown" or "Dropdown")
		local options = pick(opts, "Options", "options", "Values", "values") or {}
		item.options = {}
		for _, option in options do
			table.insert(item.options, tostring(option))
		end
		local default = pick(opts, "Default", "default", "Value")
		if multi then
			item.default = type(default) == "table" and default or (default ~= nil and { default } or {})
		else
			item.default = default
		end
		local element = register(ctx, item, pick(opts, "Callback", "callback"))
		-- New: replace the option list at runtime (keeps the current value when still valid).
		function element:SetOptions(newOptions)
			item.options = {}
			for _, option in newOptions or {} do
				table.insert(item.options, tostring(option))
			end
			local current = sanitize(item, State[item.id])
			if current == nil then
				current = defaultValue(item)
			end
			State[item.id] = current
			element.Value = current
			refreshLive(item.id)
			if DropPanel.isOpen() then
				DropPanel.close()
			end
		end
		element.Refresh = element.SetOptions
		return element
	end

	function LibSection:Dropdown(opts)
		opts = opts or {}
		local multi = opts.Multi == true or opts.multi == true
		return dropdownItem(self, opts, multi)
	end

	function LibSection:MultiDropdown(opts)
		return dropdownItem(self, opts or {}, true)
	end

	-- Paragraph: static or live text. element:Set(text) updates it everywhere it is shown.
	function LibSection:Paragraph(opts)
		opts = opts or {}
		local item = makeItem(self, "paragraph", "paragraph", opts, "")
		item.textRaw = pick(opts, "Text", "text", "Content", "content") or ""
		local element = register(self, item, nil)
		function element:Set(text)
			item.textRaw = text == nil and "" or text
			refreshLive(item.id)
		end
		function element:SetTitle(title)
			item.labelRaw = title or ""
			refreshLive(item.id)
		end
		function element:Get()
			return nil -- v1 behavior
		end
		return element
	end

	function LibSection:InputBox(opts)
		opts = opts or {}
		local item = makeItem(self, "inputbox", "inputbox", opts, "Input")
		item.maxLength = math.clamp(tonumber(pick(opts, "MaxLength", "maxLength")) or 150, 1, 500)
		local default = pick(opts, "Default", "default", "Value")
		item.default = tostring(default or "")
		item.placeholderRaw = pick(opts, "Placeholder", "placeholder")
		return register(self, item, pick(opts, "Callback", "callback"))
	end
	LibSection.TextBox = LibSection.InputBox
	LibSection.Input = LibSection.InputBox

	-- Tab ----------------------------------------------------------------------

	local LibTab = {}
	LibTab.__index = LibTab

	-- Same title = same section (v1 behavior).
	function LibTab:Section(opts)
		opts = opts or {}
		local title = pick(opts, "Title", "title", "Name", "name") or "Section"
		for _, section in self._coreTab.sections do
			if baseText(section.nameRaw) == baseText(title) then
				return setmetatable({ section = section, tab = self._coreTab }, LibSection)
			end
		end
		local section = {
			nameRaw = title,
			descRaw = pick(opts, "Desc", "desc", "Description", "description"),
			items = {},
		}
		table.insert(self._coreTab.sections, section)
		Build.request()
		return setmetatable({ section = section, tab = self._coreTab }, LibSection)
	end

	-- Shortcut used by some scripts: Tab:Toggle(...) goes to a default section.
	for _, method in { "Toggle", "Button", "Slider", "Dropdown", "MultiDropdown", "Paragraph", "InputBox", "TextBox" } do
		LibTab[method] = function(self, opts)
			local section = self:Section({ Title = self._coreTab.titleRaw }) -- raw title: stable across languages
			return section[method](section, opts)
		end
	end

	function LibTab:Select()
		Router.openTab(self._coreTab)
	end

	-- Window ---------------------------------------------------------------------

	local LibWindow = {}
	LibWindow.__index = LibWindow

	local function purgeExamples()
		for index = #TABS, 1, -1 do
			local tab = TABS[index]
			if tab.example then
				for _, section in tab.sections do
					for _, item in section.items do
						Elements[item.id] = nil
						Handlers[item.id] = nil
						State[item.id] = nil
						Live[item.id] = nil
					end
				end
				table.remove(TABS, index)
				if Router.currentTab == tab then
					Router.currentTab = nil
					Router.go("pages")
				end
			end
		end
	end

	function LibWindow:Tab(opts)
		opts = opts or {}
		if not buildingExample then
			purgeExamples() -- the demo disappears as soon as a real script adds its own tab
		end
		local title = pick(opts, "Title", "title", "Name", "name") or "Tab"
		local explicit = pick(opts, "Id", "id")
		if explicit ~= nil then
			for _, tab in TABS do
				if tab.id == tostring(explicit) then
					return setmetatable({ _coreTab = tab }, LibTab)
				end
			end
		end
		local id
		if explicit ~= nil then
			id = tostring(explicit)
		else
			legacyUID("tab")
			local base = "tab_" .. Util.slug(baseText(title))
			id = base
			local n = 1
			local function taken(candidate)
				for _, tab in TABS do
					if tab.id == candidate then
						return true
					end
				end
				return false
			end
			while taken(id) do
				n += 1
				id = base .. "_" .. n
			end
		end
		local coreTab = {
			id = id,
			titleRaw = title,
			descRaw = pick(opts, "Desc", "desc", "Description", "description") or "",
			icon = pick(opts, "Icon", "icon") or "square",
			sections = {},
			example = buildingExample,
		}
		table.insert(TABS, coreTab)
		Build.request()
		return setmetatable({ _coreTab = coreTab }, LibTab)
	end
	LibWindow.CreateTab = LibWindow.Tab

	function LibWindow:SelectTab(idOrTitle)
		return self._library:SelectTab(idOrTitle)
	end

	function LibWindow:Notify(opts)
		return self._library:Notify(opts)
	end

	-- Root -------------------------------------------------------------------------

	local Library = { Version = CONFIG.LibraryVersion }
	Library.__index = Library

	function Library:CreateWindow(opts)
		opts = opts or {}
		local title = pick(opts, "Title", "title", "Name", "name")
		if title ~= nil and string.upper(baseText(title)) ~= string.upper(CONFIG.HubName) then
			UI.windowTitle = I18n.resolve(title)
			UI.updateFooter()
		end
		local key = pick(opts, "ToggleKey", "Keybind", "MinimizeKey")
		if typeof(key) == "EnumItem" and not Prefs._saved.toggleKey then
			Prefs.toggleKey = key.Name
		end
		-- New (v2.1): hide built-in pages, e.g. CreateWindow({ Player = false })
		if opts.Player == false then
			UI.setBuiltin("player", false)
		end
		if opts.Performance == false then
			UI.setBuiltin("performance", false)
		end
		return setmetatable({ _opts = opts, _library = self }, LibWindow)
	end

	-- Optional since v2 (the UI builds itself on the next frame); calling it builds right away.
	function Library:Build()
		Build.request(true)
	end

	function Library:Notify(opts)
		opts = opts or {}
		notify(
			I18n.resolve(pick(opts, "Title", "title") or ""),
			I18n.resolve(pick(opts, "Content", "content", "Message", "message", "Text", "text") or ""),
			pick(opts, "Duration", "duration", "Time") or 3,
			pick(opts, "Type", "type", "Kind")
		)
	end

	function Library:Toggle()
		UI.setOpen(not UI.isOpen)
	end

	function Library:IsOpen()
		return UI.isOpen
	end

	function Library:SetOpen(open)
		UI.setOpen(open == true)
	end

	-- Unload: undoes every change (fly, noclip, speed, graphics), closes every connection and
	-- loop, removes the GUI and drops internal references. Loading the library again later
	-- starts from zero (no duplicated connections).
	function Library:Destroy()
		if not Maid.alive then
			return
		end
		for _, cleanup in Maid.cleanups do
			local ok, err = pcall(cleanup)
			if not ok then
				warn("[MultiHub] cleanup failed: " .. tostring(err))
			end
		end
		table.clear(Maid.cleanups)
		Maid.alive = false
		UI.isOpen = false
		UI.updateBlur()
		for _, connection in Maid.connections do
			pcall(function()
				connection:Disconnect()
			end)
		end
		for _, loop in UI.loops do
			pcall(function()
				loop:Cancel()
			end)
		end
		gui:Destroy()
		table.clear(I18n.Bound)
		table.clear(I18n.Listeners)
		table.clear(Live)
		table.clear(Style.items)
		table.clear(Icons.Targets)
		table.clear(Components.scrollers)
		Components.keyCapture = nil
		Components.activeSlider = nil
		if genv.__MultiHubLibrary == self then
			genv.__MultiHubLibrary = nil
		end
	end
	Library.Unload = Library.Destroy

	-- The Unload buttons (header and Settings) ask first.
	UI.askUnload = function()
		Modal.confirm({
			title = "unload.title",
			body = "unload.body",
			confirm = "unload.confirm",
			cancel = "unload.cancel",
			onConfirm = function()
				Library:Destroy()
			end,
		})
	end

	-- For tests: how many global connections exist and how many are still connected.
	function Library:GetDebugInfo()
		local connected = 0
		for _, connection in Maid.connections do
			if connection.Connected then
				connected += 1
			end
		end
		return {
			Alive = Maid.alive,
			Connections = #Maid.connections,
			Connected = connected,
			GuiParented = gui.Parent ~= nil,
		}
	end

	-- Languages ----------------------------------------------------------------------

	-- code = "en" | "pt-br" | "es" | "auto" | any added language. Saved in Settings.json.
	function Library:SetLanguage(code)
		local normalized = code == "auto" and "auto" or I18n.normalize(code)
		if not normalized then
			warn("[MultiHub] unknown language: " .. tostring(code))
			return I18n.Current
		end
		Elements.__ui_language:Set(normalized)
		return I18n.Current
	end

	function Library:GetLanguage()
		return I18n.Current
	end

	-- What the user picked in Settings: "auto" or a language code.
	function Library:GetLanguagePreference()
		return Prefs.language
	end

	function Library:GetLanguages()
		local list = {}
		for _, code in I18n.Order do
			table.insert(list, { Code = code, Name = I18n.Names[code] or code })
		end
		return list
	end

	-- Adds (or extends) a language; missing keys fall back to English.
	function Library:AddLanguage(code, displayName, strings)
		code = string.lower(tostring(code))
		local isNew = I18n.Strings[code] == nil
		I18n.Strings[code] = I18n.Strings[code] or {}
		for key, text in strings or {} do
			I18n.Strings[code][key] = text
		end
		I18n.Names[code] = displayName or I18n.Names[code] or code
		if isNew then
			table.insert(I18n.Order, code)
			table.insert(LANGUAGE_OPTIONS, code)
		end
		I18n.set(resolveLanguagePref())
		I18n.refresh()
		return code
	end

	function Library:AddTranslations(code, strings)
		return self:AddLanguage(code, nil, strings)
	end

	function Library:T(key, ...)
		return I18n.t(key, ...)
	end

	-- Script dictionary: translates the plain English texts of a script (titles, descriptions,
	-- tooltips, paragraphs, notifications and dropdown option labels) into the player's
	-- language. Call it before creating the controls (it also refreshes visible ones).
	--   Library:AddDictionary({ ["Auto Mine"] = { ["pt-br"] = "Mineração automática", es = "Minería automática" } })
	--   Library:AddDictionary("pt-br", { ["Auto Mine"] = "Mineração automática" })
	function Library:AddDictionary(first, second)
		local count = I18n.addDictionary(first, second)
		I18n.refresh()
		return count
	end

	-- Resolves a translatable value ({ en = ..., ["pt-br"] = ... }) in the current language.
	function Library:Translate(value)
		return I18n.resolve(value)
	end

	function Library:OnLanguageChanged(callback)
		table.insert(I18n.Listeners, callback)
		return {
			Disconnect = function()
				local at = table.find(I18n.Listeners, callback)
				if at then
					table.remove(I18n.Listeners, at)
				end
			end,
		}
	end

	-- Navigation / values / profiles ----------------------------------------------------

	function Library:SelectTab(idOrTitle)
		for _, tab in TABS do
			if tab.id == idOrTitle or string.lower(baseText(tab.titleRaw)) == string.lower(tostring(idOrTitle)) then
				Build.request(true)
				Router.openTab(tab)
				return true
			end
		end
		return false
	end

	function Library:GetValue(id)
		return State[id]
	end

	function Library:SetValue(id, value, silent)
		local element = Elements[id]
		if element and element.Set then
			element:Set(value, silent)
			return true
		end
		return false
	end

	function Library:SaveConfig(name)
		return Store.save(name)
	end

	function Library:LoadConfig(name)
		local ok, err = Store.read(name)
		if ok then
			Store.applyAll()
		end
		return ok, err
	end

	function Library:DeleteConfig(name)
		return Store.delete(name)
	end

	function Library:GetConfigName()
		return Store.Active
	end

	function Library:SetToggleKey(keyCode)
		if typeof(keyCode) == "EnumItem" then
			Prefs.toggleKey = keyCode.Name
			savePrefs()
		end
	end

	Library.Elements = Elements
	Library.Flags = State

	-- == EXAMPLE ===============================================================
	-- Demo shown when the library runs alone. It is removed automatically as soon as a
	-- script creates its own tab, so CONFIG.ExampleEnabled can stay true.

	if CONFIG.ExampleEnabled then
		buildingExample = true
		local ok, err = pcall(function()
			local window = Library:CreateWindow({ Title = CONFIG.HubName })
			local mainTab = window:Tab({
				Id = "main",
				Title = { en = "Main", ["pt-br"] = "Principal", es = "Principal" },
				Icon = "house",
				Desc = { en = "Example controls", ["pt-br"] = "Controles de exemplo", es = "Controles de ejemplo" },
			})
			local general = mainTab:Section({
				Title = { en = "General", ["pt-br"] = "Geral", es = "General" },
				Desc = { en = "Every control type", ["pt-br"] = "Todos os tipos de controle", es = "Todos los tipos de control" },
			})
			general:Paragraph({
				Title = { en = "Procedural UI", ["pt-br"] = "Interface procedural", es = "Interfaz procedural" },
				Text = {
					en = "Built only with Frames, UICorner, UIStroke and UIGradient. No image asset is required.",
					["pt-br"] = "Feita só com Frames, UICorner, UIStroke e UIGradient. Nenhuma imagem é necessária.",
					es = "Hecha solo con Frames, UICorner, UIStroke y UIGradient. No se necesita ninguna imagen.",
				},
			})
			general:Toggle({
				Id = "example_enabled",
				Title = { en = "Example toggle", ["pt-br"] = "Toggle de exemplo", es = "Toggle de ejemplo" },
				Desc = { en = "Shows a notification", ["pt-br"] = "Mostra uma notificação", es = "Muestra una notificación" },
				Default = true,
			})
			general:Slider({
				Id = "example_slider",
				Title = { en = "Example slider", ["pt-br"] = "Slider de exemplo", es = "Slider de ejemplo" },
				Min = 0,
				Max = 100,
				Default = 60,
				Step = 5,
			})
			general:Dropdown({
				Id = "example_dropdown",
				Title = { en = "Quality", ["pt-br"] = "Qualidade", es = "Calidad" },
				Options = { "Low", "Medium", "High" },
				Default = "Medium",
			})
			general:Button({
				Id = "example_button",
				Title = { en = "Test notification", ["pt-br"] = "Testar notificação", es = "Probar notificación" },
				Callback = function()
					Library:Notify({
						Title = "Multi Hub",
						Content = { en = "Example button works.", ["pt-br"] = "O botão de exemplo funciona.", es = "El botón de ejemplo funciona." },
						Duration = 2.5,
						Type = "success",
					})
				end,
			})

			local auto = mainTab:Section({
				Title = { en = "Automation", ["pt-br"] = "Automação", es = "Automatización" },
				Desc = { en = "Descriptions and tooltips", ["pt-br"] = "Descrições e dicas", es = "Descripciones y consejos" },
			})
			auto:Toggle({
				Id = "example_auto_farm",
				Title = { en = "Auto Farm", ["pt-br"] = "Farm automático", es = "Farm automático" },
				Desc = { en = "Farms the nearest target", ["pt-br"] = "Farma o alvo mais próximo", es = "Farmea el objetivo más cercano" },
				Tooltip = {
					en = "Hover tooltips explain what a feature does.",
					["pt-br"] = "As dicas ao passar o mouse explicam o que a função faz.",
					es = "Los consejos al pasar el ratón explican qué hace la función.",
				},
			})
			auto:Toggle({ Id = "example_auto_collect", Title = { en = "Auto Collect", ["pt-br"] = "Coletar automático", es = "Recolectar automático" } })
			auto:MultiDropdown({
				Id = "example_zones",
				Title = { en = "Zones", ["pt-br"] = "Zonas", es = "Zonas" },
				Options = { "Forest", "Desert", "Snow", "Volcano", "Ocean", "Sky", "Cave", "Castle" },
				Default = { "Forest" },
			})

			local moreTab = window:Tab({
				Id = "settings_example",
				Title = { en = "More", ["pt-br"] = "Mais", es = "Más" },
				Icon = "sliders-horizontal",
				Desc = { en = "Inputs and multi-selection", ["pt-br"] = "Entradas e seleção múltipla", es = "Entradas y selección múltiple" },
			})
			local profile = moreTab:Section({ Title = { en = "Profile", ["pt-br"] = "Perfil", es = "Perfil" } })
			profile:InputBox({
				Id = "example_name",
				Title = { en = "Player name", ["pt-br"] = "Nome do jogador", es = "Nombre del jugador" },
				Placeholder = { en = "Type here...", ["pt-br"] = "Digite aqui...", es = "Escribe aquí..." },
				Default = "Dev",
			})
			profile:MultiDropdown({
				Id = "example_targets",
				Title = { en = "Targets", ["pt-br"] = "Alvos", es = "Objetivos" },
				Options = { "NPC", "Chest", "Boss" },
				Default = { "NPC" },
			})
		end)
		buildingExample = false
		if not ok then
			warn("[MultiHub] example failed: " .. tostring(err))
		end
	end

	return Library
end)()

genv.__MultiHubLibrary = Library
Build.request()

return Library
