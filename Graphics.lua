dofile("Bitmap.lua")
dofile("CommonAI.lua")

local function GetFuncsOrder(funcs, sort_cmp)
  local order = {}
  if sort_cmp then
    local entries = {}
    for name, func in pairs(funcs) do
      table.insert(entries, {name = name, sort_idx = func.sort_idx})
    end
    table.sort(entries, sort_cmp)
    for k, entry in ipairs(entries) do
      order[k] = entry.name
    end
  else
    for name in pairs(funcs) do
      table.insert(order, name)
    end
    table.sort(order)
  end
  
  return order
end

local function GetFuncsMinMaxSizes(funcs, descr)
  local min_x, max_x, min_y, max_y
  local any_func = funcs[next(funcs)]
  local any_pt = any_func[next(any_func)]
  if descr.center_x then
    min_x, max_x = descr.center_x, descr.center_x
  else
    min_x, max_x = any_pt.x, any_pt.x
  end
  if descr.center_y then
    min_y, max_y = descr.center_y, descr.center_y
  else
    min_y, max_y = any_pt.y, any_pt.y
  end
  min_x = (descr.min_x and descr.min_x < min_x) and descr.min_x or min_x
  max_x = (descr.max_x and descr.max_x > max_x) and descr.max_x or max_x
  min_y = (descr.min_y and descr.min_y < min_y) and descr.min_y or min_y
  max_y = (descr.max_y and descr.max_y > max_y) and descr.max_y or max_y
  local scale = descr.y_scaling
  if scale then
    min_y, max_y = scale(min_y), scale(max_y)
  end
  if descr.y_line then
    local y_line = scale and scale(descr.y_line) or descr.y_line
    min_y = (min_y < y_line) and min_y or y_line
    max_y = (max_y > y_line) and max_y or y_line
  end
  for name, func_points in pairs(funcs) do
    local start_idx = func_points[0] and 0 or 1
    local end_idx = #func_points
    for idx = start_idx, end_idx do
      local pt = func_points[idx]
      local x, y = pt.x, pt.y
      min_x = (x < min_x) and x or min_x
      max_x = (x > max_x) and x or max_x
      if scale then
        -- TODO: calculate Y scaling only once - store it somewhere for reuse
        y = scale(y)
      end
      min_y = (y < min_y) and y or min_y
      max_y = (y > max_y) and y or max_y
    end
  end
  
  local center_x = descr.center_x or min_x
  local center_y = descr.center_y and (scale and scale(descr.center_y) or descr.center_y) or min_y
  local size_x = descr.int_x and math.ceil(max_x - min_x) or (max_x - min_x)
  local size_y = descr.int_y and math.ceil(max_y - min_y) or (max_y - min_y)
  if descr.scale_uniformly then
    if size_x > size_y then
      size_y = size_x
    else
      size_x = size_y
    end
  end
  
  return center_x, center_y, size_x, size_y
end

function DrawGraphs(bmp, funcs_data, descr)
  descr = descr or {}
  
  local div_x, div_y = descr.div_x or 10, descr.div_y or 10
  local skip_KP = descr.skip_KP
  local write_frames, write_name = descr.write_frames, descr.write_name
  local frames_step = descr.frames_step or 1
  local start_x, start_y = descr.start_x or 0, descr.start_y or 0
  local width, height = descr.width or bmp.width, descr.height or bmp.height
  local axis_x_format, axis_y_format = descr.axis_x_format, descr.axis_y_format
  local int_x, int_y = descr.int_x, descr.int_y
  
  local order = GetFuncsOrder(funcs_data.funcs, descr.sort_cmp)
  local center_x, center_y, size_x, size_y = GetFuncsMinMaxSizes(funcs_data.funcs, descr)
  
  local spacing_x, spacing_y = width // (div_x + 2), height // (div_y + 2)
  local Ox = start_x + spacing_x
  local Oy = start_y + height - spacing_y
  local axes_color = funcs_data.axes_color or RGB_GRAY
  local bars_y_padding = descr.bars_y_padding or 5
  if not axis_x_format then
    axis_x_format = int_x and "%d" or "%.2f"
  end
  if not axis_y_format then
    axis_y_format = int_y and "%d" or "%.2f"
  end

  -- draw coordinate system - X axis
  bmp:DrawLine(Ox - spacing_x // 2, Oy, Ox + div_x * spacing_x + spacing_x // 2, Oy, axes_color)
  local axis_Y_col = descr.right_axis_Y and (Ox + div_x * spacing_x + spacing_x // 4) or Ox
  bmp:DrawLine(axis_Y_col, Oy + spacing_y // 2, axis_Y_col, Oy - div_y * spacing_y - spacing_y // 2, axes_color)
  local metric_x, metric_y = spacing_x // div_x, spacing_y // div_y
  for k = 0, div_x do
    local axis_x = Ox + k * spacing_x
    bmp:DrawLine(axis_x, Oy - metric_y, axis_x, Oy + metric_y, axes_color)
    if descr.x_dividers then
      bmp:DrawLine(axis_x, Oy, axis_x, Oy - div_y * spacing_y, axes_color)
      local section_name = descr.x_dividers
      if type(descr.x_dividers) == "function" then
        section_name = descr.x_dividers(k)
      end
      if section_name then
        local tw, th = bmp:MeasureText(section_name)
        bmp:DrawText(axis_x - (tw + spacing_x) // 2, Oy - 5 * metric_y, section_name, axes_color)
      end
    end
    local text
    if descr.text_x then
      text = descr.text_x(k, size_x, div_x)
    else
      text = int_x and string.format(axis_x_format, k * size_x // div_x + center_x) or string.format(axis_x_format, k * size_x / div_x + center_x)
    end
    local tw, th = bmp:MeasureText(text)
    local text_x = Ox + k * spacing_x - tw // 2 - (descr.text_x_inside_interval and spacing_x // 2 or 0)
    if k == 0 then
      text_x = text_x + tw
    end
    bmp:DrawText(text_x, Oy + 2 * metric_y, text, axes_color)
  end
  
  -- draw coordinate system - Y axis
  for k = 1, div_y do
    bmp:DrawLine(axis_Y_col - metric_x, Oy - k * spacing_y, axis_Y_col + metric_x, Oy - k * spacing_y, axes_color)
    local text = int_y and string.format(axis_y_format, k * size_y // div_y + center_y) or string.format(axis_y_format, k * size_y / div_y + center_y)
    local tw, th = bmp:MeasureText(text)
    local text_y = Oy - k * spacing_y - th // 2 + (descr.text_y_inside_interval and spacing_y // 2 or 0)
    bmp:DrawText(descr.right_axis_Y and (width - tw - 5) or start_x, text_y, text, axes_color)
  end
  local level_y_text = int_y and string.format(axis_y_format, center_y) or string.format(axis_y_format, center_y)
  local tw, th = bmp:MeasureText(level_y_text)
  bmp:DrawText(descr.right_axis_Y and (width - tw - 5) or start_x, Oy - th - 2, level_y_text, axes_color)
  
  -- draw graphs
  local scale_x, scale_y = div_x * spacing_x / size_x, div_y * spacing_y / size_y
  local box_size = descr.KP_size or 2
  local name_x = spacing_x + 10
  local scale = descr.y_scaling
  
  if descr.y_line then
      local x1 = math.floor(Ox)
      local x2 = math.floor(Ox + scale_x * size_x)
      -- TODO: calculate Y scaling only once
      local y = math.floor(Oy - scale_y * ((scale and scale(descr.y_line) or descr.y_line) - center_y))
      bmp:DrawLine(x1, y, x2, y, axes_color)
      local text = int_y and string.format(axis_y_format, math.floor(descr.y_line)) or string.format(axis_y_format, descr.y_line)
      local tw, th = bmp:MeasureText(text)
      bmp:DrawText(descr.right_axis_Y and (width - tw - 5) or start_x, y, text, axes_color)
  end
  
  for _, name in ipairs(order) do
    local func_points = funcs_data.funcs[name]
    local color = func_points.color
    local no_KP = (func_points.skip_KP ~= nil and func_points.skip_KP) or (func_points.skip_KP == nil and skip_KP)
    local last_x, last_y
    local frame = 0
    local start_idx = func_points[0] and 0 or 1
    local end_idx = #func_points
    for idx = start_idx, end_idx do
      local pt = func_points[idx]
      local x = math.floor(Ox + scale_x * (pt.x - center_x))
      -- TODO: calculate Y scaling only once
      local y = math.floor(Oy - scale_y * ((scale and scale(pt.y) or pt.y) - center_y))
      if descr.bars then
        y = Min(y, Oy - bars_y_padding)
      end
      if last_x and last_y then
        bmp:DrawLine(last_x, last_y, x, y, color)
      end
      if not no_KP then
        bmp:DrawBox(x - box_size, y - box_size, x + box_size, y + box_size, color)
      end
      if pt.text then
        local w, h = bmp:MeasureText(pt.text)
        bmp:DrawText(x - w // 2, y - h - box_size - 2, pt.text, color)
      end
      if descr.bars and last_x and x > last_x then
        for bar_x = last_x, x do
          local bar_y = last_y + (y - last_y) * (bar_x - last_x) // (x - last_x)
          bmp:DrawLine(bar_x, Min(bar_y, Oy - bars_y_padding), bar_x, Oy - bars_y_padding, color)
        end
      end
      last_x, last_y = x, y
      if write_frames and (not write_name or name == write_name) and (idx % frames_step == 0 or idx == #func_points) then
        frame = frame + 1
        local filename = string.format("%s_%s%04d.bmp", write_frames, not write_name and (name and "_") or "", frame)
        print(string.format("Writing '%s' ...", filename))
        bmp:WriteBMP(filename)
      end
    end
    if not string.match(name, "<skip>") then
      local w, h = bmp:MeasureText(name)
      if descr.right_axis_Y then
        bmp:DrawText(width - name_x - w - 5, start_y + height - h, name, color)
      else
        bmp:DrawText(start_x + name_x, start_y + height - h, name, color)
      end
      name_x = name_x + w + 30
    end
  end
  
  if funcs_data.name_y then
    if descr.right_axis_Y then
      local w, h = bmp:MeasureText(funcs_data.name_y)
      bmp:DrawText(width - w - start_x, start_y + 5, funcs_data.name_y, axes_color)
    else
      bmp:DrawText(start_x + 5, start_y + 5, funcs_data.name_y, axes_color)
    end
  end
  if funcs_data.name_x then
    local w, h = bmp:MeasureText(funcs_data.name_x)
    bmp:DrawText(start_x + width - w - 5, start_y + height - h * 2 - 5, funcs_data.name_x, axes_color)
  end
  
  return function(pt)
    return
    {
      x = Ox + math.floor(scale_x * (pt.x - center_x)),
      y = Oy - math.floor(scale_y * ((scale and scale(pt.y) or pt.y) - center_y))
    }
  end
end

function GetGraphsMinMaxY(...)
  local min_y, max_y
  for _, funcs in ipairs({...}) do
    for _, func_pts in pairs(funcs) do
      local start_idx = func_pts[0] and 0 or 1
      local end_idx = #func_pts
      for idx = start_idx, end_idx do
        local pt = func_pts[idx]
        min_y = (not min_y or pt.y < min_y) and pt.y or min_y
        max_y = (not max_y or pt.y > max_y) and pt.y or max_y
      end
    end
  end
  
  return min_y, max_y
end
