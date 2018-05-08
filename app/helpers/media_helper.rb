module MediaHelper
  def image_owner(image)
    image.owner.html_safe.sub(/^\(c\)\s+/i, "").sub(/^&copy;\s+/i, "").html_safe
  end
end
