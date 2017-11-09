(function() {
  function loadColContents(pageId) {
    var $contain = $('#col-overlay .col-overlay-contain');
    
    $contain.empty();

    if (!pageId) {
      throw new TypeError('pageId must be present');
    }

    $.ajax({
      url: '/collected_pages_ajax/new',
      data: {
        page_id: pageId
      },
      success: function(rslt) {
        $('#col-overlay .col-overlay-contain').html($(rslt));
      }
    });
  }

  function addToCol() {
    EOL.showOverlay('col-overlay');
    loadColContents($(this).data('pageId'));
    return false;
  }

  $(function() {
    $('.js-add-to-col').click(addToCol);
  });
})();
