dofile("Bitmap.lua")
dofile("Graphics.lua")
dofile("Statistics.lua")
dofile("Combinatorics.lua")
dofile("GA_Common.lua")
dofile("GA_CommonMessy.lua")

local SUB_FUNCTIONS                 = 10
local SUB_FUNCTION_ORDER            = 3
local CHROMOSOME_LENGTH             = SUB_FUNCTION_ORDER * SUB_FUNCTIONS

local RUNS                          = 10
local PROB_CROSSOVER                = 1.0
local PROB_MUTATION                 = 0.0
local PROB_CUT                      = 1.0 / (2 * CHROMOSOME_LENGTH)
local PROB_SPLICE                   = 1.0
local TOURNAMENT_SIZE               = 2
local TOURNAMENT_SIZE_MESSY         = 2
local GENERATIONS                   = 100
local GENERATIONS_MESSY             = 40
local POPULATION_SIZE               = 2000

local IMAGE_WIDTH                   = 1000
local IMAGE_HEIGHT                  = 1000
local IMAGE_FILENAME_SGA_MAX        = "mGA/mGA_SGA_Max.bmp"
local IMAGE_FILENAME_SGA_AVG        = "mGA/mGA_SGA_Avg.bmp"
local IMAGE_FILENAME_MGA_FITNESS    = "mGA/mGA_MGA_FITNESS.bmp"
local IMAGE_FILENAME_MGA_BBLOCKS    = "mGA/mGA_MGA_BBLOCKS.bmp"
local IMAGE_FILENAME_MGA_LENGTHS    = "mGA/mGA_MGA_LENGTHS.bmp"

local ORDERING_TIGHT = {}
for i = 1, CHROMOSOME_LENGTH do
  ORDERING_TIGHT[i] = i
end

local bit_pos = {}
for bit_order = 1, SUB_FUNCTION_ORDER do
  for bit = bit_order, CHROMOSOME_LENGTH, SUB_FUNCTION_ORDER do
    table.insert(bit_pos, bit)
  end
end
local ORDERING_LOOSE = {}
for pos, bit in ipairs(bit_pos) do
  ORDERING_LOOSE[bit] = pos
end

local bit_pos =
{
  2, 17, 24,     -- subfunction 1
  22, 21, 14,
  30, 9, 4,
  5, 10, 15,
  25, 26, 28,
  19, 7, 20,
  29, 8, 12,
  3, 1, 18,
  6, 23, 11,
  27, 16, 13    -- subfunction 10
}
local ORDERING_RANDOM = {}
for pos, bit in ipairs(bit_pos) do
  ORDERING_RANDOM[bit] = pos
end

local function PrintChromosome(chrom, fitness, delim)
  print(string.format("%s: %d", table.concat(UnpackBitstring(chrom), delim or ""), fitness))
end

local function EvaluateChromosome(ind, ordering)
  local fitness, building_blocks = 0, 0
  local chrom = ind.chrom and UnpackBits(ind.chrom) or ind
  for pos = 1, #chrom, SUB_FUNCTION_ORDER do
    local code, building_block = 0, 1
    for bit = 1, SUB_FUNCTION_ORDER do
      local bit_pos = ordering[pos + bit - 1]
      if chrom[bit_pos] == 1 then
        code = code + (1 << (SUB_FUNCTION_ORDER - bit))
      else
        building_block = 0
      end
    end
    fitness = fitness + ORDER_3_DECEPTIVE_FITNESS[code]
    building_blocks = building_blocks + building_block
  end

  return fitness, building_blocks
end

local function GenInitPop(size, ordering)
  local pop = {template = ordering, tournament_perm = GenRandomPermutation(size), crossovers = 0, mutations = 0}
  while #pop < size do
    local bitstring = GenRandomBitstring(CHROMOSOME_LENGTH)
    table.insert(pop, {chrom = PackBitstring(bitstring)})
  end
  
  return pop
end

local function EvalPop(pop, eval_chromosome)
  local template = pop.template
  local total_fitness, min_fitness, max_fitness = 0
  local total_bb, min_bb, max_bb = 0
  local total_len, min_len, max_len = 0
  for _, ind in ipairs(pop) do
    local fitness, building_blocks = eval_chromosome(ind, template)
    ind.fitness, ind.building_blocks = fitness, building_blocks
    min_fitness = (not min_fitness or fitness < min_fitness) and fitness or min_fitness
    max_fitness = (not max_fitness or fitness > max_fitness) and fitness or max_fitness
    total_fitness = total_fitness + fitness
    min_bb = (not min_bb or building_blocks < min_bb) and building_blocks or min_bb
    max_bb = (not max_bb or building_blocks > max_bb) and building_blocks or max_bb
    total_bb = total_bb + building_blocks
    local len = #ind.chrom
    min_len = (not min_len or len < min_len) and len or min_len
    max_len = (not max_len or len > max_len) and len or max_len
    total_len = total_len + len
  end
  pop.min_fitness, pop.max_fitness, pop.total_fitness = min_fitness, max_fitness, total_fitness
  pop.avg_fitness = total_fitness / #pop
  pop.min_building_blocks, pop.max_building_blocks = min_bb, max_bb
  pop.avg_building_blocks = total_bb / #pop
  pop.min_length, pop.max_length = min_len, max_len
  pop.avg_length = total_len / #pop
end

local function PlotPopBuildingBlocks(pop, gen, graphs, name, prop, denom)
  denom = denom or 1.0
  
  local func = graphs.funcs[name]
  if func[gen] then
    func[gen].y = func[gen].y + pop[prop] / denom
  else
    func[gen] = {x = gen, y = pop[prop] / denom}
  end
end

local function Crossover(ind1, ind2)
  local off1, off2 = {chrom = CopyBitstring(ind1.chrom)}, {chrom = CopyBitstring(ind2.chrom)}
  local crossovers = (math.random() < PROB_CROSSOVER) and 1 or 0
  if crossovers > 0 then
    local xsite = math.random(1, ind1.chrom.bits)
    ExchangeTailBits(off1.chrom, off2.chrom, xsite)
  end

  return off1, off2, crossovers
end

local function Mutate(ind)
  if PROB_MUTATION <= 0.0 then return 0 end
  
  local mutations = 0
  local chrom = UnpackBits(ind.chrom)
  for bit, value in ipairs(chrom) do
    if math.random() < PROB_MUTATION then
      chrom[bit] = 1 - value
      mutations = mutations + 1
    end
  end
  ind.chrom = PackBitstring(table.concat(chrom, ""))
  
  return mutations
end

local function GenPartChrom(pop, combination)
  local size = #combination
  
  local binary = {}
  for i = 1, size do
    binary[i] = 0
  end
  repeat
    local chrom = {}
    for i = 1, size do
      chrom[i] = {gene = combination[i], allele = binary[i]}
    end
    table.insert(pop, {chrom = chrom})
    local no_zeroes = true
    for i = size, 1, -1 do
      if binary[i] == 0 then
        binary[i] = 1
        for k = i + 1, size do
          binary[k] = 0
        end
        no_zeroes = false
        break
      end
    end
  until no_zeroes
end

local function GenMessyInitPop()
  local n, k = CHROMOSOME_LENGTH, SUB_FUNCTION_ORDER
  local pop_size = math.floor(math.pow(2, k) * Combinations(n, k))
  
  -- incremental generation of all C(n,k) combinations without repetition
  local combination = {}
  for i = 1, k do
    combination[i] = i
  end
  local pop = {cuts = 0, splices = 0, mutations = 0}
  GenPartChrom(pop, combination)
  repeat
    local new_combination = {}
    local used = {}
    for i, value in ipairs(combination) do
      new_combination[i] = value
      used[value] = true
    end
    local generated
    combination = new_combination
    for i = k, 1, -1 do
      local value = combination[i]
      if (value < n) and (not used[value + 1]) then
        combination[i] = value + 1
        for p = i + 1, k do
          combination[p] = combination[p - 1] + 1
        end
        generated = true
        break
      end
    end
    if generated then
      GenPartChrom(pop, combination)
    end
  until not generated
  assert(#pop == pop_size)
  pop.tournament_perm = GenRandomPermutation(#pop)
  
  return pop
end

local function EvaluateMessyChromosome(ind)
  local chrom = ResoloveOverSpecification(ind.chrom)
  
  local fitness, building_blocks = 0, 0
  local no_partial_spec = true
  for pos = 1, CHROMOSOME_LENGTH, SUB_FUNCTION_ORDER do
    local code, shift = 0, SUB_FUNCTION_ORDER - 1
    local spec, no_spec, building_block = true, true, 1
    for bit = 1, SUB_FUNCTION_ORDER do
      local bit_pos = pos + bit - 1
      local value = chrom[bit_pos]
      if value == 1 then
        code = code + (1 << shift)
        no_spec = false
      else
        building_block = 0
        if value == nil then
          spec = false
        else
          no_spec = false
        end
      end
      shift = shift >> 1
    end
    if spec then
      fitness = fitness + ORDER_3_DECEPTIVE_FITNESS[code]
      building_blocks = building_blocks + building_block
    end
    no_partial_spec = no_partial_spec and (spec or no_spec)
  end
  fitness = no_partial_spec and fitness or 0
  
  return fitness, building_blocks
end

function GenCompetitiveTemplate(sweeps)
  local template = {}
  if sweeps then
    -- generate random bit string
    for i = 1, CHROMOSOME_LENGTH do
      template[i] = (math.random() < 0.5) and 1 or 0
    end
    local template_fitness = EvaluateChromosome(template, ORDERING_TIGHT)
    for sweep = 1, sweeps do
      local perm = GenRandomPermutation(CHROMOSOME_LENGTH)
      for _, bit in ipairs(perm) do
        template[bit] = 1 - template[bit]
        local fitness = EvaluateChromosome(template, ORDERING_TIGHT)
        if fitness > template_fitness then
          template_fitness = fitness
        else
          template[bit] = 1 - template[bit]
        end
      end
    end
  else
    for i = 1, CHROMOSOME_LENGTH do
      template[i] = 0
    end
  end
  
  return template
end

local function EvaluateMessyChromosomeTemplate(ind, template)
  local chrom = ResoloveOverSpecification(ind.chrom)
  ResolveUnderSpecification(chrom, template)
  
  return EvaluateResolvedChromosome(chrom, SUB_FUNCTION_ORDER, ORDER_3_DECEPTIVE_FITNESS)
end

local function NormalizeGraphs(graphs, runs, int_y)
  local scale = 1.0 / runs
  for name, func in pairs(graphs.funcs) do
    for k = 1, #func do
      func[k].y = int_y and math.floor(func[k].y * scale) or (func[k].y * scale)
    end
  end
end

local function GetStatsStr(stats)
  local text = {}
  for key, value in pairs(stats) do
    table.insert(text, string.format("%s: %.2f", key, value))
  end
  
  return table.concat(text, ", ")
end

local function SaveGraphs(filename, graphs_left, int_y, graphs_right, stats_left, stats_right)
  local min_y, max_y
  if graphs_right then
    min_y, max_y = GetGraphsMinMaxY(graphs_left.funcs, graphs_right.funcs)
  end
  
  local bmp = Bitmap.new(graphs_right and 2 * IMAGE_WIDTH or IMAGE_WIDTH, IMAGE_HEIGHT, RGB_BLACK)
  DrawGraphs(bmp, graphs_left, {int_x = true, skip_KP = true, min_y = 0, int_y = int_y, width = IMAGE_WIDTH, height = IMAGE_HEIGHT, min_y = min_y, max_y = max_y})
  if graphs_right then
    DrawGraphs(bmp, graphs_right, {int_x = true, skip_KP = true, min_y = 0, int_y = int_y, start_x = IMAGE_WIDTH, width = IMAGE_WIDTH, height = IMAGE_HEIGHT, min_y = min_y, max_y = max_y})
  end
  if stats_left then
    local text = GetStatsStr(stats_left)
    local tw, th = bmp:MeasureText(text)
    bmp:DrawText(IMAGE_WIDTH - tw - 5, 30, text, RGB_WHITE)
  end
  if stats_right then
    local text = GetStatsStr(stats_right)
    local tw, th = bmp:MeasureText(text)
    bmp:DrawText(2 * IMAGE_WIDTH - tw - 5, 30, text, RGB_WHITE)
  end
  bmp:WriteBMP(filename)
end

local function RunSimpleGA()
  local graphs_max =
  {
    funcs = {},
    name_x = "Generation #",
    name_y = string.format("Population: %d, Maximum number of '111' Building Blocks(averaged over %d runs)", POPULATION_SIZE, RUNS),
  }
  local graphs_avg =
  {
    funcs = {},
    name_x = "Generation #",
    name_y = string.format("Population: %d, Average number of '111' Building Blocks(averaged over %d runs)", POPULATION_SIZE, RUNS),
  }
  
  local rand_seeds = {}
  for run = 1, RUNS do
    rand_seeds[run] = math.random(1, 50000)
  end
  
  local orderings =
  {
    ["Tight Ordering"] = {ordering = ORDERING_TIGHT, color = RGB_GREEN},
    ["Loose Ordering"] = {ordering = ORDERING_LOOSE, color = RGB_CYAN},
    ["Random Ordering"] = {ordering = ORDERING_RANDOM, color = RGB_RED},
  }
  
  for name, descr in pairs(orderings) do
    graphs_max.funcs[name] = {color = descr.color}
    graphs_avg.funcs[name] = {color = descr.color}
    for run = 1, RUNS do
      print(string.format("%s: %d/%d, Random Seed: %d", name, run, RUNS, rand_seeds[run]))
      math.randomseed(rand_seeds[run])
      local pop = GenInitPop(POPULATION_SIZE, descr.ordering)
      EvalPop(pop, EvaluateChromosome)
      PlotPopBuildingBlocks(pop, 1, graphs_max, name, "max_building_blocks")
      PlotPopBuildingBlocks(pop, 1, graphs_avg, name, "avg_building_blocks")
      for gen = 2, GENERATIONS do
        local new_pop = {template = pop.template, tournament_perm = pop.tournament_perm, crossovers = 0, mutations = 0}
        while #new_pop < #pop do
          local ind1 = TournamentSelect(pop, TOURNAMENT_SIZE)
          local ind2 = TournamentSelect(pop, TOURNAMENT_SIZE)
          local off1, off2, crossovers = Crossover(ind1, ind2)
          new_pop.crossovers = new_pop.crossovers + crossovers
          local mut1 = Mutate(off1)
          table.insert(new_pop, off1)
          new_pop.mutations = new_pop.mutations + mut1
          -- shield in case population size is odd number
          if #new_pop < #pop then
            local mut2 = Mutate(off2)
            table.insert(new_pop, off2)
            new_pop.mutations = new_pop.mutations + mut2
          end
        end
        EvalPop(new_pop, EvaluateChromosome)
        pop = new_pop
        PlotPopBuildingBlocks(pop, gen, graphs_max, name, "max_building_blocks")
        PlotPopBuildingBlocks(pop, gen, graphs_avg, name, "avg_building_blocks")
      end
    end
  end
  
  NormalizeGraphs(graphs_max, RUNS)
  NormalizeGraphs(graphs_avg, RUNS)
  SaveGraphs(IMAGE_FILENAME_SGA_MAX, graphs_max)
  SaveGraphs(IMAGE_FILENAME_SGA_AVG, graphs_avg)
end

local function PlotGraphs(pop, gen, graphs_fitness, graphs_blocks, graphs_lengths)
  PlotPopBuildingBlocks(pop, gen, graphs_fitness, "Max", "max_fitness")
  PlotPopBuildingBlocks(pop, gen, graphs_fitness, "Min", "min_fitness")
  PlotPopBuildingBlocks(pop, gen, graphs_fitness, "Average", "avg_fitness")
  PlotPopBuildingBlocks(pop, gen, graphs_blocks, "Average", "avg_building_blocks", SUB_FUNCTIONS)
  PlotPopBuildingBlocks(pop, gen, graphs_blocks, "Max", "max_building_blocks", SUB_FUNCTIONS)
  PlotPopBuildingBlocks(pop, gen, graphs_blocks, "Min", "min_building_blocks", SUB_FUNCTIONS)
  PlotPopBuildingBlocks(pop, gen, graphs_lengths, "Max", "max_length")
  PlotPopBuildingBlocks(pop, gen, graphs_lengths, "Min", "min_length")
  PlotPopBuildingBlocks(pop, gen, graphs_lengths, "Average", "avg_length")
end

local function RunMessyGA(eval_chrom, method_name)
  local graphs_fitness =
  {
    funcs = {["Max"] = {color = RGB_GREEN}, ["Average"] = {color = RGB_CYAN}, ["Min"] = {color = RGB_RED}},
    name_x = "Generation #",
    name_y = string.format("%s: Fitness(averaged over %d runs)", method_name, RUNS),
  }
  
  local graphs_blocks =
  {
    funcs = {["Average"] = {color = RGB_CYAN}, ["Max"] = {color = RGB_GREEN}, ["Min"] = {color = RGB_RED}},
    name_x = "Generation #",
    name_y = string.format("%s: Proportions of 111 Building Blocks(averaged over %d runs)", method_name, RUNS),
  }
  
  local graphs_lengths =
  {
    funcs = {["Average"] = {color = RGB_CYAN}, ["Max"] = {color = RGB_GREEN}, ["Min"] = {color = RGB_RED}},
    name_x = "Generation #",
    name_y = string.format("%s: Lengths of Messy Chromosomes(averaged over %d runs)", method_name, RUNS),
  }
  
  local stats = {cuts = 0, splices = 0, mutations = 0}
  local template = GenCompetitiveTemplate(1000)
  for run = 1, RUNS do
    print(string.format("Messy GA %s: %d/%d", method_name, run, RUNS))
    local gen = 1
    local pop = GenMessyInitPop()
    pop.template = template
    EvalPop(pop, eval_chrom)
    PlotGraphs(pop, gen, graphs_fitness, graphs_blocks, graphs_lengths)
    
    -- Primordial phase - halve population size every other generation, no Splice & Cut - just Tournament Selection
    local pop_size = #pop
    repeat
      local new_pop = {cuts = pop.cuts, splices = pop.splices, mutations = pop.mutations}
      new_pop.tournament_perm = (pop_size == #pop) and pop.tournament_perm or GenRandomPermutation(pop_size)
      while #new_pop < pop_size do
        local ind = TournamentSelect(pop, TOURNAMENT_SIZE_MESSY)
        table.insert(new_pop, ind)
      end
      gen = gen + 1
      pop = new_pop
      pop_size = ((gen % 2) == 1) and (#pop // 2) or #pop
      EvalPop(pop, function(ind) return ind.fitness, ind.building_blocks end)
      PlotGraphs(pop, gen, graphs_fitness, graphs_blocks, graphs_lengths)
    until pop_size < POPULATION_SIZE
    
    -- Juxtapositional phase - keep population size constant, use Splice & Cut after Tournament Selection
    while gen < GENERATIONS_MESSY do
      local new_pop = {tournament_perm = pop.tournament_perm, cuts = pop.cuts, splices = pop.splices, mutations = pop.mutations}
      while #new_pop < #pop do
        local ind1 = TournamentSelect(pop, TOURNAMENT_SIZE_MESSY)
        local ind2 = TournamentSelect(pop, TOURNAMENT_SIZE_MESSY)
        CutAndSplice(new_pop, #pop, ind1, ind2, PROB_CUT, PROB_SPLICE, PROB_MUTATION)
      end
      new_pop.template = template
      EvalPop(new_pop, eval_chrom)
      gen = gen + 1
      pop = new_pop
      PlotGraphs(pop, gen, graphs_fitness, graphs_blocks, graphs_lengths)
    end
    
    stats.cuts = stats.cuts + pop.cuts
    stats.splices = stats.splices + pop.splices
    stats.mutations = stats.mutations + pop.mutations
  end
  
  NormalizeGraphs(graphs_fitness, RUNS, "int y")
  NormalizeGraphs(graphs_blocks, RUNS) 
  NormalizeGraphs(graphs_lengths, RUNS, "int y")
  stats.cuts = stats.cuts / RUNS
  stats.splices = stats.splices / RUNS
  stats.mutations = stats.mutations / RUNS
  
  return {fitness = graphs_fitness, blocks = graphs_blocks, lengths = graphs_lengths, stats = stats}
end

RunSimpleGA()
local PSPE = RunMessyGA(EvaluateMessyChromosome, "Partial Specification, Partial Evaluation")
local CT = RunMessyGA(EvaluateMessyChromosomeTemplate, "Competitive Template")
SaveGraphs(IMAGE_FILENAME_MGA_FITNESS, PSPE.fitness, "int y", CT.fitness, PSPE.stats, CT.stats)
SaveGraphs(IMAGE_FILENAME_MGA_BBLOCKS, PSPE.blocks, nil, CT.blocks, PSPE.stats, CT.stats)
SaveGraphs(IMAGE_FILENAME_MGA_LENGTHS, PSPE.lengths, "int y", CT.lengths, PSPE.stats, CT.stats)
