$(function() {
  $('.js-pred-select').change(function(e) {
    var val = $(this).val()
      , that = this
      ;

    if (val && val.length) {
      $.ajax({
        method: 'GET',
        data: {
          uri: $(this).val()
        },
        url: '/terms/predicate_traits', // TODO: no hard-coded urls
        success: function(res) {
          var $objSel = $(that).closest('.js-trait-fields').find('.js-obj-select')
            , options = []
            ;

          if (res.length) {
            options = res.map(function(obj, i) {
              return '<option value="' + obj.uri + '">' + obj.name + '</option>';
            });

            $objSel.attr('disabled', false);
          } else {
            $objSel.attr('disabled', true);
          }

          $objSel.html(options.join(''));
        }
      });
    }
  });
});
