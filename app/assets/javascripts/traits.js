//= require shared/data_row
//= require traits/data_viz 

(function() {

  function showNotification() {
    UIkit.notification($(this).data('submitNotification'), {
      status: 'primary',
      pos: 'top-center',
      offset: '100px'
    });
  }

  function fetchForm(option) {
    var data = $('#new_term_query').serializeArray();

    $('.js-term-form-dimmer').addClass('active');

    if (option) {
      data.push(option)
    }

    $.ajax({
      method: 'GET',
      data: $.param(data),
      url: Routes.term_search_form_path(),
      success: function(res) {
        $('#term_form_container').html(res)
        setupForm();
        $('.js-term-form-dimmer').removeClass('active');
      }
    });
  }

  function buildTypeahead(selector, typeaheadOptions, dataOptions, datumField, selectFn) {
    $(selector).typeahead(typeaheadOptions, dataOptions).bind('typeahead:selected', function(evt, datum, name) {
      var $target = $(evt.target);

      $target.data('lastCleanVal', $target.val());
      $(evt.target).closest('.js-typeahead-wrap').find('.js-typeahead-field').val(datum[datumField]);

      if (selectFn) {
        selectFn();
      }
    });

    $(selector).on('input', function() {
      var $this = $(this);

      if ($this.val().length === 0) {
        $this.data('lastCleanVal', '');
        $this.closest('.js-typeahead-wrap').find('.js-typeahead-field').val('');

        if (selectFn) {
          selectFn();
        }
      }
    });

    $(selector).on('blur', function() {
      var lastCleanVal = $(this).data('lastCleanVal');

      if (typeof lastCleanVal !== 'undefined') {
        $(this).val($(this).data('lastCleanVal'));
      }
    });
  }

  function setupMetaFilters() {
    $('.js-show-meta-filters').click(function() {
      fetchForm({
        name: 'show_extra_fields',
        value: $(this).data('index')
      });
    })

    $('.js-hide-meta-filters').click(function() {
      fetchForm({
        name: 'hide_extra_fields',
        value: $(this).data('index')
      });
    });

    $('.js-meta-obj-typeahead').each(function() {
      buildTypeahead(this, {}, {
        name: 'meta-obj-names',
        display: 'name',
        limit: Infinity,
        source: new Bloodhound({
          datumTokenizer: Bloodhound.tokenizers.obj.whitespace('name'),
          queryTokenizer: Bloodhound.tokenizers.whitespace,
          remote: {
            url: Routes.terms_meta_object_terms_path({ 
              query: 'QUERY',
              pred: $(this).data('pred'),
              format: 'json'
            }),
            wildcard: 'QUERY'
          }
        })
      }, 'uri', null)
    });

  }

  function setupForm() {
    $('.js-op-select').change(function() {
      fetchForm();
    });

    $('.js-term-select').each(function() {
      if ($(this).find('option').length <= 1) {
        $(this).attr('disabled', true);
      } else {
        $(this).attr('disabled', false);
      }
    });

    buildTypeahead('.js-clade-typeahead', {}, {
      name: 'clade-filter-names',
      display: 'name',
      limit: Infinity,
      source: EOL.searchNamesNoMultipleText
    }, 'id', null);

    var predSource = new Bloodhound({
      datumTokenizer: Bloodhound.tokenizers.obj.whitespace('name'),
      queryTokenizer: Bloodhound.tokenizers.whitespace,
      remote: {
        url: Routes.trait_search_predicate_typeahead_path({ 
          query: 'QUERY',
          format: 'json'
        }),
        wildcard: 'QUERY'
      }
    });

    buildTypeahead('.js-pred-typeahead', { minLength: 0 }, {
      name: 'pred-names',
      display: 'name',
      minLength: 0,
      limit: Infinity,
      source: predSource
    }, 'uri', fetchForm);

    $('.js-pred-obj-typeahead').each(function() {
      var source = new Bloodhound({
        datumTokenizer: Bloodhound.tokenizers.obj.whitespace('name'),
        queryTokenizer: Bloodhound.tokenizers.whitespace,
        remote: {
          url: Routes.terms_object_terms_for_predicate_path({ 
            query: 'QUERY',
            pred_uri: $(this).data('predUri'),
            format: 'json'
          }),
          wildcard: 'QUERY'
        }
      });
      source.initialize();

      buildTypeahead(this, {}, {
        display: 'name',
        source: source,
        limit: Infinity
      }, 'uri', null)
    });


    buildTypeahead('.js-obj-typeahead', {}, {
      name: 'obj-names',
      display: 'name',
      limit: Infinity,
      source: EOL.searchObjectTerms
    }, 'uri', fetchForm);

    buildTypeahead('.js-resource-typeahead', {}, {
      name: 'resource',
      display: 'name',
      limit: Infinity,
      source: EOL.searchResources
    }, 'id', null);

    $('.js-add-filter').click(function(e) {
      e.preventDefault();
      fetchForm({
        name: 'add_filter',
        value: true
      });
    });

    $('.js-remove-filter').click(function(e) {
      fetchForm({
        name: 'remove_filter',
        value: $(this).data('index')
      });
    });

    $('#new_term_query').submit(showNotification);
    
    setupMetaFilters();
    setupTermSelects();
  }

  EOL.onReady(setupForm);

  function setupTermSelects() {
    setupTermSelect($('.js-term-select'));
  }

  function setupTermSelect($select) {
    $select.change(function(e) {
      var $that = $(this);

      if ($that.val()) {
        setValFromTermSelect($that);
      } else {
        var $prev = $that.prev('.js-term-select');

        if ($prev.val()) {
          setValFromTermSelect($prev);
        }
      } 

      fetchForm();
    });
  }

  function setValFromTermSelect($select) {
    var $parent = $select.closest('.js-filter-row-group');
    $parent.find('.js-term-name').val($select.find('option:selected').text());
    $parent.find('.js-term-uri').val($select.val());
  }

  function loadPieChart() {
    var minWidth = 750
      , $contain = $('.js-pie-contain')
      , loaded = false
      ;
      
    if ($contain.length) {
      pieChartHelper();
      $(window).resize(pieChartHelper);
    }

    // CSS media queries don't work here because the pie chart d3 code needs it to be visible when loaded
    function pieChartHelper() {
      var width = $(window).width();

      if (!loaded && width >= minWidth) {
        loaded = true;
        loadViz($contain, TraitDataViz.buildPieChart);
      } else if (loaded) {
        if (width < minWidth) {
          $contain.hide();
        } else {
          $contain.show() 
        }
      }
    }
  }

  function loadBarChart() {
    var $contain = $('.js-bar-contain');

    if ($contain.length) {
      loadViz($contain, TraitDataViz.buildBarChart);
    }
  }

  function loadViz($contain, ready) {
    $.get($contain.data('loadPath'), function(result) {
      if (result) {
        $contain.append(result);
        ready();
      }
    });
  }

  $(function() {
    $('.js-edit-filters').click(function() {
      $('.js-filter-form-contain').removeClass('is-hidden');
      $('.js-filter-list').addClass('is-hidden');
    });
    $('.js-download-tsv').click(function() {
      var $form = $('.js-filter-form');
      // XXX: this is scary but shouldn't matter in practice since the submit is synchronous and the form will be gone after that
      $form.attr('action', $(this).data('url'));
      $form.submit();
    });
    $('.show-raw-query').click(function() {
      $('.js-raw-query').removeClass('is-hidden');
      $(this).remove();
    });
    loadPieChart();
    loadBarChart();
  });
})();
