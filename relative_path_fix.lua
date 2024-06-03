function normalize (path)
  if path:sub(1, 2) == './' then
    return path:sub(3)
  else if path:sub(1, 3) == '../' then 
    return normalize(path:sub(4))
  else if path:sub(1, 3) == 'img' then
     return path
  else return 'posts/' .. path 
  end end end
end

function fix_path (path)
  if path:sub(1, 1) == '.' then
    return 'https://rdivyanshu.github.io/' ..  normalize(path)
  else return path end
end

function Link (element)
  element.target = fix_path(element.target)
  return element
end

function Image (element)
  element.src = fix_path(element.src)
  return element
end

