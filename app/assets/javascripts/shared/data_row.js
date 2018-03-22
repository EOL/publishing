function bindMetaArrow($row) {
  $row.find('.js-meta-arw').click(function() {
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
}

$(function() {
  $('.js-load-arw').click(function() {
    var $that = $(this)
      , $row = $that.parent('.js-data-row')
      ;

    $that.removeClass('fa-angle-down');
    $that.addClass('fa-spin fa-spinner');

    $.ajax({
      url: $row.data('showPath'),
      success: function(result) {
        var $result = $(result);
        bindMetaArrow($result);
        $row.replaceWith($result);
      }
    })
  });
  
});
