-- [[ Services ]] --
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

-- [[ Arguments ]] --
local FunctionArguments = { "GetServerPage" }
local EventArguments = { "TeleportToPlaceInstance" }
local GameIds = { Gameplay = 4940687511 }

-- [[ Information ]] --
local ServerType = "Gameplay"
local SortType = "quarter"

-- [[ Whitelist / Blacklist ]] --
local Whitelist = { "ymqm" }
local IgnoreWhitelist = true

local Blacklist = { "Kickoff", "Onside" }
local IgnoreBlacklist = true

-- [[ Objects ]] --
local RemoteEvent = ReplicatedStorage:WaitForChild("ReEvent")
local RemoteFunction = RemoteEvent:WaitForChild("ReFunction")

-- [[ Player ]] --
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- [[ Teleport Variables ]] --
local AttemptedServers = {}
local TeleportInProgress = false

-- [[ Match Variables ]] --
local Match = ReplicatedStorage.Games:GetChildren()[1]
local MatchID = Match.Name
local MatchRemote = Match:FindFirstChild("ReEvent")
local MatchFunction = Match:FindFirstChild("ReFunction")
local MatchState = Match:FindFirstChild("ActiveState")

-- [[ Game Variables ]] --
local WasInHand = false
local BlockingPlayers = false

-- [[ Functions ]] --

function ValidateServer(ServerInformation)
	local PlayerCount = ServerInformation.PlayerCount
	return PlayerCount >= 8 and PlayerCount <= 10 and ServerInformation.AwayTeam ~= "" and ServerInformation.HomeTeam ~= ""
end

function AttemptJoinRequest(ServerId)
	if not ServerId then return end
	TeleportInProgress = true
	RemoteEvent:FireServer(EventArguments[1], GameIds[ServerType], ServerId)
end

function FindNewServer()
	local FoundServers, Information = RemoteFunction:InvokeServer(FunctionArguments[1], ServerType, 1, SortType, "")
	if FoundServers and Information and Information.Servers then
		for _, ServerInformation in ipairs(Information.Servers) do
			local ServerId = ServerInformation.ServerId
			if ServerId and not AttemptedServers[ServerId] then
				AttemptedServers[ServerId] = true
				if ValidateServer(ServerInformation) then
					AttemptJoinRequest(ServerId)
					return
				end
			end
		end
	end
end

function TeleportToEndzones()
	if not Character or not HumanoidRootPart then
		return
	end

	HumanoidRootPart.Anchored = true

	if (IgnoreWhitelist or WasInHand) and (not IgnoreBlacklist or not table.find(Blacklist, MatchState.Value)) then
		local Endzones = workspace.Games[MatchID]:FindFirstChild("Local"):FindFirstChild("Endzones")

		for _, Objects in Endzones:GetChildren() do
			HumanoidRootPart.CFrame = CFrame.new(Objects.Position + Vector3.new(0, 3, 0))
			task.wait(0.1)
		end
	end

	if (table.find(Blacklist, MatchState.Value)) and not IgnoreBlacklist then
		local Center = workspace.Games[MatchID]:FindFirstChild("Replicated").Center
		HumanoidRootPart.CFrame = CFrame.new(Center.Position + Vector3.new(0, 3, 0))
		MatchRemote:FireServer("Mechanics", "QBSlide", { ["VecCoordinate"] = Vector3.new(Character.LowerTorso.Position) })
	end

	HumanoidRootPart.Anchored = false
end

function AttemptToCatch(Football)
	if Football:IsDescendantOf(Character) then
		return
	end

	local LastPosition = Football.Position
	local Velocity = Vector3.zero
	local Connection

	Connection = RunService.RenderStepped:Connect(function(DeltaTime)
		if not Football or not Football.Parent then
			Connection:Disconnect()
			return
		end

		Velocity = (Football.Position - LastPosition) / DeltaTime
		LastPosition = Football.Position

		local Speed = Velocity.Magnitude
		local BasePrediction = 0.05
		local ExtraPrediction = math.clamp(Speed / 150, 0, 0.2)
		local PredictionTime = BasePrediction + ExtraPrediction
		local HeightAdjustment = math.clamp((Football.Position.Y - HumanoidRootPart.Position.Y) / 50, -0.1, 0.1)
		PredictionTime = PredictionTime + HeightAdjustment

		local PredictedPosition = Football.Position + (Velocity * PredictionTime)

		if HumanoidRootPart and HumanoidRootPart.Parent then
			HumanoidRootPart.CFrame = CFrame.new(PredictedPosition)
		end

		MatchRemote:FireServer("Mechanics", "Catching", true)

		if Football.Parent == Character then
			task.spawn(TeleportToEndzones)
			WasInHand = false
			Connection:Disconnect()
		elseif Football.Parent == nil then
			Connection:Disconnect()
		end
	end)

	LocalPlayer.CharacterRemoving:Once(function()
		if Connection then
			Connection:Disconnect()
		end
	end)
end

-- [[ Connections ]] --

workspace.Games.DescendantAdded:Connect(function(Descendant)
	if Descendant.Name == "Football" then
		AttemptToCatch(Descendant)
	end
end)

workspace.DescendantRemoving:Connect(function(Descendant)
	local IsModelAncestor = Descendant:FindFirstAncestorOfClass("Model")
	if IsModelAncestor and table.find(Whitelist, IsModelAncestor.Name) then
		WasInHand = true
	end
	
	if #Players:GetPlayers() <= 5 then
		FindNewServer()
	end
end)

TeleportService.TeleportInitFailed:Connect(function(Player)
	if Player == LocalPlayer then
		TeleportInProgress = false
		FindNewServer()
	end
end)

LocalPlayer.CharacterAdded:Connect(function()
	Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
end)

print("[✨] Script Started.")
