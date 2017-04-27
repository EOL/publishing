(function() {
  $(function() {
    return $("textarea.wysiwyg").each(function() {
      return CKEDITOR.replace(this, {
        width: $(this).width(),
        height: $(this).height(),
        bodyClass: $(this).data("body-class"),
        contentsCss: "/assets/ckeditor.css",
        customConfig: "/assets/ckeditor.js"
      });
    });
  });

  $(window).load(function() {
    return $(".box_of_holding").each(function() {
      var $img, $this, box_height, box_width, image_height, image_width;
      $img = $(this).find("img");
      image_width = $img.width();
      image_height = $img.height();
      $this = $(this);
      box_width = $this.width();
      box_height = $this.height();
      this.scrollLeft = (image_width - box_width) / 2;
      return this.scrollTop = (image_height - box_height) / 2;
    });
  });

  $(function() {
    return $(".rightbar").tabs();
  });

  window.submit_and_continue = function(e, redirect_to) {
    var instance, key, ref;
    ref = CKEDITOR.instances;
    for (key in ref) {
      instance = ref[key];
      CKEDITOR.instances[key].updateElement();
    }
    $('#continue_editing').val(true);
    $('#flash').fadeOut(250);
    $('.fieldWithErrors').removeClass('fieldWithErrors').addClass('field');
    $('#flash_container .errorExplanation').remove();
    $.post($('#continue_editing').get(0).form.action, $($('#continue_editing').get(0).form).serialize(), function(data) {
      var $flash_container, error_fields;
      if (($flash_container = $('#flash_container')).length > 0) {
        $flash_container.html(data);
        $('#flash').css({
          'width': 'auto',
          'visibility': null
        }).fadeIn(550);
        $('.errorExplanation').not($('#flash_container .errorExplanation')).remove();
        error_fields = $('#fieldsWithErrors').val();
        if (error_fields != null) {
          $.each(error_fields.split(','), function() {
            return $("#" + this).wrap("<div class='fieldWithErrors' />");
          });
        } else if (redirect_to != null) {
          window.location = redirect_to;
        }
        $('.fieldWithErrors:first :input:first').focus();
        $('#continue_editing').val(false);
        return init_flash_messages();
      }
    });
    return e.preventDefault();
  };

}).call(this);
