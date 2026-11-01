--!strict
-- แกนต่อสู้ที่ผู้เล่นและ NPC ใช้ร่วมกัน (ไม่ผูกกับ Remote)
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local Passives = require(ReplicatedStorage.Shared.Passives)
local CombatState = require(script.Parent.CombatState)

export type HitOpts = {
	Pierce: boolean?,
	Stun: number?,
	Knockdown: number?,
	Knockback: number?,
	Root: number?,
	Slow: number?,
	SlowTime: number?,
	Final: boolean?,
}

local Combat = {}

local states: { [Model]: CombatState.CombatState } = {}
local feedback: RemoteEvent? = nil
local hitListeners: { (CombatState.CombatState, CombatState.CombatState, number) -> () } = {}
local killListeners: { (CombatState.CombatState, CombatState.CombatState) -> () } = {}

function Combat.SetFeedbackRemote(remote: RemoteEvent)
	feedback = remote
end

function Combat.OnHit(fn: (CombatState.CombatState, CombatState.CombatState, number) -> ())
	table.insert(hitListeners, fn)
end

function Combat.OnKill(fn: (CombatState.CombatState, CombatState.CombatState) -> ())
	table.insert(killListeners, fn)
end

-- เหตุการณ์ทั่วไป (เช่น "Ultimate") สำหรับเควส/สถิติ
local eventListeners: { (string, CombatState.CombatState) -> () } = {}
function Combat.OnEvent(fn: (string, CombatState.CombatState) -> ())
	table.insert(eventListeners, fn)
end
function Combat.Emit(name: string, s: CombatState.CombatState)
	for _, fn in eventListeners do
		task.spawn(fn, name, s)
	end
end

-- ผลักตัวละคร: ผู้เล่นถูกคุมฟิสิกส์โดย client (network ownership) การตั้งความเร็วจาก server จะถูกทับ
-- จึงส่งให้ client ของเจ้าของใช้เอง ส่วน NPC/บอส (server เป็นเจ้าของ) ตั้งตรงได้
function Combat.Impulse(s: CombatState.CombatState, velocity: Vector3, duration: number)
	local owner = Players:GetPlayerFromCharacter(s.Character)
	if owner and feedback then
		feedback:FireClient(owner, "Impulse", velocity, duration)
		return
	end
	local root = s.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		-- Humanoid ทับ AssemblyLinearVelocity ทุกเฟรม (NPC แทบไม่ขยับ) จึงใช้ LinearVelocity คงไว้ช่วงสั้น ๆ
		local attachment = Instance.new("Attachment")
		attachment.Parent = root
		local lv = Instance.new("LinearVelocity")
		lv.Attachment0 = attachment
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.MaxForce = 1e6
		lv.VectorVelocity = velocity
		lv.Parent = root
		Debris:AddItem(lv, duration)
		Debris:AddItem(attachment, duration)
	end
end

-- บอก client ว่าตัวละครนี้เริ่มท่าอะไร (client เล่นแอนิเมชันถ้ามี asset ID)
local animCounter = 0
function Combat.PlayAnim(character: Model, name: string)
	animCounter += 1
	character:SetAttribute("Anim", `{name}:{animCounter}`)
end

function Combat.Register(character: Model): CombatState.CombatState
	local s = CombatState.new(character)
	states[character] = s
	local hum = character:WaitForChild("Humanoid") :: Humanoid
	hum.Died:Once(function()
		states[character] = nil
		local killer = s.LastAttacker and states[s.LastAttacker]
		if killer then
			for _, fn in killListeners do
				task.spawn(fn, killer, s)
			end
		end
	end)
	return s
end

function Combat.Get(character: Model?): CombatState.CombatState?
	return character and states[character] or nil
end

function Combat.All(): { [Model]: CombatState.CombatState }
	return states
end

local function rootOf(s: CombatState.CombatState): BasePart?
	return s.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function notify(attacker: CombatState.CombatState, position: Vector3, amount: number, tag: string?)
	local owner = Players:GetPlayerFromCharacter(attacker.Character)
	if owner and feedback then
		feedback:FireClient(owner, tag or "Hit", position, amount)
	end
end

-- ตำแหน่งอยู่ในโซนปลอดภัย (Part ที่มี Attribute SafeZone) หรือไม่
local safeZones: { BasePart } = {}
local safeZonesAt = -math.huge
function Combat.InSafeZone(position: Vector3): boolean
	if os.clock() - safeZonesAt > 5 then -- รีเฟรชรายการทุก 5 วินาที
		safeZonesAt = os.clock()
		table.clear(safeZones)
		for _, inst in workspace:GetDescendants() do
			if inst:IsA("BasePart") and inst:GetAttribute("SafeZone") then
				table.insert(safeZones, inst)
			end
		end
	end
	for _, zone in safeZones do
		local p = zone.CFrame:PointToObjectSpace(position)
		local h = zone.Size / 2
		if math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z then
			return true
		end
	end
	return false
end

-- โจมตี 1 ครั้ง ผ่านระบบบล็อก/สวน/เบี่ยง/พาสซีฟ
function Combat.Hit(attacker: CombatState.CombatState, victim: CombatState.CombatState, amount: number, opts: HitOpts?)
	local o: HitOpts = opts or {}
	local hum = victim.Character:FindFirstChildOfClass("Humanoid")
	local vroot, aroot = rootOf(victim), rootOf(attacker)
	if not hum or not vroot or not aroot or hum.Health <= 0 then
		return
	end

	if Combat.InSafeZone(vroot.Position) or Combat.InSafeZone(aroot.Position) then
		return
	end
	-- ผู้ชมในสนามประลองตีใครไม่ได้/ถูกตีไม่ได้ และผู้เล่นตีกันได้เฉพาะในสนามประลองเดียวกันที่แมตช์กำลังดำเนิน
	if attacker.Character:GetAttribute("ArenaSpec") or victim.Character:GetAttribute("ArenaSpec") then
		return
	end
	if Players:GetPlayerFromCharacter(attacker.Character) and Players:GetPlayerFromCharacter(victim.Character) then
		local arenaId = attacker.Character:GetAttribute("ArenaId")
		if arenaId == nil or arenaId ~= victim.Character:GetAttribute("ArenaId") then
			return
		end
	end
	local team = attacker.Character:GetAttribute("Team")
	if team ~= nil and team == victim.Character:GetAttribute("Team") then
		return -- ไม่ยิงพวกเดียวกัน (สงครามแก๊ง)
	end
	if os.clock() < victim.DeflectUntil then
		return -- ปัด/หลอกการโจมตีทั้งหมด
	end
	local counter = victim.Counter
	if counter and os.clock() < counter.Until then
		victim.Counter = nil
		Combat.Hit(victim, attacker, counter.Damage, { Pierce = true })
		return
	end

	local hpFraction = hum.Health / hum.MaxHealth
	local ahum = attacker.Character:FindFirstChildOfClass("Humanoid")
	local aFraction = ahum and ahum.Health / ahum.MaxHealth or 1
	amount *= Passives.DamageMultiplier(attacker.Equipped, aFraction, victim.IsBoss)
	amount *= (attacker.Character:GetAttribute("DamageMult") :: number?) or 1
	-- คริติคอล: ผู้เล่นมีโอกาส 8% ได้ดาเมจ x1.8 (รางวัลแบบสุ่ม ทำให้การตีน่าตื่นเต้น)
	local crit = Players:GetPlayerFromCharacter(attacker.Character) ~= nil and math.random() < 0.08
	if crit then
		amount *= 1.8
	end

	if victim.State == "Blocking" and not o.Pierce then
		if os.clock() - victim.BlockStart <= Config.PerfectBlockWindow then
			attacker:Stun(Config.PerfectBlockStun)
			notify(victim, vroot.Position, 0, "PerfectBlock")
			return
		end
		amount *= 1 - Config.BlockReduction
		Combat.PlayAnim(victim.Character, "BlockHit")
		victim.Stamina =
			math.max(0, victim.Stamina - Config.BlockStaminaCost * Passives.BlockCostMultiplier(victim.Equipped))
		if victim.Stamina <= 0 then
			victim:Stun(1)
		end
	else
		if victim.State == "Blocking" then
			victim.State = "Idle"
			Combat.PlayAnim(victim.Character, "BlockEnd")
		end
		if o.Knockdown then
			victim:Knockdown(o.Knockdown)
			Combat.PlayAnim(victim.Character, "Knockdown")
		else
			-- มอนตีผู้เล่นแค่สะดุ้งสั้นๆ (0.2 วิ) ไม่ให้ติดสตันตอนถูกรุม
			local stunTime = o.Stun or 0.4
			if Players:GetPlayerFromCharacter(victim.Character) and not Players:GetPlayerFromCharacter(attacker.Character) then
				stunTime = math.min(stunTime, 0.2)
			end
			victim:Stun(stunTime)
			Combat.PlayAnim(victim.Character, "Hit")
		end
		local push = o.Knockback or (o.Final and Config.FinisherKnockback) or 0
		if push > 0 then
			Combat.Impulse(victim, aroot.CFrame.LookVector * push + Vector3.new(0, 25, 0), 0.25)
		end
		if o.Root then
			victim:Root(o.Root)
		end
		if o.Slow then
			victim:Slow(o.Slow, o.SlowTime or 2)
		end
	end

	victim.LastAttacker = attacker.Character
	hum:TakeDamage(amount)
	attacker:AddUlt(Config.UltPerHit)
	victim:AddUlt(amount * Config.UltPerDamageTaken)
	notify(attacker, vroot.Position, amount, if crit then "Crit" else nil)
	for _, fn in hitListeners do
		task.spawn(fn, attacker, victim, amount)
	end
end

-- หาเป้าหมายใน hitbox (กล่อง) ที่ผ่านการตรวจระยะฝั่ง server
function Combat.QueryBox(
	attacker: CombatState.CombatState,
	cf: CFrame,
	size: Vector3,
	maxRange: number
): { CombatState.CombatState }
	local root = rootOf(attacker)
	local found: { CombatState.CombatState } = {}
	if not root then
		return found
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attacker.Character }
	local seen: { [Model]: boolean } = {}
	for _, part in workspace:GetPartBoundsInBox(cf, size, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		local v = model and states[model]
		if model and v and not seen[model] then
			local vroot = rootOf(v)
			if vroot and (vroot.Position - root.Position).Magnitude <= maxRange then
				seen[model] = true
				table.insert(found, v)
			end
		end
	end
	return found
end

-- หาเป้าหมายในรัศมี
function Combat.QueryRadius(attacker: CombatState.CombatState, radius: number): { CombatState.CombatState }
	local root = rootOf(attacker)
	local found: { CombatState.CombatState } = {}
	if not root then
		return found
	end
	-- ใช้การค้นหาตามพื้นที่ของ engine แทนการวนทุกตัวใน states (มอนเยอะแล้วหน่วง O(N²))
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attacker.Character }
	local seen: { [Model]: boolean } = {}
	for _, part in workspace:GetPartBoundsInRadius(root.Position, radius, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		local v = model and states[model]
		if model and v and not seen[model] then
			seen[model] = true
			table.insert(found, v)
		end
	end
	return found
end

-- ล็อกเป้านุ่ม: ผู้เล่นชก/ใช้สกิลแล้วตัวหันหาศัตรูที่ใกล้ที่สุดข้างหน้า (ภายใน 14 studs มุม ±70°) อัตโนมัติ
-- ช่วยให้ตีโดนแม้เล็งไม่เป๊ะ (มือถือเล็งยากเป็นพิเศษ)
function Combat.AimAssist(s: CombatState.CombatState)
	if not Players:GetPlayerFromCharacter(s.Character) then
		return
	end
	local root = rootOf(s)
	if not root then
		return
	end
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude < 0.01 then
		return
	end
	look = look.Unit
	local team = s.Character:GetAttribute("Team")
	local best: BasePart? = nil
	local bestScore = math.huge
	for _, v in Combat.QueryRadius(s, 14) do
		local vroot = rootOf(v)
		local hum = v.Character:FindFirstChildOfClass("Humanoid")
		if
			vroot
			and hum
			and hum.Health > 0
			and not (team ~= nil and team == v.Character:GetAttribute("Team"))
			and not Combat.InSafeZone(vroot.Position)
		then
			local offset = Vector3.new(vroot.Position.X - root.Position.X, 0, vroot.Position.Z - root.Position.Z)
			if offset.Magnitude > 0.1 then
				local dot = offset.Unit:Dot(look)
				if dot > 0.34 then
					local score = offset.Magnitude * (2 - dot) -- ใกล้และตรงหน้า ได้คะแนนดี
					if score < bestScore then
						best, bestScore = vroot, score
					end
				end
			end
		end
	end
	if best then
		root.CFrame = CFrame.lookAt(root.Position, Vector3.new(best.Position.X, root.Position.Y, best.Position.Z))
	end
end

function Combat.M1(s: CombatState.CombatState)
	local now = os.clock()
	if not s:CanAct() or now - s.LastM1 < Config.M1Cooldown then
		return
	end
	if now - s.LastM1 > Config.ComboResetTime then
		s.Combo = 0
	end
	s.Combo += 1
	s.LastM1 = now
	local final = s.Combo >= Config.ComboLength
	if final then
		s.Combo = 0
	end

	local root = rootOf(s)
	if not root then
		return
	end
	s.State = "Attacking"
	Combat.AimAssist(s)
	Combat.PlayAnim(s.Character, `M1_{if final then Config.ComboLength else s.Combo}`)
	-- พุ่งเข้าหาศัตรูที่อยู่ใกล้ข้างหน้าเท่านั้น (ห่างเกินระยะตีแต่ไม่เกิน 10) ถ้าไม่มีเป้าหมายอยู่กับที่
	if Players:GetPlayerFromCharacter(s.Character) then -- ผู้เล่นเท่านั้น (มอนไม่ต้องคำนวณ ลดภาระเซิร์ฟเวอร์)
		local look = root.CFrame.LookVector
		local nearestDist = math.huge
		for _, v in Combat.QueryRadius(s, 10) do
			local vroot = rootOf(v)
			if vroot then
				local offset = vroot.Position - root.Position
				if offset.Magnitude > 0.1 and offset.Unit:Dot(look) > 0.5 then
					nearestDist = math.min(nearestDist, offset.Magnitude)
				end
			end
		end
		if nearestDist > 4 and nearestDist < 10 then
			Combat.Impulse(s, look * 14, 0.08)
		end
	end
	local cf = root.CFrame * CFrame.new(0, 0, -Config.HitboxForward)
	local struck: { [CombatState.CombatState]: boolean } = {}
	for _, v in Combat.QueryBox(s, cf, Config.HitboxSize, Config.MaxHitRange) do
		struck[v] = true
		Combat.Hit(s, v, Config.M1Damage, { Final = final })
	end
	-- วงโดนเสริมรอบตัวด้านหน้า (รัศมี 6): ศัตรูที่อยู่ชิดตัวหรือเหลื่อมกล่องตีเพราะความหน่วงก็ยังโดน
	if Players:GetPlayerFromCharacter(s.Character) then
		local look = root.CFrame.LookVector
		for _, v in Combat.QueryRadius(s, 6) do
			local vroot = rootOf(v)
			if vroot and not struck[v] then
				local offset = vroot.Position - root.Position
				if offset.Magnitude > 0.1 and offset.Unit:Dot(look) > 0.1 then
					struck[v] = true
					Combat.Hit(s, v, Config.M1Damage, { Final = final })
				end
			end
		end
	end
	task.delay(Config.M1Cooldown, function()
		if s.State == "Attacking" then
			s.State = "Idle"
		end
	end)
end

function Combat.BlockStart(s: CombatState.CombatState)
	if s:CanAct() and s.Stamina > 0 then
		Combat.PlayAnim(s.Character, "Block")
		s.State = "Blocking"
		s.BlockStart = os.clock()
	end
end

function Combat.BlockEnd(s: CombatState.CombatState)
	if s.State == "Blocking" then
		s.State = "Idle"
		Combat.PlayAnim(s.Character, "BlockEnd")
	end
end

function Combat.Dash(s: CombatState.CombatState)
	local now = os.clock()
	local root = rootOf(s)
	local cooldown = Config.DashCooldown * Passives.DashCooldownMultiplier(s.Equipped)
	if not root or not s:CanAct() or now - s.LastDash < cooldown or s.Stamina < Config.DashStaminaCost then
		return
	end
	s.LastDash = now
	s.Stamina -= Config.DashStaminaCost
	Combat.PlayAnim(s.Character, "Dash")
	Combat.Impulse(s, root.CFrame.LookVector * Config.DashSpeed, Config.DashTime)
end

RunService.Heartbeat:Connect(function(dt)
	for _, s in states do
		s:Regen(dt)
	end
end)

return Combat
