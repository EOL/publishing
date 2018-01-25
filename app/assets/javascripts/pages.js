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
});
