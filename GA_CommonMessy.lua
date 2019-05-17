function ResoloveOverSpecification(messy_chrom)
  local chrom = {}
  for _, loci in ipairs(messy_chrom) do
    if chrom[loci.gene] == nil then
      chrom[loci.gene] = loci.allele
    end
  end
  
  return chrom
end

function ResolveUnderSpecification(messy_chrom, template)
  for i = 1, #template do
    messy_chrom[i] = messy_chrom[i] or template[i]
  end
end

function EvaluateResolvedChromosome(chrom, order, func)
  local fitness, building_blocks = 0, 0
  for pos = 1, #chrom, order do
    local code, building_block = 0, 1
    for bit = 1, order do
      local bit_pos = pos + bit - 1
      if chrom[bit_pos] == 1 then
        code = code + (1 << (order - bit))
      else
        building_block = 0
      end
    end
    fitness = fitness + func[code]
    building_blocks = building_blocks + building_block
  end

  return fitness, building_blocks
end

function MutateMessy(chrom, prob_mutation)
  local mutations = 0
  for _, loci in ipairs(chrom) do
    if math.random() < prob_mutation then
      loci.allele = 1 - loci.allele
      mutations = mutations + 1
    end
  end
  
  return mutations
end

function CutAndSplice(pop, max_size, ind1, ind2, prob_cut, prob_splice, prob_mutation)
  local chrom1, chrom2 = ind1.chrom, ind2.chrom
  local prob_cut_overall1 = prob_cut * (#chrom1 - 1)
  local prob_cut_overall2 = prob_cut * (#chrom2 - 1)
  
  -- collect pieces for splicing
  local pieces = {}
  if math.random() < prob_cut_overall1 then
    -- cut the first one
    local cut_site1 = math.random(1, #chrom1 - 1)
    table.insert(pieces, {chrom1, 1, cut_site1})
    if math.random() < prob_cut_overall2 then
      -- cut the second one too
      local cut_site2 = math.random(1, #chrom2 - 1)
      table.insert(pieces, {chrom2, cut_site2 + 1, #chrom2})
      table.insert(pieces, {chrom2, 1, cut_site2})
      pop.cuts = pop.cuts + 1
    else
      -- keep the second one intact
      table.insert(pieces, {chrom2, 1, #chrom2})
    end
    table.insert(pieces, {chrom1, cut_site1 + 1, #chrom1})
    pop.cuts = pop.cuts + 1
  else
    -- keep the first one intact
    table.insert(pieces, {chrom1, 1, #chrom1})
    if math.random() < prob_cut_overall2 then
      -- cut the second one
      local cut_site = math.random(#chrom2 - 1)
      table.insert(pieces, {chrom2, cut_site + 1, #chrom2})
      table.insert(pieces, {chrom2, 1, cut_site})
      pop.cuts = pop.cuts + 1
    else
      -- keep the second one intact too
      table.insert(pieces, {chrom2, 1, #chrom2})
    end
  end
  
  -- try to splice pieces in order
  local index = 1
  while #pop < max_size and index <= #pieces do
    local piece = pieces[index]
    local orig_chrom, pos1, pos2 = piece[1], piece[2], piece[3]
    local chrom = {}
    for k = pos1, pos2 do
      table.insert(chrom, orig_chrom[k])
    end
    index = index + 1
    if (index <= #pieces) and (math.random() < prob_splice) then
      piece = pieces[index]
      orig_chrom, pos1, pos2 = piece[1], piece[2], piece[3]
      for k = pos1, pos2 do
        table.insert(chrom, orig_chrom[k])
      end
      index = index + 1
      pop.splices = pop.splices + 1
    end
    local mutations = MutateMessy(chrom, prob_mutation)
    pop.mutations = pop.mutations + mutations
    table.insert(pop, {chrom = chrom})
  end
end

function GetGenes(chrom)
  local genes, genes_map = {}, {}
  for _, loci in ipairs(chrom) do
    local gene = loci.gene
    if not genes_map[gene] then
      genes_map[gene] = true
      table.insert(genes, gene)
    end
  end
  
  return genes, genes_map
end

function GenCommonGenesMessy(ind1, ind2)
  local common_genes = 0
  
  local genes1_map = ind1.genes_map
  local genes2 = ind2.genes
  for _, gene in ipairs(genes2) do
    if genes1_map[gene] then
      common_genes = common_genes + 1
    end
  end
  
  return common_genes  
end

function GetThresholdMessy(chrom1, chrom2, len, z_score)
  local len1, len2 = #chrom1, #chrom2
  local stddev = math.sqrt(len1 * (len - len1) * len2 * (len - len2) / (len * len * (len - 1)))
  local threshold = math.ceil(len1 * len2 / len + z_score * stddev)
  
  return threshold
end

g_Likes, g_Misses, g_TieBreaking = 0, 0, 0

function BinaryTournamentSelectMessy(pop, len)
  local perm = pop.tournament_perm
  local alpha, z_score = 0.001, 3.091
  local tests = Min(math.ceil(1.0 / alpha), #pop)
  
  local best = pop[GetPermutationNext(perm)]
  local old_likes = g_Likes
  for test = 0, tests - 1 do
    local next_index = (perm.index + test > #perm) and (perm.index + test - #perm) or (perm.index + test)
    local ind = pop[perm[next_index]]
    local threshold = GetThresholdMessy(best.chrom, ind.chrom, len, z_score)
    local common_genes = GenCommonGenesMessy(best, ind)
    if common_genes >= threshold then
      g_Likes = g_Likes + 1
      perm[perm.index], perm[next_index] = perm[next_index], perm[perm.index]
      GetPermutationNext(perm)    -- advance the permutation
      if ind.fitness == best.fitness then
        -- tie breaking
        if #ind.chrom == #best.chrom then
          best = (math.random() < 0.5) and ind or best
        else
          best = (#ind.chrom < #best.chrom) and ind or best
          g_TieBreaking = g_TieBreaking + 1
        end
      else
        best = (ind.fitness > best.fitness) and ind or best
      end
      break
    end
  end
  if old_likes == g_Likes then
    g_Misses = g_Misses + 1
  end
  
  return best
end

function BinaryTournamentSelectMessyNoThresholding(pop)
  local perm = pop.tournament_perm
  
  local ind1 = pop[GetPermutationNext(perm)]
  local ind2 = pop[GetPermutationNext(perm)]
  if ind1.fitness == ind2.fitness then
    -- tie breaking
    if #ind1.chrom == #ind2.chrom then
      return (math.random() < 0.5) and ind1 or ind2
    else
      return (#ind1.chrom < #ind2.chrom) and ind1 or ind2
    end
  else
    return (ind1.fitness > ind2.fitness) and ind1 or ind2
  end
end
