function bindMetaArrow($row) {
  $row.find('.js-meta-arw').click(function() {
    var $metaList = $(this).siblings('.js-meta-items')
      , $pred = $(this).closest('.js-data-row').find('.js-predicate')
      , hidePredWhenClosed = $(this).data('hidePredWhenClosed')
      ;

    if ($(this).hasClass('fa-angle-down')) {
      $(this).removeClass('fa-angle-down');
      $(this).addClass('fa-angle-up');
      $metaList.removeClass('is-hidden');

      if (hidePredWhenClosed) {
        $pred.removeClass('is-hidden');
      }
    } else {
      $(this).removeClass('fa-angle-up');
      $(this).addClass('fa-angle-down');
      $metaList.addClass('is-hidden');

      if (hidePredWhenClosed) {
        $pred.addClass('is-hidden');
      }
    }
  });
}

function bindLoadArrows() {
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
}

$(function() {
  bindLoadArrows();
});
