//= require shared/data_row

function setupMenus() {
  EOL.enableDropdowns();

  $('.js-media-menus a').on('ajax:success', function(e, data, status, xhr) {
    $('#gallery').replaceWith(data);
    setupMenus();
  });
}

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

function scrollToRecord() {
  var hashParams = EOL.parseHashParams();
  
  if ('trait_id' in hashParams) {
    var $row = $('.js-data-row[data-id="' + hashParams.trait_id + '"]')
      , $nav = $('.l-nav')
      , $tabs = $('.l-tabs')
      ;

    if ($row.length) {
      setTimeout(function() {
        $(document).scrollTop($row.offset().top - $nav.height() - $tabs.height());
        $row.find('.js-load-arw').click();
      }, 1000);
    }
  }
}

$(function() {
  setupMenus();
  scrollToRecord();
});
