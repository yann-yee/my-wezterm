function Entity:click(event, up)
  if up or event.is_middle then
    return
  end

  if self._file.cha.is_dir then
    ya.emit("enter", {})
  else
    ya.emit("open", { hovered = true })
  end
end