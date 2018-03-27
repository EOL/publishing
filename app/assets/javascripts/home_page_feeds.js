(function() {
  function addItem(e) {
    e.preventDefault();

    var $contain = $('.js-form-contain')
      , $dimmer = $('.js-form-dimmer')
      , data = $('.js-form').serializeArray();
      ;

    data.push({
      name: 'add_item',
      value: true
    });

    $dimmer.addClass('active');

    $.ajax({
      method: 'GET',
      data: $.param(data),
      url: $contain.data('formUrl'),
      success: function(res) {
        $contain.html(res);
        $dimmer.removeClass('active');
      }
    });

    return false;
  }

  $(function() {
    $('.js-add-item').click(addItem);
  });
})();
