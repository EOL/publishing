$(function() {''
  var autocompletePath = '/search_suggestions/' // TODO: gross url
    , minAutocompleteLen = 3
    , queryCount = 0
    , $suggestionsContainer = $('.suggestions-container')
    , $searchInput = $('.search-input')
    , $backArrow = $('.navbar .arrow.left')
    ;

  $searchInput.on('input', function() {
    if ($(this).val() && $(this).val().length >= minAutocompleteLen) {
      var queryNum = ++queryCount;

      $.ajax({
        url: autocompletePath,
        data: {
          query: $(this).val()
        },
        success: function(result) {
          if (queryNum === queryCount) {
            $suggestionsContainer.html(result);
            $suggestionsContainer.find('.suggestion').click(function() {
              $searchInput.val($(this).html());
              $searchInput.focus()
            });
          }
        }
      });
    } else {
      $suggestionsContainer.empty();
    }
  });

  $searchInput.focus();
  $backArrow.click(function() {
    window.history.back();
  });
});
