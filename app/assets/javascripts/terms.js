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

    $('.js-clade-typeahead').typeahead(null, {
      name: 'clade-filter-names',
      display: 'scientific_name',
      source: EOL.searchNames
    }).bind('typeahead:selected', function(evt, datum, name) {
      $('.js-clade-typeahead').closest('.js-typeahead-wrap').find('.js-clade-field').val(datum.id);
    });
  }

  setupForm();
});
