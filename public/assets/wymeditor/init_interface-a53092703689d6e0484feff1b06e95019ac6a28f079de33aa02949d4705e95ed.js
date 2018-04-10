this.visual_editor_init_interface_hook = (function(_this) {
  return function() {
    return $("textarea.wymeditor, textarea.visual_editor").each(function() {
      var instance, next, prev, textarea;
      textarea = $(this);
      if ((instance = WYMeditor.INSTANCES[$((textarea.next(".visual_editor_box").find("iframe").attr("id") || "").split("_")).last().get(0)]) != null) {
        if (((next = textarea.parent().next()) != null) && next.length > 0) {
          next.find("input, textarea").keydown($.proxy(function(e) {
            var shiftHeld;
            shiftHeld = e.shiftKey;
            if (shiftHeld && e.keyCode === $.ui.keyCode.TAB) {
              this._iframe.contentWindow.focus();
              return e.preventDefault();
            }
          }, instance)).keyup(function(e) {
            var shiftHeld;
            return shiftHeld = false;
          });
        }
        if (((prev = textarea.parent().prev()) != null) && prev.length > 0) {
          return prev.find("input, textarea").keydown($.proxy(function(e) {
            if (e.keyCode === $.ui.keyCode.TAB) {
              this._iframe.contentWindow.focus();
              return e.preventDefault();
            }
          }, instance));
        }
      }
    });
  };
})(this);

this.visual_editor_update = (function(_this) {
  return function() {
    $.each(WYMeditor.INSTANCES, function(index, wym) {
      wym.update();
    });
  }
})(this);

this.visual_editor_init = (function(_this) {
  return function() {
    return WYMeditor.init();
  };
})(this);
