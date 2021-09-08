function setupTable() {
  $('.js-sort-by').on('ajax:success', function(e, data, status, xhr) {
    $(this).closest('.js-table').replaceWith(data); 
    setupTable();
  });
}

$(function() {
  setupTable();
});

