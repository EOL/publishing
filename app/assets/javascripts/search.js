$(function() {
  // constants
  var resultTypeOrder = [ 'pages', 'articles', 'images', 'videos', 'sounds', 'collections', 'users' ]
    , firstPageIndex = 1
    , nextPageScrollThreshold = 300
    , minAutocompleteLen = 3
    ;

  // jquery
  var $suggestionsContainer = $('#search-sug-cont')
    , $searchInput = $('.search-input')
    , $filterBar = $('.js-search-filter-bar')
    , $filter = $('.js-search-filter-types')
    , $filterItem = $filter.find('.js-search-filter-type')
    , $resultContainer = $('.js-search-results')
    , $results = $resultContainer.find('.js-search-result')
    , $addToColIcon = $resultContainer.find('.search-result-icon-plus')
    ;

  // state
  var autocompletePath = $suggestionsContainer.data('path')
    , queryCount = 0
    , resultTypeIndex
    , selectedResultTypes = buildSelectedResultTypes()
    , pageIndex = firstPageIndex
    , query = $resultContainer.data('query')
    , pagePath = $resultContainer.data('pagePath')
    , loadingPage = false
    ;

  function buildSelectedResultTypes() {
    var selectedResultTypes = {};

    $.each(resultTypeOrder, (i, type) => {
      selectedResultTypes[type] = true;
    });

    return selectedResultTypes;
  }

  function openFilter() {
    EOL.showOverlay('search-filter')
  }

  function updateSelectedResultTypes() {
    var changed = false;

    $filterItem.each(function(i, filter) {
      var selected = $(filter).hasClass('is-search-filter-type-active')
        , type = $(filter).data('type')
        , curSelected = selectedResultTypes[type]
        ;

      if (curSelected !== selected) {
        changed = true;
      }

      selectedResultTypes[type] = selected;
    });

    if (changed) {
      reloadResults();
    }

    EOL.hideOverlay();
  }

  function reloadResults() {
    pageIndex = firstPageIndex - 1;
    resultTypeIndex = 0;
    loadingPage = true;
    $resultContainer.empty();
    loadNextPage();
  }

  function toggleSelected() {
    $(this).toggleClass('is-search-filter-type-active');
  }

  /*
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
            $suggestionsContainer.find('.search-sug').click(function() { // TODO: require at least one type to be selected
              $searchInput.val($(this).html());
              $searchInput.focus();
            });
          }
        }
      });
    } else {
      $suggestionsContainer.empty();
    }
  });
  */

  function loadNextPage() {
    var selectedResultTypeFound = selectedResultTypes[resultTypeOrder[resultTypeIndex]];

    while(resultTypeIndex < resultTypeOrder.length - 1 && !selectedResultTypeFound) {
      resultTypeIndex++;
      selectedResultTypeFound = selectedResultTypes[resultTypeOrder[resultTypeIndex]];
    }

    if (selectedResultTypeFound) {
      $.ajax({
        url: pagePath,
        data: {
          q: query,
          only: resultTypeOrder[resultTypeIndex],
          page: ++pageIndex
        },
        success: function(result) {
          if (!result.replace(/\s/g, '').length) {
            pageIndex = firstPageIndex - 1;
            resultTypeIndex++;
            loadNextPage();
          } else {
            $resultContainer.append($(result));
            loadingPage = false;
            $(window).scroll();
          }
        }
      });
    }
  }

  function restoreFilters() {
    $.each(Object.entries(selectedResultTypes), function(i, entry) {
      var $elmt = $filter.find('.search-filter-type[data-type="' + entry[0] + '"]');
      
      if (entry[1]) {
        $elmt.addClass('is-search-filter-type-active');
      } else {
        $elmt.removeClass('is-search-filter-type-active');
      }
    });
  }

  $searchInput.focus();
  $filterBar.click(openFilter);
  $filterItem.click(toggleSelected);

  $('#search-filter .js-overlay-x').click(restoreFilters);
  $('#search-filter .js-apply-filter-btn').click(updateSelectedResultTypes);

  if ($results.length) {
    resultTypeIndex = resultTypeOrder.indexOf($results.last().data('type'));

    $(window).scroll(function() {
      var scrollBottomOffset = $(document).height() - $(this).scrollTop() - $(this).height();

      if (scrollBottomOffset < nextPageScrollThreshold && !loadingPage) {
        loadingPage = true;
        loadNextPage();
      }
    });
    $(window).scroll(); // If there's no scrollbar, the next page will never load without this
  }
});
