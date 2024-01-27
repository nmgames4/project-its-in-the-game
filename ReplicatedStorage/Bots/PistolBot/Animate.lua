wait(5)
function waitForChild(parent, childName)
	local child = parent:findFirstChild(childName)
	if child then return child end
	while true do
		child = parent.ChildAdded:wait()
		if child.Name==childName then return child end
	end
end

local Figure = script.Parent
local Torso = waitForChild(Figure, "Torso")
local RightHip = waitForChild(Torso, "Right Hip")
local LeftHip = waitForChild(Torso, "Left Hip")
local Neck = waitForChild(Torso, "Neck")
local Humanoid = waitForChild(Figure, "Humanoid")
local pose = "Standing"

local currentAnim = ""
local currentAnimTrack = nil
local currentAnimKeyframeHandler = nil
local oldAnimTrack = nil
local animTable = {}
local animNames = { 
	idle = 	{	
		{ id = "http://www.roblox.com/asset/?id=125750544", weight = 9 },
		{ id = "http://www.roblox.com/asset/?id=125750618", weight = 1 }
	},
	walk = 	{ 	
		{ id = "http://www.roblox.com/asset/?id=125749145", weight = 10 } 
	}, 
	run = 	{
		{ id = "run.xml", weight = 10 } 
	}, 
	jump = 	{
		{ id = "http://www.roblox.com/asset/?id=125750702", weight = 10 } 
	}, 
	fall = 	{
		{ id = "http://www.roblox.com/asset/?id=125750759", weight = 10 } 
	}, 
	climb = {
		{ id = "http://www.roblox.com/asset/?id=125750800", weight = 10 } 
	}, 
	toolnone = {
		{ id = "http://www.roblox.com/asset/?id=125750867", weight = 10 } 
	},
	toolslash = {
		{ id = "http://www.roblox.com/asset/?id=129967390", weight = 10 } 
		--				{ id = "slash.xml", weight = 10 } 
	},
	toollunge = {
		{ id = "http://www.roblox.com/asset/?id=129967478", weight = 10 } 
	},
	wave = {
		{ id = "http://www.roblox.com/asset/?id=128777973", weight = 10 } 
	},
	point = {
		{ id = "http://www.roblox.com/asset/?id=128853357", weight = 10 } 
	},
	dance = {
		{ id = "http://www.roblox.com/asset/?id=130018893", weight = 10 }, 
		{ id = "http://www.roblox.com/asset/?id=132546839", weight = 10 }, 
		{ id = "http://www.roblox.com/asset/?id=132546884", weight = 10 } 
	},
	laugh = {
		{ id = "http://www.roblox.com/asset/?id=129423131", weight = 10 } 
	},
	cheer = {
		{ id = "http://www.roblox.com/asset/?id=129423030", weight = 10 } 
	},
}

-- Existance in this list signifies that it is an emote, the value indicates If it is a looping emote
local emoteNames = { wave = false, point = false, dance = true, laugh = false, cheer = false}
	
math.randomseed(tick())
	
-- Setup animation objects
for name, fileList in pairs(animNames) do 
	animTable[name] = {}
	animTable[name].count = 0
	animTable[name].totalWeight = 0
		
	-- check for config values
	local config = script:FindFirstChild(name)
	if (config ~= nil) then
		--		print("Loading anims " .. name)
		local idx = 1
		for _, childPart in pairs(config:GetChildren()) do
			animTable[name][idx] = {}
			animTable[name][idx].anim = childPart
			local weightObject = childPart:FindFirstChild("Weight")
			if (weightObject == nil) then
				animTable[name][idx].weight = 1
			else
				animTable[name][idx].weight = weightObject.Value
			end
			animTable[name].count = animTable[name].count + 1
			animTable[name].totalWeight = animTable[name].totalWeight + animTable[name][idx].weight
			--			print(name .. " [" .. idx .. "] " .. animTable[name][idx].anim.AnimationId .. " (" .. animTable[name][idx].weight .. ")")
			idx = idx + 1
		end
	end
		
	-- fallback to defaults
	if (animTable[name].count <= 0) then
		for idx, anim in pairs(fileList) do
			animTable[name][idx] = {}
			animTable[name][idx].anim = Instance.new("Animation")
			animTable[name][idx].anim.Name = name
			animTable[name][idx].anim.AnimationId = anim.id
			animTable[name][idx].weight = anim.weight
			animTable[name].count = animTable[name].count + 1
			animTable[name].totalWeight = animTable[name].totalWeight + anim.weight
			--			print(name .. " [" .. idx .. "] " .. anim.id .. " (" .. anim.weight .. ")")
		end
	end
end
	
-- ANIMATION
	
-- declarations
local toolAnim = "None"
local toolAnimTime = 0
	
local jumpAnimTime = 0
local jumpAnimDuration = 0.175
	
local toolTransitionTime = 0.1
local fallTransitionTime = 0.2
local jumpMaxLimbVelocity = 0.75
	
-- functions
	
function stopAllAnimations()
	local oldAnim = currentAnim
		
	-- return to idle If finishing an emote
	if (emoteNames[oldAnim] ~= nil and emoteNames[oldAnim] == false) then
		oldAnim = "idle"
	end
		
	currentAnim = ""
	if (currentAnimKeyframeHandler ~= nil) then
		currentAnimKeyframeHandler:disconnect()
	end
		
	if (oldAnimTrack ~= nil) then
		oldAnimTrack:Stop()
		oldAnimTrack:Destroy()
		oldAnimTrack = nil
	end
	if (currentAnimTrack ~= nil) then
		currentAnimTrack:Stop()
		currentAnimTrack:Destroy()
		currentAnimTrack = nil
	end
	return oldAnim
end
	
function keyFrameReachedFunc(frameName)
	if (frameName == "End") then
		--		print("Keyframe : ".. frameName)
		local repeatAnim = stopAllAnimations()
		playAnimation(repeatAnim, 0.0, Humanoid)
	end
end
	
-- Preload animations
function playAnimation(animName, transitionTime, humanoid)
	if (animName ~= currentAnim) then		 
			
		if (oldAnimTrack ~= nil) then
			oldAnimTrack:Stop()
			oldAnimTrack:Destroy()
		end
			
		local roll = math.random(1, animTable[animName].totalWeight) 
		local origRoll = roll
		local idx = 1
		while (roll > animTable[animName][idx].weight) do
			roll = roll - animTable[animName][idx].weight
			idx = idx + 1
		end
		--		print(animName .. " " .. idx .. " [" .. origRoll .. "]")
		local anim = animTable[animName][idx].anim
			
		-- load it to the humanoid; get AnimationTrack
		oldAnimTrack = currentAnimTrack
		currentAnimTrack = humanoid:LoadAnimation(anim)
		 
		-- play the animation
		currentAnimTrack:Play(transitionTime)
		currentAnim = animName
			
		-- set up keyframe name triggers
		if (currentAnimKeyframeHandler ~= nil) then
			currentAnimKeyframeHandler:disconnect()
		end
		currentAnimKeyframeHandler = currentAnimTrack.KeyframeReached:connect(keyFrameReachedFunc)
	end
end
	
-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------
	
local toolAnimName = ""
local toolOldAnimTrack = nil
local toolAnimTrack = nil
local currentToolAnimKeyframeHandler = nil
	
function toolKeyFrameReachedFunc(frameName)
	if (frameName == "End") then
		--		print("Keyframe : ".. frameName)
		local repeatAnim = stopToolAnimations()
		playToolAnimation(repeatAnim, 0.0, Humanoid)
	end
end
	
	
function playToolAnimation(animName, transitionTime, humanoid)
	if (animName ~= toolAnimName) then		 
			
		if (toolAnimTrack ~= nil) then
			toolAnimTrack:Stop()
			toolAnimTrack:Destroy()
			transitionTime = 0
		end
			
		local roll = math.random(1, animTable[animName].totalWeight) 
		local origRoll = roll
		local idx = 1
		while (roll > animTable[animName][idx].weight) do
			roll = roll - animTable[animName][idx].weight
			idx = idx + 1
		end
		--		print(animName .. " * " .. idx .. " [" .. origRoll .. "]")
		local anim = animTable[animName][idx].anim
			
		-- load it to the humanoid; get AnimationTrack
		toolOldAnimTrack = toolAnimTrack
		toolAnimTrack = humanoid:LoadAnimation(anim)
		 
		-- play the animation
		toolAnimTrack:Play(transitionTime)
		toolAnimName = animName
			
		currentToolAnimKeyframeHandler = toolAnimTrack.KeyframeReached:connect(toolKeyFrameReachedFunc)
	end
end
	
function stopToolAnimations()
	local oldAnim = toolAnimName
		
	if (currentToolAnimKeyframeHandler ~= nil) then
		currentToolAnimKeyframeHandler:disconnect()
	end
		
	toolAnimName = ""
	if (toolAnimTrack ~= nil) then
		toolAnimTrack:Stop()
		toolAnimTrack:Destroy()
		toolAnimTrack = nil
	end
		
		
	return oldAnim
end
	
-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------
	
	
function onRunning(speed)
	if speed>0 then
		playAnimation("walk", 0.1, Humanoid)
		pose = "Running"
	else
		playAnimation("idle", 0.1, Humanoid)
		pose = "Standing"
	end
end
	
function onDied()
	pose = "Dead"
end
	
function onJumping()
	playAnimation("jump", 0.1, Humanoid)
	jumpAnimTime = jumpAnimDuration
	pose = "Jumping"
end
	
function onClimbing()
	playAnimation("climb", 0.1, Humanoid)
	pose = "Climbing"
end
	
function onGettingUp()
	pose = "GettingUp"
end
	
function onFreeFall()
	if (jumpAnimTime <= 0) then
		playAnimation("fall", fallTransitionTime, Humanoid)
	end
	pose = "FreeFall"
end
	
function onFallingDown()
	pose = "FallingDown"
end
	
function onSeated()
	pose = "Seated"
end
	
function onPlatformStanding()
	pose = "PlatformStanding"
end
	
function onSwimming(speed)
	if speed>0 then
		pose = "Running"
	else
		pose = "Standing"
	end
end
	
function getTool()	
	for _, kid in ipairs(Figure:GetChildren()) do
		if kid.className == "Tool" then return kid end
	end
	return nil
end
	
function getToolAnim(tool)
	for _, c in ipairs(tool:GetChildren()) do
		if c.Name == "toolanim" and c.className == "StringValue" then
			return c
		end
	end
	return nil
end
	
function animateTool()
		
	if (toolAnim == "None") then
		playToolAnimation("toolnone", toolTransitionTime, Humanoid)
		return
	end
		
	if (toolAnim == "Slash") then
		playToolAnimation("toolslash", 0, Humanoid)
		return
	end
		
	if (toolAnim == "Lunge") then
		playToolAnimation("toollunge", 0, Humanoid)
		return
	end
end
	
function moveSit()
	RightHip:SetDesiredAngle(3.14 /2)
	LeftHip:SetDesiredAngle(-3.14 /2)
end
	
local lastTick = 0
	
function move(time)
	local amplitude = 1
	local frequency = 1
	local deltaTime = time - lastTick
	lastTick = time
		
	local climbFudge = 0
	local setAngles = false
		
	if (jumpAnimTime > 0) then
		jumpAnimTime = jumpAnimTime - deltaTime
	end
		
	if (pose == "FreeFall" and jumpAnimTime <= 0) then
		playAnimation("fall", fallTransitionTime, Humanoid)
	elseif (pose == "Seated") then
		stopAllAnimations()
		moveSit()
		return
	elseif (pose == "Running") then
		playAnimation("walk", 0.1, Humanoid)
	elseif (pose == "Dead" or pose == "GettingUp" or pose == "FallingDown" or pose == "Seated" or pose == "PlatformStanding") then
		--		print("Wha " .. pose)
		amplitude = 0.1
		frequency = 1
		setAngles = true
	end
		
	if (setAngles) then
		desiredAngle = amplitude * math.sin(time * frequency)
			
		RightHip:SetDesiredAngle(-desiredAngle)
		LeftHip:SetDesiredAngle(-desiredAngle)
	end
		
	-- Tool Animation handling
	local tool = getTool()
	if tool then
			
		animStringValueObject = getToolAnim(tool)
			
		if animStringValueObject then
			toolAnim = animStringValueObject.Value
			-- message recieved, delete StringValue
			animStringValueObject.Parent = nil
			toolAnimTime = time + .3
		end
			
		if time > toolAnimTime then
			toolAnimTime = 0
			toolAnim = "None"
		end
			
		animateTool()		
	else
		stopToolAnimations()
		toolAnim = "None"
		toolAnimTime = 0
	end
end
	
-- connect events
Humanoid.Died:connect(onDied)
Humanoid.Running:connect(onRunning)
Humanoid.Jumping:connect(onJumping)
Humanoid.Climbing:connect(onClimbing)
Humanoid.GettingUp:connect(onGettingUp)
Humanoid.FreeFalling:connect(onFreeFall)
Humanoid.FallingDown:connect(onFallingDown)
Humanoid.Seated:connect(onSeated)
Humanoid.PlatformStanding:connect(onPlatformStanding)
Humanoid.Swimming:connect(onSwimming)
-- main program
	
local runService = game:service("RunService");
	
-- initialize to idle
playAnimation("idle", 0.1, Humanoid)
pose = "Standing"
	
while Figure.Parent~=nil do
	local _, time = wait(0.1)
	move(time)
end
