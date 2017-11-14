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
        var $contain = $('#col-overlay .col-overlay-contain');
        $contain.html($(rslt));
        buildColSelect($contain.find('.js-col-sel'));
        $contain.find('.js-col-sel').on('ajax:success', function(e, data) {
          $contain.append($(data));
        });
      }
    });
  }

  function addToCol() {
    EOL.showOverlay('col-overlay');
    loadColContents($(this).data('pageId'));
    return false;
  }

  function openColSelect() {
    $(this).parent('.js-col-sel').addClass('is-col-sel-open');
    $(this).off('click', openColSelect);
    $(this).click(closeColSelect);
  }

  function closeColSelect() {
    $(this).parent('.js-col-sel').removeClass('is-col-sel-open');
    $(this).off('click', closeColSelect);
    $(this).click(openColSelect);
  }

  function setColSelectChoice() {
    var $form = $(this).closest('.js-col-sel')
      , $choice = $form.find('.js-col-sel-choice')
      , $field = $form.find('.js-col-sel-id')
      ; 

    $field.attr('value', $(this).data('id'));
    $choice.find('.js-col-sel-choice-name').html($(this).data('name'));
    closeColSelect.call($choice);
  }
  
  function buildColSelect($elmt) {
    $elmt.find('.js-col-sel-choice').click(openColSelect);
    $elmt.find('.js-col-sel-item').click(setColSelectChoice);
    setColSelectChoice.call($elmt.find('.js-col-sel-item').first());
  }

  $(function() {
    $('.js-add-to-col').click(addToCol);
  });
})();
