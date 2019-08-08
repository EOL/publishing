//= require shared/data_row

(function() {
  function showNotification() {
    UIkit.notification('This may take a minute', {
      status: 'primary',
      pos: 'top-center',
      offset: '100px'
    })
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

  function buildTypeahead(selector, options, datumField, selectFn) {
    $(selector).typeahead({}, options).bind('typeahead:selected', function(evt, datum, name) {
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
        name: 'show_meta',
        value: $(this).data('index')
      });
    })

    $('.js-hide-meta-filters').click(function() {
      fetchForm({
        name: 'hide_meta',
        value: $(this).data('index')
      });
    });

    $('.js-meta-obj-typeahead').each(function() {
      buildTypeahead(this, {
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

    buildTypeahead('.js-clade-typeahead', {
      name: 'clade-filter-names',
      display: 'name',
      limit: Infinity,
      source: EOL.searchNamesNoMultipleText
    }, 'id', null);

    buildTypeahead('.js-pred-typeahead', {
      name: 'pred-names',
      display: 'name',
      limit: Infinity,
      source: EOL.searchPredicates
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

      buildTypeahead(this, {
        display: 'name',
        source: source,
        limit: Infinity
      }, 'uri', null)
    });


    buildTypeahead('.js-obj-typeahead', {
      name: 'obj-names',
      display: 'name',
      limit: Infinity,
      source: EOL.searchObjectTerms
    }, 'uri', fetchForm);

    buildTypeahead('.js-resource-typeahead', {
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
  }

  EOL.onReady(setupForm);

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
  });
})();
