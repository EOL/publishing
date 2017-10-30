$(function() {
  var autocompletePath = '/search_suggestions/' // TODO: gross url
    , minAutocompleteLen = 3
    , queryCount = 0
    , $suggestionsContainer = $('.suggestions-container')
    , $searchInput = $('.search-input')
    , $backArrow = $('.navbar-icon.fa-arrow-left')
    , $filterBar = $('.filterBar')
    , $filter = $('.searchFilter')
    , $filterItem = $('.searchFilter-types-type')
    , $resultContainer = $('.search-results')
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
    var selectedResultTypes = {}

    $.each(resultTypeOrder, (i, type) => {
      selectedResultTypes[type] = true;
    });

    return selectedResultTypes;
  }

  function openFilter() {
    $filter.show();
    $filterBar.off('click', openFilter);
    $filterBar.click(closeFilter);
    $filterBar.addClass('open');
    $('body').addClass('noscroll');
  }

  function closeFilter() {
    $filter.hide();
    $filterBar.off('click', closeFilter);
    $filterBar.click(openFilter);
    $filterBar.removeClass('open');
    $('body').removeClass('noscroll');

    updateSelectedResultTypes();
  }

  function updateSelectedResultTypes() {
    var changed = false;

    $filterItem.each(function(i, filter) {
      var selected = $(filter).hasClass('selected')
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
    $(this).toggleClass('selected');
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
            $suggestionsContainer.find('.suggestion').click(function() { // TODO: require at least one type to be selected
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

    console.log('selectedResultTypeFound', selectedResultTypeFound);

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

  if ($resultContainer.find('.search-result').length) {
    resultTypeIndex = resultTypeOrder.indexOf($resultContainer.find('.search-result').last().data('type'));

    $(window).scroll(function() {
      var scrollBottomOffset = $(document).height() - $(this).scrollTop() - $(this).height();
      console.log('offset', scrollBottomOffset)

      if (scrollBottomOffset < nextPageScrollThreshold && !loadingPage) {
        loadingPage = true;
        loadNextPage();
      }
    });
    $(window).scroll(); // If there's no scrollbar, the next page will never load without this
  }
});
