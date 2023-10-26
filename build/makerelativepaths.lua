function Image (img)

  --remove invalid urls
  if string.find(img.src, "shields.io") then
    img.src = ""
    return img
  end

  --makes paths relative so that links resolve on pandoc compile
  img.src = pandoc.path.make_relative(img.src, '/')

  return img
end

