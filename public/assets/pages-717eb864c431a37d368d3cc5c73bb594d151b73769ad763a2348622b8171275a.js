function setupMenus() {
  EOL.enableDropdowns();

  $('.js-media-menus a').on('ajax:success', function(e, data, status, xhr) {
    $('#gallery').replaceWith(data);
    setupMenus();
  });
}

$(function() {
  $('.js-meta-arw').click(function() {
    var $metaList = $(this).siblings('.js-meta-items');

    if ($(this).hasClass('fa-angle-down')) {
      $(this).removeClass('fa-angle-down');
      $(this).addClass('fa-angle-up');
      $metaList.removeClass('is-hidden');
    } else {
      $(this).removeClass('fa-angle-up');
      $(this).addClass('fa-angle-down');
      $metaList.addClass('is-hidden');
    }
  });
  
  setupMenus();
});
