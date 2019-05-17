function Min(a, b) return (a < b) and a or b end
function Max(a, b) return (a > b) and a or b end
function Abs(x) return (x < 0) and -x or x end
function Sqr(x) return x * x end
function Clamp(x, a, b) return (x < a) and a or ((x > b) and b or x) end

function GetPreciseTicks()
	return os.clock()
end

local s_StartTime = 0

function ResetTime()
  s_StartTime = GetPreciseTicks()
end

function GetTime()
  return GetPreciseTicks() - s_StartTime
end

function rand(max)
	if max then
		return max > 1 and math.random(0, max - 1) or 0
	else
		return math.random(0, 10000) / 10000.0
	end
end

function objective_function(vector)
	local sum = 0
	for _, x in ipairs(vector) do
		sum = sum + x * x
	end
	
	return sum
end

function rand_in_bounds(min, max)
	return min + (max - min) * rand()
end

function random_gaussian(mean, stdev)
	mean = mean or 0.0
	stdev = stdev or 1.0
	
	local u1, u2, w = 0.0, 0.0, 1.0
	while w >= 1.0 do
		u1 = 2 * rand() - 1
		u2 = 2 * rand() - 1
		w = u1 * u1 + u2 * u2
	end
	w = math.sqrt(-2.0 * math.log(w) / w)
	
	return mean + u2 * w * stdev
end

function random_vector(minmax)
	local rnd_vec = {}
	for i = 1, #minmax do
		rnd_vec[i] = rand_in_bounds(minmax[i][1], minmax[i][2])
	end
	
	return rnd_vec
end

function vector_to_string(vector)
    return "{ " .. table.concat(vector, ", ") .. " }"
end

function TakeStep(minmax, current, step_size)
	local position = {}
	for i = 1, #current do
		local min = Max(minmax[i][1], current[i] - step_size)
		local max = Min(minmax[i][2], current[i] + step_size)
		position[i] = rand_in_bounds(min, max)
	end
	
	return position
end

function OneMax(vector)
	local sum = 0
	for i = 1, #vector do
		sum = sum + (vector[i] == '1' and 1 or 0)
	end
	
	return sum
end

function RandomBitString(num_bits)
	local vector = {}
	for i = 1, num_bits do
		vector[i] = (rand() < 0.5) and '1' or '0'
	end
	
	return vector
end

function Euc2D(c1, c2)
	return math.sqrt((c1[1] - c2[1]) ^ 2 + (c1[2] - c2[2]) ^ 2)
end

function EucDist(c1, c2)
	local sum = 0
	for i = 1, #c1 do
		sum = sum + (c1[i] - c2[i]) * (c1[i] - c2[i])
	end
	
	return math.sqrt(sum)
end

function clamp(x, a, b)
	if x < a then
		return a
	elseif x > b then
		return b
	else
		return x
	end
end

function table.merge_sorted_ascending(list1, list2, max_len, member)
	local list = {}	
	local l1, l2 = 1, 1
	while #list < max_len and l1 <= #list1 and l2 <= #list2 do
		local value1, value2 = list1[l1], list2[l2]
		local from_first
		if member then
			from_first = value1[member] < value2[member]
		else
			from_first = value1 < value2
		end
		if from_first then
			table.insert(list, value1)
			l1 = l1 + 1
		else
			table.insert(list, value2)
			l2 = l2 + 1
		end
	end
	
	if #list2 == 0 then
		while #list < max_len and l1 <= #list1 do
			table.insert(list, list1[l1])
			l1 = l1 + 1
		end
	end
	if #list1 == 0 then
		while #list < max_len and l2 <= #list2 do
			table.insert(list, list2[l2])
			l2 = l2 + 1
		end
	end

	return list
end

function table.closest(tbl, value)
	local x = tbl[1]
	for _, v in ipairs(tbl) do
		x = (math.abs(v - value) < math.abs(x - value)) and v or x
	end
	
	return x
end

function table.closest_diff(tbl, value, diff)
	local best = tbl[1]
	if best == value then
		return best
	end
	local best_diff = math.abs(math.abs(best - value) - diff)
	for i = 2, #tbl do
		local x = tbl[i]
		if x == value then
			return x
		end
		local x_diff = math.abs(math.abs(x - value) - diff)
		if x_diff < best_diff then
			best = x
		end
	end
	
	return best
end

function table.average(t)
	local s = 0.0
	for _, v in ipairs(t) do
		s = s + v
	end
	
	return s / #t
end
  
function table.min(t, functor)
	local min, min_i
	if functor then
		local min_value
		for i = 1, #t do
			local value = functor(t[i])
			if value and (not min_value or value < min_value) then
				min, min_value, min_i = t[i], value, i
			end
		end
	else
		min, min_i = t[1], 1
		for i = 2, #t do
			local value = t[i]
			if value < min then
				min, min_i = value, i
			end
		end
	end
	return min, min_i
end

function table.max(t, functor)
	local max, max_i
	if functor then
		local max_value
		for i = 1, #t do
			local value = functor(t[i])
			if value and (not max_value or value > max_value) then
				max, max_value, max_i = t[i], value, i
			end
		end
	else
		max, max_i = t[1], 1
		for i = 2, #t do
			local value = t[i]
			if value > max then
				max, max_i = value, i
			end
		end
	end
	return max, max_i
end

function table.copy(t, deep, filter)
	if type(t) ~= "table" then
		assert(false, "Attept to table.copy a var of type " .. type(t))
		return {}
	end	

	if type(deep) == "number" then
		deep = deep > 1 and deep - 1
	end
	
	local meta = getmetatable(t)
	if meta then
		local __copy = rawget(meta, "__copy")
		if __copy then
			return __copy(t)
		elseif type(t.class) == "string" then
			assert(false, "Attept to table.copy an object of class " .. t.class)
			return {}
		end
	end
	local copy = {}
	for k, v in pairs(t) do
		if deep then
			if type(k) == "table" then k = table.copy(k, deep) end
			if type(v) == "table" then v = table.copy(v, deep) end
		end
		if not filter or filter(k, v) then
			copy[k] = v
		end
	end
	return copy
end

function table.append(t, t2)
	if t2 then
		local num = #t
		for i = 1, #t2 do
			t[num+i] = t2[i]
		end
	end
	return t
end

function table.find(array, field, value)
	if not array then return end
	if value == nil then
		value = field
		for i = 1, #array do
			if value == array[i] then return i end
		end
	else
		for i = 1, #array do
			if value == array[i][field] then return i end
		end
	end
end

function table.find_entry(array, field, value)
  local i = table.find(array, field, value)
  return i and array[i]
end

function table.remove_entry(array, field, value)
	local i = table.find(array, field, value)
	if i then
		table.remove(array, i)
		return i
	end
end

function string.trim_spaces(s)
	return s and s:match("^%s*(.-)%s*$")
end

function string.format_table(fmt_str, params_tbl, num_fmt)
  local function repl_func(param)
    local value = params_tbl[param]
    if value ~= nil then
      if type(value) == "bool" then
        return tostring(value)
      elseif type(value) == "number" then
        local value_fmt = num_fmt and num_fmt[param]
        return value_fmt and string.format(value_fmt, value) or tostring(value)
      else
        return tostring(value)
      end
    else
      return string.format("<%s - invalid param!>", param)
    end
  end

  local str = string.gsub(fmt_str, "<([%w_]+)>", repl_func)
  
  return str
end

function table.averagized(tbl, avg_span)
  local avg_tbl = {}
  local k, len = 1, #tbl
  while k <= len do
    local sum, count = 0, Min(avg_span, len - k + 1)
    for i = k, k + count - 1 do
      sum = sum + tbl[i]
    end
    table.insert(avg_tbl, k // count)
    k = k + count
  end
  
  return avg_tbl
end
