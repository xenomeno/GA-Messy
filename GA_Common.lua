local WORD_SIZE = 32
local FULL_MASK = (1 << WORD_SIZE) - 1

function GetBitstringWordSize()
  return WORD_SIZE
end

function PackBitstring(bitstr)
  local bits = string.len(bitstr)
  local words = { bits = bits }
  local word, bit_pos, power2 = 0, 1, 1
  for i = 1,  bits do
    local bit = string.sub(bitstr, i, i)
    if bit == "1" then
      word = word + power2
    end
    power2 = power2 << 1
    bit_pos = bit_pos + 1
    if bit_pos > WORD_SIZE then
      table.insert(words, word)
      word, bit_pos, power2 = 0, 1, 1
    end
  end
  if bit_pos > 1 then
    table.insert(words, word)    -- add the last word if started
  end
  
  return words
end

function UnpackBitstring(words)
  local count = #words
  local str_words, bits_left = {}, words.bits
  for idx, word in ipairs(words) do
    local word_bits = (bits_left < WORD_SIZE) and bits_left or WORD_SIZE
    local str_word, power2 = {}, 1
    for i = 1, word_bits do
      str_word[i] = ((word & power2) ~= 0) and "1" or "0"
      power2 = power2 << 1
    end
    bits_left = bits_left - word_bits
    str_words[idx] = table.concat(str_word, "")
  end
  
  return table.concat(str_words, "")
end

function UnpackBits(words)
  local count = #words
  local bits, bits_left = {}, words.bits
  for idx, word in ipairs(words) do
    local word_bits = (bits_left < WORD_SIZE) and bits_left or WORD_SIZE
    local power2 = 1
    for i = 1, word_bits do
      table.insert(bits, ((word & power2) ~= 0) and 1 or 0)
      power2 = power2 << 1
    end
    bits_left = bits_left - word_bits
  end
  
  return bits
end

function CopyBitstring(words)
  local new_words = { bits = words.bits }
  for idx, word in ipairs(words) do
    new_words[idx] = word
  end
  
  return new_words
end

local function GetWordParams(bit_pos)
  local word_idx = 1 + (bit_pos - 1) // WORD_SIZE
  local src_bit_pos = bit_pos - (word_idx - 1) * WORD_SIZE
  local bits_to_word_end = WORD_SIZE - src_bit_pos + 1
  local lo_mask = (1 << (src_bit_pos - 1)) - 1
  local hi_mask = FULL_MASK - lo_mask
  
  return word_idx, src_bit_pos, bits_to_word_end, lo_mask, hi_mask
end

function ExtractBitstring(words, bit_pos, bit_len)
  if bit_pos < 1 or bit_pos > words.bits then
    return { bits = 0 }
  end
  
  bit_len = (words.bits - bit_pos + 1 < bit_len) and (words.bits - bit_pos + 1) or bit_len
  
  local word_idx, src_bit_pos, bits_to_word_end, lo_mask, hi_mask = GetWordParams(bit_pos)
  local src_word = words[word_idx]
  
  -- alternate copying HI bits from current SRC word with LO bits from next SRC word to full a DEST word
  local extract_words = { bits = bit_len }
  while bit_len > 0 do
    local dest_word = 0
    
    -- reads HI word bits
    
    -- all bits left are in the tail of the current SRC word
    if bit_len <= bits_to_word_end then
      local src_mask = ((1 << (src_bit_pos + bit_len - 1)) - 1) - ((1 << src_bit_pos - 1) - 1)
      dest_word = (src_word & src_mask) >> (src_bit_pos - 1)
      table.insert(extract_words, dest_word)
      break
    end
    
    -- read all bits till the end of the word
    dest_word = (src_word & hi_mask) >> (src_bit_pos - 1)
    bit_len = bit_len - bits_to_word_end
    
    -- read LO bits
    
    -- fetch the next SRC word and use its LO bits to fill up DEST word
    word_idx = word_idx + 1
    src_word = words[word_idx]
    
    -- NOTE: if bit pos is 1 whole words are copied except the last one which may be partial
    if src_bit_pos > 1 then
      -- all bits left are in the head of the current SRC word
      if bit_len <= src_bit_pos - 1 then
        local src_mask = (1 << bit_len) - 1
        dest_word = dest_word + ((src_word & src_mask) << bits_to_word_end)
        table.insert(extract_words, dest_word)
        break
      end
    
      -- fill up DEST word with the LO bits from current SRC one
      dest_word = dest_word + ((src_word & lo_mask) << bits_to_word_end)
      bit_len = bit_len - (src_bit_pos - 1)
    end
    
    table.insert(extract_words, dest_word)
  end
  
  return extract_words
end

function ReplaceBitstring(dst_words, dst_pos, src_words, src_pos, src_len)
  if dst_pos < 1 or dst_pos > dst_words.bits then return end
  if src_pos < 1 or src_pos > src_words.bits then return end
  
  src_len = (src_words.bits - src_pos + 1 < src_len) and (src_words.bits - src_pos + 1) or src_len
  dst_words.bits = (dst_words.bits > dst_pos + src_len - 1) and dst_words.bits or (dst_pos + src_len - 1)

  local d_word_idx, d_bit_pos, d_bits_to_word_end, d_lo_mask, d_hi_mask = GetWordParams(dst_pos)
  local d_word = dst_words[d_word_idx]
  
  -- fill up 1st DST word with head bits of SRC word
  local head_bits = (d_bits_to_word_end < src_len) and d_bits_to_word_end or src_len
  local s_word = ExtractBitstring(src_words, src_pos, head_bits)
  d_hi_mask = FULL_MASK - ((1 << (d_bit_pos + src_len - 1)) - 1)
  dst_words[d_word_idx] = (d_word & d_lo_mask) + (s_word[1] << (d_bit_pos - 1)) + (d_word & d_hi_mask)
  src_pos = src_pos + head_bits
  src_len = src_len - head_bits
  d_bit_pos = d_bit_pos + head_bits
  
  -- fill full DST words
  while src_len > 0 do
    d_word_idx = d_word_idx + 1
    -- TODO: optimize ExtractBitstring by passing word_idx, masks and other params
    local len = (src_len < WORD_SIZE) and src_len or WORD_SIZE
    s_word = ExtractBitstring(src_words, src_pos, len)
    if len < WORD_SIZE then break end
    dst_words[d_word_idx] = s_word[1]
    src_pos = src_pos + len
    src_len = src_len - len
    d_bit_pos = d_bit_pos + WORD_SIZE
  end
  
  -- replace 1st bits of last DST word with lat SRC bits
  if src_len > 0 then
    d_word = dst_words[d_word_idx] or 0
    d_hi_mask = ((1 << (dst_words.bits - d_bit_pos + 1)) - 1) - ((1 << src_len) - 1)
    dst_words[d_word_idx] = s_word[1] + (d_word & d_hi_mask)
  end
end

function ExchangeTailBits(words1, words2, tail_pos)
  if words1.bits ~= words2.bits then
    local bits = (words1.bits > words2.bits) and words1.bits or words2.bits
    local words = (#words1 > #words2) and #words1 or #words2
    
    -- make them equal size by appending zeroes
    while #words1 < words do table.insert(words1, 0) end
    while #words2 < words do table.insert(words2, 0) end
    
    words1.bits = bits
    words2.bits = bits
  end
  
  -- bitstrings are equal size:
  local word_idx, bit_pos, bits_to_word_end, lo_mask, hi_mask = GetWordParams(tail_pos)
  
  -- exchange bits from the partial word
  if bit_pos > 1 then
    local word1, word2 = words1[word_idx], words2[word_idx]
    words1[word_idx] = (word1 & lo_mask) + (word2 & hi_mask)
    words2[word_idx] = (word2 & lo_mask) + (word1 & hi_mask)
    word_idx = word_idx + 1
  end

  -- exchange whole words till the end
  while word_idx <= #words1 do
    words1[word_idx], words2[word_idx] = words2[word_idx], words1[word_idx]
    word_idx = word_idx + 1
  end
end

function GetCommonBits(words1, words2)
  local count = (#words1 < #words2) and #words1 or #words2
  local common = 0
  for idx = 1, count do
    local word1 = words1[idx]
    local word2 = words2[idx]
    while word1 > 0 and word2 > 0 do
      if ((word1 & 1) ~= 0) and ((word2 & 1) ~= 0) then
        common = common + 1
      end
      word1 = word1 >> 1
      word2 = word2 >> 1
    end
  end
  
  return common
end

function FlipCoin(bias)
  return math.random() < (bias or 0.5)
end

function GenRandomBitstring(size)
  local bits = {}
  for k = 1, size do
    bits[k] = FlipCoin() and "1" or "0"
  end
  
  return table.concat(bits, "")
end

function TournamentSelect(pop, candidates)
  local perm = pop.tournament_perm
  
  local best
  for i = 1, candidates do
    local idx = perm[perm.index]
    perm.index = perm.index + 1
    if perm.index > #perm then
      perm = GenRandomPermutation(#perm, perm)
    end
    local ind = pop[idx]
    best = (not best or ind.fitness > best.fitness) and ind or best
  end
  
  return best
end

local function TestBitstrings(random_tests, random_bit_len)
  random_tests = random_tests or 100
  random_bit_len = random_bit_len or 100
  
  math.randomseed(os.clock())
  
  for test = 1, random_tests do
    local size = math.random(1, random_bit_len)
    local bitstring1 = GenRandomBitstring(size)
    local bitstring2 = GenRandomBitstring(size)
    local tail_pos = math.random(1, size)
    local packed1 = PackBitstring(bitstring1)
    local packed2 = PackBitstring(bitstring2)
    ExchangeTailBits(packed1, packed2, tail_pos)
    local unpacked1 = UnpackBitstring(packed1)
    local unpacked2 = UnpackBitstring(packed2)
    local str1 = string.sub(bitstring1, 1, tail_pos - 1) .. string.sub(bitstring2, tail_pos, string.len(bitstring2))
    local str2 = string.sub(bitstring2, 1, tail_pos - 1) .. string.sub(bitstring1, tail_pos, string.len(bitstring1))
    if str1 ~= unpacked1 or str2 ~= unpacked2 then
      print(string.format("%s[%d]: %s --> %s", bitstring1, tail_pos, str1, unpacked1))
      print(string.format("%s[%d]: %s --> %s", bitstring2, tail_pos, str2, unpacked2))
    end
  end
  
  -- test packing & unpacking
  local bitstrings =
  {
    "101", "111", "10000", "00000000000000000000000000",
    "11111111",
    "100000000",
    "1111111111111111",
    "10000000000000000",
    "1010101010101010",
    "0101010101010101",
    "11111111111111111111111111111111",
    "100000000000000000000000000000000",
    "10101010101010101010101010101010",
    "01010101010101010101010101010101",
    "1111111111111111111111111111111111111111111111111111111111111111",
    "10000000000000000000000000000000000000000000000000000000000000000",
  }

  for _, bitstring in ipairs(bitstrings) do
    local words = PackBitstring(bitstring)
    local unpacked = UnpackBitstring(words)
    if unpacked ~= bitstring then
      print(bitstring, table.concat(words, ","), unpacked, bitstring == unpacked)
    end
  end

  for i = 1, random_tests do
    local size = math.random(1, random_bit_len)
    local bitstring = GenRandomBitstring(size)
    local words = PackBitstring(bitstring)
    local unpacked = UnpackBitstring(words)
    if bitstring ~= unpacked then
      print("Len: ", size, bitstring, table.concat(words, ","), unpacked, bitstring == unpacked)
    end
  end

  -- test extracting
  local bitstrings =
  {
    { str = "1001101110", pos = 2, len = 9 },
    { str = "001110100", pos = 1, len = 9 },
    { str = "1111111111111111111111111111111001", pos = 31, len = 4 },
    { str = "1111111111111111111111111111101001", pos = 30, len = 4 },
    { str = "1111111111111111111111111111101001", pos = 30, len = 5 },
    { str = "1111111111111111111111111111111111", pos = 31, len = 4 },
    { str = "11111111", pos = 1, len = 4 },
    { str = "11111111", pos = 2, len = 4 },
    { str = "11111111", pos = 3, len = 4 },
    { str = "11111111", pos = 4, len = 4 },
    { str = "11111111", pos = 5, len = 4 },
    { str = "11111111", pos = 6, len = 4 },
    { str = "11111111", pos = 7, len = 4 },
    { str = "11111111", pos = 8, len = 4 },
    { str = "11111111", pos = 9, len = 4 },
    { str = "11111111", pos = 10, len = 4 },
    { str = "1111111111111111111111111111111111", pos = 30, len = 4 },
  }
  
  for _, test in ipairs(bitstrings) do
    local packed = PackBitstring(test.str)
    local extracted = ExtractBitstring(packed, test.pos, test.len)
    local unpacked = UnpackBitstring(extracted)
    local substr = string.sub(test.str, test.pos, test.pos + test.len - 1)
    if unpacked ~= substr then
      print(string.format("Error %s[%d,%d]: %s --> %s", test.str, test.pos, test.len, substr, unpacked))
    end
  end
  
  for test = 1, random_tests do
    local size = math.random(1, random_bit_len)
    local bitstring = GenRandomBitstring(size)
    local pos = math.random(1, size)
    local len = math.random(1, size - pos + 1)
    local packed = PackBitstring(bitstring)
    local extracted = ExtractBitstring(packed, pos, len)
    local unpacked = UnpackBitstring(extracted)
    local substr = string.sub(bitstring, pos, pos + len - 1)
    if substr ~= unpacked then
      print(string.format("Error %s[%d,%d]: %s --> %s", bitstring, pos, len, substr, unpacked))
    end
  end
  
  -- test replacing
  local bitstrings =
  {
    { dest_str = "011", dest_pos = 2, src_str = "010", src_pos = 1, src_len = 3 },
    { dest_str = "0011000011", dest_pos = 8, src_str = "101", src_pos = 1, src_len = 2 },
    { dest_str = "010100110", dest_pos = 9, src_str = "001001", src_pos = 3, src_len = 3 },
    { dest_str = "01", dest_pos = 1, src_str = "101", src_pos = 3, src_len = 1 },
    { dest_str = "00000000", dest_pos = 1, src_str = "11111111", src_pos = 1, src_len = 4 },
  }

  for _, test in ipairs(bitstrings) do
    local dest_packed = PackBitstring(test.dest_str)
    local src_packed = PackBitstring(test.src_str)
    ReplaceBitstring(dest_packed, test.dest_pos, src_packed, test.src_pos, test.src_len)
    local unpacked = UnpackBitstring(dest_packed)
    local substr = string.sub(test.src_str, test.src_pos, test.src_pos + test.src_len - 1)
    local s1 = string.sub(test.dest_str, 1, test.dest_pos - 1)
    local s2 = string.sub(test.dest_str, test.dest_pos + test.src_len, string.len(test.dest_str))
    local str = s1 .. substr .. s2
    if str ~= unpacked then
      print(string.format("Error %s[%d] x %s[%d,%d]: %s --> %s", test.dest_str, test.dest_pos, test.src_str, test.src_pos, test.src_len, str, unpacked))
    end
  end
  
  for test = 1, random_tests do
    local size = math.random(1, random_bit_len)
    local bitstring = GenRandomBitstring(size)
    local pos = math.random(1, size)
    local size2 = math.random(1, random_bit_len)
    local bitstring2 = GenRandomBitstring(size2)
    local pos2 = math.random(1, size2)
    local len2 = math.random(1, size2 - pos2 + 1)
    
    local packed = PackBitstring(bitstring)
    local packed2 = PackBitstring(bitstring2)
    ReplaceBitstring(packed, pos, packed2, pos2, len2)
    local unpacked = UnpackBitstring(packed)
    local substr = string.sub(bitstring2, pos2, pos2 + len2 - 1)
    local s1 = string.sub(bitstring, 1, pos - 1)
    local s2 = string.sub(bitstring, pos + len2, string.len(bitstring))
    local str = s1 .. substr .. s2
    if str ~= unpacked then
      print(string.format("Error %s[%d] x %s[%d,%d]: %s --> %s", bitstring, pos, bitstring2, pos2, len2, str, unpacked))
    end
  end

  -- test tail exchanging
  local bitstrings =
  {
    { str1 = "000001100111000101001101011011", str2 = "001111100100111100101000111011", tail_pos = 13 },
    { str1 = "0", str2 = "1", tail_pos = 1 },
    { str1 = "01", str2 = "11", tail_pos = 1 },
    { str1 = "00000000", str2 = "11111111", tail_pos = 5 },
  }
  
  for _, test in ipairs(bitstrings) do
    local packed1 = PackBitstring(test.str1)
    local packed2 = PackBitstring(test.str2)
    ExchangeTailBits(packed1, packed2, test.tail_pos)
    local unpacked1 = UnpackBitstring(packed1)
    local unpacked2 = UnpackBitstring(packed2)
    local str1 = string.sub(test.str1, 1, test.tail_pos - 1) .. string.sub(test.str2, test.tail_pos, string.len(test.str2))
    local str2 = string.sub(test.str2, 1, test.tail_pos - 1) .. string.sub(test.str1, test.tail_pos, string.len(test.str1))
    if str1 ~= unpacked1 or str2 ~= unpacked2 then
      print(string.format("%s[%d]: %s --> %s", test.str1, test.tail_pos, str1, unpacked1))
      print(string.format("%s[%d]: %s --> %s", test.str2, test.tail_pos, str2, unpacked2))
    end
  end
end

--TestBitstrings()