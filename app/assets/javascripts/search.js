$(function() {''
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
    , resultTypeOrder = [ 'pages', 'media', 'collections', 'users' ]
    , resultTypeIndex = 0
    , selectedResultTypes = {
        pages: true,
        media: true,
        collections: true,
        users: true
      }
    , firstPageIndex = 1
    , pageIndex = firstPageIndex
    , nextPageScrollThreshold = 300
    , query = $resultContainer.data('query')
    , loadingPage = false
    ;

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

    console.dir(selectedResultTypes);

    if (changed) {
      reloadResults();
    }
  }

  function reloadResults() {
    console.log('reload!')
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

  function loadNextPage() {
    $.ajax({
      url: '/search_page', // TODO: get rid of hard-coded path
      data: {
        q: query,
        only: resultTypeOrder[resultTypeIndex],
        page: ++pageIndex
      },
      success: function(result) {
        if (!result.replace(/\s/g, '').length) {
          if (resultTypeIndex < resultTypeOrder.length - 1) {
            resultTypeIndex++;
            pageIndex = firstPageIndex - 1;
            loadNextPage();
          }
        } else {
          $resultContainer.append($(result));
          loadingPage = false;
        }
      }
    });
  }

  $searchInput.focus();
  $backArrow.click(function() {
    window.history.back();
  });
  $filterBar.click(openFilter);
  $filterItem.click(toggleSelected);

  $(window).scroll(function() {
    var scrollBottomOffset = $(document).height() - $(this).scrollTop() - $(this).height();

    if (scrollBottomOffset < nextPageScrollThreshold && !loadingPage) {
      loadingPage = true;
      loadNextPage();
    }
  });
});
