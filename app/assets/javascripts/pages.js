//= require shared/data_row
//= require shared/slideshow
//= require trophic_web

function setupMenus() {
  EOL.enableDropdowns();

  $('.js-menus a').on('ajax:success', function(e, data, status, xhr) {
    $('.js-content').replaceWith(data);
    setupMenus();
    bindLoadArrows(); // No-op for media, but needed for data
  });
}

function setupBreadcrumbs() {
  var $summary = $('.js-hier-summary')
    , $full = $('.js-hier-full')
    ;

  $('.js-show-full-hier').click(function() { 
    $summary.addClass('is-hidden');
    $full.removeClass('is-hidden');
  })

  $('.js-show-summary-hier').click(function() {
    $full.addClass('is-hidden');
    $summary.removeClass('is-hidden');
  })
}

function scrollToRecord() {
  var hashParams = EOL.parseHashParams();
  
  if ('trait_id' in hashParams) {
    var $row = $('.js-data-row[data-id="' + hashParams.trait_id + '"]')
      , $nav = $('.l-nav')
      , $tabs = $('.l-tabs')
      , $filters = $('.js-menus')
      ;

    if ($row.length) {
      setTimeout(function() {
        $(document).scrollTop($row.offset().top - $nav.height() - $tabs.height() - $filters.height());
        $row.find('.js-load-arw').click();
      }, 1000);
    }
  }
}

function setupWordcloud() {
  var $container = $('.js-trait-wordcloud')
    , words = []
    ;

  if ($container.length) {
    words = $container.data('words'); 
    $container.jQCloud(words, {
      autoResize: true 
    });
  }
}

$(function() {
  setupMenus();
  setupBreadcrumbs();
  setupWordcloud();
  scrollToRecord();
});

