dofile("Bitmap.lua")
dofile("Graphics.lua")
dofile("Statistics.lua")
dofile("Combinatorics.lua")
dofile("CommonAI.lua")
dofile("GA_Common.lua")
dofile("GA_CommonMessy.lua")

local PROB_ALPHA              = 0.2559
local RUNS                    = 5
local EPOCHS                  = 1
local LEVEL_WISE_START        = 3
local GENERATIONS_SELECTION   = 7
local GENERATIONS             = 35
local INIT_LENGTH_FACTOR      = 1.0
local PROB_CUT                = 0.03
local PROB_SPLICE             = 1.0
local PROB_MUTATION           = 0.0
local ORDER_FITNESS           = {[3] = ORDER_3_DECEPTIVE_FITNESS, [5] = ORDER_5_DECEPTIVE_FITNESS}
local PRINT_POPULATION_STATS  = false
local BASE_LINE_FILENAME      = "FMGA/BaseLine.bmp"
local LARGE_SCALE_FILENAME    = "FMGA/LargeScale.bmp"
local BASE_BBLOCKS_FILENAME   = "FMGA/BaseLineBuildingBlocks.bmp"
local LARGE_BBLOCKS_FILENAME  = "FMGA/LargeScaleBuildingBlocks.bmp"
local BASE_GENES_FILENAME     = "FMGA/BaseLineGenes.bmp"
local LARGE_GENES_FILENAME    = "FMGA/LargeScaleGenes.bmp"
local HISTOGRAM_FILENAME      = "FMGA/Histogram_%03d.bmp"

local N_G_STRING_LEN          = 20
local N_G_K_MIN               = 1
local N_G_K_MAX               = 4
local N_G_FILENAME            = "FMGA/N_G.bmp"

local AREA_MIN                = 0.00001
local AREA_MAX                = 0.5
local AREA_STEP               = 0.00001
local AREA_FILENAME           = "FMGA/C_ALPHA.bmp"

local IMAGE_WIDTH             = 1000
local IMAGE_HEIGHT            = 1000

local COLORS          = {RGB_GREEN, RGB_CYAN, RGB_RED, RGB_WHITE}

local function PlotPopSizeInitStrLen(points, len, k)
  for l = k, len do
    local size = math.ceil(Combinations(len, l) / Combinations(len - k, l - k))
    table.insert(points, {x = l, y = size})
  end
end

local function GenPopSizeInitStrLen(len)
  local graphs = {name_x = "Initial string length, l'", name_y = "Population Size, n_g", funcs = {}}
  for k = N_G_K_MIN, N_G_K_MAX do
    local points = {color = COLORS[k]}
    PlotPopSizeInitStrLen(points, len, k)
    local name = string.format("k=%d", k)
    graphs.funcs[name] = points
  end
  
  local bmp = Bitmap.new(IMAGE_WIDTH, IMAGE_HEIGHT, RGB_BLACK)
  DrawGraphs(bmp, graphs, {int_x = true, skip_KP = true, int_y = true})
  bmp:WriteBMP(N_G_FILENAME)
end

local function GetInitPopSize(len, len_start, k, z_score, subfunctions, noise_to_signal_sqr)
  local c_mul = 1.0
  for i = 1, k do
    c_mul = c_mul * (len - i + 1) / (len_start - i + 1)
  end
  local pow = math.pow(2, k)  
  local size = c_mul * 2 * z_score * z_score * noise_to_signal_sqr * (subfunctions - 1) * pow
  
  return math.ceil(size)
end

local function GenZScoreSqrAsErrorArea()
  local graphs = {name_x = "Area Alpha", name_y = "c=Z-Score(Alpha)^2", funcs = {}}
  local points = {color = RGB_GREEN}
  for alpha = AREA_MIN, AREA_MAX, AREA_STEP do
    local z_score = GetZScoreRightTail(alpha)
    table.insert(points, {x = alpha, y = z_score * z_score})
  end
  graphs.funcs["Square of Z-Score"] = points
  
  local bmp = Bitmap.new(IMAGE_WIDTH, IMAGE_HEIGHT, RGB_BLACK)
  DrawGraphs(bmp, graphs, {skip_KP = true, axis_y_format = "%.0f", max_x = 0.5})
  bmp:WriteBMP(AREA_FILENAME)
end

local function ProbabilisticallyCompleteInitialization(subfunctions, order, level, alpha)
  local len = subfunctions * order
  local start_len = len - level
  local z_score = GetZScoreRightTail(alpha)
  local mean, stddev, variance, signal, max = GetFuncStats(ORDER_FITNESS[order])
  local noise_to_signal_sqr = variance / (signal * signal)
  local pop_size = GetInitPopSize(len, start_len, level, z_score, subfunctions, noise_to_signal_sqr)
  
  local pop = {func_order = order, func_fitness = ORDER_FITNESS[order]}
  for i = 1, pop_size do
    local genes = GenRandomPermutation(len)
    local chrom = {}
    for k = 1, start_len do
      local gene = GetPermutationNext(genes)
      chrom[k] = {gene = gene, allele = (math.random() < 0.5) and 1 or 0} 
    end
    pop[i] = {chrom = chrom}
  end
  
  return pop, max
end

local function EvaluatePopulation(pop, no_recalc)
  local template = pop.template
  local total_fitness, min_fitness, max_fitness = 0
  local total_bb, min_bb, max_bb = 0
  for _, ind in ipairs(pop) do
    local fitness, building_blocks
    if no_recalc then
      fitness, building_blocks = ind.fitness, ind.building_blocks
    else
      local chrom = ResoloveOverSpecification(ind.chrom)
      ResolveUnderSpecification(chrom, template)
      fitness, building_blocks = EvaluateResolvedChromosome(chrom, pop.func_order, pop.func_fitness)
      ind.fitness, ind.building_blocks = fitness, building_blocks
      ind.genes, ind.genes_map = GetGenes(ind.chrom)
      ind.resolved_chrom = chrom
    end
    min_fitness = (not min_fitness or fitness < min_fitness) and fitness or min_fitness
    max_fitness = (not max_fitness or fitness > max_fitness) and fitness or max_fitness
    total_fitness = total_fitness + fitness
    min_bb = (not min_bb or building_blocks < min_bb) and building_blocks or min_bb
    max_bb = (not max_bb or building_blocks > max_bb) and building_blocks or max_bb
    total_bb = total_bb + building_blocks
  end
  pop.min_fitness, pop.max_fitness, pop.total_fitness = min_fitness, max_fitness, total_fitness
  pop.avg_fitness = total_fitness / #pop
  pop.min_building_blocks, pop.max_building_blocks = min_bb, max_bb
  pop.avg_building_blocks = total_bb / #pop
end

local function FilterReducePopulation(pop, len)
  for _, ind in ipairs(pop) do
    local chrom = ind.chrom
    while #chrom > len do
      local pos = math.random(1, #chrom)
      table.remove(chrom, pos)
    end
  end
end

local function PlotPopulation(pop, gen, funcs, funcs_blocks)
  if funcs["Max"][gen] then
    funcs["Max"][gen].y = funcs["Max"][gen].y + pop.max_fitness
    funcs["Average"][gen].y = funcs["Average"][gen].y + pop.avg_fitness
    funcs_blocks["Max B-Blocks"][gen].y = funcs_blocks["Max B-Blocks"][gen].y + pop.max_building_blocks
    funcs_blocks["Average B-Blocks"][gen].y = funcs_blocks["Average B-Blocks"][gen].y + pop.avg_building_blocks
  else
    funcs["Max"][gen] = {x = gen, y = pop.max_fitness}
    funcs["Average"][gen] = {x = gen, y = pop.avg_fitness}
    funcs_blocks["Max B-Blocks"][gen] = {x = gen, y = pop.max_building_blocks}
    funcs_blocks["Average B-Blocks"][gen] = {x = gen, y = pop.avg_building_blocks}
  end
end

local function NormalizeGraphs(graphs, runs, percents, int_y)
  local scale = 1.0 / runs
  local max_y
  for name, func in pairs(graphs.funcs) do
    local start = func[0] and 0 or 1
    local total_y = 0
    if percents then
      for k = start, #func do
        local y = int_y and math.floor(func[k].y * scale) or (func[k].y * scale)
        total_y = total_y + y
      end
    end
    
    for k = start, #func do
      if percents then
        func[k].y = int_y and math.floor(100.0 * func[k].y * scale / total_y) or (100.0 * func[k].y * scale / total_y)
      else
        func[k].y = int_y and math.floor(func[k].y * scale) or (func[k].y * scale)
      end
      max_y = (not max_y or func[k].y > max_y) and func[k].y or max_y
    end
  end
  
  return max_y
end

local function FormatResolveChromosome(chrom, order)
  local formated = {}
  for i, v in ipairs(chrom) do
    table.insert(formated, chrom[i])
    if i % order == 0 then
      table.insert(formated, " ")
    end
  end
  
  return table.concat(formated, "")
end

-- TODO: remove this when debugging done
local function PrintPopStats(pop, gen, level, funcs_genes, funcs_blocks, graphs_histogram)
  if not PRINT_POPULATION_STATS then return end

  if level == pop.func_order then
    for gene = 1, #pop.template do
      if not graphs_histogram["Histogram"][gene] then
        graphs_histogram["Histogram"][gene] = {x = gene, y = 0}
      end
    end
  end
  local genes = {}
  local total_genes, max_genes = 0, 0
  local total_blocks, max_blocks = 0, 0
  for idx, ind in ipairs(pop) do
    for _, gene in ipairs(ind.genes) do
      genes[gene] = true
      if level == pop.func_order then
        graphs_histogram["Histogram"][gene].y = graphs_histogram["Histogram"][gene].y + 1
      end
    end
    local ind_blocks, genes_map = 0, ind.genes_map
    for pos = 1, #pop.template, pop.func_order do
      local block = 1
      for bit = 1, pop.func_order do
        if genes_map[pos + bit - 1] == nil then
          block = 0
          break
        end
      end
      ind_blocks = ind_blocks + block
    end
    total_genes = total_genes + #ind.genes
    max_genes = (#ind.genes > max_genes) and #ind.genes or max_genes
    total_blocks = total_blocks + ind_blocks
    max_blocks = (ind_blocks > max_blocks) and ind_blocks or max_blocks
    
    local chrom, binary_chrom = {}, {}
    for i = 1, #pop.template do
      binary_chrom[i] = "?"
    end
    for i, loci in ipairs(ind.chrom) do
      table.insert(chrom, string.format("(%d %d)", loci.gene, loci.allele))
      if binary_chrom[loci.gene] == "?" then
        binary_chrom[loci.gene] = loci.allele
      end
    end
    print(string.format("%d: Level: %d, Fitness: %.2f, Binary: %s, Chrom: %s, Messy Chrom: %s", idx, level, ind.fitness, FormatResolveChromosome(ind.resolved_chrom, pop.func_order), FormatResolveChromosome(binary_chrom, pop.func_order), table.concat(chrom, "")))
  end
  local count_genes = 0
  for gene, _ in pairs(genes) do
    count_genes = count_genes + 1
  end
  local avg_genes = total_genes / #pop
  local avg_blocks = total_blocks / #pop
  print(string.format("Gen: %d, Size: %d, Total Genes: %d, Avg Genes: %.2f, Avg Fitness: %.2f, Max Fitness: %.2f, Avg Blocks: %.2f, Max Blocks: %d", gen, #pop, count_genes, avg_genes, pop.avg_fitness, pop.max_fitness, avg_blocks, max_blocks))
  if level == pop.func_order then
    if funcs_genes["Total"][gen] then
      funcs_genes["Total"][gen].y = funcs_genes["Total"][gen].y + count_genes
      funcs_genes["Average"][gen].y = funcs_genes["Average"][gen].y + avg_genes
      funcs_genes["Max"][gen].y = funcs_genes["Max"][gen].y + max_genes
      funcs_blocks["Average Blocks"][gen].y = funcs_blocks["Average Blocks"][gen].y + avg_blocks
      funcs_blocks["Max Blocks"][gen].y = funcs_blocks["Max Blocks"][gen].y + max_blocks
    else
      funcs_genes["Total"][gen] = {x = gen, y = count_genes}
      funcs_genes["Average"][gen] = {x = gen, y = avg_genes}
      funcs_genes["Max"][gen] = {x = gen, y = max_genes}
      funcs_blocks["Average Blocks"][gen] = {x = gen, y = avg_blocks}
      funcs_blocks["Max Blocks"][gen] = {x = gen, y = max_blocks}
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

local function PrimordialPhase(pop, gen, run, len, len_prev, gamma, len_init, len_problem, lens, graphs, graphs_blocks, graphs_genes, histogram_gens)
  if gen > 1 and (gen - 1) % GENERATIONS_SELECTION == 0 then
    -- BBs filtering & reduction - reduce chromozome length every GENERATIONS_SELECTION
    len = len_prev // gamma
    if len >= len_init then
      FilterReducePopulation(pop, len)
      EvaluatePopulation(pop)
      if run == 1 then
        table.insert(lens, len)
      end
    end
    len_prev = len
  end
  
  pop.tournament_perm = GenRandomPermutation(#pop)
  local new_pop = {template = pop.template, tournament_perm = pop.tournament_perm, func_order = pop.func_order, func_fitness = pop.func_fitness, cuts = pop.cuts, splices = pop.splices, mutations = pop.mutations}
  while #new_pop < #pop do
    local ind = BinaryTournamentSelectMessy(pop, len_problem)
    table.insert(new_pop, ind)
  end
  EvaluatePopulation(new_pop, "no recalc")
  print(string.format("Run: #%d/%d, Gen: %d, Pop: %d, Likes: %d, Misses: %d, Tie Breaking: %d", run, RUNS, gen, #pop, g_Likes, g_Misses, g_TieBreaking))
  
  return new_pop, len, len_prev
end

local function JuxtapositionalPhase(pop, gen, graphs, graphs_blocks, graphs_genes, histogram_gens)
  pop.tournament_perm = GenRandomPermutation(#pop)
  local new_pop = {tournament_perm = pop.tournament_perm, cuts = pop.cuts, splices = pop.splices, mutations = pop.mutations, func_order = pop.func_order, func_fitness = pop.func_fitness}
  while #new_pop < #pop do
    local ind1 = BinaryTournamentSelectMessyNoThresholding(pop)
    local ind2 = BinaryTournamentSelectMessyNoThresholding(pop)
    CutAndSplice(new_pop, #pop, ind1, ind2, PROB_CUT, PROB_SPLICE, PROB_MUTATION)
  end
  new_pop.template = pop.template
  EvaluatePopulation(new_pop)
  
  return new_pop
end

local function RunFastMessyGA(subfunctions_count, subfunctions_order, gamma, filename, filename_blocks, filename_genes)
  local graphs =
  {
    funcs = {["Max"] = {color = RGB_GREEN}, ["Average"] = {color = RGB_CYAN}},
    name_x = "Generation Number",
    name_y = string.format("Function Value(averaged over %d runs)", RUNS),
  }
  local graphs_blocks =
  {
    funcs =
    {
      ["Max B-Blocks"] = {color = RGB_GREEN}, ["Average B-Blocks"] = {color = RGB_CYAN},
      ["Max Blocks"] = {color = RGB_WHITE}, ["Average Blocks"] = {color = RGB_MAGENTA},
    },
    name_x = "Generation Number",
    name_y = string.format("Building Blocks(averaged over %d runs)", RUNS),
  }
  local graphs_genes =
  {
    funcs = {["Total"] = {color = RGB_GREEN}, ["Average"] = {color = RGB_RED}, ["Max"] = {color = RGB_CYAN}},
    name_x = "Generation Number",
    name_y = string.format("Genes(averaged over %d runs)", RUNS),
  }
  local histogram_gens = {}
  
  local stats = {cuts = 0, splices = 0, mutations = 0}
  local lens = {}
  local max_fitness
  for run = 1, RUNS do
    local template = {}
    for i = 1, subfunctions_count * subfunctions_order do
      template[i] = (math.random() < 0.5) and 1 or 0
    end
    for epoch = 1, EPOCHS do
      local time_start = os.time()
      for level = LEVEL_WISE_START, subfunctions_order do
        local pop, max = ProbabilisticallyCompleteInitialization(subfunctions_count, subfunctions_order, level, PROB_ALPHA)
        pop.template = template
        max_fitness = (not max_fitness or max > max_fitness) and max or max_fitness
        print(string.format("Run #%d/%d, Epoch: %d, Level: %d, Population: %d", run, RUNS, epoch, level, #pop))
        EvaluatePopulation(pop)
        if level == subfunctions_order then
          PlotPopulation(pop, 0, graphs.funcs, graphs_blocks.funcs)
          histogram_gens[0] = {funcs = {["Histogram"] = {color = RGB_GREEN}}, name_x = "Code", name_y = string.format("Quantity in %%(averaged over %d runs)", RUNS)}
        end
        PrintPopStats(pop, 0, level, graphs_genes.funcs, graphs_blocks.funcs, level == pop.func_order and histogram_gens[0].funcs)
        
        local len_problem = subfunctions_count * subfunctions_order
        local len_prev = len_problem
        local len = len_prev - level
        local len_init = math.floor(INIT_LENGTH_FACTOR * level)
        if run == 1 then
          table.insert(lens, len)
        end
        pop.cuts, pop.splices, pop.mutations = 0, 0, 0
        local gen = 1
        while len >= len_init do
          -- Primordial phase - pump up high fit BBs via Tournament Selection
          histogram_gens[gen] = {funcs = {["Histogram"] = {color = RGB_GREEN}}, name_x = "Code", name_y = string.format("Quantity in %%(averaged over %d runs)", RUNS)}
          pop, len, len_prev = PrimordialPhase(pop, gen, run, len, len_prev, gamma, len_init, len_problem, lens, graphs, graphs_blocks, graphs_genes, histogram_gens)
          if level == subfunctions_order then
            PlotPopulation(pop, gen, graphs.funcs, graphs_blocks.funcs)
          end
          PrintPopStats(pop, gen, level, graphs_genes.funcs, graphs_blocks.funcs, histogram_gens[gen].funcs)
          gen = gen + 1
        end
        local gen_finish = Max(GENERATIONS, gen + GENERATIONS_SELECTION)
        while gen <= gen_finish do
          --keep population size constant, use Splice & Cut after Tournament Selection
          histogram_gens[gen] = {funcs = {["Histogram"] = {color = RGB_GREEN}}, name_x = "Code", name_y = string.format("Quantity in %%(averaged over %d runs)", RUNS)}
          pop = JuxtapositionalPhase(pop, gen, graphs, graphs_blocks, graphs_genes, histogram_gens)
          if level == subfunctions_order then
            PlotPopulation(pop, gen, graphs.funcs, graphs_blocks.funcs)
          end
          PrintPopStats(pop, gen, level, graphs_genes.funcs, graphs_blocks.funcs, histogram_gens[gen].funcs)
          gen = gen + 1
        end
        stats.cuts, stats.splices, stats.mutations = stats.cuts + pop.cuts, stats.splices + pop.splices, stats.mutations + pop.mutations
        -- Save locally best chromosome as template for the next level
        local best = table.max(pop, function(ind) return ind.fitness end)
        for i = 1, #template do
          template[i] = best.resolved_chrom[i]
        end
        local messy_chrom, binary_chrom = {}, {}
        for i = 1, #pop.template do
          binary_chrom[i] = "?"
        end
        for idx, loci in ipairs(best.chrom) do
          table.insert(messy_chrom, string.format("(%d %d)", loci.gene, loci.allele))
          if binary_chrom[loci.gene] == "?" then
            binary_chrom[loci.gene] = loci.allele
          end
        end
        local time = os.time() - time_start
        print(string.format("Run: #%d/%d, Epoch: %d, Level: %d, Best template: %s, Best Chrom: %s, Best Messy Chrom(#%d len): %s, Fitness: %.2f, Time: %ds", run, RUNS, epoch, level, FormatResolveChromosome(template, subfunctions_order), FormatResolveChromosome(binary_chrom, subfunctions_order), #messy_chrom, table.concat(messy_chrom, ""), best.fitness, time))
      end
    end
  end
  
  NormalizeGraphs(graphs, RUNS * EPOCHS)
  NormalizeGraphs(graphs_blocks, RUNS * EPOCHS)
  NormalizeGraphs(graphs_genes, RUNS * EPOCHS)
  stats.cuts, stats.splices, stats.mutations = stats.cuts / (RUNS * EPOCHS), stats.splices / (RUNS * EPOCHS), stats.mutations / (RUNS * EPOCHS)

  local bmp = Bitmap.new(IMAGE_WIDTH, IMAGE_HEIGHT, RGB_BLACK)
  DrawGraphs(bmp, graphs,
  {
    skip_KP = true, int_x = true,
    min_y = max_fitness / 2, max_y = subfunctions_count * max_fitness, min_x = 0, max_x = GENERATIONS,
    div_x = GENERATIONS // GENERATIONS_SELECTION, div_y = 8,
    x_dividers = function(section) return lens[section] and string.format("l'=%d", lens[section]) end
  })
  local text = GetStatsStr(stats)
  local tw, th = bmp:MeasureText(text)
  bmp:DrawText(IMAGE_WIDTH - tw - 5, 30, text, RGB_WHITE)
  bmp:WriteBMP(filename)
  if PRINT_POPULATION_STATS then
    local bmp = Bitmap.new(IMAGE_WIDTH, IMAGE_HEIGHT, RGB_BLACK)
    DrawGraphs(bmp, graphs_blocks,
    {
      skip_KP = true, int_x = true,
      min_y = 0, max_y = subfunctions_count, min_x = 0, max_x = GENERATIONS,
      div_x = GENERATIONS // GENERATIONS_SELECTION, div_y = 10,
      x_dividers = function(section) return lens[section] and string.format("l'=%d", lens[section]) end
    })
    bmp:WriteBMP(filename_blocks)
    local bmp = Bitmap.new(IMAGE_WIDTH, IMAGE_HEIGHT, RGB_BLACK)
    DrawGraphs(bmp, graphs_genes,
    {
      skip_KP = true, int_x = true,
      min_y = 0, max_y = subfunctions_count * subfunctions_order, min_x = 0, max_x = GENERATIONS,
      div_x = GENERATIONS // GENERATIONS_SELECTION, div_y = 10,
      x_dividers = function(section) return lens[section] and string.format("l'=%d", lens[section]) end
    })
    bmp:WriteBMP(filename_genes)
  
    -- draw histogram sequence
    local max_percents
    for gen = 0, GENERATIONS do
      local max_y = NormalizeGraphs(histogram_gens[gen], RUNS * EPOCHS, "percents")
      max_percents = (not max_percents or max_y > max_percents) and max_y or max_percents
    end
    max_percents = math.pow(10, math.ceil(math.log10(max_percents)))

    for gen = 0, GENERATIONS do
      local bmp = Bitmap.new(IMAGE_WIDTH, IMAGE_HEIGHT, RGB_BLACK)
      DrawGraphs(bmp, histogram_gens[gen],
      {
        center_x = 1, min_y = 0, max_y = max_percents, int_x = true, int_y = false, bars = true,
        div_x = subfunctions_count * subfunctions_order - 1,
      })
      bmp:WriteBMP(string.format(HISTOGRAM_FILENAME, gen))
    end
  end
end

RunFastMessyGA(10, 3, 2, BASE_LINE_FILENAME, BASE_BBLOCKS_FILENAME, BASE_GENES_FILENAME)
RunFastMessyGA(10, 5, 3, LARGE_SCALE_FILENAME, LARGE_BBLOCKS_FILENAME, LARGE_GENES_FILENAME)
GenPopSizeInitStrLen(N_G_STRING_LEN)
GenZScoreSqrAsErrorArea()
