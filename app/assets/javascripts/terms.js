$(function() {
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
        }
      });
    }
  });
});
