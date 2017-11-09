(function() {
  function addToCol() {
    EOL.showOverlay('col-overlay');
    return false;
  }

  $(function() {
    $('.js-add-to-col').click(addToCol);
  });
})();
