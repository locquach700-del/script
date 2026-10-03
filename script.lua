--[[ ═══════════════════════════════════════════════════════════════════════════════
   ⚔️  ANH HÙNG PHIÊU LƯU — RPG đánh quái · farm level · 6 bản đồ · boss · UI · VFX · SFX
   ▸ CHỈ 1 SCRIPT. Tạo LocalScript trong  StarterPlayer ▸ StarterPlayerScripts  rồi dán toàn bộ code này.
   ▸ (Studio Lite chỉ tạo được Script thường? Để trong ServerScriptService cũng chạy, code tự chuyển sang client.)
   ▸ PC:  Chuột trái / F = đánh · Z X C = kỹ năng · Q = bình máu · R = tự đánh · M = bản đồ · B = cửa hàng
   ▸ Mobile: dùng các nút tròn bên phải màn hình.   ▸ Muốn đổi âm thanh: sửa bảng SFX bên dưới.
═══════════════════════════════════════════════════════════════════════════════ ]]
local Players, RunService, TweenService = game:GetService("Players"), game:GetService("RunService"), game:GetService("TweenService")
local UIS, Lighting, Debris = game:GetService("UserInputService"), game:GetService("Lighting"), game:GetService("Debris")
local SoundService, StarterGui, RS = game:GetService("SoundService"), game:GetService("StarterGui"), game:GetService("ReplicatedStorage")
if RunService:IsServer() then -- lỡ đặt Script thường ở server → nhân bản thành script chạy phía client
	pcall(function() local c = script:Clone(); c.RunContext = Enum.RunContext.Client; c.Parent = RS end)
	return
end
if not game:IsLoaded() then game.Loaded:Wait() end
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local cam = workspace.CurrentCamera
local Terrain = workspace.Terrain
local V3, CF, C3, ANG, U2, MAT, PI = Vector3.new, CFrame.new, Color3.fromRGB, CFrame.Angles, UDim2.new, Enum.Material, math.pi
local PLASTIC = MAT.SmoothPlastic
local rng = Random.new()
local A = {} -- hành động khai báo ở phần sau (attack, skill, enterMap...)

----------------------------------------------------------------- TIỆN ÍCH
local function rnd(a, b) return a + (b - a) * rng:NextNumber() end
local function pick(t) return t[rng:NextInteger(1, #t)] end
local function new(class, props, parent)
	local o = Instance.new(class)
	if props then for k, v in pairs(props) do o[k] = v end end
	if parent then o.Parent = parent end
	return o
end
local function tw(o, t, goal, style, dir)
	local tween = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tween:Play()
	return tween
end
local function fmt(n)
	local r = tostring(math.floor(n + .5)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (r:gsub("^,", ""))
end
local function flat(v) return V3(v.X, 0, v.Z) end
local function dist2(a, b) local x, z = a.X - b.X, a.Z - b.Z; return math.sqrt(x * x + z * z) end
local function getChar() return player.Character end
local function getRoot() local c = player.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c = player.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function corner(o, r) return new("UICorner", {CornerRadius = UDim.new(0, r or 8)}, o) end
local function stroke(o, c, t, tr) return new("UIStroke", {Color = c, Thickness = t or 2, Transparency = tr or 0}, o) end
local function grad(o, c0, c1, rot) return new("UIGradient", {Color = ColorSequence.new(c0, c1), Rotation = rot or 90}, o) end
local function box(p, parent)
	p.BorderSizePixel = 0
	p.BackgroundColor3 = p.BackgroundColor3 or C3(20, 24, 46)
	return new("Frame", p, parent)
end
local function txt(p, parent)
	p.BackgroundTransparency = 1
	p.Font = p.Font or Enum.Font.GothamMedium
	p.TextColor3 = p.TextColor3 or C3(255, 255, 255)
	p.TextSize = p.TextSize or 14
	return new("TextLabel", p, parent)
end
local FX = new("Folder", {Name = "HeroFX"}, workspace)
local MOBS = new("Folder", {Name = "HeroMobs"}, workspace)
local FONTB = Enum.Font.GothamBlack

----------------------------------------------------------------- CẤU HÌNH + TRẠNG THÁI
local CFG = {R = 150, CAMP = 24, MAXLV = 99, SPEED = 20}
local S = {lv = 1, exp = 0, gold = 0, pots = 3, mpots = 1, wpn = 1, own = {true}, map = 0, sound = true, auto = false, held = false,
	dead = false, busy = false, combo = 0, lastAtk = 0, atkCD = 0, cd = {0, 0, 0}, potCD = 0, inv = 0, hp = 1, mp = 1, qs = {}}

----------------------------------------------------------------- ÂM THANH (dùng âm thanh có sẵn của Roblox, đổi cao độ để tạo nhiều hiệu ứng)
local SFXG = new("SoundGroup", {Name = "HeroSFX", Volume = 1}, SoundService)
local SFX = { -- {id, âm lượng, cao độ} → thay bằng "rbxassetid://ID_CỦA_BẠN" nếu muốn âm thanh khác
	slash = {"rbxasset://sounds/swordslash.wav", .7, 1.05}, lunge = {"rbxasset://sounds/swordlunge.wav", .8, 1},
	hit = {"rbxasset://sounds/action_jump_land.mp3", .9, 1.6}, crit = {"rbxasset://sounds/impact_explosion_03.mp3", .3, 2.4},
	hurt = {"rbxasset://sounds/uuhhh.mp3", .8, 1.25}, mdie = {"rbxasset://sounds/uuhhh.mp3", .8, .6},
	roar = {"rbxasset://sounds/uuhhh.mp3", 1, .38}, boom = {"rbxasset://sounds/impact_explosion_03.mp3", .8, 1},
	whoosh = {"rbxasset://sounds/impact_water.mp3", .5, 1.7}, potion = {"rbxasset://sounds/impact_water.mp3", .6, 1.15},
	equip = {"rbxasset://sounds/unsheath.wav", .9, 1}, ping = {"rbxasset://sounds/electronicpingshort.wav", .5, 1},
	coin = {"rbxasset://sounds/electronicpingshort.wav", .3, 2}, click = {"rbxasset://sounds/electronicpingshort.wav", .3, 1.5},
	deny = {"rbxasset://sounds/electronicpingshort.wav", .4, .55},
}
local function sfx(name, at, vol, pitch, exact)
	local d = SFX[name]
	if not d or not S.sound then return end
	local v, r = d[2] * (vol or 1), getRoot()
	if at and r then v = v * math.clamp(1 - (at - r.Position).Magnitude / 150, .06, 1) end
	local s = new("Sound", {SoundId = d[1], Volume = v, PlaybackSpeed = d[3] * (pitch or 1) * (exact and 1 or rnd(.94, 1.06)), SoundGroup = SFXG}, SoundService)
	s:Play()
	Debris:AddItem(s, 3)
end
local function seq(name, list, gap, vol) -- chuỗi nốt (level up, nhiệm vụ...)
	task.spawn(function() for _, p in ipairs(list) do sfx(name, nil, vol, p, true); task.wait(gap) end end)
end
local MUSIC = new("Sound", {Looped = true, Volume = .35, SoundGroup = SFXG}, SoundService)

----------------------------------------------------------------- DỮ LIỆU: THỜI TIẾT, BẢN ĐỒ, QUÁI, VŨ KHÍ, KỸ NĂNG
local WX = { -- hạt thời tiết bay quanh người chơi
	petal = {c = C3(255, 215, 235), sz = .5, rate = 14, life = 8, sp = 3, acc = V3(2, -1, 1), dir = "Bottom", h = 28},
	spore = {c = C3(150, 255, 190), sz = .45, rate = 12, life = 7, sp = 2, acc = V3(0, .6, 0), dir = "Top", h = 1},
	dust = {c = C3(235, 200, 150), sz = 1.4, rate = 16, life = 5, sp = 14, acc = V3(6, 0, 2), dir = "Bottom", h = 12, tr = .6},
	snow = {c = C3(255, 255, 255), sz = .4, rate = 70, life = 6, sp = 2, acc = V3(1.5, -4, 0), dir = "Bottom", h = 30},
	ember = {c = C3(255, 150, 60), sz = .4, rate = 30, life = 4, sp = 3, acc = V3(1, 7, 0), dir = "Top", h = 1},
	wisp = {c = C3(200, 130, 255), sz = .5, rate = 14, life = 6, sp = 2, acc = V3(0, 1.2, 0), dir = "Top", h = 1},
}
-- lit: t=giờ, amb/out=ánh sáng môi trường, br=độ sáng, fog=màu sương, dn=độ dày sương, hz=mờ chân trời, tint/sat=chỉnh màu
local MAPS = {
	{n = "Đồng Cỏ Xanh", ic = "🌿", lv = 1, col = C3(110, 220, 120), biome = "meadow", gnd = MAT.Grass, gnd2 = MAT.Ground, rim = MAT.Rock, cap = MAT.Grass, wx = "petal",
		mobs = {"slime", "shroom", "bee"}, boss = "kslime", music = "",
		lit = {t = 14, amb = C3(105, 115, 125), out = C3(150, 160, 170), br = 3, fog = C3(190, 220, 255), dn = .28, hz = .5, tint = C3(255, 250, 240), sat = .12},
		pal = {trunk = C3(110, 75, 45), leaf = {C3(90, 190, 90), C3(70, 165, 80), C3(120, 205, 90)}, rock = C3(140, 140, 145), mound = C3(150, 210, 110),
			acc = {C3(255, 120, 150), C3(255, 220, 90), C3(255, 255, 255), C3(150, 170, 255)}}},
	{n = "Rừng Ma Ám", ic = "🌲", lv = 10, col = C3(170, 130, 255), biome = "forest", gnd = MAT.Mud, gnd2 = MAT.LeafyGrass, rim = MAT.Slate, cap = MAT.Slate, wx = "spore",
		mobs = {"skel", "ghost", "spider"}, boss = "treant", music = "",
		lit = {t = 19.3, amb = C3(60, 55, 95), out = C3(95, 85, 135), br = 2, fog = C3(80, 60, 120), dn = .4, hz = 1.4, tint = C3(215, 200, 255), sat = -.05},
		pal = {trunk = C3(55, 40, 50), leaf = {C3(35, 90, 70), C3(45, 110, 85), C3(30, 75, 80)}, rock = C3(80, 80, 95), mound = C3(60, 50, 70),
			acc = {C3(120, 255, 200), C3(190, 140, 255), C3(120, 200, 255)}}},
	{n = "Sa Mạc Cháy", ic = "🏜️", lv = 20, col = C3(255, 200, 90), biome = "desert", gnd = MAT.Sand, gnd2 = MAT.Sandstone, rim = MAT.Sandstone, cap = MAT.Sand, wx = "dust",
		mobs = {"scorpion", "mummy", "cactus"}, boss = "pharaoh", music = "",
		lit = {t = 12.8, amb = C3(140, 120, 90), out = C3(190, 160, 120), br = 3.6, fog = C3(255, 220, 170), dn = .32, hz = 1.3, tint = C3(255, 236, 205), sat = .2},
		pal = {trunk = C3(120, 90, 60), leaf = {C3(80, 170, 90), C3(95, 185, 100)}, rock = C3(200, 150, 100), mound = C3(232, 196, 130), acc = {C3(255, 90, 110), C3(255, 210, 90)}}},
	{n = "Đỉnh Băng Giá", ic = "❄️", lv = 30, col = C3(130, 220, 255), biome = "ice", gnd = MAT.Snow, gnd2 = MAT.Ice, rim = MAT.Glacier, cap = MAT.Snow, wx = "snow",
		mobs = {"snowman", "wolf", "crystal"}, boss = "yeti", music = "",
		lit = {t = 10.5, amb = C3(115, 135, 165), out = C3(160, 185, 215), br = 3, fog = C3(205, 235, 255), dn = .4, hz = 1.1, tint = C3(225, 240, 255), sat = -.08},
		pal = {trunk = C3(80, 60, 50), leaf = {C3(50, 110, 100), C3(60, 130, 115)}, rock = C3(170, 200, 225), mound = C3(240, 248, 255),
			acc = {C3(120, 220, 255), C3(170, 240, 255), C3(200, 200, 255)}}},
	{n = "Núi Lửa Hỏa Ngục", ic = "🌋", lv = 40, col = C3(255, 120, 50), biome = "volcano", gnd = MAT.Basalt, gnd2 = MAT.CrackedLava, rim = MAT.Basalt, cap = MAT.Slate, wx = "ember",
		mobs = {"lavaslime", "imp", "golem"}, boss = "ifrit", music = "",
		lit = {t = 21.5, amb = C3(120, 55, 35), out = C3(150, 75, 50), br = 2.2, fog = C3(100, 35, 20), dn = .5, hz = 2, tint = C3(255, 190, 160), sat = .1},
		pal = {trunk = C3(40, 30, 30), leaf = {C3(90, 40, 30)}, rock = C3(45, 40, 45), mound = C3(70, 50, 50), acc = {C3(255, 110, 30), C3(255, 170, 50), C3(255, 70, 30)}}},
	{n = "Lâu Đài Bóng Đêm", ic = "🏰", lv = 50, col = C3(200, 110, 255), biome = "castle", gnd = MAT.Slate, gnd2 = MAT.Cobblestone, rim = MAT.Basalt, cap = MAT.Slate, wx = "wisp",
		mobs = {"knight", "bat", "demon"}, boss = "demonlord", music = "",
		lit = {t = 23.9, amb = C3(70, 60, 115), out = C3(95, 85, 150), br = 1.8, fog = C3(45, 25, 80), dn = .45, hz = 1.3, tint = C3(215, 195, 255), sat = .05},
		pal = {trunk = C3(40, 35, 50), leaf = {C3(60, 40, 90)}, rock = C3(70, 70, 90), mound = C3(60, 55, 80), acc = {C3(190, 90, 255), C3(255, 80, 120), C3(120, 120, 255)}}},
}
for i, m in ipairs(MAPS) do m.center = V3(1500 * i, 0, 0); m.gy = 0 end

-- t=mẫu mô hình · c/s/e=màu thân/da/mắt · sz|sc=kích thước · hp,dm=hệ số máu/sát thương · sp=tốc độ · boss
local MOB = {
	slime = {n = "Slime Xanh", lv = 1, t = "blob", c = C3(90, 220, 120), sz = 3.4, sp = 10},
	shroom = {n = "Nấm Độc", lv = 3, t = "blob", c = C3(240, 230, 200), cap = C3(215, 55, 80), sz = 3.3, sp = 11, hp = 1.1},
	bee = {n = "Ong Bầu", lv = 5, t = "float", k = "bee", sp = 16, hp = .8, dm = 1.2, hov = 3.2, fl = 26},
	kslime = {n = "Vua Slime", lv = 10, t = "blob", c = C3(80, 175, 255), crown = true, sz = 9, sp = 9, hp = 7, dm = 1.5, boss = true},
	skel = {n = "Xương Khô", lv = 10, t = "human", c = C3(52, 50, 64), s = C3(235, 228, 205), h = "skull", e = C3(90, 255, 220), rib = 1, lc = C3(235, 228, 205), ac = C3(235, 228, 205), wpn = {"sword", C3(150, 150, 165)}, sp = 12},
	ghost = {n = "Bóng Ma", lv = 13, t = "float", k = "ghost", sp = 13, hp = .9, hov = 3.4, fl = 0},
	spider = {n = "Nhện Độc", lv = 16, t = "crawl", k = "spider", c = C3(62, 42, 88), e = C3(255, 60, 90), g = C3(120, 255, 130), sp = 15, hp = 1.1, dm = 1.2},
	treant = {n = "Cổ Thụ Ma", lv = 20, t = "human", c = C3(105, 72, 44), s = C3(92, 64, 40), m = MAT.Wood, h = "round", e = C3(255, 225, 80), leaf = C3(70, 165, 75), aw = 1.35, sc = 2.4, sp = 9, hp = 8, dm = 1.5, boss = true},
	scorpion = {n = "Bọ Cạp Cát", lv = 20, t = "crawl", k = "scorpion", c = C3(228, 170, 90), sp = 14, dm = 1.2},
	mummy = {n = "Xác Ướp", lv = 23, t = "human", c = C3(226, 216, 186), m = MAT.Fabric, h = "round", e = C3(255, 90, 60), wrap = C3(196, 186, 156), sp = 9, hp = 1.3},
	cactus = {n = "Xương Rồng", lv = 26, t = "human", c = C3(72, 172, 92), h = "round", e = C3(25, 25, 30), spike = C3(255, 255, 225), flower = C3(255, 90, 140), sp = 11, dm = 1.1},
	pharaoh = {n = "Pharaoh Vàng", lv = 30, t = "human", c = C3(240, 192, 62), s = C3(232, 178, 52), m = MAT.Metal, h = "mask", e = C3(80, 200, 255), cape = C3(40, 90, 200), wpn = {"staff", C3(90, 220, 255)}, sc = 2.2, sp = 10, hp = 8, dm = 1.5, boss = true},
	snowman = {n = "Người Tuyết", lv = 30, t = "snow", c = C3(245, 250, 255), sz = 3, sp = 11},
	wolf = {n = "Sói Băng", lv = 33, t = "beast", c = C3(215, 230, 245), c2 = C3(150, 190, 230), e = C3(90, 230, 255), spk = C3(140, 230, 255), sp = 17, dm = 1.2},
	crystal = {n = "Tinh Thể Băng", lv = 36, t = "float", k = "crystal", sp = 12, hp = 1.2, hov = 3.4, fl = 0},
	yeti = {n = "Yeti Chúa", lv = 40, t = "human", c = C3(236, 242, 252), s = C3(150, 190, 240), m = MAT.Fabric, h = "round", e = C3(255, 90, 90), horn = C3(180, 235, 255), aw = 1.4, sc = 2.3, sp = 10, hp = 8, dm = 1.5, boss = true},
	lavaslime = {n = "Slime Dung Nham", lv = 40, t = "blob", c = C3(255, 110, 40), m = MAT.Neon, core = C3(60, 20, 10), fire = true, sz = 3.6, sp = 11, dm = 1.1},
	imp = {n = "Tiểu Quỷ Lửa", lv = 43, t = "human", c = C3(205, 55, 45), s = C3(228, 80, 60), h = "round", e = C3(255, 230, 80), horn = C3(60, 30, 30), tail = C3(205, 55, 45), fire = C3(255, 140, 40), sc = .85, sp = 16},
	golem = {n = "Golem Dung Nham", lv = 46, t = "human", c = C3(62, 56, 64), s = C3(56, 50, 58), m = MAT.Slate, h = "block", e = C3(255, 140, 40), crack = C3(255, 120, 30), aw = 1.5, sc = 1.5, sp = 9, hp = 2},
	ifrit = {n = "Ifrit Hỏa Vương", lv = 50, t = "human", c = C3(150, 30, 30), s = C3(190, 45, 35), h = "round", e = C3(255, 240, 120), horn = C3(40, 20, 20), fire = C3(255, 130, 30), wpn = {"sword", C3(255, 120, 40)}, aw = 1.3, sc = 2.5, sp = 11, hp = 9, dm = 1.6, boss = true},
	knight = {n = "Hiệp Sĩ Đen", lv = 50, t = "human", c = C3(38, 38, 52), s = C3(50, 50, 68), m = MAT.Metal, h = "helm", e = C3(190, 90, 255), cape = C3(100, 20, 60), wpn = {"sword", C3(170, 170, 205)}, sc = 1.1, sp = 12, hp = 1.3},
	bat = {n = "Dơi Ma", lv = 54, t = "float", k = "bat", sp = 18, hp = .8, dm = 1.2, hov = 4, fl = 14},
	demon = {n = "Quỷ Nhỏ", lv = 58, t = "human", c = C3(122, 62, 162), s = C3(150, 82, 190), h = "round", e = C3(120, 255, 120), horn = C3(40, 20, 60), wing = C3(70, 30, 100), tail = C3(122, 62, 162), sp = 14, dm = 1.2},
	demonlord = {n = "Ma Vương Bóng Đêm", lv = 65, t = "human", c = C3(32, 22, 48), s = C3(62, 32, 84), m = MAT.Metal, h = "round", e = C3(255, 60, 80), horn = C3(20, 10, 25), spk = C3(255, 80, 90), wing = C3(50, 20, 80), cape = C3(130, 10, 30), wpn = {"sword", C3(200, 60, 255)}, aw = 1.2, sc = 2.7, sp = 11, hp = 10, dm = 1.7, boss = true},
}
local WPN = {
	{n = "Kiếm Gỗ", atk = 0, price = 0, lv = 1, len = 3.4, wid = .7, bl = C3(176, 124, 74), gd = C3(96, 64, 44), gem = C3(255, 225, 130), tr = C3(255, 240, 200)},
	{n = "Kiếm Sắt", atk = 10, price = 250, lv = 3, len = 3.9, wid = .8, bl = C3(205, 212, 226), gd = C3(120, 124, 140), gem = C3(110, 200, 255), tr = C3(220, 235, 255)},
	{n = "Kiếm Rừng Xanh", atk = 30, price = 1400, lv = 10, len = 4.2, wid = .85, bl = C3(120, 215, 140), gl = C3(90, 255, 150), gd = C3(60, 95, 60), gem = C3(90, 255, 150), tr = C3(120, 255, 170)},
	{n = "Kiếm Hoàng Sa", atk = 65, price = 4500, lv = 20, len = 4.4, wid = .9, bl = C3(245, 205, 95), gl = C3(255, 220, 90), gd = C3(150, 100, 40), gem = C3(255, 90, 90), tr = C3(255, 220, 120)},
	{n = "Kiếm Băng Vĩnh Cửu", atk = 115, price = 12000, lv = 30, len = 4.7, wid = 1, bl = C3(170, 230, 255), gl = C3(120, 230, 255), gd = C3(90, 140, 190), gem = C3(200, 255, 255), tr = C3(140, 230, 255), aura = true},
	{n = "Kiếm Dung Nham", atk = 190, price = 30000, lv = 40, len = 5, wid = 1.05, bl = C3(70, 40, 40), gl = C3(255, 120, 40), gd = C3(50, 40, 45), gem = C3(255, 160, 50), tr = C3(255, 140, 50), aura = true},
	{n = "Kiếm Bóng Đêm", atk = 300, price = 65000, lv = 50, len = 5.2, wid = 1.1, bl = C3(50, 30, 80), gl = C3(190, 90, 255), gd = C3(30, 20, 50), gem = C3(255, 80, 150), tr = C3(190, 100, 255), aura = true},
	{n = "Thánh Kiếm Ánh Sáng", atk = 450, price = 150000, lv = 60, len = 5.6, wid = 1.2, bl = C3(255, 250, 225), gl = C3(255, 235, 150), gd = C3(240, 200, 90), gem = C3(120, 220, 255), tr = C3(255, 240, 170), aura = true},
}
local SK = {
	{n = "Chém Xoáy", ic = "🌀", key = "Z", cd = 4.5, mp = 12, lv = 1, col = C3(90, 200, 255)},
	{n = "Kiếm Khí", ic = "🌙", key = "X", cd = 7, mp = 18, lv = 5, col = C3(170, 125, 255)},
	{n = "Địa Chấn", ic = "💥", key = "C", cd = 12, mp = 32, lv = 10, col = C3(255, 150, 70)},
}

----------------------------------------------------------------- CHỈ SỐ NGƯỜI CHƠI
local function maxHP() return 100 + (S.lv - 1) * 24 end
local function maxMP() return 50 + (S.lv - 1) * 6 end
local function atkDmg() return 10 + S.lv * 4 + WPN[S.wpn].atk end
local function defense() return S.lv * 1.3 end
local function need(l) return math.floor(40 * l ^ 1.35) end
S.hp, S.mp = maxHP(), maxMP()

----------------------------------------------------------------- DỰNG MÔ HÌNH QUÁI (khối + khớp Motor6D để hoạt họa)
local CYL = setmetatable({}, {__mode = "k"}) -- trụ của Roblox nằm dọc trục X → xoay 90° để dựng đứng theo trục Y
local ROTC = ANG(0, 0, PI / 2)
local function shape(sh, sz, c, m, tr, anch) -- b=khối s=cầu c=trụ(dựng đứng theo Y) w=nêm
	local cy = sh == "c"
	local p = new(sh == "w" and "WedgePart" or "Part", {Size = cy and V3(sz.Y, sz.X, sz.Z) or sz, Color = c, Material = m or PLASTIC, Transparency = tr or 0,
		Anchored = anch or false, CanCollide = false, CanQuery = false, CanTouch = false, Massless = true})
	if sh == "s" then new("SpecialMesh", {MeshType = Enum.MeshType.Sphere}, p)
	elseif cy then p.Shape = Enum.PartType.Cylinder; CYL[p] = true end
	return p
end
local function put(p, cf) p.CFrame = CYL[p] and cf * ROTC or cf end
local PL, TPL = {}, {}
-- P(tên, cha, dạng, kích thước, vị trí khớp (CFrame so với cha), màu, chất liệu, {pv=tâm xoay, tr=trong suốt, fx=hàm})
local function P(n, par, sh, sz, at, c, m, x)
	local d = x or {}
	d.n, d.p, d.sh, d.s, d.a, d.c, d.m = n, par, sh, sz, at, c, m
	PL[#PL + 1] = d
end
local function assemble(list, sc)
	local model = new("Model", {Name = "Mob"})
	local root = new("Part", {Name = "Root", Size = V3(1, 1, 1), Transparency = 1, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false}, model)
	model.PrimaryPart = root
	local nodes, J = {root = root}, {}
	for _, d in ipairs(list) do
		local part = shape(d.sh, d.s * sc, d.c, d.m, d.tr)
		part.Name = d.n
		local base = CF(d.a.Position * sc) * d.a.Rotation
		local mot = new("Motor6D", {Part0 = nodes[d.p], Part1 = part, C0 = base, C1 = (d.sh == "c" and ANG(0, 0, -PI / 2) or CF()) * CF((d.pv or V3()) * sc)}, part)
		part.Parent = model
		nodes[d.n] = part
		if d.fx then d.fx(part) end
		if not J[d.n] then J[d.n] = {m = mot, b = base, s = part.Size, p = part} end
	end
	return model, J, root
end
local function eyes(par, x, y, z, sz, col, pupil)
	for s = -1, 1, 2 do
		P("eye", par, "s", V3(sz, sz * 1.1, sz * .6), CF(x * s, y, z), col, pupil and PLASTIC or MAT.Neon)
		if pupil then P("pup", par, "s", V3(sz * .5, sz * .6, sz * .3), CF(x * s, y - sz * .05, z - sz * .2), pupil, PLASTIC) end
	end
end

TPL.blob = function(o) -- slime, nấm, vua slime...
	PL = {}
	local z, cap, W = o.sz, o.cap, C3(255, 255, 255)
	local mat = o.m or (cap and PLASTIC or MAT.Glass)
	P("body", "root", "s", V3(z, z * .85, z), CF(0, z * .43, 0), o.c, mat, {tr = mat == MAT.Glass and .18 or 0})
	if not cap then P("core", "body", "s", V3(z * .4, z * .34, z * .4), CF(0, -z * .08, 0), o.core or o.c:Lerp(C3(20, 20, 30), .45), PLASTIC) end
	local ey = cap and -.08 or .1
	eyes("body", z * .2, z * ey, -z * .42, z * .22, W, C3(20, 20, 30))
	P("mouth", "body", "s", V3(z * .2, z * .09, z * .06), CF(0, z * (ey - .17), -z * .47), C3(70, 25, 35), PLASTIC)
	for s = -1, 1, 2 do P("blush", "body", "s", V3(z * .13, z * .08, z * .05), CF(s * z * .33, z * (ey - .1), -z * .4), C3(255, 130, 160), PLASTIC) end
	if cap then
		P("cap", "body", "s", V3(z * 1.3, z * .62, z * 1.3), CF(0, z * .36, 0), cap, PLASTIC)
		for i = 1, 6 do local a = i * 1.05; P("dot", "cap", "s", V3(z * .2, z * .1, z * .2), CF(math.cos(a) * z * .38, z * .25, math.sin(a) * z * .38), W, PLASTIC) end
		for s = -1, 1, 2 do P("foot", "body", "s", V3(z * .3, z * .2, z * .36), CF(s * z * .2, -z * .4, -z * .05), W:Lerp(o.c, .3), PLASTIC) end
	end
	if o.crown then
		local G = C3(255, 205, 60)
		P("crn", "body", "c", V3(z * .55, z * .13, z * .55), CF(0, z * .45, 0), G, MAT.Metal)
		for i = 1, 5 do local a = i * 1.2566; P("spk", "body", "s", V3(z * .1, z * .22, z * .1), CF(math.cos(a) * z * .25, z * .56, math.sin(a) * z * .25), G, MAT.Metal) end
		P("gem", "body", "s", V3(z * .14, z * .14, z * .1), CF(0, z * .47, -z * .27), C3(255, 60, 90), MAT.Neon)
	end
	if o.fire then
		P("fx", "body", "s", V3(.2, .2, .2), CF(0, z * .3, 0), o.c, PLASTIC, {tr = 1, fx = function(p)
			new("Fire", {Size = z * 1.2, Heat = 6, Color = C3(255, 150, 40), SecondaryColor = C3(255, 60, 20)}, p)
			new("PointLight", {Color = o.c, Range = z * 3, Brightness = 2}, p)
		end})
		for i = 1, 3 do local a = i * 2.1; P("crust", "body", "s", V3(z * .3, z * .12, z * .3), CF(math.cos(a) * z * .25, z * .38, math.sin(a) * z * .25), C3(40, 30, 30), MAT.Slate) end
	end
	return PL, z
end

TPL.snow = function(o) -- người tuyết
	PL = {}
	local z, W, K = o.sz, o.c, C3(30, 30, 40)
	P("body", "root", "s", V3(z, z * .9, z), CF(0, z * .45, 0), W, PLASTIC)
	P("mid", "body", "s", V3(z * .72, z * .66, z * .72), CF(0, z * .68, 0), W, PLASTIC)
	P("head", "mid", "s", V3(z * .55, z * .5, z * .55), CF(0, z * .5, 0), W, PLASTIC)
	P("hat", "head", "c", V3(z * .4, z * .36, z * .4), CF(0, z * .38, 0), K, PLASTIC)
	P("brim", "head", "c", V3(z * .62, z * .06, z * .62), CF(0, z * .22, 0), K, PLASTIC)
	P("scarf", "mid", "c", V3(z * .62, z * .12, z * .62), CF(0, z * .3, 0), C3(220, 50, 60), MAT.Fabric)
	P("nose", "head", "s", V3(z * .09, z * .09, z * .34), CF(0, -z * .02, -z * .34), C3(255, 140, 40), PLASTIC)
	for s = -1, 1, 2 do
		P("eye", "head", "s", V3(z * .1, z * .1, z * .06), CF(s * z * .13, z * .09, -z * .24), K, PLASTIC)
		P("arm", "mid", "b", V3(z * .07, z * .7, z * .07), CF(s * z * .46, z * .08, 0) * ANG(0, 0, -s * .9), C3(110, 75, 45), MAT.Wood)
	end
	return PL, z * 2.2
end

TPL.human = function(o) -- mẫu người: xương, xác ướp, golem, quỷ, hiệp sĩ, boss...
	PL = {}
	local M, c, s, aw, hk = o.m or PLASTIC, o.c, o.s or o.c, o.aw or 1, o.h or "round"
	P("legL", "root", "b", V3(.95, 2.1, .95), CF(-.6, 2.15, 0), o.lc or c, M, {pv = V3(0, 1.05, 0)})
	P("legR", "root", "b", V3(.95, 2.1, .95), CF(.6, 2.15, 0), o.lc or c, M, {pv = V3(0, 1.05, 0)})
	P("body", "root", "b", V3(2.3, 2.4, 1.3), CF(0, 3.4, 0), c, M)
	P("head", "body", (hk == "block" or hk == "mask" or hk == "helm") and "b" or "s", V3(1.75, 1.7, 1.7), CF(0, 2.05, 0), s, M)
	for i, k in ipairs({-1, 1}) do
		local nm = i == 1 and "armL" or "armR"
		P(nm, "body", "b", V3(.85 * aw, 2.2, .85 * aw), CF(k * (1.5 + .2 * (aw - 1)), .95, 0), o.ac or c, M, {pv = V3(0, 1, 0)})
		if aw > 1.2 then P("fist", nm, "s", V3(aw * .95, aw * .95, aw * .95), CF(0, -1.2, 0), o.ac or c, M) end
	end
	if hk == "skull" then
		P("jaw", "head", "b", V3(1.2, .5, 1.1), CF(0, -.95, -.1), s, M)
		for k = -1, 1, 2 do
			P("sock", "head", "s", V3(.5, .55, .3), CF(k * .4, .12, -.72), C3(15, 15, 20), PLASTIC)
			P("eye", "head", "s", V3(.24, .26, .2), CF(k * .4, .12, -.8), o.e, MAT.Neon)
		end
	elseif hk == "helm" then
		P("visor", "head", "b", V3(1.35, .22, .2), CF(0, .1, -.86), o.e, MAT.Neon)
		P("crest", "head", "b", V3(.3, 1, 1.5), CF(0, 1, 0), o.cape or s, M)
	elseif hk == "mask" then
		local B = C3(40, 90, 200)
		P("band", "head", "b", V3(2.1, .3, 1.9), CF(0, .95, 0), B, M)
		P("beard", "head", "b", V3(.35, .8, .3), CF(0, -1.1, -.6), B, M)
		for k = -1, 1, 2 do P("flap", "head", "b", V3(.45, 1.9, 1.5), CF(k * 1.05, -.45, .1), B, M) end
		eyes("head", .4, .12, -.88, .3, o.e)
	else
		eyes("head", .42, .12, -.8, .38, o.e)
		P("mouth", "head", "b", V3(.8, .14, .12), CF(0, -.42, -.84), C3(20, 10, 15), PLASTIC)
	end
	if o.horn then for k = -1, 1, 2 do P("horn", "head", "s", V3(.32, 1.2, .32), CF(k * .7, .95, 0) * ANG(0, 0, -k * .45), o.horn, PLASTIC) end end
	if o.spk then for i = 1, 5 do local a = i * 1.2566; P("spk", "head", "s", V3(.22, 1, .22), CF(math.cos(a) * .7, 1, math.sin(a) * .7) * ANG(math.sin(a) * .5, 0, -math.cos(a) * .5), o.spk, MAT.Neon) end end
	if o.leaf then
		for _ = 1, 4 do P("lf", "head", "s", V3(rnd(1.8, 2.6), rnd(1.2, 1.8), rnd(1.8, 2.6)), CF(rnd(-.9, .9), 1 + rnd(0, .8), rnd(-.9, .9)), o.leaf:Lerp(C3(255, 255, 120), rnd(0, .25)), PLASTIC) end
		for k = -1, 1, 2 do P("lf", "body", "s", V3(1.5, 1.1, 1.5), CF(k * 1.4, 1.3, 0), o.leaf, PLASTIC) end
	end
	if o.flower then P("fl", "head", "s", V3(.8, .5, .8), CF(0, .95, 0), o.flower, PLASTIC); P("fl2", "head", "s", V3(.3, .3, .3), CF(0, 1.2, 0), C3(255, 230, 90), PLASTIC) end
	if o.fire then
		P("flame", "head", "s", V3(.3, .3, .3), CF(0, .9, 0), o.fire, PLASTIC, {tr = 1, fx = function(p)
			new("Fire", {Size = 4 * (o.sc or 1), Heat = 8, Color = o.fire, SecondaryColor = C3(255, 70, 20)}, p)
			new("PointLight", {Color = o.fire, Range = 14, Brightness = 1.5}, p)
		end})
	end
	if o.wing then
		for i, k in ipairs({-1, 1}) do
			P(i == 1 and "wingL" or "wingR", "body", "s", V3(2.8, 3.2, .14), CF(k * .5, .9, .75) * ANG(0, -k * .6, 0), o.wing, PLASTIC, {pv = V3(-k * 1.3, 0, 0)})
		end
	end
	if o.cape then P("cape", "body", "b", V3(2.1, 3.1, .12), CF(0, 1.2, .75), o.cape, MAT.Fabric, {pv = V3(0, 1.5, 0)}) end
	if o.tail then P("tail", "body", "s", V3(.4, .4, 2.6), CF(0, -.9, .65) * ANG(-.6, 0, 0), o.tail, PLASTIC, {pv = V3(0, 0, -1.3)}) end
	if o.wpn then
		local k, wc = o.wpn[1], o.wpn[2]
		if k == "sword" then
			local g = CF(0, -1.1, 0) * ANG(-.75, 0, 0) -- cầm chéo lên phía trước
			P("hilt", "armR", "c", V3(.24, 1.1, .24), g, C3(90, 60, 40), MAT.Wood)
			P("guard", "armR", "b", V3(1.2, .22, .3), g * CF(0, .62, 0), C3(160, 130, 60), MAT.Metal)
			P("blade", "armR", "b", V3(.36, 3.6, .12), g * CF(0, 2.5, 0), wc, MAT.Metal)
		else -- gậy: cầm thẳng đứng, ngọc phát sáng ở đỉnh
			local g = CF(0, -1.1, 0)
			P("pole", "armR", "c", V3(.26, 4.6, .26), g * CF(0, .8, 0), C3(110, 80, 50), MAT.Wood)
			P("gem", "armR", "s", V3(.95, .95, .95), g * CF(0, 3.3, 0), wc, MAT.Neon)
		end
	end
	if o.wrap then
		for i = 1, 4 do P("wr", "body", "b", V3(2.4, .26, 1.4), CF(0, -1.05 + i * .5, 0) * ANG(0, .2 * i, 0), o.wrap, MAT.Fabric) end
		for _, n in ipairs({"armL", "armR"}) do for i = 1, 3 do P("wa", n, "b", V3(.95 * aw, .24, .95 * aw), CF(0, -.9 + i * .6, 0) * ANG(0, .3 * i, 0), o.wrap, MAT.Fabric) end end
	end
	if o.rib then
		for i = 1, 3 do P("rib", "body", "b", V3(2, .2, .3), CF(0, -.7 + i * .55, -.62), s, M) end
		P("spine", "body", "b", V3(.28, 2.2, .28), CF(0, 0, -.62), s, M)
	end
	if o.crack then for _ = 1, 5 do P("crk", "body", "b", V3(.16, rnd(.8, 1.6), .1), CF(rnd(-.8, .8), rnd(-.8, .8), -.68) * ANG(0, 0, rnd(-.8, .8)), o.crack, MAT.Neon) end end
	if o.spike then for _ = 1, 10 do local a = rnd(0, 6.28); P("sp", "body", "b", V3(.08, .5, .08), CF(math.cos(a) * 1.1, rnd(-1, 1), math.sin(a) * .66) * ANG(0, 0, -math.cos(a) * 1.2), o.spike, PLASTIC) end end
	return PL, 6.3 + (o.leaf and 1.8 or 0) + ((o.horn or o.spk or o.fire or o.flower) and 1 or 0)
end

TPL.float = function(o) -- ong, ma, dơi, tinh thể
	PL = {}
	local k, W = o.k, C3(255, 255, 255)
	if k == "bee" then
		P("body", "root", "s", V3(1.7, 1.5, 2.2), CF(), C3(255, 205, 50), PLASTIC)
		for i = -1, 1 do P("str", "body", "s", V3(1.74, 1.2, .38), CF(0, 0, i * .6), C3(40, 30, 30), PLASTIC) end
		P("sting", "body", "s", V3(.25, .25, .7), CF(0, 0, 1.3), C3(40, 30, 30), PLASTIC)
		eyes("body", .42, .28, -1, .5, W, C3(20, 20, 25))
		for i, s in ipairs({-1, 1}) do P(i == 1 and "wingL" or "wingR", "body", "s", V3(1.9, .1, 1.1), CF(s * .5, .9, .1), C3(220, 245, 255), MAT.Glass, {tr = .35, pv = V3(-s * .95, 0, 0)}) end
	elseif k == "ghost" then
		local G = C3(225, 240, 255)
		P("body", "root", "s", V3(2.6, 3.2, 2.6), CF(), G, PLASTIC, {tr = .3})
		P("tail1", "body", "s", V3(1.9, 1.6, 1.9), CF(0, -1.7, .2), G, PLASTIC, {tr = .45})
		P("tail2", "tail1", "s", V3(1.2, 1.3, 1.2), CF(0, -1.1, .3), G, PLASTIC, {tr = .6})
		P("mouth", "body", "s", V3(.6, .8, .3), CF(0, -.5, -1.2), C3(20, 25, 50), PLASTIC)
		for s = -1, 1, 2 do
			P("eye", "body", "s", V3(.55, .85, .3), CF(s * .55, .45, -1.15), C3(20, 25, 50), PLASTIC)
			P("glow", "body", "s", V3(.2, .3, .2), CF(s * .55, .4, -1.28), C3(120, 200, 255), MAT.Neon)
			P(s < 0 and "armL" or "armR", "body", "s", V3(.6, 1.6, .6), CF(s * 1.5, -.1, -.2) * ANG(0, 0, s * .5), G, PLASTIC, {tr = .4, pv = V3(0, .7, 0)})
		end
	elseif k == "bat" then
		local D = C3(70, 45, 95)
		P("body", "root", "s", V3(1.5, 1.7, 1.4), CF(), D, PLASTIC)
		P("head", "body", "s", V3(1.5, 1.3, 1.3), CF(0, 1.05, -.1), D, PLASTIC)
		for s = -1, 1, 2 do
			P("ear", "head", "s", V3(.35, .9, .2), CF(s * .5, .8, 0) * ANG(0, 0, -s * .3), D, PLASTIC)
			P("eye", "head", "s", V3(.3, .3, .2), CF(s * .34, .1, -.6), C3(255, 50, 70), MAT.Neon)
			P("fang", "head", "s", V3(.14, .38, .14), CF(s * .2, -.6, -.55), W, PLASTIC)
			P(s < 0 and "wingL" or "wingR", "body", "s", V3(3.6, .1, 1.9), CF(s * .6, .3, .2), C3(110, 60, 140), PLASTIC, {pv = V3(-s * 1.8, 0, 0)})
		end
	else -- crystal
		local ic = C3(120, 225, 255)
		P("body", "root", "b", V3(1.5, 3.2, 1.5), CF() * ANG(.3, .6, .3), ic, MAT.Neon, {tr = .1})
		P("core", "body", "s", V3(.8, .8, .8), CF(), W, MAT.Neon)
		P("orb", "root", "s", V3(.2, .2, .2), CF(), ic, PLASTIC, {tr = 1})
		for i = 1, 5 do local a = i * 1.2566; P("shard", "orb", "b", V3(.6, 1.6, .6), CF(math.cos(a) * 2.6, math.sin(a * 2) * .6, math.sin(a) * 2.6) * ANG(a, a, .4), ic:Lerp(W, .3), MAT.Neon) end
	end
	return PL, 3
end

TPL.beast = function(o) -- sói
	PL = {}
	local c, c2, e, F = o.c, o.c2 or o.c, o.e, MAT.Fabric
	P("body", "root", "s", V3(2.3, 2.1, 4.2), CF(0, 2.5, 0), c, F)
	P("belly", "body", "s", V3(1.9, 1.3, 3.4), CF(0, -.4, 0), c2, F)
	P("head", "body", "s", V3(1.7, 1.6, 1.7), CF(0, .55, -2.3), c, F)
	P("snout", "head", "s", V3(.95, .8, 1.2), CF(0, -.3, -.95), c2, F)
	P("nose", "snout", "s", V3(.35, .3, .3), CF(0, .15, -.6), C3(25, 25, 35), PLASTIC)
	for s = -1, 1, 2 do
		P("ear", "head", "s", V3(.45, 1, .3), CF(s * .55, .95, .1) * ANG(0, 0, -s * .25), c, F)
		P("eye", "head", "s", V3(.32, .3, .2), CF(s * .42, .18, -.78), e, MAT.Neon)
	end
	local nm, lx = {"legFL", "legFR", "legBL", "legBR"}, {{-.75, -1.3}, {.75, -1.3}, {-.75, 1.3}, {.75, 1.3}}
	for i = 1, 4 do P(nm[i], "body", "b", V3(.65, 1.7, .65), CF(lx[i][1], -.85, lx[i][2]), c2, F, {pv = V3(0, .85, 0)}) end
	P("tail", "body", "s", V3(.7, .7, 2.2), CF(0, .5, 2.6) * ANG(-.6, 0, 0), c, F, {pv = V3(0, 0, -1.1)})
	if o.spk then for i = 1, 4 do P("sp", "body", "b", V3(.28, .9, .28), CF(0, 1.1, -1.5 + i * .8) * ANG(0, 0, .7), o.spk, MAT.Neon) end end
	return PL, 4.2
end

TPL.crawl = function(o) -- nhện, bọ cạp
	PL = {}
	local c, e = o.c, o.e
	if o.k == "spider" then
		P("body", "root", "s", V3(2.6, 2.3, 3), CF(0, 2, 1.3), c, PLASTIC)
		P("head", "root", "s", V3(1.8, 1.5, 1.7), CF(0, 1.9, -.9), c, PLASTIC)
		P("mark", "body", "s", V3(.9, .3, 1.6), CF(0, 1.12, .1), o.g, MAT.Neon)
		for s = -1, 1, 2 do
			P("eye", "head", "s", V3(.32, .32, .2), CF(s * .3, .3, -.8), e, MAT.Neon)
			P("eye", "head", "s", V3(.22, .22, .15), CF(s * .62, .05, -.7), e, MAT.Neon)
			P("fang", "head", "s", V3(.18, .7, .18), CF(s * .3, -.7, -.75) * ANG(-.3, 0, 0), C3(235, 235, 225), PLASTIC)
		end
		for i = 1, 8 do
			local sd, r = i % 2 == 0 and 1 or -1, math.ceil(i / 2)
			P("l" .. i, "root", "b", V3(.26, 2.7, .26), CF(sd * .9, 1.7, -.9 + r * .5) * ANG(0, sd * (2.5 - r) * .55, sd * .95), c, PLASTIC, {pv = V3(0, 1.35, 0)})
		end
	else
		P("body", "root", "s", V3(2.8, 1.5, 3.6), CF(0, 1.3, 0), c, PLASTIC)
		P("head", "body", "s", V3(1.6, 1.1, 1.3), CF(0, .1, -1.9), c, PLASTIC)
		for s = -1, 1, 2 do
			local cn = s < 0 and "clawL" or "clawR"
			P("eye", "head", "s", V3(.28, .3, .2), CF(s * .4, .3, -.6), C3(30, 20, 20), PLASTIC)
			P(cn, "body", "b", V3(.5, .5, 1.9), CF(s * 1.4, 0, -2.3) * ANG(0, s * .3, 0), c, PLASTIC, {pv = V3(0, 0, .9)})
			P("pinch", cn, "s", V3(1.1, .6, 1.3), CF(0, 0, -1.2), c:Lerp(C3(255, 90, 60), .2), PLASTIC)
		end
		for i = 1, 6 do
			local sd, r = i % 2 == 0 and 1 or -1, math.ceil(i / 2)
			P("l" .. i, "root", "b", V3(.24, 2.1, .24), CF(sd * 1, 1.1, -.6 + r * .6) * ANG(0, sd * (2 - r) * .5, sd), c:Lerp(C3(0, 0, 0), .25), PLASTIC, {pv = V3(0, 1.05, 0)})
		end
		local prev = "body"
		for i = 1, 4 do
			local n = "t" .. i
			P(n, prev, "s", V3(.8 - i * .06, .8 - i * .06, 1.4), i == 1 and CF(0, .4, 1.7) * ANG(-.5, 0, 0) or CF(0, 0, .7) * ANG(-.5, 0, 0), i == 4 and C3(190, 50, 45) or c, PLASTIC, {pv = V3(0, 0, -.7)})
			prev = n
		end
		P("sting", "t4", "s", V3(.25, .25, .8), CF(0, 0, .95) * ANG(-.3, 0, 0), C3(220, 70, 55), PLASTIC)
	end
	return PL, o.k == "spider" and 3.3 or 5
end

----------------------------------------------------------------- HOẠT HỌA QUÁI (đi, nhảy, bay, đánh, thở)
local KIND = {blob = "hop", snow = "hop", human = "walk", float = "float", beast = "quad", crawl = "crawl"}
local function jset(J, n, r) local j = J[n]; if j then j.m.C0 = j.b * r end end
local function animate(m, now)
	local J, k, mv, at, d = m.J, m.kind, m.mv, m.at, m.d
	local t, yo, tilt = now + m.ph, 0, 0
	if k == "walk" then
		local w = math.sin(t * 9) * mv
		jset(J, "legL", ANG(w * .9, 0, 0)); jset(J, "legR", ANG(-w * .9, 0, 0))
		local aL, aR, lean = -w * .8, w * .8, -.08 * mv
		if at then -- giơ tay lên (0→.5) rồi bổ xuống (.5→.7) rồi thu về
			local th = at < .5 and 2.9 * at / .5 or (at < .7 and 2.9 - 2.4 * (at - .5) / .2 or .5 * (1 - (at - .7) / .3))
			aR, aL = th, th * .8
			lean = at < .5 and .3 * at / .5 or -.35
		end
		jset(J, "armL", ANG(aL, 0, .06)); jset(J, "armR", ANG(aR, 0, -.06))
		jset(J, "body", ANG(lean, math.sin(t * 9) * .08 * mv, 0))
		yo = math.abs(math.sin(t * 9)) * .3 * mv + math.sin(t * 2) * .06
		local f = math.sin(t * (2 + mv * 6)) * (.2 + mv * .3)
		jset(J, "cape", ANG(-.12 - .3 * mv, 0, 0)); jset(J, "tail", ANG(0, math.sin(t * 4) * .35, 0))
		jset(J, "wingL", ANG(0, 0, f)); jset(J, "wingR", ANG(0, 0, -f))
	elseif k == "float" then
		yo = d.hov + math.sin(t * 2.2) * .45
		local f = (d.fl or 0) > 0 and math.sin(t * d.fl) * .8 or 0
		jset(J, "wingL", ANG(0, 0, f)); jset(J, "wingR", ANG(0, 0, -f)); jset(J, "orb", ANG(0, t * 1.5, 0))
		local sw = math.sin(t * 2) * .25
		jset(J, "armL", ANG(0, 0, .3 + sw)); jset(J, "armR", ANG(0, 0, -.3 - sw))
		tilt = -mv * .25 - (at and math.sin(math.min(at, 1) * PI) * .7 or 0)
	elseif k == "hop" then
		local hop = mv > .1 and math.sin(((t * 2.4) % 1) * PI) or 0
		yo = hop * (d.sz or 3) * .4
		local sq = mv > .1 and (.1 - hop * .26) or math.sin(t * 3) * .04
		if at then sq = at < .5 and .28 * at / .5 or -.2; tilt = at > .5 and -.3 or 0 end
		local b = J.body
		b.p.Size = b.s * V3(1 + sq, 1 - sq, 1 + sq)
		b.m.C0 = b.b * CF(0, -sq * b.s.Y * .5, 0)
	elseif k == "quad" then
		local w = math.sin(t * 11) * mv
		jset(J, "legFL", ANG(w * .8, 0, 0)); jset(J, "legBR", ANG(w * .8, 0, 0)); jset(J, "legFR", ANG(-w * .8, 0, 0)); jset(J, "legBL", ANG(-w * .8, 0, 0))
		yo = math.abs(math.sin(t * 11)) * .35 * mv + math.sin(t * 2) * .05
		jset(J, "tail", ANG(math.sin(t * 5) * .3, 0, 0))
		if at then local s = math.sin(math.min(at, 1) * PI); jset(J, "head", ANG(-s * .6, 0, 0)); tilt = -s * .25 end
	else -- crawl
		local w = t * 12
		for i = 1, 8 do jset(J, "l" .. i, ANG(math.sin(w + i * 1.9) * .35 * mv, 0, 0)) end
		yo = math.sin(t * 2) * .05 + math.abs(math.sin(w)) * .1 * mv
		if J.t1 then
			local a, sw = at and math.sin(math.min(at, 1) * PI) * .55 or 0, math.sin(t * 2) * .08
			for i = 1, 3 do jset(J, "t" .. i, ANG(-a + sw, 0, 0)) end
			jset(J, "clawL", ANG(0, math.sin(t * 6) * .15 * mv, 0)); jset(J, "clawR", ANG(0, -math.sin(t * 6) * .15 * mv, 0))
		elseif at then tilt = -math.sin(math.min(at, 1) * PI) * .3 end
	end
	local cf = CF(m.pos.X, m.pos.Y + yo, m.pos.Z) * ANG(0, m.yaw, 0) * ANG(tilt, 0, 0)
	if m.lunge ~= 0 then cf = cf * CF(0, 0, -m.lunge) end
	m.root.CFrame = cf
end

----------------------------------------------------------------- THẾ GIỚI: địa hình, đạo cụ, trại, ánh sáng, thời tiết
local MAPST, F, SPIN, GY = {}, nil, nil, 0
local function prop(sh, sz, cf, c, mat, cc, tr)
	local p = shape(sh, sz, c, mat, tr, true)
	put(p, cf + V3(0, GY, 0))
	if cc then p.CanCollide = true end
	p.Parent = F
	return p
end
local PROPS = {}
function PROPS.tree(x, z, pal)
	local h = rnd(7, 12)
	prop("c", V3(1.7, h, 1.7), CF(x, h / 2, z), pal.trunk, MAT.Wood, true)
	for i = 1, 3 do
		local s = rnd(6, 9) - i
		prop("s", V3(s, s * .85, s), CF(x + rnd(-1.5, 1.5), h + i * 1.2 - .6, z + rnd(-1.5, 1.5)), pick(pal.leaf))
	end
end
function PROPS.pine(x, z, pal, snow)
	local h = rnd(9, 14)
	prop("c", V3(1.4, h * .5, 1.4), CF(x, h * .25, z), pal.trunk, MAT.Wood, true)
	for i = 1, 4 do
		local w = (5 - i) * .95 + .6
		prop("c", V3(w * 2, h * .22, w * 2), CF(x, h * .3 + i * h * .15, z), (snow and i % 2 == 0) and C3(240, 248, 255) or pick(pal.leaf))
	end
end
function PROPS.dead(x, z, pal)
	local h = rnd(6, 10)
	prop("c", V3(1.1, h, 1.1), CF(x, h / 2, z) * ANG(rnd(-.12, .12), 0, rnd(-.12, .12)), pal.trunk, MAT.Wood, true)
	for i = 1, 3 do prop("c", V3(.5, rnd(2.5, 4), .5), CF(x, h * (.45 + i * .13), z) * ANG(0, i * 2.1, 1 + rnd(-.3, .3)) * CF(0, 1.5, 0), pal.trunk, MAT.Wood) end
end
function PROPS.rock(x, z, pal)
	local s = rnd(2.5, 6)
	prop("s", V3(s, s * rnd(.6, .9), s * rnd(.8, 1.2)), CF(x, s * .25, z) * ANG(rnd(-.3, .3), rnd(0, 6), rnd(-.3, .3)), pal.rock:Lerp(C3(255, 255, 255), rnd(0, .15)), MAT.Slate, s > 4)
end
function PROPS.crystal(x, z, pal)
	local c, h = pick(pal.acc), rnd(3, 7)
	for i = 1, 3 do prop("b", V3(h * .16, h * (1 - i * .18), h * .16), CF(x + rnd(-1, 1), h * .4, z + rnd(-1, 1)) * ANG(rnd(-.35, .35), rnd(0, 6), rnd(-.35, .35)), c, MAT.Neon, false, .12) end
end
function PROPS.cactus(x, z, pal)
	local h, g = rnd(5, 9), pick(pal.leaf)
	prop("c", V3(1.8, h, 1.8), CF(x, h / 2, z), g, PLASTIC, true)
	prop("s", V3(.9, .6, .9), CF(x, h + .2, z), C3(255, 90, 140))
	for s = -1, 1, 2 do
		if rng:NextNumber() > .3 then
			local ah = rnd(2, 3.5)
			prop("c", V3(1.1, 2.2, 1.1), CF(x + s * 1.3, h * .45, z) * ANG(0, 0, PI / 2), g, PLASTIC)
			prop("c", V3(1.1, ah, 1.1), CF(x + s * 2.3, h * .45 + ah / 2, z), g, PLASTIC)
		end
	end
end
function PROPS.pillar(x, z, pal)
	local h, cf = rnd(6, 13), CF(x, 0, z) * ANG(0, rnd(0, 6), 0)
	local dk = pal.rock:Lerp(C3(0, 0, 0), .2)
	prop("c", V3(2.6, h, 2.6), cf * CF(0, h / 2, 0), pal.rock, MAT.Marble, true)
	prop("b", V3(3.6, .8, 3.6), cf * CF(0, .4, 0), dk, MAT.Slate, true)
	prop("b", V3(3.4, .8, 3.4), cf * CF(0, h + .2, 0) * ANG(rnd(-.15, .15), 0, rnd(-.15, .15)), dk, MAT.Slate)
end
function PROPS.bush(x, z, pal) for _ = 1, 3 do local s = rnd(1.6, 2.6); prop("s", V3(s, s * .75, s), CF(x + rnd(-1, 1), s * .3, z + rnd(-1, 1)), pick(pal.leaf)) end end
function PROPS.flower(x, z, pal)
	local h = rnd(.9, 1.6)
	prop("b", V3(.12, h, .12), CF(x, h / 2, z), C3(70, 160, 70))
	prop("s", V3(.55, .4, .55), CF(x, h + .1, z), pick(pal.acc))
end
function PROPS.torch(x, z, pal)
	prop("c", V3(.5, 4.2, .5), CF(x, 2.1, z), C3(60, 45, 40), MAT.Wood, true)
	local f = prop("s", V3(.9, .9, .9), CF(x, 4.6, z), pick(pal.acc), MAT.Neon)
	new("PointLight", {Color = f.Color, Range = 22, Brightness = 1.6}, f)
end
function PROPS.lava(x, z, pal)
	local r = rnd(4, 8)
	local p = prop("c", V3(r * 2, .3, r * 2), CF(x, .12, z), pal.acc[1], MAT.Neon)
	new("PointLight", {Color = pal.acc[1], Range = 26, Brightness = 2}, p)
end
function PROPS.grave(x, z, pal)
	local cf = CF(x, 0, z) * ANG(rnd(-.12, .12), rnd(0, 6), rnd(-.12, .12))
	prop("b", V3(1.8, 2.6, .6), cf * CF(0, 1.3, 0), pal.rock, MAT.Slate, true)
	prop("s", V3(1.8, 1.2, .6), cf * CF(0, 2.6, 0), pal.rock, MAT.Slate)
end
function PROPS.mush(x, z, pal)
	local h, c = rnd(1.2, 3.2), pick(pal.acc)
	prop("c", V3(.5, h, .5), CF(x, h / 2, z), C3(230, 230, 240))
	prop("s", V3(h * 1.1, h * .55, h * 1.1), CF(x, h, z), c, MAT.Neon, false, .1)
end
function PROPS.mound(x, z, pal) local s = rnd(5, 12); prop("s", V3(s * 1.4, s * .35, s), CF(x, 0, z) * ANG(0, rnd(0, 6), 0), pal.mound) end
function PROPS.wall(x, z, pal)
	local w, h = rnd(8, 16), rnd(4, 9)
	local cf = CF(x, 0, z) * ANG(0, rnd(0, 6), 0)
	prop("b", V3(w, h, 2), cf * CF(0, h / 2, 0), pal.rock, MAT.Cobblestone, true)
	for _ = 1, 3 do local s = rnd(1, 2.5); prop("b", V3(s, s, s), cf * CF(rnd(-w / 2, w / 2), s / 2, rnd(2, 3.5)) * ANG(rnd(0, 3), rnd(0, 3), 0), pal.rock, MAT.Cobblestone) end
end
local RECIPE = {
	meadow = {tree = 20, bush = 16, flower = 55, rock = 12}, forest = {pine = 26, dead = 10, mush = 34, grave = 16, rock = 8, torch = 6},
	desert = {cactus = 22, rock = 16, dead = 6, pillar = 8, mound = 14}, ice = {pine = 22, crystal = 24, mound = 18, rock = 10},
	volcano = {rock = 28, lava = 9, crystal = 10, dead = 8}, castle = {pillar = 14, wall = 10, torch = 12, crystal = 12, dead = 8},
}

local function buildMap(i, step) -- step(p, text) cập nhật thanh tải
	local m = MAPS[i]
	local c, R, pal, col = m.center, CFG.R, m.pal, m.col
	F, SPIN = new("Folder", {Name = "Map" .. i}), {}
	step(.2, "Đắp địa hình...")
	Terrain:FillCylinder(CF(c.X, 25, c.Z), 70, R + 70, m.rim) -- vòng núi đá
	for k = 1, 16 do
		local a = k / 16 * 2 * PI + rnd(-.1, .1)
		Terrain:FillBall(c + V3(math.cos(a) * (R + 40), rnd(45, 80), math.sin(a) * (R + 40)), rnd(28, 46), k % 3 == 0 and m.cap or m.rim)
	end
	Terrain:FillCylinder(CF(c.X, 70, c.Z), 140, R, MAT.Air) -- khoét sân đấu
	Terrain:FillCylinder(CF(c.X, -6, c.Z), 12, R + 4, m.gnd) -- nền
	for _ = 1, 12 do
		local a, d = rnd(0, 2 * PI), rnd(20, R - 20)
		Terrain:FillCylinder(CF(c.X + math.cos(a) * d, -3, c.Z + math.sin(a) * d), 6, rnd(6, 14), m.gnd2)
	end
	task.wait()
	local hit = workspace:Raycast(c + V3(0, 40, 0), V3(0, -90, 0))
	m.gy = hit and hit.Position.Y or 0
	if not hit or math.abs(m.gy) > 3 then -- địa hình không dùng được → sàn + tường dự phòng
		m.gy, GY = 0, 0
		prop("c", V3(2 * R + 20, 4, 2 * R + 20), CF(c.X, -2, c.Z), pal.mound, MAT.Slate, true)
		for k = 1, 24 do
			local a = k / 24 * 2 * PI
			prop("b", V3(40, 90, 4), CF(c.X + math.cos(a) * (R + 4), 45, c.Z + math.sin(a) * (R + 4)) * ANG(0, -a - PI / 2, 0), pal.rock, MAT.Slate, true)
		end
	end
	GY = m.gy
	step(.5, "Trồng cây, xếp đá...")
	local ba = rnd(0, 2 * PI)
	local bx, bz = c.X + math.cos(ba) * 108, c.Z + math.sin(ba) * 108
	m.bossPos = V3(bx, m.gy, bz)
	for name, n in pairs(RECIPE[m.biome]) do
		for _ = 1, n do
			local a, d = rnd(0, 2 * PI), rnd(32, R - 6)
			local x, z = c.X + math.cos(a) * d, c.Z + math.sin(a) * d
			if (x - bx) ^ 2 + (z - bz) ^ 2 > 450 then PROPS[name](x, z, pal, m.biome == "ice") end
		end
		task.wait()
	end
	step(.85, "Dựng trại nghỉ...")
	prop("c", V3(CFG.CAMP * 2 + 3, .1, CFG.CAMP * 2 + 3), CF(c.X, .06, c.Z), col, MAT.Neon, false, .55)
	prop("c", V3(CFG.CAMP * 2, .2, CFG.CAMP * 2), CF(c.X, .1, c.Z), C3(82, 86, 108), MAT.Slate)
	prop("c", V3(11, .25, 11), CF(c.X, .14, c.Z), col, MAT.Neon, false, .25)
	prop("c", V3(3.2, 60, 3.2), CF(c.X, 30, c.Z), col, MAT.Neon, false, .82)
	local crys = prop("b", V3(2.4, 4.6, 2.4), CF(c.X, 7, c.Z) * ANG(.5, 0, .5), col, MAT.Neon, false, .1)
	SPIN[1] = crys
	new("PointLight", {Color = col, Range = 40, Brightness = 2}, crys)
	new("ParticleEmitter", {Rate = 22, Lifetime = NumberRange.new(1.5, 2.2), Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Top,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, .7), NumberSequenceKeypoint.new(1, 0)}), Color = ColorSequence.new(col), LightEmission = 1}, crys)
	local bb = new("BillboardGui", {Size = U2(0, 220, 0, 50), StudsOffset = V3(0, 4.5, 0), MaxDistance = 140, LightInfluence = 0}, crys)
	txt({Size = U2(1, 0, 0, 24), Text = m.ic .. " " .. m.n, Font = FONTB, TextSize = 20, TextColor3 = col, TextStrokeTransparency = .3}, bb)
	txt({Position = U2(0, 0, 0, 26), Size = U2(1, 0, 0, 18), Text = "Trại nghỉ · Khu an toàn", TextSize = 13, TextStrokeTransparency = .5}, bb)
	for k = 1, 4 do local a = k * PI / 2 + PI / 4; PROPS.torch(c.X + math.cos(a) * 17, c.Z + math.sin(a) * 17, pal) end
	local fx, fz = c.X + 9, c.Z - 7 -- lửa trại
	prop("c", V3(.7, 4, .7), CF(fx, .5, fz) * ANG(0, 0, 1.2), C3(90, 60, 40), MAT.Wood)
	prop("c", V3(.7, 4, .7), CF(fx, .5, fz) * ANG(0, 1.6, -1.2), C3(90, 60, 40), MAT.Wood)
	local fp = prop("s", V3(.8, .8, .8), CF(fx, 1.4, fz), C3(255, 150, 50), MAT.Neon)
	new("Fire", {Size = 7, Heat = 9}, fp)
	new("PointLight", {Color = C3(255, 170, 80), Range = 30, Brightness = 2}, fp)
	for k = 1, 6 do local a = k * 1.047; prop("s", V3(1.1, .8, 1.1), CF(fx + math.cos(a) * 2.2, .3, fz + math.sin(a) * 2.2), C3(110, 110, 120), MAT.Slate) end
	prop("c", V3(32, .3, 32), CF(bx, .16, bz), C3(255, 70, 70), MAT.Neon, false, .6) -- bệ boss
	prop("c", V3(30, .5, 30), CF(bx, .22, bz), C3(48, 44, 56), MAT.Slate)
	for k = 1, 6 do local a = k * PI / 3; PROPS.pillar(bx + math.cos(a) * 14, bz + math.sin(a) * 14, pal) end
	MAPST[i] = {folder = F, spin = SPIN}
	m.built = true
end

local function lfx(class) return Lighting:FindFirstChildOfClass(class) or new(class, nil, Lighting) end
local ATM, CC, BLOOM = lfx("Atmosphere"), lfx("ColorCorrectionEffect"), lfx("BloomEffect")
BLOOM.Intensity, BLOOM.Size, BLOOM.Threshold = .5, 24, .95
local WXP = new("Part", {Name = "Weather", Size = V3(90, 1, 90), Transparency = 1, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false}, FX)
local WXE = new("ParticleEmitter", {Enabled = false, Shape = Enum.ParticleEmitterShape.Box, LightEmission = .6}, WXP)
local WXH = 20
local function applyLighting(m)
	local l, w = m.lit, WX[m.wx]
	Lighting.ClockTime, Lighting.Ambient, Lighting.OutdoorAmbient, Lighting.Brightness = l.t, l.amb, l.out, l.br
	ATM.Color, ATM.Decay, ATM.Density, ATM.Haze, ATM.Glare = l.fog, l.fog:Lerp(C3(0, 0, 0), .35), l.dn, l.hz, 0
	CC.TintColor, CC.Saturation, CC.Contrast = l.tint, l.sat, .06
	WXH = w.h
	WXE.Color, WXE.Size = ColorSequence.new(w.c), NumberSequence.new(w.sz)
	WXE.Rate, WXE.Lifetime, WXE.Speed = w.rate, NumberRange.new(w.life * .7, w.life), NumberRange.new(w.sp * .5, w.sp)
	WXE.Acceleration, WXE.EmissionDirection = w.acc, Enum.NormalId[w.dir]
	WXE.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(.15, w.tr or .1), NumberSequenceKeypoint.new(.8, w.tr or .1), NumberSequenceKeypoint.new(1, 1)})
	WXE.Enabled = true
	MUSIC.SoundId = m.music
	if m.music ~= "" then MUSIC:Play() else MUSIC:Stop() end
end

----------------------------------------------------------------- NHÂN VẬT: vũ khí + hoạt họa vung kiếm
local RIG = {}
local function bindChar(char)
	local hum, hrp = char:WaitForChild("Humanoid"), char:WaitForChild("HumanoidRootPart")
	local r15 = hum.RigType == Enum.HumanoidRigType.R15
	local hand, sh
	if r15 then
		hand = char:WaitForChild("RightHand", 8)
		local ua = char:WaitForChild("RightUpperArm", 8)
		sh = ua and ua:WaitForChild("RightShoulder", 8)
	else
		hand = char:WaitForChild("Right Arm", 8)
		local tor = char:WaitForChild("Torso", 8)
		sh = tor and tor:WaitForChild("Right Shoulder", 8)
	end
	RIG = {char = char, hum = hum, hrp = hrp, hand = hand, sh = sh, base = sh and sh.C0, r15 = r15}
	hum.WalkSpeed = CFG.SPEED
end
local function buildWeapon(w)
	local m = new("Model", {Name = "HeroWeapon"})
	local handle = shape("b", V3(.3, 1.2, .3), C3(70, 50, 40), MAT.Fabric)
	handle.Name = "Handle"; handle.Parent = m
	local function add(sh, sz, off, col, mat, tr)
		local p = shape(sh, sz, col, mat, tr)
		p.Parent = m
		new("Weld", {Part0 = handle, Part1 = p, C0 = off}, p)
		return p
	end
	add("s", V3(.5, .5, .5), CF(0, -.7, 0), w.gd, MAT.Metal)
	add("b", V3(1.7, .26, .5), CF(0, .68, 0), w.gd, MAT.Metal)
	local blade = add("b", V3(w.wid, w.len, .16), CF(0, .8 + w.len / 2, 0), w.bl, MAT.Metal)
	add("b", V3(w.wid * .72, w.wid * .72, .17), CF(0, .8 + w.len, 0) * ANG(0, 0, PI / 4), w.bl, MAT.Metal)
	if w.gl then add("b", V3(w.wid * .3, w.len * .95, .2), CF(0, .8 + w.len / 2, 0), w.gl, MAT.Neon) end
	add("s", V3(.34, .34, .34), CF(0, .68, 0), w.gem, MAT.Neon)
	local a0 = new("Attachment", {Position = V3(0, -w.len / 2 + .1, 0)}, blade)
	local a1 = new("Attachment", {Position = V3(0, w.len / 2 + .5, 0)}, blade)
	local trail = new("Trail", {Attachment0 = a0, Attachment1 = a1, Lifetime = .3, MinLength = .02, LightEmission = 1, FaceCamera = true, Enabled = false,
		Color = ColorSequence.new(w.tr), Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, .1), NumberSequenceKeypoint.new(1, 1)})}, blade)
	if w.aura then
		new("ParticleEmitter", {Rate = 16, Lifetime = NumberRange.new(.5, .9), Speed = NumberRange.new(.5, 2), SpreadAngle = Vector2.new(180, 180), LightEmission = 1,
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, .35), NumberSequenceKeypoint.new(1, 0)}), Color = ColorSequence.new(w.gl or w.tr)}, blade)
		new("PointLight", {Color = w.gl or w.tr, Range = 10, Brightness = 1}, blade)
	end
	return m, handle, trail
end
local function equip(idx, silent)
	S.wpn = idx
	if RIG.wm then RIG.wm:Destroy(); RIG.wm = nil end
	if not RIG.hand then return end
	local m, handle, trail = buildWeapon(WPN[idx])
	new("Weld", {Part0 = RIG.hand, Part1 = handle, C0 = (RIG.r15 and CF(0, -.15, 0) or CF(0, -1.05, 0)) * ANG(-1, 0, 0)}, handle)
	m.Parent = RIG.char
	RIG.wm, RIG.trail = m, trail
	if not silent then sfx("equip") end
end
-- các tư thế vung tay (xoay quanh vai): a = giơ lên, b = chém xuống
local SW = {
	{a = ANG(2.9, 0, 0), b = ANG(.6, 0, 0), t1 = .08, t2 = .09},                          -- 1: bổ từ trên xuống
	{a = ANG(0, -1.3, 0) * ANG(1.5, 0, 0), b = ANG(0, 1, 0) * ANG(1.5, 0, 0), t1 = .08, t2 = .1}, -- 2: chém ngang
	{a = ANG(3.3, 0, 0), b = ANG(.3, 0, 0), t1 = .12, t2 = .1},                           -- 3: bổ mạnh
	{a = ANG(1.57, 0, 0), b = ANG(1.57, 0, 0), t1 = .05, t2 = .45},                       -- 4: dang tay xoay tròn
	{a = ANG(0, -1.5, 0) * ANG(1.5, 0, 0), b = ANG(0, 1.3, 0) * ANG(1.5, 0, 0), t1 = .1, t2 = .08}, -- 5: chém sóng kiếm
}
local swingTok = 0
local function swing(kind)
	local sh, base = RIG.sh, RIG.base
	if not sh or not base then return end
	local pv = CF(base.Position)
	local function pose(rot) return pv * rot * pv:Inverse() * base end
	swingTok += 1
	local tok, k = swingTok, SW[kind]
	task.spawn(function()
		tw(sh, k.t1, {C0 = pose(k.a)})
		task.wait(k.t1)
		if tok ~= swingTok then return end
		if RIG.trail then RIG.trail.Enabled = true end
		tw(sh, k.t2, {C0 = pose(k.b)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(k.t2 + .06)
		if tok ~= swingTok then return end
		tw(sh, .2, {C0 = base})
		task.wait(.14)
		if RIG.trail and tok == swingTok then RIG.trail.Enabled = false end
	end)
end
local function faceTo(pos)
	local r = getRoot()
	if r and dist2(r.Position, pos) > .1 then r.CFrame = CFrame.lookAt(r.Position, V3(pos.X, r.Position.Y, pos.Z)) end
end

----------------------------------------------------------------- HIỆU ỨNG (VFX)
local function fxPart(cf, size)
	return new("Part", {Size = size or V3(.2, .2, .2), Transparency = 1, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CFrame = cf}, FX)
end
local function burst(pos, col, n, spd, size, life) -- chùm tia lửa
	local p = fxPart(CF(pos))
	local e = new("ParticleEmitter", {Rate = 0, Lifetime = NumberRange.new(life * .6, life), Speed = NumberRange.new(spd * .5, spd), SpreadAngle = Vector2.new(180, 180), Drag = 4,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0)}), Color = ColorSequence.new(col), LightEmission = 1}, p)
	e:Emit(n)
	Debris:AddItem(p, life + .3)
end
local function ring(pos, col, r0, r1, dur, tr) -- sóng xung kích lan trên mặt đất
	local p = shape("c", V3(r0 * 2, .35, r0 * 2), col, MAT.Neon, tr or .35, true)
	put(p, CF(pos.X, pos.Y + .25, pos.Z)); p.Parent = FX
	tw(p, dur, {Size = V3(.15, r1 * 2, r1 * 2), Transparency = 1})
	Debris:AddItem(p, dur + .1)
end
local function beam(pos, col, h, w, dur) -- cột sáng
	local p = shape("c", V3(w, h, w), col, MAT.Neon, .3, true)
	put(p, CF(pos.X, pos.Y + h / 2, pos.Z)); p.Parent = FX
	tw(p, dur, {Size = V3(h, w * .2, w * .2), Transparency = 1})
	Debris:AddItem(p, dur + .1)
end
local function flashLight(pos, col, range, dur)
	local p = fxPart(CF(pos))
	local l = new("PointLight", {Color = col, Range = range, Brightness = 4}, p)
	tw(l, dur, {Brightness = 0})
	Debris:AddItem(p, dur + .1)
end
local function hitFlash(model)
	local h = new("Highlight", {FillColor = C3(255, 255, 255), FillTransparency = .25, OutlineTransparency = 1}, model)
	tw(h, .18, {FillTransparency = 1})
	Debris:AddItem(h, .22)
end
local function dmgText(pos, text, col, size) -- số sát thương bay lên
	local p = fxPart(CF(pos + V3(rnd(-1, 1), 0, rnd(-1, 1))))
	local bb = new("BillboardGui", {Size = U2(0, 140, 0, 44), AlwaysOnTop = true, LightInfluence = 0, Adornee = p}, p)
	local l = txt({Size = U2(1, 0, 1, 0), Text = text, TextColor3 = col, Font = FONTB, TextSize = size or 24}, bb)
	local st, sc = stroke(l, C3(25, 10, 15), 2.5), new("UIScale", {Scale = 1.8}, l)
	tw(sc, .2, {Scale = 1}, Enum.EasingStyle.Back)
	tw(bb, .8, {StudsOffsetWorldSpace = V3(rnd(-1.5, 1.5), 5, 0)})
	task.delay(.5, function() tw(l, .35, {TextTransparency = 1}); tw(st, .35, {Transparency = 1}) end)
	Debris:AddItem(p, 1)
end
local shakeT, shakeI = 0, 0
local function shake(i, d) shakeI = math.max(shakeI, i); shakeT = math.max(shakeT, d) end
local function fovPunch(a, t)
	tw(cam, t * .35, {FieldOfView = 70 + a})
	task.delay(t * .35, function() tw(cam, t * .65, {FieldOfView = 70}) end)
end
local BITS, COINS = {}, {}
local function debris(pos, col, n, spd) -- mảnh đá văng
	for _ = 1, n do
		local s, a = rnd(.5, 1.2), rnd(0, 2 * PI)
		local p = shape("b", V3(s, s, s), col, MAT.Slate, 0, true)
		p.CFrame = CF(pos) * ANG(rnd(0, 6), rnd(0, 6), 0); p.Parent = FX
		BITS[#BITS + 1] = {p = p, v = V3(math.cos(a) * rnd(.3, 1) * spd, rnd(.7, 1.3) * spd * .9, math.sin(a) * rnd(.3, 1) * spd), life = rnd(.9, 1.4), spin = V3(rnd(-8, 8), rnd(-8, 8), 0)}
	end
end
local function coins(pos, gold) -- tiền văng ra rồi bay về phía người chơi
	local n = math.clamp(3 + math.floor(gold / 40), 3, 14)
	for _ = 1, n do
		local p, a = shape("c", V3(.9, .14, .9), C3(255, 205, 60), MAT.Neon, 0, true), rnd(0, 2 * PI)
		p.Parent = FX
		COINS[#COINS + 1] = {p = p, pos = pos + V3(0, 2, 0), v = V3(math.cos(a) * rnd(6, 16), rnd(22, 36), math.sin(a) * rnd(6, 16)), t = 0, val = gold / n, ang = rnd(0, 6)}
	end
end
local lastCoin = 0
local function updateFx(dt, now, r, gy)
	for i = #BITS, 1, -1 do
		local b = BITS[i]
		b.life -= dt
		b.v = b.v - V3(0, 90 * dt, 0)
		local pos = b.p.Position + b.v * dt
		if pos.Y < gy + .3 then pos = V3(pos.X, gy + .3, pos.Z); b.v = V3(b.v.X * .5, math.abs(b.v.Y) * .25, b.v.Z * .5) end
		b.p.CFrame = CF(pos) * b.p.CFrame.Rotation * ANG(b.spin.X * dt, b.spin.Y * dt, 0)
		if b.life <= 0 then b.p:Destroy(); table.remove(BITS, i) end
	end
	for i = #COINS, 1, -1 do
		local c = COINS[i]
		c.t += dt; c.ang += dt * 9
		if c.t < .5 then
			c.v = c.v - V3(0, 80 * dt, 0)
			c.pos = c.pos + c.v * dt
			if c.pos.Y < gy + .6 then c.pos = V3(c.pos.X, gy + .6, c.pos.Z); c.v = V3(c.v.X * .6, math.abs(c.v.Y) * .35, c.v.Z * .6) end
		elseif r then
			local d = r.Position + V3(0, .5, 0) - c.pos
			if d.Magnitude < 2.4 then
				S.gold += c.val; S.ui = true
				if now - lastCoin > .04 then lastCoin = now; sfx("coin", nil, .8, 1 + math.min(.5, #COINS * .02), true) end
				c.p:Destroy(); table.remove(COINS, i)
				continue
			end
			c.pos = c.pos + d.Unit * (28 + (c.t - .5) * 90) * dt
		end
		c.p.CFrame = CF(c.pos) * ANG(0, c.ang, 0) -- đồng xu dựng đứng, xoay quanh trục Y
	end
end

----------------------------------------------------------------- GIAO DIỆN (UI)
local gui = new("ScreenGui", {Name = "HeroUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 10}, playerGui)
local root = new("Frame", {Size = U2(1, 0, 1, 0), BackgroundTransparency = 1}, gui)
local uiscale = new("UIScale", {}, root)
local function rescale()
	local s = math.clamp(cam.ViewportSize.Y / 560, .68, 1.3)
	uiscale.Scale = s
	root.Size = U2(1 / s, 0, 1 / s, 0)
end
rescale(); cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false); StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
local GOLD, INK, LEFT = C3(255, 205, 80), C3(214, 224, 255), Enum.TextXAlignment.Left
local function panel(p, parent, r)
	p.BackgroundColor3 = p.BackgroundColor3 or C3(16, 20, 44)
	p.BackgroundTransparency = p.BackgroundTransparency or .12
	local f = box(p, parent)
	corner(f, r or 12); stroke(f, C3(110, 130, 215), 1.5, .5)
	return f
end
local function button(p, parent, fn)
	p.AutoButtonColor, p.BorderSizePixel, p.Font = false, 0, p.Font or FONTB
	p.TextColor3, p.TextSize = p.TextColor3 or C3(255, 255, 255), p.TextSize or 15
	local b = new("TextButton", p, parent)
	local sc = new("UIScale", {}, b)
	b.MouseButton1Down:Connect(function() tw(sc, .07, {Scale = .92}) end)
	b.MouseButton1Up:Connect(function() tw(sc, .15, {Scale = 1}, Enum.EasingStyle.Back) end)
	b.MouseLeave:Connect(function() tw(sc, .15, {Scale = 1}) end)
	b.Activated:Connect(function() sfx("click"); if fn then fn() end end)
	return b
end
local HUD = {sk = {}}
-- bảng nhân vật (trái trên)
local pnl = panel({Position = U2(0, 10, 0, 8), Size = U2(0, 300, 0, 80)}, root, 14)
local badge = box({Position = U2(0, 8, 0, 9), Size = U2(0, 62, 0, 62), BackgroundColor3 = C3(255, 255, 255)}, pnl)
corner(badge, 31); grad(badge, C3(255, 226, 120), C3(255, 150, 50)); stroke(badge, C3(255, 255, 255), 2, .3)
txt({Position = U2(0, 0, 0, 7), Size = U2(1, 0, 0, 14), Text = "CẤP", TextSize = 11, Font = FONTB, TextColor3 = C3(90, 50, 10)}, badge)
HUD.lv = txt({Position = U2(0, 0, 0, 19), Size = U2(1, 0, 0, 36), Text = "1", TextSize = 30, Font = FONTB, TextColor3 = C3(70, 35, 5)}, badge)
txt({Position = U2(0, 80, 0, 3), Size = U2(1, -90, 0, 16), Text = player.DisplayName, TextSize = 13, Font = FONTB, TextXAlignment = LEFT, TextColor3 = INK}, pnl)
local function bar(y, h, c0, c1, ts)
	local bg = box({Position = U2(0, 80, 0, y), Size = U2(1, -90, 0, h), BackgroundColor3 = C3(8, 10, 24), ClipsDescendants = true}, pnl)
	corner(bg, h)
	local fill = box({Size = U2(1, 0, 1, 0), BackgroundColor3 = C3(255, 255, 255)}, bg)
	corner(fill, h); grad(fill, c0, c1, 90)
	return fill, txt({Size = U2(1, 0, 1, 0), TextSize = ts, Font = FONTB, TextStrokeTransparency = .55}, bg)
end
HUD.hpF, HUD.hpT = bar(21, 17, C3(255, 120, 120), C3(230, 50, 80), 12)
HUD.mpF, HUD.mpT = bar(41, 14, C3(120, 215, 255), C3(60, 120, 255), 11)
HUD.xpF, HUD.xpT = bar(59, 12, C3(190, 255, 140), C3(90, 210, 90), 9)
-- nhiệm vụ
local qp = panel({Position = U2(0, 10, 0, 94), Size = U2(0, 300, 0, 50)}, root, 12)
txt({Position = U2(0, 10, 0, 3), Size = U2(1, -20, 0, 16), Text = "📜 Nhiệm vụ", TextSize = 12, Font = FONTB, TextXAlignment = LEFT, TextColor3 = GOLD}, qp)
HUD.qT = txt({Position = U2(0, 10, 0, 19), Size = U2(1, -20, 0, 16), Text = "", TextSize = 13, TextXAlignment = LEFT}, qp)
local qbg = box({Position = U2(0, 10, 1, -10), Size = U2(1, -20, 0, 5), BackgroundColor3 = C3(8, 10, 24)}, qp)
corner(qbg, 3)
HUD.qF = box({Size = U2(0, 0, 1, 0), BackgroundColor3 = GOLD}, qbg)
corner(HUD.qF, 3)
-- vàng + tên bản đồ
local gp = panel({AnchorPoint = Vector2.new(1, 0), Position = U2(1, -10, 0, 8), Size = U2(0, 170, 0, 34)}, root, 17)
txt({Position = U2(0, 10, 0, 0), Size = U2(0, 26, 1, 0), Text = "💰", TextSize = 20}, gp)
HUD.gold = txt({Position = U2(0, 38, 0, 0), Size = U2(1, -48, 1, 0), Text = "0", TextSize = 18, Font = FONTB, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Right}, gp)
local zp = panel({AnchorPoint = Vector2.new(.5, 0), Position = U2(.5, 0, 0, 8), Size = U2(0, 250, 0, 30)}, root, 15)
HUD.zone = txt({Size = U2(1, 0, 1, 0), Text = "", TextSize = 14, Font = FONTB}, zp)
-- thanh máu boss
local bossF = panel({AnchorPoint = Vector2.new(.5, 0), Position = U2(.5, 0, 0, 46), Size = U2(0, 380, 0, 44), Visible = false}, root, 12)
HUD.bossN = txt({Position = U2(0, 0, 0, 3), Size = U2(1, 0, 0, 18), Text = "", Font = FONTB, TextSize = 15, TextColor3 = C3(255, 150, 150)}, bossF)
local bbg = box({Position = U2(0, 12, 0, 24), Size = U2(1, -24, 0, 14), BackgroundColor3 = C3(10, 8, 18)}, bossF)
corner(bbg, 7)
HUD.bossF = box({Size = U2(1, 0, 1, 0), BackgroundColor3 = C3(255, 255, 255)}, bbg)
corner(HUD.bossF, 7); grad(HUD.bossF, C3(255, 110, 100), C3(190, 20, 50))
HUD.bossFrame = bossF
-- nút chức năng bên phải
local function sideBtn(i, ic, key, fn)
	local b = button({AnchorPoint = Vector2.new(1, 0), Position = U2(1, -10, 0, 50 + (i - 1) * 54), Size = U2(0, 46, 0, 46), BackgroundColor3 = C3(30, 38, 78), Text = ic, TextSize = 22}, root, fn)
	corner(b, 23); stroke(b, C3(120, 140, 230), 2, .3)
	txt({Position = U2(0, 4, 1, -15), Size = U2(0, 14, 0, 14), Text = key, TextSize = 10, Font = FONTB, TextColor3 = INK}, b)
	return b
end
sideBtn(1, "🗺️", "M", function() A.open("map") end)
sideBtn(2, "🛒", "B", function() A.open("shop") end)
HUD.autoB = sideBtn(3, "🤖", "R", function() A.auto() end)
HUD.sndB = sideBtn(4, "🔊", "", function() S.sound = not S.sound; HUD.sndB.Text = S.sound and "🔊" or "🔇" end)
-- nút hành động (đánh, kỹ năng, bình thuốc)
local function actionBtn(cx, cy, size, ic, col, key, fn, held)
	local b = new("TextButton", {AnchorPoint = Vector2.new(.5, .5), Position = U2(1, cx, 1, cy), Size = U2(0, size, 0, size), BackgroundColor3 = C3(22, 28, 60), Text = "", AutoButtonColor = false, BorderSizePixel = 0}, root)
	corner(b, size); stroke(b, col, 3, .1)
	local sc = new("UIScale", {}, b)
	local cg = new("CanvasGroup", {Size = U2(1, 0, 1, 0), BackgroundTransparency = 1}, b)
	corner(cg, size)
	txt({Size = U2(1, 0, 1, 0), Text = ic, TextSize = size * .5}, cg)
	local ov = box({AnchorPoint = Vector2.new(0, 1), Position = U2(0, 0, 1, 0), Size = U2(1, 0, 0, 0), BackgroundColor3 = C3(0, 0, 0), BackgroundTransparency = .35}, cg)
	local cdT = txt({Size = U2(1, 0, 1, 0), Text = "", TextSize = size * .34, Font = FONTB, ZIndex = 3}, cg)
	local lock = box({Size = U2(1, 0, 1, 0), BackgroundColor3 = C3(10, 10, 20), BackgroundTransparency = .2, Visible = false, ZIndex = 4}, cg)
	local lockT = txt({Size = U2(1, 0, 1, 0), TextSize = size * .26, Font = FONTB, ZIndex = 5}, lock)
	txt({Position = U2(0, 5, 0, 2), Size = U2(0, 14, 0, 14), Text = key, TextSize = 11, Font = FONTB, TextColor3 = INK}, b)
	local function isPress(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end
	b.InputBegan:Connect(function(i) if isPress(i) then tw(sc, .07, {Scale = .9}); if held then S.held, S.hin = true, i else fn() end end end)
	b.InputEnded:Connect(function(i) if isPress(i) then tw(sc, .15, {Scale = 1}, Enum.EasingStyle.Back); if held then S.held = false end end end)
	return {b = b, ov = ov, cd = cdT, lock = lock, lockT = lockT}
end
actionBtn(-190, -62, 88, "⚔️", C3(255, 190, 80), "F", nil, true)
HUD.sk[1] = actionBtn(-292, -42, 62, SK[1].ic, SK[1].col, "Z", function() A.skill(1) end)
HUD.sk[2] = actionBtn(-270, -118, 62, SK[2].ic, SK[2].col, "X", function() A.skill(2) end)
HUD.sk[3] = actionBtn(-200, -168, 62, SK[3].ic, SK[3].col, "C", function() A.skill(3) end)
HUD.pb = actionBtn(-118, -182, 54, "🧪", C3(255, 110, 130), "Q", function() A.potion() end)
HUD.pot = txt({AnchorPoint = Vector2.new(1, 1), Position = U2(1, -2, 1, -2), Size = U2(0, 30, 0, 14), Text = "x3", TextSize = 12, Font = FONTB, TextStrokeTransparency = .3, ZIndex = 6}, HUD.pb.b)
-- thông báo nhỏ + biểu ngữ lớn
local toastBox = box({AnchorPoint = Vector2.new(.5, 1), Position = U2(.5, 0, 1, -16), Size = U2(0, 360, 0, 200), BackgroundTransparency = 1}, root)
new("UIListLayout", {VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, toastBox)
local toastN = 0
local function toast(text, col)
	toastN += 1
	local l = txt({Size = U2(1, 0, 0, 22), Text = text, TextColor3 = col or C3(255, 255, 255), Font = FONTB, TextSize = 16, TextTransparency = 1, LayoutOrder = toastN}, toastBox)
	local st = stroke(l, C3(15, 10, 25), 2, 1)
	tw(l, .2, {TextTransparency = 0}); tw(st, .2, {Transparency = 0})
	task.delay(2.3, function() tw(l, .4, {TextTransparency = 1}); tw(st, .4, {Transparency = 1}); task.wait(.45); l:Destroy() end)
end
local function banner(big, small, col, hold)
	local f = box({AnchorPoint = Vector2.new(.5, .5), Position = U2(.5, 0, .28, 0), Size = U2(0, 600, 0, 96), BackgroundTransparency = 1}, root)
	local a = txt({Size = U2(1, 0, 0, 54), Text = big, Font = FONTB, TextSize = 44, TextColor3 = col}, f)
	local b = txt({Position = U2(0, 0, 0, 56), Size = U2(1, 0, 0, 26), Text = small, TextSize = 18, Font = FONTB, TextColor3 = C3(235, 240, 255)}, f)
	local sa, sb, sc = stroke(a, C3(20, 10, 35), 3), stroke(b, C3(20, 10, 35), 2), new("UIScale", {Scale = .5}, f)
	tw(sc, .35, {Scale = 1}, Enum.EasingStyle.Back)
	task.delay(hold or 2, function()
		tw(sc, .3, {Scale = .9}); tw(a, .3, {TextTransparency = 1}); tw(b, .3, {TextTransparency = 1}); tw(sa, .3, {Transparency = 1}); tw(sb, .3, {Transparency = 1})
		task.wait(.35); f:Destroy()
	end)
end
-- nhiệm vụ: trả về trạng thái hiện tại
local function questState()
	local i = S.map
	if i == 0 then return end
	local m = MAPS[i]
	local q = S.qs[i]
	if not q then q = {step = 1, have = 0, round = 0}; S.qs[i] = q end
	local reg = q.step <= 3
	return q, reg and m.mobs[q.step] or m.boss, (reg and 8 + q.step * 2 + q.round * 4 or 1)
end
local function refresh()
	local mh, mm, nd = maxHP(), maxMP(), need(S.lv)
	HUD.lv.Text = tostring(S.lv)
	HUD.hpT.Text, HUD.mpT.Text = fmt(S.hp) .. " / " .. fmt(mh), fmt(S.mp) .. " / " .. fmt(mm)
	HUD.xpT.Text = S.lv >= CFG.MAXLV and "MAX" or fmt(S.exp) .. " / " .. fmt(nd) .. " EXP"
	tw(HUD.hpF, .2, {Size = U2(math.clamp(S.hp / mh, 0, 1), 0, 1, 0)})
	tw(HUD.mpF, .2, {Size = U2(math.clamp(S.mp / mm, 0, 1), 0, 1, 0)})
	tw(HUD.xpF, .3, {Size = U2(math.clamp(S.exp / nd, 0, 1), 0, 1, 0)})
	HUD.gold.Text, HUD.pot.Text = fmt(S.gold), "x" .. S.pots
	for i, sk in ipairs(SK) do HUD.sk[i].lock.Visible = S.lv < sk.lv; HUD.sk[i].lockT.Text = "Cấp " .. sk.lv end
	local q, key, nn = questState()
	if q then
		HUD.qT.Text = "Hạ " .. MOB[key].n .. "  " .. q.have .. "/" .. nn
		tw(HUD.qF, .25, {Size = U2(math.clamp(q.have / nn, 0, 1), 0, 1, 0)})
	end
end
-- cửa sổ (bản đồ, cửa hàng)
local WINS, curWin = {}, nil
local function window(key, title, w, h)
	local f = panel({AnchorPoint = Vector2.new(.5, .5), Position = U2(.5, 0, .5, 10), Size = U2(0, w, 0, h), BackgroundTransparency = .03, Visible = false, ZIndex = 20}, root, 18)
	local sc = new("UIScale", {Scale = .85}, f)
	txt({Position = U2(0, 18, 0, 8), Size = U2(1, -80, 0, 34), Text = title, Font = FONTB, TextSize = 22, TextXAlignment = LEFT}, f)
	corner(button({AnchorPoint = Vector2.new(1, 0), Position = U2(1, -10, 0, 8), Size = U2(0, 34, 0, 34), Text = "✕", TextSize = 16, BackgroundColor3 = C3(200, 60, 80)}, f, function() A.close() end), 17)
	local list = new("ScrollingFrame", {Position = U2(0, 12, 0, 52), Size = U2(1, -24, 1, -64), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5,
		CanvasSize = U2(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y}, f)
	new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, list)
	WINS[key] = {f = f, sc = sc, list = list, tok = 0}
end
window("map", "🗺️  Bản Đồ Phiêu Lưu", 540, 370)
window("shop", "🛒  Cửa Hàng", 540, 370)
function A.close()
	local k = curWin
	if not k then return end
	local w = WINS[k]
	curWin = nil; w.tok += 1
	local t = w.tok
	tw(w.sc, .12, {Scale = .85})
	task.delay(.12, function() if w.tok == t then w.f.Visible = false end end)
end
function A.open(key)
	if curWin == key then return A.close() end
	if curWin then A.close() end
	curWin = key
	local w = WINS[key]
	w.tok += 1
	A.fill[key]()
	w.sc.Scale = .85; w.f.Visible = true
	tw(w.sc, .22, {Scale = 1}, Enum.EasingStyle.Back)
	sfx("ping", nil, .6, 1.2)
end
local function clearList(l) for _, c in ipairs(l:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end end
local function card(list, order, h, bg, col, locked)
	local c = box({Size = U2(1, -6, 0, h), BackgroundColor3 = bg, LayoutOrder = order}, list)
	corner(c, 12); stroke(c, col, 2, locked and .75 or .2)
	return c
end
A.fill = {}
A.fill.map = function()
	local list = WINS.map.list
	clearList(list)
	for i, m in ipairs(MAPS) do
		local locked, here = S.lv < m.lv, S.map == i
		local c = card(list, i, 66, here and C3(44, 66, 124) or C3(28, 34, 68), m.col, locked)
		txt({Position = U2(0, 8, 0, 0), Size = U2(0, 50, 1, 0), Text = m.ic, TextSize = 32}, c)
		txt({Position = U2(0, 64, 0, 8), Size = U2(1, -200, 0, 22), Text = m.n, Font = FONTB, TextSize = 17, TextXAlignment = LEFT, TextColor3 = m.col}, c)
		txt({Position = U2(0, 64, 0, 33), Size = U2(1, -200, 0, 28), Text = "Cấp " .. m.lv .. "+ · Boss: " .. MOB[m.boss].n, TextSize = 12, TextXAlignment = LEFT, TextColor3 = C3(175, 185, 220), TextWrapped = true}, c)
		corner(button({AnchorPoint = Vector2.new(1, .5), Position = U2(1, -10, .5, 0), Size = U2(0, 118, 0, 38), TextSize = 14,
			Text = here and "Đang ở đây" or (locked and "🔒 Cấp " .. m.lv or "Dịch chuyển"), BackgroundColor3 = (here or locked) and C3(60, 66, 100) or C3(60, 170, 90)}, c,
			function()
				if here then return end
				if locked then sfx("deny"); toast("Cần đạt cấp " .. m.lv .. " để vào " .. m.n, C3(255, 120, 120))
				else A.close(); A.enterMap(i) end
			end), 10)
	end
end
A.fill.shop = function()
	local list = WINS.shop.list
	clearList(list)
	local pp = 20 + S.lv * 3
	local packs = {{1, 1}, {5, .9}, {20, .8}}
	for i, pk in ipairs(packs) do
		local price = math.floor(pp * pk[1] * pk[2])
		local c = card(list, i, 56, C3(28, 34, 68), C3(255, 110, 130), false)
		txt({Position = U2(0, 8, 0, 0), Size = U2(0, 46, 1, 0), Text = "🧪", TextSize = 28}, c)
		txt({Position = U2(0, 60, 0, 6), Size = U2(1, -190, 0, 22), Text = "Bình Hồi Phục x" .. pk[1], Font = FONTB, TextSize = 16, TextXAlignment = LEFT}, c)
		txt({Position = U2(0, 60, 0, 30), Size = U2(1, -190, 0, 18), Text = "Hồi 40% máu + 30% năng lượng", TextSize = 12, TextXAlignment = LEFT, TextColor3 = C3(175, 185, 220)}, c)
		corner(button({AnchorPoint = Vector2.new(1, .5), Position = U2(1, -10, .5, 0), Size = U2(0, 112, 0, 36), TextSize = 14, Text = fmt(price) .. " 💰", BackgroundColor3 = C3(200, 140, 40)}, c,
			function()
				if S.gold < price then sfx("deny"); return toast("Không đủ vàng!", C3(255, 120, 120)) end
				S.gold -= price; S.pots += pk[1]; S.ui = true; sfx("coin"); toast("Đã mua " .. pk[1] .. " bình hồi phục", C3(255, 170, 190)); A.fill.shop()
			end), 10)
	end
	for i, w in ipairs(WPN) do
		local own, eq, locked = S.own[i], S.wpn == i, S.lv < w.lv
		local c = card(list, 10 + i, 66, eq and C3(44, 66, 124) or C3(28, 34, 68), w.tr, locked and not own)
		local ic = box({Position = U2(0, 10, .5, -20), Size = U2(0, 40, 0, 40), BackgroundColor3 = w.bl}, c)
		corner(ic, 10); stroke(ic, w.gl or w.tr, 2, .1)
		txt({Size = U2(1, 0, 1, 0), Text = "🗡️", TextSize = 22}, ic)
		txt({Position = U2(0, 64, 0, 8), Size = U2(1, -200, 0, 22), Text = w.n, Font = FONTB, TextSize = 16, TextXAlignment = LEFT, TextColor3 = w.tr}, c)
		txt({Position = U2(0, 64, 0, 33), Size = U2(1, -200, 0, 20), Text = "⚔️ +" .. w.atk .. " sát thương · cần cấp " .. w.lv, TextSize = 12, TextXAlignment = LEFT, TextColor3 = C3(175, 185, 220)}, c)
		local label = eq and "Đang dùng" or (own and "Trang bị" or (locked and "🔒 Cấp " .. w.lv or fmt(w.price) .. " 💰"))
		corner(button({AnchorPoint = Vector2.new(1, .5), Position = U2(1, -10, .5, 0), Size = U2(0, 118, 0, 38), TextSize = 14, Text = label,
			BackgroundColor3 = eq and C3(60, 66, 100) or (own and C3(60, 150, 220) or (locked and C3(60, 66, 100) or C3(60, 170, 90)))}, c,
			function()
				if eq then return end
				if not own then
					if locked then sfx("deny"); return toast("Cần đạt cấp " .. w.lv, C3(255, 120, 120)) end
					if S.gold < w.price then sfx("deny"); return toast("Không đủ vàng!", C3(255, 120, 120)) end
					S.gold -= w.price; S.own[i] = true; sfx("coin"); toast("Đã mua " .. w.n .. "!", C3(255, 235, 150))
				end
				equip(i); S.ui = true; A.fill.shop()
			end), 10)
	end
end
-- lớp phủ: làm mờ chuyển cảnh, hồi sinh, viền máu, màn hình tải
local fade = box({Size = U2(1, 0, 1, 0), BackgroundColor3 = C3(0, 0, 0), BackgroundTransparency = 1, ZIndex = 100}, root)
local function fadeTo(a, t) tw(fade, t, {BackgroundTransparency = 1 - a}); task.wait(t) end
local deathF = box({Size = U2(1, 0, 1, 0), BackgroundColor3 = C3(90, 0, 12), BackgroundTransparency = 1, Visible = false, ZIndex = 60}, root)
txt({AnchorPoint = Vector2.new(.5, .5), Position = U2(.5, 0, .42, 0), Size = U2(1, 0, 0, 60), Text = "💀 BẠN ĐÃ GỤC NGÃ", Font = FONTB, TextSize = 40, TextColor3 = C3(255, 120, 120)}, deathF)
HUD.deathS = txt({AnchorPoint = Vector2.new(.5, .5), Position = U2(.5, 0, .52, 0), Size = U2(1, 0, 0, 30), TextSize = 18, Font = FONTB}, deathF)
local vig = new("CanvasGroup", {Size = U2(1, 0, 1, 0), BackgroundTransparency = 1, GroupTransparency = 1, ZIndex = 30}, root)
for _, e in ipairs({{U2(0, 0, 0, 0), U2(1, 0, .28, 0), 90}, {U2(0, 0, .72, 0), U2(1, 0, .28, 0), -90}, {U2(0, 0, 0, 0), U2(.2, 0, 1, 0), 0}, {U2(.8, 0, 0, 0), U2(.2, 0, 1, 0), 180}}) do
	new("UIGradient", {Transparency = NumberSequence.new(0, 1), Rotation = e[3]}, box({Position = e[1], Size = e[2], BackgroundColor3 = C3(255, 30, 40)}, vig))
end
local function vignette() vig.GroupTransparency = .2; tw(vig, .55, {GroupTransparency = 1}) end
local splash = new("CanvasGroup", {Size = U2(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 200}, root)
grad(box({Size = U2(1, 0, 1, 0), BackgroundColor3 = C3(255, 255, 255)}, splash), C3(34, 26, 78), C3(8, 10, 24), 90)
txt({AnchorPoint = Vector2.new(.5, .5), Position = U2(.5, 0, .36, 0), Size = U2(1, 0, 0, 60), Text = "⚔️ ANH HÙNG PHIÊU LƯU", Font = FONTB, TextSize = 46, TextColor3 = GOLD}, splash)
txt({AnchorPoint = Vector2.new(.5, .5), Position = U2(.5, 0, .47, 0), Size = U2(1, 0, 0, 30), Text = "Đánh quái · Farm cấp · Chinh phục 6 vùng đất", TextSize = 18, TextColor3 = INK}, splash)
local pbg = box({AnchorPoint = Vector2.new(.5, .5), Position = U2(.5, 0, .62, 0), Size = U2(0, 320, 0, 12), BackgroundColor3 = C3(40, 44, 84)}, splash)
corner(pbg, 6)
local pfill = box({Size = U2(0, 0, 1, 0), BackgroundColor3 = GOLD}, pbg)
corner(pfill, 6)
local ptxt = txt({AnchorPoint = Vector2.new(.5, .5), Position = U2(.5, 0, .68, 0), Size = U2(1, 0, 0, 24), Text = "Đang tải...", TextSize = 14, TextColor3 = INK}, splash)
local function progress(p, t) tw(pfill, .25, {Size = U2(p, 0, 1, 0)}); ptxt.Text = t end

----------------------------------------------------------------- NGƯỜI CHƠI: dịch chuyển, lên cấp, bị đánh, gục ngã
local mobs, cur = {}, nil
local function tpTo(pos)
	local ch, r = getChar(), getRoot()
	if ch and r then ch:PivotTo(CF(pos)); r.AssemblyLinearVelocity = V3() end
end
local function campPos() return V3(cur.center.X, cur.gy + 5, cur.center.Z + 12) end
local function levelFx()
	local r = getRoot()
	if not r then return end
	local p = r.Position - V3(0, 2.8, 0)
	beam(p, C3(255, 230, 120), 55, 5, 1)
	ring(p, C3(255, 215, 90), 2, 22, .8, .2)
	task.delay(.2, function() ring(p, C3(255, 255, 255), 2, 32, .7, .3) end)
	burst(r.Position, C3(255, 235, 140), 60, 40, 1.1, 1.2)
	flashLight(r.Position, C3(255, 230, 150), 40, .8)
	seq("ping", {1, 1.26, 1.5, 2}, .09, .7)
	fovPunch(8, .6)
end
local function gainExp(n)
	S.exp += n
	local up = false
	while S.lv < CFG.MAXLV and S.exp >= need(S.lv) do S.exp -= need(S.lv); S.lv += 1; up = true end
	if S.lv >= CFG.MAXLV then S.exp = 0 end
	if up then
		S.hp, S.mp = maxHP(), maxMP()
		levelFx()
		local sub = "Máu +24 · Năng lượng +6 · Sát thương +4"
		for _, sk in ipairs(SK) do if sk.lv == S.lv then sub = "Mở khoá kỹ năng: " .. sk.ic .. " " .. sk.n .. "!" end end
		banner("⬆ LÊN CẤP " .. S.lv, sub, GOLD, 2.4)
	end
	S.ui = true
end
local function hurtPlayer(dmg, from)
	local now = os.clock()
	if S.dead or now < S.inv then return end
	S.inv, S.lastHurt = now + .25, now
	dmg = math.max(1, math.floor(dmg * 100 / (100 + defense()) * rnd(.9, 1.1)))
	S.hp = math.max(0, S.hp - dmg); S.ui = true
	local r = getRoot()
	if r then
		dmgText(r.Position + V3(0, 2, 0), "-" .. fmt(dmg), C3(255, 90, 90), 26)
		burst(r.Position, C3(255, 70, 70), 10, 22, .6, .4)
		local d = from and flat(r.Position - from)
		if d and d.Magnitude > .1 then r.AssemblyLinearVelocity = d.Unit * 26 + V3(0, 14, 0) end
	end
	sfx("hurt", nil, .9); vignette(); shake(.5, .2)
	if S.hp <= 0 then A.die() end
end
function A.die()
	S.dead, S.auto, S.held = true, false, false
	HUD.autoB.BackgroundColor3 = C3(30, 38, 78)
	local h = getHum()
	if h then h.PlatformStand = true end
	deathF.Visible = true
	tw(deathF, .6, {BackgroundTransparency = .45})
	sfx("roar", nil, .8, 1.6)
	task.spawn(function()
		for i = 3, 1, -1 do HUD.deathS.Text = "Hồi sinh tại trại nghỉ sau " .. i .. " giây"; task.wait(1) end
		fadeTo(1, .3)
		local loss = math.floor(S.gold * .05)
		S.gold -= loss; S.hp, S.mp, S.dead = maxHP() * .6, maxMP() * .5, false
		local h2 = getHum()
		if h2 then h2.PlatformStand = false end
		tpTo(campPos())
		deathF.Visible, deathF.BackgroundTransparency = false, 1
		S.ui, S.inv = true, os.clock() + 2.5
		fadeTo(0, .4)
		if loss > 0 then toast("Mất " .. fmt(loss) .. " 💰 vì gục ngã", C3(255, 150, 150)) end
	end)
end
function A.auto()
	S.auto = not S.auto
	HUD.autoB.BackgroundColor3 = S.auto and C3(40, 160, 90) or C3(30, 38, 78)
	toast(S.auto and "🤖 Tự động đánh: BẬT" or "🤖 Tự động đánh: TẮT", S.auto and C3(150, 255, 170) or C3(220, 220, 230))
end
local function questKill(key)
	local q, qk, nn = questState()
	if not q or qk ~= key then return end
	q.have += 1
	if q.have >= nn then
		local d = MOB[key]
		local mul = d.boss and 8 or 1
		local g, e = nn * (20 + d.lv * 6) * mul, nn * (12 + d.lv * 8) * mul
		toast("✅ Hoàn thành nhiệm vụ!  +" .. fmt(g) .. " 💰  +" .. fmt(e) .. " EXP", C3(150, 255, 170))
		seq("ping", {1.2, 1.5, 1.8}, .1, .6)
		S.gold += g
		q.step += 1; q.have = 0
		if q.step > 4 then q.step = 1; q.round += 1 end
		gainExp(e)
	end
	S.ui = true
end

----------------------------------------------------------------- QUÁI VẬT: sinh ra, AI, boss, chết & rơi đồ
local function startTele(m) -- vòng đỏ báo hiệu đòn đập đất của boss
	local rad, gy = 12 + m.h * .5, m.pos.Y
	m.srad = rad
	local a = shape("c", V3(rad * 2, .2, rad * 2), C3(255, 40, 40), MAT.Neon, .72, true)
	put(a, CF(m.pos.X, gy + .15, m.pos.Z)); a.Parent = FX
	local b = shape("c", V3(1, .25, 1), C3(255, 100, 60), MAT.Neon, .4, true)
	put(b, CF(m.pos.X, gy + .2, m.pos.Z)); b.Parent = FX
	tw(b, 1, {Size = V3(.25, rad * 2, rad * 2)}, Enum.EasingStyle.Linear)
	m.tele = {a, b}
	sfx("roar", m.pos, 1, 1 + rnd(-.1, .1))
end
local function endTele(m) if m.tele then for _, p in ipairs(m.tele) do p:Destroy() end; m.tele = nil end end
local function spawnMob(key, pos)
	local d = MOB[key]
	local list, hgt = TPL[d.t](d)
	local sc = d.sc or 1
	local model, J, rootP = assemble(list, sc)
	local h, lv = hgt * sc, d.lv
	local hp = math.floor((30 + 5 * lv ^ 1.65) * (d.hp or 1))
	local m = {key = key, d = d, model = model, J = J, root = rootP, pos = pos, home = pos, yaw = rnd(0, 2 * PI), ph = rnd(0, 10), mv = 0, lunge = 0, state = "idle", wt = 0, wp = pos,
		maxhp = hp, hp = hp, lv = lv, h = h, rad = h * .28 + 1, kind = KIND[d.t], sp = d.sp or 11, ag = d.boss and 60 or 36, leash = d.boss and 150 or 70, reach = 2.6 + h * .34,
		dmg = (6 + lv * 3.2) * (d.dm or 1), cd = 0, kv = V3(), slot = rnd(0, 2 * PI), boss = d.boss, slamCD = 0, col = d.c or d.cap or d.e or C3(255, 240, 200)}
	local bb = new("BillboardGui", {Size = U2(0, 150, 0, 36), StudsOffset = V3(0, h + 1.5, 0), MaxDistance = d.boss and 240 or 120, LightInfluence = 0, Adornee = rootP}, rootP)
	local lc = lv > S.lv + 4 and C3(255, 120, 120) or (lv >= S.lv - 3 and C3(255, 235, 150) or C3(170, 255, 175))
	txt({Size = U2(1, 0, 0, 17), Text = (d.boss and "👑 " or "") .. d.n .. "  Lv." .. lv, Font = FONTB, TextSize = 13, TextColor3 = lc, TextStrokeTransparency = .3}, bb)
	local back = box({Position = U2(0, 4, 0, 21), Size = U2(1, -8, 0, 9), BackgroundColor3 = C3(14, 10, 20)}, bb)
	corner(back, 5); stroke(back, C3(0, 0, 0), 1.5, .3)
	m.bar = box({Size = U2(1, 0, 1, 0), BackgroundColor3 = C3(255, 255, 255)}, back)
	corner(m.bar, 5); grad(m.bar, C3(255, 150, 150), C3(220, 40, 70))
	m.bb = bb
	rootP.CFrame = CF(pos) * ANG(0, m.yaw, 0)
	model.Parent = MOBS
	mobs[#mobs + 1] = m
	return m
end
local function updateMob(m, dt, now, pp, alive)
	local pos, c = m.pos, cur.center
	if m.kv.Magnitude > .2 then pos = pos + m.kv * dt; m.kv = m.kv * math.max(0, 1 - dt * 7) end
	local dp = pp and dist2(pos, pp) or 1e9
	local inCamp = pp ~= nil and dist2(pp, c) < CFG.CAMP + 3
	local hd = dist2(pos, m.home)
	local spd, mvT = m.sp * (m.rage and 1.3 or 1), 0
	local function walk(tgt, s)
		local dv = flat(tgt - pos)
		local len = dv.Magnitude
		if len > .3 then
			local dir = dv / len
			pos = pos + dir * math.min(s * dt, len)
			m.yawT, mvT = math.atan2(-dir.X, -dir.Z), 1
		end
	end
	local st = m.state
	if st == "idle" then
		if alive and not inCamp and dp < m.ag then m.state = "chase"
		else
			if now > m.wt then m.wt = now + rnd(2, 5); local a = rnd(0, 2 * PI); m.wp = m.home + V3(math.cos(a), 0, math.sin(a)) * rnd(0, 12) end
			if dist2(pos, m.wp) > 1 then walk(m.wp, spd * .35); mvT = .5 end
		end
	elseif st == "chase" then
		if not alive or inCamp or hd > m.leash then m.state = "back"
		elseif now >= m.cd and (dp <= m.reach * .95 or (m.boss and dp < 30 and now >= m.slamCD)) then
			m.state, m.at, m.hit = "atk", 0, false
			m.slam = m.boss and now >= m.slamCD and (dp > m.reach * .95 or rng:NextNumber() < .5)
			if m.slam then m.slamCD = now + rnd(7, 10); startTele(m) end
			m.yawT = math.atan2(-(pp.X - pos.X), -(pp.Z - pos.Z))
		else
			local tgt = pp
			if dp < 16 then tgt = pp + V3(math.cos(m.slot), 0, math.sin(m.slot)) * m.reach * .8 end
			walk(tgt, spd)
		end
	elseif st == "atk" then
		m.at += dt / (m.slam and 2 or (m.boss and 1.1 or .9))
		if alive and not m.slam and m.at < .5 then m.yawT = math.atan2(-(pp.X - pos.X), -(pp.Z - pos.Z)) end
		m.lunge = (not m.slam and m.at > .45 and m.at < .8) and math.sin((m.at - .45) / .35 * PI) * 1.8 or 0
		if m.at >= .5 and not m.hit then
			m.hit = true
			if m.slam then
				endTele(m)
				ring(pos, C3(255, 90, 60), 2, m.srad, .5, .3)
				burst(pos + V3(0, 1, 0), C3(255, 160, 80), 30, 36, 1.2, .6)
				debris(pos + V3(0, 1, 0), C3(110, 100, 110), 6, 26)
				sfx("boom", pos, 1, .8); shake(.9, .35)
				if alive and dist2(pp, pos) < m.srad then hurtPlayer(m.dmg * 2.2, pos) end
			else
				sfx("whoosh", pos, .7, 1 + rnd(-.1, .1))
				if alive and dist2(pp, pos) <= m.reach * 1.45 then hurtPlayer(m.dmg, pos) end
			end
		end
		if m.at >= 1 then m.at, m.lunge, m.slam, m.state, m.cd = nil, 0, false, "chase", now + (m.boss and 1.3 or rnd(1.1, 1.7)) end
	else -- về nhà hồi máu
		walk(m.home, spd * 1.6)
		m.hp = math.min(m.maxhp, m.hp + m.maxhp * .2 * dt)
		if hd < 2 then m.state, m.hp = "idle", m.maxhp; tw(m.bar, .3, {Size = U2(1, 0, 1, 0)}) end
		if alive and not inCamp and dp < m.ag * .6 and hd < m.leash * .5 then m.state = "chase" end
	end
	local off = flat(pos - c)
	if off.Magnitude > CFG.R - 8 then local p2 = c + off.Unit * (CFG.R - 8); pos = V3(p2.X, pos.Y, p2.Z) end
	if m.yawT then m.yaw = m.yaw + ((m.yawT - m.yaw + PI) % (2 * PI) - PI) * math.min(1, dt * 10) end
	m.mv = m.mv + (mvT - m.mv) * math.min(1, dt * 8)
	m.pos = pos
end
local function killMob(m)
	m.dead = true
	endTele(m)
	for i, x in ipairs(mobs) do if x == m then table.remove(mobs, i); break end end
	if S.boss == m then S.boss = nil end
	local p, lv, boss = m.pos, m.lv, m.boss
	m.bb.Enabled = false
	sfx("mdie", p)
	burst(p + V3(0, m.h * .5, 0), m.col, 30, 32, 1.1, .8)
	ring(p, m.col, 1, m.h * .9 + 3, .55, .4)
	for _, x in ipairs(m.model:GetDescendants()) do
		if x:IsA("BasePart") and x ~= m.root then tw(x, .55, {Transparency = 1}) end
	end
	Debris:AddItem(m.model, .8)
	local xp = math.floor((12 + lv * 8) * (boss and 10 or 1) * math.clamp(1 - (S.lv - lv - 6) * .1, .2, 1))
	local gold = math.floor((4 + lv * 2.2) * rnd(.8, 1.25) * (boss and 12 or 1))
	dmgText(p + V3(0, m.h + 1, 0), "+" .. fmt(xp) .. " EXP", C3(150, 255, 150), 20)
	coins(p, gold)
	toast(("+%s EXP   +%s 💰"):format(fmt(xp), fmt(gold)), C3(255, 235, 150))
	if rng:NextNumber() < (boss and 1 or .07) then
		S.pots += boss and 3 or 1
		toast("🧪 Nhặt được bình hồi phục" .. (boss and " x3" or "") .. "!", C3(255, 170, 190))
	end
	if boss then banner("👑 HẠ BOSS!", m.d.n, C3(255, 215, 90), 2.6); shake(1.2, .6); seq("ping", {1, 1.25, 1.5, 1.9}, .09, .8) end
	gainExp(xp)
	questKill(m.key)
	local ep, key, home = S.epoch, m.key, m.home
	task.delay(boss and 60 or rnd(9, 14), function() -- hồi sinh
		if S.epoch ~= ep then return end
		local nm = spawnMob(key, home)
		if boss then S.boss = nm end
	end)
end
local function hitMob(m, dmg, crit, from)
	if m.dead then return end
	dmg = math.max(1, math.floor(dmg))
	m.hp -= dmg
	tw(m.bar, .18, {Size = U2(math.clamp(m.hp / m.maxhp, 0, 1), 0, 1, 0)})
	dmgText(m.pos + V3(0, m.h * .8, 0), fmt(dmg) .. (crit and "!" or ""), crit and C3(255, 205, 70) or C3(255, 255, 255), crit and 34 or 24)
	sfx(crit and "crit" or "hit", m.pos)
	hitFlash(m.model)
	burst(m.pos + V3(0, m.h * .55, 0), crit and C3(255, 210, 90) or C3(255, 255, 255), crit and 16 or 8, 26, .7, .35)
	local d = flat(m.pos - from)
	if d.Magnitude > .1 then m.kv = m.kv + d.Unit * (m.boss and 3 or 11) end
	if m.state == "idle" or m.state == "back" then m.state = "chase" end
	if m.boss and not m.rage and m.hp < m.maxhp * .5 then
		m.rage = true
		sfx("roar", m.pos); shake(.8, .4); toast("⚠️ " .. m.d.n .. " nổi điên!", C3(255, 120, 100))
		new("Highlight", {FillColor = C3(255, 40, 40), FillTransparency = .8, OutlineColor = C3(255, 60, 60), OutlineTransparency = .3}, m.model)
	end
	if m.hp <= 0 then killMob(m) end
end
local function spawnAll(mp)
	local c, R = mp.center, CFG.R
	for _, key in ipairs(mp.mobs) do
		for _ = 1, 5 do
			local a, d = rnd(0, 2 * PI), rnd(40, R - 18)
			local p = V3(c.X + math.cos(a) * d, mp.gy, c.Z + math.sin(a) * d)
			if dist2(p, mp.bossPos) < 26 then p = V3(c.X - math.cos(a) * d, mp.gy, c.Z - math.sin(a) * d) end
			spawnMob(key, p)
		end
	end
	S.boss = spawnMob(mp.boss, mp.bossPos)
end
local function updateMobs(dt, now, r)
	local pp, alive = r and r.Position, r ~= nil and not S.dead
	for i = #mobs, 1, -1 do
		local m = mobs[i]
		if m and (m.state ~= "idle" or not pp or dist2(m.pos, pp) < 170) then
			updateMob(m, dt, now, pp, alive)
			animate(m, now)
		end
	end
end

----------------------------------------------------------------- CHIẾN ĐẤU: đánh thường, 3 kỹ năng, bình thuốc, tự động farm
local function nearestMob(pos, range, noBoss)
	local best, bd = nil, range
	for _, m in ipairs(mobs) do
		local d = dist2(m.pos, pos) - m.rad
		if d < bd and not (noBoss and m.boss) then best, bd = m, d end
	end
	return best
end
local function rollDmg(mult)
	local crit = rng:NextNumber() < .12
	return atkDmg() * mult * rnd(.9, 1.1) * (crit and 1.8 or 1), crit
end
local function slashFx(r, k, col)
	local p = shape("b", V3(9, .45, .45), col, MAT.Neon, .15, true)
	p.CFrame = r.CFrame * CF(0, .8, -5) * ANG(0, 0, ({.9, -.6, 1.3})[k])
	p.Parent = FX
	tw(p, .2, {Size = V3(k == 3 and 16 or 13, .08, .08), Transparency = 1})
	Debris:AddItem(p, .3)
	burst(r.Position + r.CFrame.LookVector * 5 + V3(0, 1, 0), col, 6, 20, .5, .3)
end
function A.attack()
	local now, r = os.clock(), getRoot()
	if S.dead or S.busy or not r or now < S.atkCD then return end
	S.atkCD = now + .42
	S.combo = (now - S.lastAtk > 1.3) and 1 or S.combo % 3 + 1
	S.lastAtk = now
	local k = S.combo
	local t = nearestMob(r.Position, 16)
	if t then faceTo(t.pos) end
	swing(k)
	sfx(k == 3 and "lunge" or "slash", nil, .9)
	if k == 3 then r.AssemblyLinearVelocity = r.CFrame.LookVector * 22 + V3(0, r.AssemblyLinearVelocity.Y, 0) end
	task.delay(.12, function()
		local r2 = getRoot()
		if not r2 or S.dead then return end
		local p0, look = r2.Position, flat(r2.CFrame.LookVector)
		slashFx(r2, k, WPN[S.wpn].tr)
		local n = 0
		for _, m in ipairs(table.clone(mobs)) do
			local dv = flat(m.pos - p0)
			local d = dv.Magnitude
			if d - m.rad * .7 < 10 and (d < 5 or dv.Unit:Dot(look) > .15) then
				local dmg, crit = rollDmg(k == 3 and 1.6 or 1)
				hitMob(m, dmg, crit, p0)
				n += 1
				if n >= 6 then break end
			end
		end
		if n > 0 and k == 3 then shake(.4, .15) end
	end)
end
local PROJ = {}
local function skillSpin() -- Chém Xoáy: xoay tròn chém mọi thứ xung quanh
	local r, h = getRoot(), getHum()
	if not r then return end
	swing(4)
	sfx("lunge", nil, 1.1, .9); sfx("whoosh", nil, .8, .8)
	if h then h.AutoRotate = false end
	local col, t0 = SK[1].col, os.clock()
	local y0 = math.atan2(-r.CFrame.LookVector.X, -r.CFrame.LookVector.Z)
	ring(r.Position - V3(0, 2.8, 0), col, 3, 15, .5, .3)
	task.spawn(function()
		local hits = 0
		while true do
			local el, r2 = os.clock() - t0, getRoot()
			if el >= .5 or not r2 then break end
			r2.CFrame = CF(r2.Position) * ANG(0, y0 + el / .5 * 2 * PI, 0)
			if hits < 3 and el >= .12 + hits * .14 then
				hits += 1
				burst(r2.Position, col, 12, 28, .7, .35)
				ring(r2.Position - V3(0, 2.8, 0), col, 4, 14 + hits, .3, .45)
				for _, m in ipairs(table.clone(mobs)) do
					if dist2(m.pos, r2.Position) - m.rad < 14 then
						local dmg, crit = rollDmg(.95)
						hitMob(m, dmg, crit, r2.Position)
					end
				end
			end
			RunService.Heartbeat:Wait()
		end
		local h2 = getHum()
		if h2 then h2.AutoRotate = true end
	end)
end
local function skillWave() -- Kiếm Khí: phóng sóng kiếm xuyên qua kẻ địch
	local r = getRoot()
	if not r then return end
	local t = nearestMob(r.Position, 30)
	if t then faceTo(t.pos) end
	swing(5)
	sfx("lunge", nil, 1, 1.3); sfx("whoosh", nil, .8, 1.1)
	local col = SK[2].col
	task.delay(.14, function()
		local r2 = getRoot()
		if not r2 then return end
		local dir = flat(r2.CFrame.LookVector).Unit
		local pos = r2.Position + dir * 4 - V3(0, .3, 0)
		local p = shape("c", V3(3.4, .5, 7), col, MAT.Neon, .1, true) -- đĩa mỏng 7 x 3.4, trục hướng về phía trước
		p.CFrame = CFrame.lookAt(pos, pos + dir) * ANG(0, PI / 2, 0)
		p.Parent = FX
		new("PointLight", {Color = col, Range = 18, Brightness = 3}, p)
		new("ParticleEmitter", {Rate = 70, Lifetime = NumberRange.new(.3, .5), Speed = NumberRange.new(2, 6), SpreadAngle = Vector2.new(180, 180), LightEmission = 1,
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, .8), NumberSequenceKeypoint.new(1, 0)}), Color = ColorSequence.new(col)}, p)
		PROJ[#PROJ + 1] = {p = p, dir = dir, pos = pos, life = .9, hit = {}}
	end)
end
local function updateProj(dt)
	for i = #PROJ, 1, -1 do
		local q = PROJ[i]
		q.life -= dt
		q.pos = q.pos + q.dir * 85 * dt
		q.p.CFrame = CFrame.lookAt(q.pos, q.pos + q.dir) * ANG(0, PI / 2, 0)
		for _, m in ipairs(table.clone(mobs)) do
			if not q.hit[m] and dist2(m.pos, q.pos) - m.rad < 5 then
				q.hit[m] = true
				local dmg, crit = rollDmg(2.4)
				hitMob(m, dmg, crit, q.pos - q.dir * 5)
				burst(q.pos, SK[2].col, 14, 30, .8, .4)
			end
		end
		if q.life <= 0 then
			burst(q.pos, SK[2].col, 14, 20, .8, .4)
			q.p:Destroy(); table.remove(PROJ, i)
		end
	end
end
local function skillSlam() -- Địa Chấn: nhảy lên rồi đập xuống tạo sóng xung kích
	local r = getRoot()
	if not r then return end
	local t = nearestMob(r.Position, 24)
	if t then faceTo(t.pos) end
	swing(3)
	sfx("lunge", nil, 1, .7)
	r.AssemblyLinearVelocity = V3(0, 62, 0)
	local col = SK[3].col
	task.delay(.42, function()
		local r2, hh = getRoot(), getHum()
		if not r2 then return end
		r2.AssemblyLinearVelocity = V3(0, -110, 0)
		local t0 = os.clock()
		while os.clock() - t0 < .35 and not (hh and hh.FloorMaterial ~= Enum.Material.Air) do task.wait() end
		local r3 = getRoot()
		if not r3 then return end
		local p = r3.Position - V3(0, 2.8, 0)
		sfx("boom", nil, 1, .8); shake(1.1, .45); fovPunch(10, .5)
		ring(p, col, 3, 26, .55, .25)
		task.delay(.12, function() ring(p, C3(255, 230, 160), 2, 20, .5, .3) end)
		burst(p + V3(0, 1, 0), col, 40, 44, 1.2, .7)
		flashLight(p + V3(0, 3, 0), col, 36, .5)
		debris(p + V3(0, 1, 0), cur.pal.rock, 12, 40)
		for _, m in ipairs(table.clone(mobs)) do
			if dist2(m.pos, p) - m.rad < 24 then
				local dmg, crit = rollDmg(3.2)
				hitMob(m, dmg, crit, p)
			end
		end
	end)
end
local SKF = {skillSpin, skillWave, skillSlam}
function A.skill(i)
	local sk, now = SK[i], os.clock()
	if S.dead or S.busy then return end
	if S.lv < sk.lv then sfx("deny"); return toast("Mở khoá kỹ năng ở cấp " .. sk.lv, C3(255, 150, 150)) end
	if now < S.cd[i] then return end
	if S.mp < sk.mp then sfx("deny"); return toast("Không đủ năng lượng!", C3(130, 190, 255)) end
	S.mp -= sk.mp; S.cd[i] = now + sk.cd; S.ui = true
	SKF[i]()
end
function A.potion()
	local now = os.clock()
	if S.dead or now < S.potCD then return end
	if S.pots <= 0 then sfx("deny"); return toast("Hết bình! Mua thêm ở 🛒 Cửa hàng", C3(255, 150, 150)) end
	if S.hp >= maxHP() and S.mp >= maxMP() then return toast("Máu và năng lượng đã đầy", C3(200, 210, 230)) end
	S.pots -= 1; S.potCD = now + 1.5
	local hp = maxHP() * .4
	S.hp, S.mp = math.min(maxHP(), S.hp + hp), math.min(maxMP(), S.mp + maxMP() * .3)
	S.ui = true
	sfx("potion"); seq("ping", {1.3, 1.7}, .08, .5)
	local r = getRoot()
	if r then
		dmgText(r.Position + V3(0, 2, 0), "+" .. fmt(hp), C3(120, 255, 150), 26)
		burst(r.Position, C3(120, 255, 160), 20, 14, .8, .8)
		ring(r.Position - V3(0, 2.8, 0), C3(120, 255, 160), 1, 7, .5, .4)
	end
end
local function autoFarm(now, r, hum)
	if S.hp < maxHP() * .35 and S.pots > 0 then A.potion() end
	local t = nearestMob(r.Position, 120, S.lv < MOB[cur.boss].lv - 2) -- tự đánh không lao vào boss quá mạnh
	if not t then return end
	local d = dist2(t.pos, r.Position) - t.rad
	if d > 6 then hum:MoveTo(t.pos); return end
	hum:MoveTo(r.Position)
	A.attack()
	for i = 3, 1, -1 do
		if S.lv >= SK[i].lv and now >= S.cd[i] and S.mp >= SK[i].mp + 8 and d < (i == 2 and 24 or 12) then A.skill(i); break end
	end
end

----------------------------------------------------------------- CHUYỂN BẢN ĐỒ
local function clearMobs()
	for _, m in ipairs(mobs) do endTele(m); m.model:Destroy() end
	mobs, S.boss = {}, nil
	for _, c in ipairs(COINS) do c.p:Destroy() end
	for _, b in ipairs(BITS) do b.p:Destroy() end
	for _, q in ipairs(PROJ) do q.p:Destroy() end
	COINS, BITS, PROJ = {}, {}, {}
end
function A.enterMap(i, first)
	if S.busy then return end
	S.busy = true
	local mp = MAPS[i]
	if not first then sfx("whoosh"); fadeTo(1, .35) end
	S.epoch = (S.epoch or 0) + 1
	clearMobs()
	if cur then MAPST[S.map].folder.Parent = nil end
	if not mp.built then buildMap(i, progress) end
	MAPST[i].folder.Parent = workspace
	cur, S.map = mp, i
	applyLighting(mp)
	tpTo(campPos())
	spawnAll(mp)
	HUD.zone.Text, HUD.zone.TextColor3 = mp.ic .. " " .. mp.n .. " · Cấp " .. mp.lv .. "+", mp.col
	S.ui = true
	if not first then task.wait(.15); fadeTo(0, .5) end
	banner(mp.ic .. " " .. mp.n, "Cấp đề nghị " .. mp.lv .. "+", mp.col, 2.2)
	S.busy = false
end
player.CharacterAdded:Connect(function(ch) -- người chơi bấm Reset → gắn lại vũ khí, về trại
	bindChar(ch)
	equip(S.wpn, true)
	if cur then task.wait(.2); tpTo(campPos()); S.hp = math.max(S.hp, maxHP() * .5); S.ui = true end
end)

----------------------------------------------------------------- ĐIỀU KHIỂN + VÒNG LẶP CHÍNH
UIS.InputBegan:Connect(function(i, gpe)
	if gpe or UIS:GetFocusedTextBox() then return end
	local k = i.KeyCode
	if i.UserInputType == Enum.UserInputType.MouseButton1 or k == Enum.KeyCode.F then S.held = true
	elseif k == Enum.KeyCode.Z then A.skill(1)
	elseif k == Enum.KeyCode.X then A.skill(2)
	elseif k == Enum.KeyCode.C then A.skill(3)
	elseif k == Enum.KeyCode.Q then A.potion()
	elseif k == Enum.KeyCode.R then A.auto()
	elseif k == Enum.KeyCode.M then A.open("map")
	elseif k == Enum.KeyCode.B then A.open("shop") end
end)
UIS.InputEnded:Connect(function(i)
	if i == S.hin or i.UserInputType == Enum.UserInputType.MouseButton1 or i.KeyCode == Enum.KeyCode.F then S.held = false end
end)
player.CameraMaxZoomDistance = 80
local TARGET = shape("c", V3(5, .15, 5), C3(255, 170, 60), MAT.Neon, 1, true) -- vòng khoanh quái đang nhắm
TARGET.Parent = FX
local uiT = 0
RunService.Heartbeat:Connect(function(dt)
	if not cur then return end
	local now = os.clock()
	local r, hum = getRoot(), getHum()
	if r and not S.dead and not S.busy then
		local inCamp = dist2(r.Position, cur.center) < CFG.CAMP + 2
		S.hp = math.min(maxHP(), S.hp + maxHP() * (inCamp and .06 or (now - (S.lastHurt or 0) > 6 and .01 or 0)) * dt)
		S.mp = math.min(maxMP(), S.mp + maxMP() * (inCamp and .1 or .035) * dt)
		S.ui = true
		if S.auto and hum then autoFarm(now, r, hum) end
		if S.held then A.attack() end
		if r.Position.Y < cur.gy - 60 then tpTo(campPos()) end
	end
	updateMobs(dt, now, r)
	local tg = r and not S.dead and nearestMob(r.Position, 18)
	if tg then
		local d = tg.rad * 2 + 2
		TARGET.Size, TARGET.Transparency = V3(.15, d, d), .55
		put(TARGET, CF(tg.pos.X, tg.pos.Y + .2, tg.pos.Z))
	else TARGET.Transparency = 1 end
	updateProj(dt)
	updateFx(dt, now, r, cur.gy)
	for _, p in ipairs(MAPST[S.map].spin) do p.CFrame = p.CFrame * ANG(0, dt * 1.2, 0) end
	WXP.CFrame = CF(cam.CFrame.Position + V3(0, WXH, 0))
	local b = S.boss -- thanh máu boss
	if b and not b.dead and r and dist2(b.pos, r.Position) < 90 then
		if not HUD.bossFrame.Visible then
			HUD.bossFrame.Visible = true
			HUD.bossN.Text = "👑 " .. b.d.n .. "  Lv." .. b.lv
			if not b.warned then b.warned = true; banner("⚠️ BOSS", b.d.n, C3(255, 100, 90), 1.8); sfx("roar") end
		end
		HUD.bossF.Size = U2(math.clamp(b.hp / b.maxhp, 0, 1), 0, 1, 0)
	elseif HUD.bossFrame.Visible then HUD.bossFrame.Visible = false end
	for i, sk in ipairs(SK) do -- hồi chiêu
		local u, rem = HUD.sk[i], S.cd[i] - now
		if rem > 0 then
			u.ov.Size = U2(1, 0, math.clamp(rem / sk.cd, 0, 1), 0)
			u.cd.Text = rem >= 1 and tostring(math.ceil(rem)) or string.format("%.1f", rem)
		elseif u.cd.Text ~= "" then u.ov.Size = U2(1, 0, 0, 0); u.cd.Text = "" end
	end
	local pr = S.potCD - now
	HUD.pb.ov.Size = U2(1, 0, pr > 0 and math.clamp(pr / 1.5, 0, 1) or 0, 0)
	uiT += dt
	if S.ui and uiT > .2 then uiT, S.ui = 0, false; refresh() end
end)
RunService.RenderStepped:Connect(function(dt) -- rung màn hình
	local h = getHum()
	if not h then return end
	if shakeT > 0 then shakeT -= dt; h.CameraOffset = V3(rnd(-1, 1), rnd(-1, 1), rnd(-.5, .5)) * shakeI
	elseif shakeI > 0 then shakeI = 0; h.CameraOffset = V3() end
end)

----------------------------------------------------------------- KHỞI ĐỘNG
task.spawn(function()
	local ch = player.Character or player.CharacterAdded:Wait()
	bindChar(ch)
	equip(1, true)
	progress(.1, "Chuẩn bị nhân vật...")
	A.enterMap(1, true)
	refresh()
	progress(1, "Sẵn sàng phiêu lưu!")
	task.wait(.5)
	tw(splash, .8, {GroupTransparency = 1})
	task.delay(.9, function() splash:Destroy() end)
	toast("Giữ nút ⚔️ để đánh · bấm 🤖 để tự động farm", C3(255, 235, 150))
end)
