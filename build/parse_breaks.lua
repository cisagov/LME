--- Transform a raw HTML element which contains only a `<br>`
-- into a format-indepentent line break.
function RawInline (el)
  if el.format:match '^html' and el.text:match '%<?/?br ?/?%>' then
    return pandoc.LineBreak()
  end
end
