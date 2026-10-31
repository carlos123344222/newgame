-- Trailer cinematic. Active only when workspace attribute TrailerMode = true.
-- Press T to start (or TrailerAuto = true starts it after 2 s). Works in 9:16 (TikTok) and 16:9.
if not workspace:GetAttribute("TrailerMode") then return end

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local Lighting=game:GetService("Lighting")
local UIS=game:GetService("UserInputService")
local StarterGui=game:GetService("StarterGui")
local SoundService=game:GetService("SoundService")
local RS=game:GetService("ReplicatedStorage")

local plr=Players.LocalPlayer
local cam=workspace.CurrentCamera
local SET=workspace:WaitForChild("TrailerSet")
local O=Vector3.new(4000,0,0)
local V=Vector3.new
local SCARES=RS.Assets.Scares
local SOUNDS=RS.Assets.Sounds
local WALK,RUN,IDLE,FALL="507777826","507767714","507766388","507767968"

-- UI
local ui=Instance.new("ScreenGui") ui.Name="TrailerUI" ui.IgnoreGuiInset=true ui.DisplayOrder=1000 ui.ResetOnSpawn=false ui.Parent=plr.PlayerGui
local black=Instance.new("Frame") black.Size=UDim2.fromScale(1,1) black.BackgroundColor3=Color3.new(0,0,0) black.ZIndex=50 black.Parent=ui
local flash=Instance.new("Frame") flash.Size=UDim2.fromScale(1,1) flash.BackgroundColor3=Color3.new(1,1,1) flash.BackgroundTransparency=1 flash.ZIndex=40 flash.Parent=ui

local function hideOthers()
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,false) end)
	for _,g in ipairs(plr.PlayerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g~=ui then g.Enabled=false end
	end
	for _,s in ipairs(game:GetDescendants()) do
		if s:IsA("Sound") and s.Playing and not s:GetAttribute("Trailer") then pcall(function() s:Stop() end) end
	end
end
hideOthers()
task.spawn(function() while true do task.wait(0.4) hideOthers() end end)

local function tw(o,t,p,st,dir) local x=TweenService:Create(o,TweenInfo.new(t,st or Enum.EasingStyle.Quad,dir or Enum.EasingDirection.Out),p) x:Play() return x end
local function sfx(name,vol,pitch)
	local s=SOUNDS:FindFirstChild(name) if not s then return end
	s=s:Clone() s:SetAttribute("Trailer",true) s.Volume=vol or 1 s.PlaybackSpeed=pitch or 1 s.Looped=false s.Parent=SoundService s:Play()
	task.delay(12,function() s:Destroy() end) return s
end
local function S() local v=cam.ViewportSize return math.min(v.X,v.Y) end
local portrait=function() return cam.ViewportSize.Y>cam.ViewportSize.X end

-- camera rig
local camV=Instance.new("CFrameValue") local fovV=Instance.new("NumberValue") fovV.Value=60
local shake=0
RunService:BindToRenderStep("Trailer",Enum.RenderPriority.Last.Value+50,function(dt)
	cam.CameraType=Enum.CameraType.Scriptable
	local off=CFrame.new()
	if shake>0 then
		off=CFrame.Angles(math.rad((math.random()-.5)*shake),math.rad((math.random()-.5)*shake),math.rad((math.random()-.5)*shake*.5))
		shake=math.max(0,shake-dt*14)
	end
	cam.CFrame=camV.Value*off
	cam.FieldOfView=fovV.Value*(portrait() and 1 or 0.7)
end)
local function cut(from,look,fov) camV.Value=CFrame.lookAt(from,look) if fov then fovV.Value=fov end end
local function move(from,look,t,fov,st) tw(camV,t,{Value=CFrame.lookAt(from,look)},st or Enum.EasingStyle.Sine,Enum.EasingDirection.InOut) if fov then tw(fovV,t,{Value=fov},Enum.EasingStyle.Sine) end end
local function punch(f,t) local base=fovV.Value fovV.Value=base*f tw(fovV,t or .35,{Value=base},Enum.EasingStyle.Back) end
local function doFlash(a,t) flash.BackgroundTransparency=a or 0 tw(flash,t or .3,{BackgroundTransparency=1}) end

-- look
local cc=Instance.new("ColorCorrectionEffect") cc.Name="TrailerCC" cc.TintColor=Color3.fromRGB(245,228,255) cc.Saturation=.25 cc.Contrast=.1 cc.Brightness=.08 cc.Parent=Lighting
local bloom=Instance.new("BloomEffect") bloom.Intensity=.45 bloom.Size=24 bloom.Threshold=1.4 bloom.Parent=Lighting
Lighting.ClockTime=0
Lighting.Ambient=Color3.fromRGB(125,95,160) Lighting.OutdoorAmbient=Color3.fromRGB(150,115,190) Lighting.ExposureCompensation=.25 Lighting.Brightness=2
for _,e in ipairs(Lighting:GetChildren()) do if e:IsA("PostEffect") and e~=cc and e~=bloom then e.Enabled=false end end
local atm=Lighting:FindFirstChildOfClass("Atmosphere")
if atm then atm.Density=.32 atm.Color=Color3.fromRGB(120,70,170) atm.Decay=Color3.fromRGB(60,30,100) atm.Glare=0 atm.Haze=1.5 end
local dof=Lighting:FindFirstChildOfClass("DepthOfFieldEffect") if dof then dof.Enabled=false end
for _,p in ipairs({V(-16,22,48),V(16,22,48),V(0,16,85)}) do
	local a=Instance.new("Part") a.Anchored=true a.CanCollide=false a.Transparency=1 a.Size=V(1,1,1) a.Position=O+p a.Parent=SET
	local l=Instance.new("PointLight") l.Color=Color3.fromRGB(190,110,255) l.Range=40 l.Brightness=.5 l.Parent=a
end

-- model helpers
local offs={}
local function off(m) if not offs[m] then local cf,s=m:GetBoundingBox() offs[m]=m:GetPivot().Y-(cf.Y-s.Y/2) end return offs[m] end
local function place(m,pos,look,scale)
	scale=scale or 1
	local o=off(m)
	if scale~=1 or m:GetScale()~=1 then m:ScaleTo(scale) end
	m:PivotTo((CFrame.lookAt(pos,V(look.X,pos.Y,look.Z))+V(0,o*scale,0))*(m:GetAttribute("Flip") and CFrame.Angles(0,math.pi,0) or CFrame.new()))
end
local function scare(name) local m=SCARES[name]:Clone() for _,d in ipairs(m:GetDescendants()) do if d:IsA("BaseScript") then d:Destroy() elseif d:IsA("BasePart") then d.Anchored=true d.CanCollide=false end end m:PivotTo(CFrame.new(0,-500,0)) m.Parent=SET off(m) return m end
local function hl(m,col) local h=Instance.new("Highlight") h.FillTransparency=1 h.OutlineColor=col or Color3.fromRGB(255,150,40) h.OutlineTransparency=1 h.Parent=m tw(h,.15,{OutlineTransparency=0}) task.delay(1,function() tw(h,.3,{OutlineTransparency=1}) end) end
local function pop(m,pos,look,scale,t)
	scale=scale or 1 t=t or .22
	local t0=os.clock()
	place(m,pos,look,.05*scale)
	hl(m)
	task.spawn(function()
		while true do
			local a=math.min(1,(os.clock()-t0)/t)
			local s=1+2.7*(a-1)^3+1.7*(a-1)^2 -- back-out
			place(m,pos,look,math.max(.05,s)*scale)
			if a>=1 then break end
			RunService.RenderStepped:Wait()
		end
	end)
end
local function hide(m) m:PivotTo(CFrame.new(0,-500,0)) end

-- visitors
local bots=SET.Bots:GetChildren()
table.sort(bots,function(a,b) return a.Name<b.Name end)
local shirts={Color3.fromRGB(40,90,220),Color3.fromRGB(220,60,60),Color3.fromRGB(60,170,80),Color3.fromRGB(240,170,40),Color3.fromRGB(150,70,220)}
for i,b in ipairs(bots) do
	local bc=b:FindFirstChildOfClass("BodyColors")
	if bc then bc.HeadColor3=Color3.fromRGB(245,205,48) bc.LeftArmColor3=bc.HeadColor3 bc.RightArmColor3=bc.HeadColor3 bc.TorsoColor3=shirts[i] bc.LeftLegColor3=Color3.fromRGB(40,40,50) bc.RightLegColor3=bc.LeftLegColor3 end
end
local tracks={}
local function anim(b,id,speed)
	local h=b:FindFirstChildOfClass("Humanoid")
	local a=h:FindFirstChildOfClass("Animator") or Instance.new("Animator",h)
	if tracks[b] then tracks[b]:Stop(.1) end
	local an=Instance.new("Animation") an.AnimationId="rbxassetid://"..id
	local tr=a:LoadAnimation(an) tr.Looped=true tr:Play(.1) tr:AdjustSpeed(speed or 1) tracks[b]=tr
end
local movers={}
local function goTo(b,from,to,t,id,speed)
	if movers[b] then movers[b]:Cancel() end
	local o=off(b)
	local cv=Instance.new("CFrameValue") cv.Value=CFrame.lookAt(from,V(to.X,from.Y,to.Z))+V(0,o,0)
	b:PivotTo(cv.Value) cv.Changed:Connect(function(v) b:PivotTo(v) end)
	anim(b,id or WALK,speed)
	if t>0 then movers[b]=tw(cv,t,{Value=CFrame.lookAt(to,to+(to-from).Unit)+V(0,o,0)},Enum.EasingStyle.Linear) end
end
local function stand(b,pos,look) goTo(b,pos,look,0,IDLE) end
local function emote(b,txt)
	local bb=Instance.new("BillboardGui") bb.Size=UDim2.fromScale(4,4) bb.StudsOffset=V(0,3.2,0) bb.AlwaysOnTop=true bb.Adornee=b:FindFirstChild("Head") bb.Parent=ui
	local l=Instance.new("TextLabel") l.BackgroundTransparency=1 l.Size=UDim2.fromScale(1,1) l.TextScaled=true l.Text=txt l.Parent=bb
	local sc=Instance.new("UIScale") sc.Scale=0 sc.Parent=l tw(sc,.2,{Scale=1},Enum.EasingStyle.Back)
	task.delay(.9,function() tw(sc,.15,{Scale=0}) task.wait(.2) bb:Destroy() end)
end
local function fright(b,away)
	local p=b:GetPivot().Position-V(0,off(b),0)
	local to=p+away.Unit*9
	goTo(b,p,to,.9,RUN,1.6)
	emote(b,"😱")
end

-- HUD: currency counters + rewards
local function stroke(o,th,col) local s=Instance.new("UIStroke") s.Thickness=th s.Color=col or Color3.fromRGB(25,10,40) s.LineJoinMode=Enum.LineJoinMode.Round s.Parent=o return s end
local function grad(o,a,b) local g=Instance.new("UIGradient") g.Color=ColorSequence.new(a,b) g.Rotation=90 g.Parent=o return g end
local hud=Instance.new("Frame") hud.BackgroundTransparency=1 hud.Size=UDim2.fromScale(1,1) hud.Visible=false hud.Parent=ui
local counters={}
local function counter(icon,x,col)
	local f=Instance.new("Frame") f.AnchorPoint=Vector2.new(.5,.5) f.Position=UDim2.fromScale(x,.13) f.Size=UDim2.fromScale(.34,.055) f.BackgroundColor3=Color3.fromRGB(30,14,50) f.BackgroundTransparency=.15 f.Parent=hud
	local ar=Instance.new("UIAspectRatioConstraint") ar.AspectRatio=3.6 ar.Parent=f
	Instance.new("UICorner",f).CornerRadius=UDim.new(1,0) stroke(f,3,col)
	local i=Instance.new("TextLabel") i.BackgroundTransparency=1 i.Size=UDim2.fromScale(.32,1.15) i.Position=UDim2.fromScale(-.06,-.08) i.TextScaled=true i.Text=icon i.Parent=f
	local t=Instance.new("TextLabel") t.BackgroundTransparency=1 t.Size=UDim2.fromScale(.66,.8) t.Position=UDim2.fromScale(.3,.1) t.TextScaled=true t.Font=Enum.Font.FredokaOne t.TextColor3=Color3.new(1,1,1) t.Text="0" t.Parent=f stroke(t,2)
	local sc=Instance.new("UIScale") sc.Parent=f
	counters[icon]={f=f,t=t,v=0,sc=sc}
end
counter("💰",.28,Color3.fromRGB(255,190,40)) counter("💎",.72,Color3.fromRGB(80,220,255))
local function addTo(icon,n)
	local c=counters[icon] local from=c.v c.v+=n
	c.sc.Scale=1.18 tw(c.sc,.25,{Scale=1},Enum.EasingStyle.Back)
	local nv=Instance.new("NumberValue") nv.Value=from nv.Changed:Connect(function(v) c.t.Text=tostring(math.floor(v)):reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","") end)
	tw(nv,.35,{Value=c.v})
end
local function burst(worldPos,icon,amount,count)
	local p=cam:WorldToViewportPoint(worldPos) local s=S()
	local tgt=counters[icon].f
	local plus=Instance.new("TextLabel") plus.BackgroundTransparency=1 plus.AnchorPoint=Vector2.new(.5,.5) plus.Position=UDim2.fromOffset(p.X,p.Y-s*.08) plus.Size=UDim2.fromOffset(s*.5,s*.13) plus.TextScaled=true plus.Font=Enum.Font.FredokaOne plus.Text="+"..amount.." "..icon plus.TextColor3=Color3.new(1,1,1) plus.ZIndex=5 plus.Parent=ui stroke(plus,4)
	grad(plus,icon=="💎" and Color3.fromRGB(150,240,255) or Color3.fromRGB(255,240,120),icon=="💎" and Color3.fromRGB(60,140,255) or Color3.fromRGB(255,150,20))
	local ps=Instance.new("UIScale") ps.Scale=0 ps.Parent=plus tw(ps,.25,{Scale=1},Enum.EasingStyle.Back) tw(plus,.9,{Position=UDim2.fromOffset(p.X,p.Y-s*.22)})
	task.delay(.75,function() tw(plus,.2,{TextTransparency=1}) for _,d in ipairs(plus:GetChildren()) do if d:IsA("UIStroke") then tw(d,.2,{Transparency=1}) end end task.wait(.25) plus:Destroy() end)
	for i=1,count or 9 do
		local l=Instance.new("TextLabel") l.BackgroundTransparency=1 l.AnchorPoint=Vector2.new(.5,.5) l.Text=icon l.TextScaled=true l.ZIndex=4
		l.Size=UDim2.fromOffset(s*.075,s*.075) l.Position=UDim2.fromOffset(p.X,p.Y) l.Rotation=math.random(-30,30) l.Parent=ui
		local a=math.random()*math.pi*2 local r=s*(.07+math.random()*.12)
		tw(l,.3,{Position=UDim2.fromOffset(p.X+math.cos(a)*r,p.Y+math.sin(a)*r*.8)},Enum.EasingStyle.Back)
		task.delay(.3+i*.035,function()
			local c=tgt.AbsolutePosition+tgt.AbsoluteSize/2+V(0,0,0).Magnitude*Vector2.zero
			tw(l,.35,{Position=UDim2.fromOffset(c.X,c.Y),Size=UDim2.fromOffset(s*.04,s*.04)},Enum.EasingStyle.Quad,Enum.EasingDirection.In)
			task.wait(.35) l:Destroy() addTo(icon,amount/(count or 9)) sfx("Coin",.35,1+i*.04)
		end)
	end
end

-- titles
local function title(txt,y,h,c1,c2,dur,rot,font)
	local l=Instance.new("TextLabel") l.BackgroundTransparency=1 l.AnchorPoint=Vector2.new(.5,.5) l.Position=UDim2.fromScale(.5,y)
	l.Size=UDim2.fromScale(.92,h) l.TextScaled=true l.Font=font or Enum.Font.FredokaOne l.Text=txt l.TextColor3=Color3.new(1,1,1) l.Rotation=rot or 0 l.ZIndex=10 l.Parent=ui
	stroke(l,math.max(3,S()*.009)) grad(l,c1 or Color3.fromRGB(255,235,120),c2 or Color3.fromRGB(255,120,20))
	local sc=Instance.new("UIScale") sc.Scale=0 sc.Parent=l tw(sc,.28,{Scale=1},Enum.EasingStyle.Back)
	if dur then task.delay(dur,function() tw(sc,.15,{Scale=0},Enum.EasingStyle.Back,Enum.EasingDirection.In) task.wait(.2) l:Destroy() end) end
	return l,sc
end
local function subtitle(txt,y,dur) return title(txt,y,.045,Color3.new(1,1,1),Color3.fromRGB(220,200,255),dur) end

-- letterbox for 16:9
local bars={}
for i=0,1 do local b=Instance.new("Frame") b.BackgroundColor3=Color3.new(0,0,0) b.BorderSizePixel=0 b.Size=UDim2.fromScale(1,.075) b.AnchorPoint=Vector2.new(0,i) b.Position=UDim2.fromScale(0,i) b.ZIndex=30 b.Parent=ui bars[#bars+1]=b end
RunService.RenderStepped:Connect(function() for _,b in ipairs(bars) do b.Visible=not portrait() end end)

-- cast
local frank,skel,demon,vamp,phead,king,parca=scare("Frankenstein"),scare("Esqueleto"),scare("Demonio"),scare("Vampiro"),scare("HombreCalabaza"),scare("ReyCalabaza"),scare("Parca")
local ghosts={scare("Fantasma"),scare("FantasmaEcto")}
local V1,V2,V3,V4,V5=bots[1],bots[2],bots[3],bots[4],bots[5]
for _,b in ipairs(bots) do b:PivotTo(CFrame.new(0,-500,0)) end

-- mythic look
local function molten(b)
	for _,d in ipairs(b:GetDescendants()) do if d:IsA("BasePart") and d.Name~="HumanoidRootPart" then d.Material=Enum.Material.CrackedLava d.Color=Color3.fromRGB(255,110,30) end end
	local t=b:FindFirstChild("UpperTorso")
	local f=Instance.new("Fire") f.Size=4 f.Heat=6 f.Color=Color3.fromRGB(255,120,30) f.SecondaryColor=Color3.fromRGB(255,220,80) f.Parent=t
	local l=Instance.new("PointLight") l.Color=Color3.fromRGB(255,140,40) l.Range=18 l.Brightness=4 l.Parent=t
	local h=Instance.new("Highlight") h.FillTransparency=.75 h.FillColor=Color3.fromRGB(255,120,20) h.OutlineColor=Color3.fromRGB(255,220,90) h.Parent=b
end
molten(V5)

-- floating ghosts
task.spawn(function()
	local t0=os.clock()
	while true do
		local t=os.clock()-t0
		place(ghosts[1],O+V(17,14+math.sin(t*2)*1.2,32),O+V(0,14,80),1.2)
		place(ghosts[2],O+V(-19,18+math.sin(t*2+2)*1.2,26),O+V(0,18,80),1.2)
		RunService.RenderStepped:Wait()
	end
end)

-- TD rig

local wps={} for _,v in ipairs(SET:GetAttribute("Path"):split(";")) do local x,y,z=v:match("([^,]+),([^,]+),([^,]+)") wps[#wps+1]=V(tonumber(x),tonumber(y),tonumber(z)) end
local cum={0} for i=2,#wps do cum[i]=cum[i-1]+(wps[i]-wps[i-1]).Magnitude end
local function along(d) d=math.clamp(d,0,cum[#cum]) for i=2,#wps do if cum[i]>=d then local a=(d-cum[i-1])/(cum[i]-cum[i-1]) return wps[i-1]:Lerp(wps[i],a),(wps[i]-wps[i-1]).Unit end end return wps[#wps],V(0,0,-1) end
local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Include rp.FilterDescendantsInstances={SET.TD}
local function groundY(p) local r=workspace:Raycast(p+V(0,30,0),V(0,-80,0),rp) return r and r.Position or p-V(0,9.5,0) end

-- ============ SEQUENCE ============
local function run()
	tw(black,.35,{BackgroundTransparency=1})
	sfx("Title",.8) sfx("Wind",.5)
	-- 1. Intro (0 - 2.4)
	cut(O+V(7,4,135),O+V(0,16,15),62)
	move(O+V(2.5,6,64),O+V(0,11,15),2.4,58)
	goTo(V1,O+V(-1,0,72),O+V(-1,0,46),2.4,WALK,1.1)
	goTo(V2,O+V(2,0,74),O+V(2,0,50),3,WALK)
	goTo(V3,O+V(-2.5,0,84),O+V(-2.5,0,60),3,WALK)
	task.wait(.25) title("THEY CAME FOR CANDY...",.3,.07,nil,nil,1.9)
	task.wait(2.15)
	-- 2. First scare at the door (2.4 - 4.2)
	stand(V1,O+V(-1,0,46),O+V(-1,0,20))
	cut(O+V(9,4.5,55),O+V(-2.5,5,42),56)
	move(O+V(7.5,4.6,52.5),O+V(-2.5,5,42),1.8,52)
	sfx("Knock",1) task.wait(.45)
	pop(frank,O+V(-5.5,0,42),O+V(-1,0,46))
	sfx("Scream",1) sfx("Boom",.6) doFlash(.2,.25) shake=9 punch(.78)
	fright(V1,V(.3,0,1))
	title("MAKE THEM",.27,.085,nil,nil,1.25,-4)
	task.wait(.12) title("SCREAM!",.36,.12,Color3.fromRGB(255,120,120),Color3.fromRGB(200,20,40),1.15,3)
	task.wait(.2) burst(V1:GetPivot().Position+V(0,2,0),"💰",250)
	hud.Visible=true
	task.wait(1.03)
	hide(frank)
	-- 3. Rapid combo (4.2 - 8.0)
	local combo={
		{skel,V2,V(18,0,55),"💰",300,"Scream2","x2 COMBO!"},
		{demon,V3,V(-20,0,64),"💎",15,"Growl","x3 COMBO!"},
		{vamp,V4,V(22,0,82),"💰",600,"Laugh","x4 COMBO!!"},
		{phead,V1,V(-16,0,92),"💎",40,"Scream","MEGA SCARE!!!"},
	}
	for i,c in ipairs(combo) do
		local m,b,p,icon,amt,snd,txt=table.unpack(c)
		local pos=O+p local fwd=V(0,0,-1)
		local side=(p.X>0) and 1 or -1
		goTo(b,pos+V(0,0,3),pos,1,WALK,.8)
		cut(pos+V(7*side,3.6,7),pos+V(-1.5*side,3.2,-1.5),54)
		move(pos+V(5.5*side,3.8,5.5),pos+V(-1.5*side,3.2,-1.5),.95,50)
		task.wait(.22)
		pop(m,pos+V(-4.2*side,0,-3.2),pos)
		sfx(snd,1,1+i*.03) sfx("Boom",.5) doFlash(.35,.2) shake=7 punch(.8,.3)
		fright(b,V(side*.6,0,1))
		title(txt,.27,.075,Color3.fromRGB(255,255,255),Color3.fromRGB(255,170,40),.65,(i%2==0) and 4 or -4)
		task.wait(.06) burst(pos+V(0,2,0),icon,amt,7)
		task.wait(.67)
		hide(m)
	end
	-- 4. Mythic visitor (8.0 - 10.2)
	local mp=O+V(0,0,72)
	goTo(V5,mp+V(0,0,6),mp-V(0,0,4),2.2,WALK,.45)
	cut(mp+V(6,1.8,-7),mp+V(0,4,4),50)
	move(mp+V(-6,2.6,-6),mp+V(0,4,1),2.2,46)
	sfx("Sparkle",1) sfx("Deep",.7)
	title("MYTHIC VISITORS",.27,.08,Color3.fromRGB(255,240,140),Color3.fromRGB(255,110,20),1.9,-3)
	task.wait(.25) subtitle("SLOWER • RARER • 10x 💎",.36,1.6)
	task.wait(1.15)
	pop(parca,mp+V(-4,0,-6),mp)
	sfx("Wail",1) doFlash(.3,.2) shake=7
	emote(V5,"😱")
	task.wait(.1) burst(mp+V(0,4,0),"💎",250,12)
	task.wait(.7)
	hide(parca)
	-- 5. Pumpkin King (10.2 - 12.6)
	local kp=O+V(0,0,42)
	for _,b in ipairs(bots) do b:PivotTo(CFrame.new(0,-500,0)) end
	cut(kp+V(3,1.5,30),kp+V(0,12.5,0),58)
	move(kp+V(2,2,24),kp+V(0,12.5,0),2.4,55)
	tw(flash,.01,{BackgroundTransparency=1})
	task.wait(.2)
	sfx("Thunder",1) doFlash(0,.5) shake=6
	local t0=os.clock()
	task.spawn(function()
		while os.clock()-t0<.55 do local a=(os.clock()-t0)/.55 place(king,kp-V(0,(1-a)^2*14,0),kp+V(0,0,20),1.7) RunService.RenderStepped:Wait() end
		place(king,kp,kp+V(0,0,20),1.7)
	end)
	hl(king,Color3.fromRGB(255,170,40))
	task.wait(.55) sfx("Laugh",1,.8) shake=4
	title("UNLOCK",.22,.07,Color3.fromRGB(255,255,255),Color3.fromRGB(220,190,255),1.6)
	title("LEGENDARY SCARES",.3,.085,Color3.fromRGB(255,220,90),Color3.fromRGB(255,100,20),1.6,-2)
	task.wait(1.65)
	-- 6. Tower defense (12.6 - 16.4)
	sfx("TDMusic",.8)
	local enemies={}
	local kinds={"Zombie","ZombiePlaga","Momia","Zombie","ZombiePlaga","Momia","Zombie","ZombiePlaga"}
	for i,k in ipairs(kinds) do enemies[i]={m=scare(k),d=95+i*8,s=1.25} end
	local boss={m=scare("DragonInfernal"),d=20,s=1.9}
	table.insert(enemies,boss)
	local mid=along(cum[#cum]*.5)
	local towers={}
	for i,k in ipairs({"Bruja","Payaso","Espantapajaros"}) do
		local p,dir=along(130+i*55)
		local side=dir:Cross(V(0,1,0)).Unit*(i%2==0 and 9 or -9)
		local m=scare(k) local gp=groundY(p+side) place(m,gp,groundY(p)) towers[i]={m=m,p=gp+V(0,5,0)}
	end
	local tdOn=true
	task.spawn(function()
		while tdOn do
			local dt=RunService.RenderStepped:Wait()
			for _,e in ipairs(enemies) do
				e.d+=dt*(e==boss and 7 or 12)
				local p,dir=along(e.d)
				local g=groundY(p) + V(0,math.abs(math.sin(e.d*.6))*.5,0)
				place(e.m,g,g+dir,e.s)
			end
		end
	end)
	task.spawn(function()
		while tdOn do
			task.wait(.16)
			local t=towers[math.random(#towers)]
			local e=enemies[math.random(#enemies-1)]
			local tp=e.m:GetPivot().Position+V(0,2,0)
			local b=Instance.new("Part") b.Shape=Enum.PartType.Ball b.Size=V(1.4,1.4,1.4) b.Material=Enum.Material.Neon b.Color=Color3.fromRGB(190,90,255) b.Anchored=true b.CanCollide=false b.CastShadow=false b.Position=t.p b.Parent=SET
			tw(b,.22,{Position=tp},Enum.EasingStyle.Linear)
			task.delay(.22,function() tw(b,.18,{Size=V(5,5,5),Transparency=1}) task.wait(.2) b:Destroy() end)
		end
	end)
	local p1=along(150)
	cut(p1+V(-45,55,40),p1,58)
	move(p1+V(-18,40,10),p1+V(10,0,-10),1.9,55)
	title("TOWER DEFENSE",.27,.085,Color3.fromRGB(170,255,140),Color3.fromRGB(40,180,90),1.75,-3)
	task.wait(.25) subtitle("5 • 10 • 20 WAVES",.36,1.45)
	task.wait(1.65)
	local bp=boss.m:GetPivot().Position
	cut(bp+V(14,4,22),bp+V(0,10,0),62)
	task.spawn(function() local t1=os.clock() while os.clock()-t1<1.9 do local q=boss.m:GetPivot().Position camV.Value=camV.Value:Lerp(CFrame.lookAt(q+V(12,3.5,18),q+V(0,11,0)),.08) RunService.RenderStepped:Wait() end end)
	sfx("Boss",1) sfx("Growl",1,.7) shake=10 doFlash(.4,.3)
	title("BOSS WAVE!",.28,.1,Color3.fromRGB(255,140,140),Color3.fromRGB(190,0,20),1.7,3)
	task.wait(.6) shake=6 task.wait(.6) shake=6 task.wait(.6)
	tdOn=false
	-- 7. Logo (16.4 - 20)
	hud.Visible=false
	local line={{frank,-11,1},{skel,-7,1},{demon,7,1},{vamp,11,1},{phead,-3.5,1},{king,0,1.5}}
	for i,c in ipairs(line) do local z=(c[2]==0) and 34 or 38 place(c[1],O+V(c[2]*1.1,0,z-math.abs(c[2])*.2),O+V(0,0,90),c[3]) end
	doFlash(0,.45) sfx("Success",1) sfx("Thunder",.6)
	cut(O+V(0,5,82),O+V(0,13,28),60)
	move(O+V(0,6.5,64),O+V(0,12,28),3.2,58)
	local logo,ls=title("MAKE THEM\nSCREAM",.26,.2,Color3.fromRGB(255,225,80),Color3.fromRGB(255,95,10),nil,-3)
	logo.LineHeight=.85
	task.wait(.25) local pk=title("🎃",.13,.09,Color3.new(1,1,1),Color3.new(1,1,1),nil,10)
	task.wait(.15) title("[HALLOWEEN]",.39,.06,Color3.fromRGB(230,180,255),Color3.fromRGB(150,60,230),nil,2)
	task.wait(.5)
	local btn=Instance.new("TextLabel") btn.AnchorPoint=Vector2.new(.5,.5) btn.Position=UDim2.fromScale(.5,.74) btn.Size=UDim2.fromScale(.56,.08) btn.BackgroundColor3=Color3.fromRGB(70,220,90)
	btn.Font=Enum.Font.FredokaOne btn.TextScaled=true btn.Text="PLAY NOW!" btn.TextColor3=Color3.new(1,1,1) btn.ZIndex=12 btn.Parent=ui
	local ar=Instance.new("UIAspectRatioConstraint") ar.AspectRatio=4 ar.Parent=btn
	Instance.new("UICorner",btn).CornerRadius=UDim.new(.35,0) grad(btn,Color3.fromRGB(255,255,255),Color3.fromRGB(170,170,170))
	local pad=Instance.new("UIPadding") pad.PaddingTop=UDim.new(.14,0) pad.PaddingBottom=UDim.new(.14,0) pad.Parent=btn
	local bs=Instance.new("UIStroke") bs.Thickness=math.max(3,S()*.008) bs.Color=Color3.fromRGB(20,70,30) bs.ApplyStrokeMode=Enum.ApplyStrokeMode.Border bs.Parent=btn
	stroke(btn,math.max(2,S()*.005)).ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual
	local bsc=Instance.new("UIScale") bsc.Scale=0 bsc.Parent=btn tw(bsc,.3,{Scale=1},Enum.EasingStyle.Back) sfx("Pickup",1)
	task.spawn(function() while btn.Parent do task.wait(.45) tw(bsc,.22,{Scale=1.08},Enum.EasingStyle.Sine) task.wait(.22) tw(bsc,.22,{Scale=1},Enum.EasingStyle.Sine) end end)
	task.spawn(function() while logo.Parent do tw(ls,.6,{Scale=1.04},Enum.EasingStyle.Sine) task.wait(.6) tw(ls,.6,{Scale=1},Enum.EasingStyle.Sine) task.wait(.6) end end)
	task.wait(2.6)
	tw(black,.6,{BackgroundTransparency=0})
end

local started=false
local function start() if started then return end started=true task.spawn(run) end
UIS.InputBegan:Connect(function(i,gp) if i.KeyCode==Enum.KeyCode.T then start() end end)
if workspace:GetAttribute("TrailerAuto") then task.delay(2,start) end
