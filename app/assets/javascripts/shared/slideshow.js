function stopPlayers() {
  var $youtube = $(this).find('.js-youtube-player');

  $(this).find('audio').trigger('pause');
  $(this).find('video').trigger('pause');


  if ($youtube.length) {
    $youtube.data('youtubePlayer').stopVideo();
  }
}

function setupAutoPause() {
  // pause audio and video players on hide. 
  $('.uk-slideshow').on('beforehide beforeitemhide', stopPlayers);
  $('.uk-modal').on('beforehide', stopPlayers);

  EOLYoutube.register(function() {
    $('.js-youtube-player').each(function(i, player) {
      $(player).data('youtubePlayer', new YT.Player(player));
    });
  });
}

$(function() {
  setupAutoPause();

  $('.js-grid-modal-toggle').click(function(e) {
    e.preventDefault();

    var slideId = '#slide-' + $(this).data('slideId')
      , slideElmt = $(slideId)
      , slideIndex = slideElmt.data('index')
      ;

    UIkit.slideshow('.js-grid-slideshow').show(slideIndex);
    UIkit.modal('.js-grid-modal').show(); 
  });
});

