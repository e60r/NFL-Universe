-- [Start up] --

if _G.Connections then
	for Index, ScriptSignal in _G.Connections do
		ScriptSignal:Disconnect()
	end

	_G.Connections = nil
end

_G.Connections = {}

-- [ Services ] --

local LocalPlayer = game:GetService("Players").LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- [Player & Character] --
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- [Whtelist & Blacklist] --

local Whitelist = {"ymqm"}
local IgnoreWhitelist = true

local Blacklist = {"Kickoff", "Onside"}
local IgnoreBlacklist = true

-- [ Veriables ] --

local MatchID, Remote, Function, MatchState
local Teleporting, TeleportPosition

local WasInHand = false
local BlockingPlayers = false

-- [Getting required objects] --

for _, Index in ReplicatedStorage.Games:GetChildren() do
	MatchID = Index.Name
	Remote = Index:FindFirstChild("ReEvent")
	Function = Index:FindFirstChild("ReFunction")
	MatchState = Index:FindFirstChild("ActiveState")

	Teleporting = false
	TeleportPosition = nil
end

-- [Starting Key Connections]

_G.Connections[1] = RunService.Heartbeat:Connect(function()
	Character = LocalPlayer.Character
	HumanoidRootPart = Character.PrimaryPart

	local Replicated = workspace.Games[MatchID]:FindFirstChild("Replicated")
	if Replicated then
		for _, Object in pairs(Replicated:GetChildren()) do
			if (Object.Name == "Football" and not Object:GetAttribute("BeingTracked")) then
				Object:SetAttribute("BeingTracked", true)
				task.spawn(function()
					TeleportToBall(Object)
				end)
			end
		end
	end
end)

_G.Connections[2] = RunService.RenderStepped:Connect(function()
	if TeleportPosition ~= nil then
		HumanoidRootPart.Anchored = false
		workspace.CurrentCamera.CameraSubject = Character.Humanoid
		HumanoidRootPart.Velocity = Vector3.zero
		HumanoidRootPart.CFrame = CFrame.new(TeleportPosition)
	end
end)

_G.Connections[3] = MatchState:GetPropertyChangedSignal("Value"):Connect(function()
	TeleportPosition = nil
end)

-- [Functions] --

function Teleport()
	HumanoidRootPart.Anchored = false
	Teleporting = true

	if (IgnoreWhitelist or WasInHand) and (not IgnoreBlacklist or not table.find(Blacklist, MatchState.Value)) then
		local Endzones =  workspace.Games[MatchID]:FindFirstChild("Local"):FindFirstChild("Endzones")
		for _, Objects in Endzones:GetChildren() do
			wait(0.2)
			HumanoidRootPart.Velocity = Vector3.new(0, 0, 0)
			TeleportPosition = Objects.Position + Vector3.new(0, 2, 0)
		end
	end
	if (table.find(Blacklist, MatchState.Value)) and not IgnoreBlacklist then
		local Center = workspace.Games[MatchID]:FindFirstChild("Replicated").Center
		HumanoidRootPart.Velocity = Vector3.new(0, 0, 0)
		TeleportPosition = Center.Position + Vector3.new(0, 3, 0)
		Remote:FireServer("Mechanics", "QBSlide", {["VecCoordinate"] = Vector3.new(HumanoidRootPart.Position)})
	end

	Teleporting = false
	task.wait(0.1)
end

function TeleportToBall(ball)
	if ball:IsDescendantOf(Character) then
		return
	end

	local connection, catchConnection, proximityCheck

	local Last = ball.Position
	local velocity = Vector3.zero	

	connection = RunService.Heartbeat:Connect(function(Time)
		if (ball and ball.Parent) and not ball:IsDescendantOf(Character) then
			velocity = (ball.Position - Last) / Time
			Last = ball.Position

			local predictedPosition = ball.Position + (velocity * 0.05)
			TeleportPosition = (predictedPosition + Vector3.new(3, 0, 0))
		else
			connection:Disconnect()
		end
	end)

	catchConnection = RunService.Heartbeat:Connect(function()
		if ball and ball.Parent and not ball:IsDescendantOf(Character) then
			Remote:FireServer("Mechanics", "Catching", true)
		else
			catchConnection:Disconnect()
		end
	end)

	proximityCheck = RunService.Heartbeat:Connect(function()
		if (ball and ball.Parent) and ball:IsDescendantOf(Character) then
			proximityCheck:Disconnect()

			task.spawn(function()
				Teleport()
			end)
			WasInHand = false
			HumanoidRootPart.Anchored = false
			ball:SetAttribute("BeingTracked", nil)
		elseif not BlockingPlayers then
			pcall(function()
				HumanoidRootPart.Anchored = false
				local LastState = MatchState.Value
				local CaughtPlayer = Players:GetPlayerFromCharacter(ball:FindFirstAncestorOfClass("Model"))

				if CaughtPlayer then
					BlockingPlayers = true
					while ball:IsDescendantOf(CaughtPlayer.Character) do
						Remote:FireServer("Mechanics", "Blocking", true)

						if CaughtPlayer:FindFirstChild("Replicated").TeamID.Value ~= LocalPlayer:FindFirstChild("Replicated").TeamID.Value then
							TeleportPosition = CaughtPlayer.Character.PrimaryPart.CFrame
						else
							for _, Target in Players:GetPlayers() do
								if Target:FindFirstChild("Replicated").TeamID.Value ~= LocalPlayer:FindFirstChild("Replicated").TeamID.Value then
									if LastState ~= MatchState.Value then
										break
									end
									Remote:FireServer("Mechanics", "Blocking", true)
									TeleportPosition = Target.Character.PrimaryPart.Position
									wait(0.1)
								end
							end
						end

						BlockingPlayers = false
						wait()
					end
					proximityCheck:Disconnect()
				end
			end)
		end
	end)

	LocalPlayer.CharacterRemoving:Once(function()
		proximityCheck:Disconnect()
		catchConnection:Disconnect()
		connection:Disconnect()
	end)
end

function BindToWhitelist(Character)
	Character.DescendantRemoving:Connect(function(Part)
		if Part.Name == "Football" then
			WasInHand = true
		end
	end)
end

-- [Whitelist] --

Players.PlayerAdded:Connect(function(plr)
	if table.find(Whitelist, plr.Name) then
		BindToWhitelist(plr.Character or plr.CharacterAdded:Wait())
		plr.CharacterAdded:Connect(BindToWhitelist)
	end
end)

--

for Index, Player in Players:GetPlayers() do
	if table.find(Whitelist, Player.Name) then
		BindToWhitelist(Player.Character or Player.CharacterAdded:Wait())
		Player.CharacterAdded:Connect(BindToWhitelist)
	end
end
