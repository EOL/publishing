$(function() {
  var autocompletePath = '/search_suggestions/' // TODO: gross url
    , minAutocompleteLen = 3
    , queryCount = 0
    , $suggestionsContainer = $('#search-sug-cont')
    , $searchInput = $('.search-input')
    , $backArrow = $('.navbar-icon.fa-arrow-left')
    , $filterBar = $('#filter-bar')
    , $filter = $('#search-filter')
    , $filterItem = $filter.find('.search-filter-type')
    , $resultContainer = $('#search-results')
    , $results = $resultContainer.find('.search-result')
    , resultTypeOrder = [ 'pages', 'articles', 'images', 'videos', 'sounds', 'collections', 'users' ]
    , resultTypeIndex
    , selectedResultTypes = buildSelectedResultTypes()
    , firstPageIndex = 1
    , pageIndex = firstPageIndex
    , nextPageScrollThreshold = 300
    , query = $resultContainer.data('query')
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
    $filter.show();
    $filterBar.off('click', openFilter);
    $filterBar.click(closeFilter);
    $filterBar.addClass('is-active');
    $('body').addClass('is-noscroll');
  }

  function closeFilter() {
    $filter.hide();
    $filterBar.off('click', closeFilter);
    $filterBar.click(openFilter);
    $filterBar.removeClass('is-active');
    $('body').removeClass('noscroll');

    updateSelectedResultTypes();
  }

  function updateSelectedResultTypes() {
    var changed = false;

    $filterItem.each(function(i, filter) {
      var selected = $(filter).hasClass('is-active')
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
  }

  function reloadResults() {
    pageIndex = firstPageIndex - 1;
    resultTypeIndex = 0;
    loadingPage = true;
    $resultContainer.empty();
    loadNextPage();
  }

  function toggleSelected() {
    $(this).toggleClass('is-active');
  }

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

  function loadNextPage() {
    var selectedResultTypeFound = selectedResultTypes[resultTypeOrder[resultTypeIndex]];

    while(resultTypeIndex < resultTypeOrder.length - 1 && !selectedResultTypeFound) {
      resultTypeIndex++;
      selectedResultTypeFound = selectedResultTypes[resultTypeOrder[resultTypeIndex]];
    }

    if (selectedResultTypeFound) {
      $.ajax({
        url: '/search_page', // TODO: get rid of hard-coded path
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

  $searchInput.focus();
  $backArrow.click(function() {
    window.history.back();
  });
  $filterBar.click(openFilter);
  $filterItem.click(toggleSelected);

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
