--!strict
-- ป้ายคะแนนในสนาม instance: เซิร์ฟเวอร์เซ็ต Attribute (BState/BTitle/BNameA/BNameB/BMid/BLeadA/BLeadB/BNote/BEnds) บนโมเดลสนาม
-- ไคลเอนต์วาดข้อความเอง และคำนวณเวลาที่เหลือ = BEnds - เวลาเซิร์ฟเวอร์ ทุก 0.2 วินาที (นาฬิกาไม่ค้างแม้เซิร์ฟเวอร์ไม่ส่งอะไรเพิ่ม)
local container = workspace:WaitForChild("ArenaInstances")

local boards: { [Model]: { [string]: { TextLabel } } } = {}

local function register(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local labels: { [string]: { TextLabel } } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("SurfaceGui") and d.Name == "Board" then
			for _, l in d:GetChildren() do
				if l:IsA("TextLabel") then
					labels[l.Name] = labels[l.Name] or {}
					table.insert(labels[l.Name], l)
				end
			end
		end
	end
	boards[model] = labels
end

container.ChildAdded:Connect(register)
container.ChildRemoved:Connect(function(m)
	boards[m :: Model] = nil
end)
for _, m in container:GetChildren() do
	register(m)
end

local function set(labels: { [string]: { TextLabel } }, name: string, text: string)
	local list = labels[name]
	if list then
		for _, l in list do
			if l.Text ~= text then
				l.Text = text
			end
		end
	end
end

local function clock(sec: number): string
	sec = math.max(0, math.ceil(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

local function timerText(model: Model): string
	local state = (model:GetAttribute("BState") :: string?) or "wait"
	local ends = model:GetAttribute("BEnds") :: number?
	if state == "over" then
		return "จบแล้ว"
	elseif state == "countdown" and ends then
		return `เริ่มใน {math.max(0, math.ceil(ends - workspace:GetServerTimeNow()))}`
	elseif state == "live" and ends then
		return `เหลือ {clock(ends - workspace:GetServerTimeNow())}`
	end
	return "รอเริ่ม"
end

while true do
	for model, labels in boards do
		if model.Parent then
			set(labels, "Title", (model:GetAttribute("BTitle") :: string?) or "")
			set(labels, "NameA", (model:GetAttribute("BNameA") :: string?) or "")
			set(labels, "NameB", (model:GetAttribute("BNameB") :: string?) or "")
			set(labels, "Mid", (model:GetAttribute("BMid") :: string?) or "")
			set(labels, "LeadA", (model:GetAttribute("BLeadA") :: string?) or "")
			set(labels, "LeadB", (model:GetAttribute("BLeadB") :: string?) or "")
			set(labels, "Note", (model:GetAttribute("BNote") :: string?) or "")
			set(labels, "Timer", timerText(model))
		end
	end
	task.wait(0.2)
end
