ORDER_3_DECEPTIVE_FITNESS  =
{
  [0] = 28,       -- 000
  [1] = 26,       -- 001
  [2] = 22,       -- 010
  [3] = 0,        -- 011
  [4] = 14,       -- 100
  [5] = 0,        -- 101,
  [6] = 0,        -- 110,
  [7] = 30,       -- 111
}

ORDER_5_DECEPTIVE_FITNESS = {}

local function GenerateOrder5Deceptive(local_max, global_max, local_min_unitation, local_min_fitness)
  for code = 0, 31 do
    local unitation = 0
    local mask = 1
    while mask <= code do
      unitation = unitation + (((code & mask) ~= 0) and 1 or 0)
      mask = mask << 1
    end
    
    local fitness
    if unitation < local_min_unitation then
      fitness = local_max - (local_max - local_min_fitness) * unitation / local_min_unitation
    else
      fitness = local_min_fitness + (global_max - local_min_fitness) * (unitation - local_min_unitation) / (5 - local_min_unitation)
    end
    
    ORDER_5_DECEPTIVE_FITNESS[code] = fitness
  end
end

GenerateOrder5Deceptive(0.58, 1.0, 4, 0.0)

function GetFuncStats(func)
  local mean, count = 0.0, 0
  local best, second_best
  for _, fitness in pairs(func) do
    mean = mean + fitness
    count = count + 1
    if not best then
      best, second_best = fitness, fitness
    elseif fitness > best then
      best, second_best = fitness, best
    elseif fitness > second_best then
      second_best = fitness
    end
  end
  mean = mean / count
  
  local variance = 0.0
  for _, fitness in pairs(func) do
    variance = variance + (fitness - mean) * (fitness - mean)
  end
  variance = variance / count
  
  local stddev = math.sqrt(variance)
  local signal = best - second_best
  
  return mean, stddev, variance, signal, best
end

local function RationalApproximation(t)
    local c = {2.515517, 0.802853, 0.010328}
    local d = {1.432788, 0.189269, 0.001308}
    return t - ((c[3] * t + c[2]) * t + c[1]) / (((d[3] * t + d[2]) * t + d[1]) * t + 1.0)
end

function GetZScore(alpha)
  if alpha < 0.5 then
    return -RationalApproximation(math.sqrt(-2.0 * math.log(alpha)))
  else
    return RationalApproximation(math.sqrt(-2.0 * math.log(1.0 - alpha)))
  end
end

function GetZScoreRightTail(alpha)
  return GetZScore(1.0 - alpha)
end

local s_Z1, s_Generate = false, false

function GenGausNoise(mean, stddev, epsilon)
  mean = mean or 0.0
  stddev = stddev or 1.0
  epsilon = epsilon or 0.00001
  
  s_Generate = not s_Generate  
  if not s_Generate then
    return mean + s_Z1 * stddev
  end
  
  local u1, u2
  repeat
    u1, u2 = math.random(), math.random()
  until u1 > epsilon
  
  local sqrt_log_u1 = math.sqrt(-2.0 * math.log(u1)) 
  local z0 = sqrt_log_u1 * math.cos(2.0 * math.pi * u2)
  s_Z1 = sqrt_log_u1 * math.sin(2.0 * math.pi * u2)
  
  return mean + z0 * stddev
end
