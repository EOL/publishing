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

  $(function() {
    scrollToDefn();
  });
})();
