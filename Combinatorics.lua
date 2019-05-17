function Combinations(n, k)
  local Cn_k = 1
  for i = n - k + 1, n do
    Cn_k = Cn_k * i
  end
  for i = 2, k do
    Cn_k = Cn_k / i
  end
  
  return Cn_k
end

function GenRandomPermutation(size, perm)
  local avail_pos = {}
  for i = 1, size do
    avail_pos[i] = i
  end

  perm = perm or {}
  perm.index = 1
  for k = 1, size do
    local p = math.random(1, #avail_pos)
    perm[k] = avail_pos[p]
    avail_pos[p] = avail_pos[#avail_pos]
    table.remove(avail_pos)
  end
  
  return perm
end

function GetPermutationNext(perm)
  local value = perm[perm.index]
  perm.index = perm.index + 1
  if perm.index > #perm then
    GenRandomPermutation(#perm, perm)
    perm.index = 1
  end
  
  return value
end
