(function() {
  function scrollToDefn() {
    var $scrollToDefn = $('dt[data-scroll-to]');

    if ($scrollToDefn.length) {
      setTimeout(function() {
        $('html, body').animate({
          scrollTop: $scrollToDefn.offset().top - $('.js-navbar').outerHeight()
        });
      }, 1000);
    }
  }

  function setupTermSelects() {
    setupTermSelect($('.js-term-select'));
  }

  function setupTermSelect($select) {
    $select.change(function(e) {
      var $that = $(this);
      console.log($that.val());
      removeTermSelectsAfter($that);

      if ($that.val()) {
        $.ajax(Routes.child_terms_path({ uri: $that.val() }))
          .done(function(childSelect) {
            var $childSelect = $(childSelect);

            if ($childSelect.find('option').length > 1) {
              setupTermSelect($childSelect)
              $that.parent('.js-term-select-contain').append($childSelect);
            }
          });
      }
    });
  }

  function removeTermSelectsAfter($select) {
    $select.nextAll('.js-term-select').remove();
  }

  $(function() {
    scrollToDefn();
    setupTermSelects();
  });
})();
