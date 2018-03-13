(function() {
  function fetchForm(option) {
    var data = $('#new_term_query').serializeArray();

    $('.js-term-form-dimmer').addClass('active');

    if (option) {
      data.push(option)
    }

    $.ajax({
      method: 'GET',
      data: $.param(data),
      url: '/terms/search_form', // TODO: no hard-coded urls
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
      $(this).val($(this).data('lastCleanVal')); 
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
      source: EOL.searchNames
    }, 'id', null);

    buildTypeahead('.js-pred-typeahead', {
      name: 'pred-names',
      display: 'name',
      source: EOL.searchPredicates
    }, 'uri', fetchForm);

    $('.js-obj-typeahead').each(function() {
      var source = new Bloodhound({
        datumTokenizer: Bloodhound.tokenizers.obj.whitespace('name'),
        queryTokenizer: Bloodhound.tokenizers.whitespace,
        remote: {
          url: '/terms/object_terms_for_predicate.json?query=%QUERY&pred_uri=' + $(this).data('predUri'),
          wildcard: '%QUERY'
        },
        limit: 10
      });
      source.initialize();

      buildTypeahead(this, {
        display: 'name',
        source: source
      }, 'uri', null)
    });

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
  }

  EOL.onReady(setupForm);
  
  $(function() {
    $('.js-edit-filters').click(function() {
      $('.js-filter-form').removeClass('is-hidden');
      $('.js-filter-list').addClass('is-hidden');
    });
  });
})();
