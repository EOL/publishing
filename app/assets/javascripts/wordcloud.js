$(function() {
  $('.js-wordcloud').each(function() {
    var $this = $(this);
    $this.jQCloud($this.data('words'), {
      autoResize: true,
      encodeURI: false
    });
  });
})
