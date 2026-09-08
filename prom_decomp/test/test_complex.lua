-- å¤ææµè¯æºç ï¼å­¦çæç»©ç®¡çç³»ç»
local StudentSystem = {}
StudentSystem.__index = StudentSystem

function StudentSystem.new(name)
    local self = setmetatable({}, StudentSystem)
    self.name = name
    self.students = {}
    self.totalScore = 0
    self.count = 0
    return self
end

function StudentSystem:addStudent(id, name, score)
    if self.students[id] then
        return false, "å­¦çå·²å­å¨"
    end
    self.students[id] = {
        name = name,
        score = score,
        grade = self:_calcGrade(score)
    }
    self.totalScore = self.totalScore + score
    self.count = self.count + 1
    return true
end

function StudentSystem:_calcGrade(score)
    if score >= 90 then return "A"
    elseif score >= 80 then return "B"
    elseif score >= 70 then return "C"
    elseif score >= 60 then return "D"
    else return "F" end
end

function StudentSystem:getAverage()
    if self.count == 0 then return 0 end
    return self.totalScore / self.count
end

function StudentSystem:getTopStudent()
    local topId, topScore = nil, -1
    for id, info in pairs(self.students) do
        if info.score > topScore then
            topId = id
            topScore = info.score
        end
    end
    if topId then
        return self.students[topId]
    end
    return nil
end

function StudentSystem:removeStudent(id)
    if not self.students[id] then
        return false, "å­¦çä¸å­å¨"
    end
    self.totalScore = self.totalScore - self.students[id].score
    self.count = self.count - 1
    self.students[id] = nil
    return true
end

function StudentSystem:listAll()
    local result = {}
    for id, info in pairs(self.students) do
        result[#result + 1] = string.format("[%s] %s - %då (%s)", id, info.name, info.score, info.grade)
    end
    table.sort(result, function(a, b)
        local sa = tonumber(a:match("%-(%d+)å"))
        local sb = tonumber(b:match("%-(%d+)å"))
        return sa > sb
    end)
    return result
end

function StudentSystem:exportReport()
    local lines = {}
    lines[#lines + 1] = "=== " .. self.name .. " æç»©æ¥å ==="
    lines[#lines + 1] = string.format("å­¦çæ»æ°: %d", self.count)
    lines[#lines + 1] = string.format("å¹³åå: %.2f", self:getAverage())
    local top = self:getTopStudent()
    if top then
        lines[#lines + 1] = string.format("æé«å: %s (%då)", top.name, top.score)
    end
    lines[#lines + 1] = "--- æç»©åè¡¨ ---"
    for _, line in ipairs(self:listAll()) do
        lines[#lines + 1] = line
    end
    return table.concat(lines, "\n")
end

-- ææ³¢é£å¥æ°åï¼éå½ï¼
local function fibonacci(n)
    if n <= 1 then return n end
    return fibonacci(n - 1) + fibonacci(n - 2)
end

-- å¿«éæåº
local function quickSort(arr, low, high)
    if low >= high then return end
    local pivot = arr[high]
    local i = low - 1
    for j = low, high - 1 do
        if arr[j] <= pivot then
            i = i + 1
            arr[i], arr[j] = arr[j], arr[i]
        end
    end
    arr[i + 1], arr[high] = arr[high], arr[i + 1]
    local pi = i + 1
    quickSort(arr, low, pi - 1)
    quickSort(arr, pi + 1, high)
end

-- ä¸»ç¨åº
local system = StudentSystem.new("é«ä¸(1)ç­")
system:addStudent("001", "å¼ ä¸", 85)
system:addStudent("002", "æå", 92)
system:addStudent("003", "çäº", 78)
system:addStudent("004", "èµµå­", 65)
system:addStudent("005", "é±ä¸", 100)

print(system:exportReport())

print("\n--- ææ³¢é£å¥æ°åå10é¡¹ ---")
for i = 1, 10 do
    print("F(" .. i .. ") = " .. fibonacci(i))
end

print("\n--- å¿«éæåºæµè¯ ---")
local nums = {64, 34, 25, 12, 22, 11, 90}
print("æåºå: " .. table.concat(nums, ", "))
quickSort(nums, 1, #nums)
print("æåºå: " .. table.concat(nums, ", "))

print("\n--- å é¤å­¦çæµè¯ ---")
system:removeStudent("003")
print(system:exportReport())
