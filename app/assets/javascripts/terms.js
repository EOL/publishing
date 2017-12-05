EOL.onReady(function() {
  function setupForm() {
    $('.js-pred-select').change(function(e) {
      var val = $(this).val()
        , that = this
        ;

      if (val && val.length) {
        $.ajax({
          method: 'GET',
          data: $('#new_trait_bank_query').serialize(),
          url: '/terms/search_form', // TODO: no hard-coded urls
          success: function(res) {
            $('#new_trait_bank_query').html(res)
            setupForm();
          }
        });
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
      display: 'scientific_name',
      source: EOL.searchNames
    }).bind('typeahead:selected', function(evt, datum, name) {
      $('.js-clade-typeahead').closest('.js-typeahead-wrap').find('.js-clade-field').val(datum.id);
    });

    $('.js-clade-typeahead').on('input', function() {
      console.log('input!');
      if ($(this).val().length === 0) {
        $(this).closest('.js-typeahead-wrap').find('.js-clade-field').val('');
      }
    });
  }

  setupForm();
});
