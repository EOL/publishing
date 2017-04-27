(function() {
  this.init_interface = function() {
    if (parent && parent.document.location.href !== document.location.href) {
      $("body#dialog_container.dialog").addClass("iframed");
    }
    $("input:submit:not(.button)").addClass("button");
    if (typeof visual_editor_init_interface_hook !== 'undefined') {
      visual_editor_init_interface_hook();
    }
    $("#current_locale li a").click(function(e) {
      $("#current_locale li a span.action").each(function(span) {
        return $(this).css("display", ($(this).css("display") === "none" ? "" : "none"));
      });
      $("#other_locales").animate({
        opacity: "toggle",
        height: "toggle"
      }, 250);
      $("html,body").animate({
        scrollTop: $("#other_locales").parent().offset().top
      }, 250);
      return e.preventDefault();
    });
    $("#existing_image img").load(function() {
      var margin_top;
      margin_top = $("#existing_image").height() - $("form.edit_image").height() + 8;
      if (margin_top > 0) {
        return $("form.edit_image .form-actions").css({
          "margin-top": margin_top
        });
      }
    });
    $(".form-actions .form-actions-left input:submit#submit_button").click(function(e) {
      return $(this).nextAll('#spinner').removeClass('hidden_icon').addClass('unhidden_icon');
    });
    $(".form-actions.form-actions-dialog .form-actions-left a.close_dialog").click(function(e) {
      var titlebar_close_button;
      titlebar_close_button = $('.ui-dialog-titlebar-close');
      if (parent) {
        titlebar_close_button = parent.$('.ui-dialog-titlebar-close');
      }
      titlebar_close_button.trigger('click');
      return e.preventDefault();
    });
    return $("a.suppress").on("click", function(e) {
      return e.preventDefault();
    });
  };

}).call(this);
