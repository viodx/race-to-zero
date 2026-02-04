local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local speaker = Players.LocalPlayer

--===================================================
-- HELPERS
--===================================================
local function getTorso(char)
	return char
		and (char:FindFirstChild("HumanoidRootPart")
		or char:FindFirstChild("UpperTorso")
		or char:FindFirstChild("LowerTorso")
		or char:FindFirstChild("Torso"))
end

local function getRoot(char)
	return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end

local function getDisplay(plr)
	if not plr then return "player" end
	local dn = tostring(plr.DisplayName or ""):gsub("^%s+", ""):gsub("%s+$", "")
	return dn ~= "" and dn or plr.Name
end

local function randomString(len)
	local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	local t = {}
	for i = 1, len do
		local n = math.random(1, #chars)
		t[i] = chars:sub(n, n)
	end
	return table.concat(t)
end

local function sendChat(msg)
	pcall(function()
		local tcs = game:GetService("TextChatService")
		local ch = tcs.TextChannels:FindFirstChild("RBXGeneral") or tcs.TextChannels:GetChildren()[1]
		if ch then ch:SendAsync(msg) end
	end)
end

--===================================================
-- HEADSIT
--===================================================
local headSitConn

local function stopHeadSit()
	if headSitConn then
		headSitConn:Disconnect()
		headSitConn = nil
	end
end

local function startHeadSit(target)
	stopHeadSit()

	local char = speaker.Character
	if not char then return end

	local hum = char:FindFirstChildOfClass("Humanoid")
	local myRoot = getRoot(char)
	if not hum or not myRoot then return end

	hum.Sit = true

	headSitConn = RunService.Heartbeat:Connect(function()
		if not target
			or not target.Parent
			or not target.Character
			or not getTorso(target.Character)
			or hum.Sit ~= true
		then
			stopHeadSit()
			return
		end

		myRoot.CFrame =
			getTorso(target.Character).CFrame
			* CFrame.new(0, 1.6, 0.4)
	end)
end

--===================================================
-- TARGET PICK (NO REPEAT)
--===================================================
local lastTarget

local function getRandomTargetNoRepeat()
	local pool = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= speaker and p ~= lastTarget and p.Character and getTorso(p.Character) then
			table.insert(pool, p)
		end
	end
	if #pool == 0 then return nil end
	return pool[math.random(1, #pool)]
end

--===================================================
-- SETTINGS
--===================================================
math.randomseed(tick())

local TARGET_SWITCH_EVERY = 8
local CHAT_COOLDOWN = 3

local SERVERHOP_EVERY = 24

local texts = {
	"yo [targetPlayerName] join my favorites, the new \"so crying rn\" has anticheat",
	"hi [targetPlayerName], join the new \"so crying rn\" from my favorites",
	"[targetPlayerName] join the updated version in my favorites",
	"[targetPlayerName] leave this, join the new game from my favorites fr",
	"[targetPlayerName] this game gets no updates, the new one in my favorites is better",
	"[targetPlayerName] the dev abandoned this game, new game is in my favorites",
	"[targetPlayerName] trust me join the new version in my favorites",
	"[targetPlayerName] join my favorites, the new one has better scripts + anticheat",
	"[targetPlayerName] new game in my favorites",
	"hey [targetPlayerName] wanna hop to the new game? its in my favorites",
	"[targetPlayerName] join the new game in my favorites",
	"[targetPlayerName] this game is outdated, new update is in my favorites",
	"[targetPlayerName] join the new game w anticheat from my favorites",
	"[targetPlayerName] join the anticheat version in my favorites",
	"[targetPlayerName] new game has anticheat + better stuff (favorites)",
}

--===================================================
-- TEXT PICKER
--===================================================
local lastTextIdx
local function pickTextNoRepeat()
	if #texts == 1 then return texts[1] end
	local i
	repeat i = math.random(1, #texts) until i ~= lastTextIdx
	lastTextIdx = i
	return texts[i]
end

--===================================================
-- ULTRA STABLE SERVERHOP
--===================================================

local hopping = false
local SERVER_CACHE = {}
local CACHE_TIME = 0
local CACHE_LIFETIME = 15
local currentIndex = math.random(1,10)

local function fetchServers()

	if os.clock() - CACHE_TIME < CACHE_LIFETIME and #SERVER_CACHE > 0 then
		return SERVER_CACHE
	end

	local url =
		"https://games.roblox.com/v1/games/"
		.. game.PlaceId
		.. "/servers/Public?sortOrder=Asc&limit=100"

	local ok, data = pcall(function()
		return HttpService:JSONDecode(game:HttpGet(url))
	end)

	if ok and data and data.data then

		local newList = {}

		for _, s in ipairs(data.data) do
			if s.id ~= game.JobId and s.playing < s.maxPlayers then
				table.insert(newList, s.id)
			end
		end

		if #newList > 0 then
			SERVER_CACHE = newList
			CACHE_TIME = os.clock()
		end
	end

	return SERVER_CACHE
end

local function forceServerHop()

	if hopping then return end
	hopping = true

	while true do

		local servers = fetchServers()

		if #servers > 0 then

			currentIndex += 1
			if currentIndex > #servers then
				currentIndex = 1
			end

			local serverId = servers[currentIndex]

			pcall(function()
				TeleportService:TeleportToPlaceInstance(
					game.PlaceId,
					serverId,
					speaker
				)
			end)
		end

		task.wait(1)
	end
end

--===================================================
-- SERVERHOP TIMER
--===================================================

task.spawn(function()
	local joinTime = os.clock()

	while task.wait(1) do
		if os.clock() - joinTime >= SERVERHOP_EVERY then
			forceServerHop()
			return
		end
	end
end)

--===================================================
-- MAIN LOOP
--===================================================

local lastChat = 0
local lastSwitch = 0
local currentTarget

while task.wait(0.2) do
	if not speaker.Character then
		stopHeadSit()
		currentTarget = nil
		continue
	end

	if os.clock() - lastSwitch >= TARGET_SWITCH_EVERY then
		lastSwitch = os.clock()
		stopHeadSit()
		lastTarget = currentTarget
		currentTarget = getRandomTargetNoRepeat()
		if currentTarget then
			startHeadSit(currentTarget)
		end
	end

	if not currentTarget
		or not currentTarget.Parent
		or not currentTarget.Character
		or not getTorso(currentTarget.Character)
	then
		stopHeadSit()
		lastTarget = currentTarget
		currentTarget = getRandomTargetNoRepeat()
		if currentTarget then
			startHeadSit(currentTarget)
		end
	end

	if currentTarget and os.clock() - lastChat >= CHAT_COOLDOWN then
		lastChat = os.clock()
		local msg = pickTextNoRepeat():gsub(
			"%[targetPlayerName%]",
			getDisplay(currentTarget)
		)
		sendChat(msg .. " | " .. randomString(5))
	end
end
