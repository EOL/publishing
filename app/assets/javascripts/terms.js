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

  function setupTermSelect() {
    $('.js-term-select').change(function(e) {
      $.ajax(Routes.child_terms_path({ uri: e.target.value }), function(res) {
        console.log(res); 
      });
    });
  }

  $(function() {
    scrollToDefn();
    setupTermSelect();
  });
})();
