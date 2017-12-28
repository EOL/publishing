EOL.onReady(function() {
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
        $('#new_term_query').html(res)
        setupForm();
        $('.js-term-form-dimmer').removeClass('active');
      }
    });
  }

  function setupForm() {
    $('.js-pred-select').change(function(e) {
      var val = $(this).val()
        , that = this
        ;

      if (val && val.length) {
        fetchForm(false);
      }
    });

    $('.js-term-select').each(function() {
      if ($(this).find('option').length <= 1) {
        $(this).attr('disabled', true);
      } else {
        $(this).attr('disabled', false);
      }
    });

    $('.js-clade-typeahead').typeahead(null, {
      name: 'clade-filter-names',
      display: 'name',
      source: EOL.searchNames
    }).bind('typeahead:selected', function(evt, datum, name) {
      $('.js-clade-typeahead').closest('.js-typeahead-wrap').find('.js-clade-field').val(datum.id);
    });

    $('.js-clade-typeahead').on('input', function() {
      if ($(this).val().length === 0) {
        $(this).closest('.js-typeahead-wrap').find('.js-clade-field').val('');
      }
    });

    $('.js-add-pair').click(function(e) {
      e.preventDefault();
      fetchForm({
        name: 'add_pair',
        value: true
      });
    });

    $('.js-remove-pair').click(function(e) {
      fetchForm({
        name: 'remove_pair',
        value: $(this).data('index')
      });
    });
  }

  setupForm();
});
