window.EOLYoutube = (function(exports) {
  var tagCreated = false
    , loaded = false
    , cbs = []
    ;
  
  // Register a callback for youtube API load
  exports.register = function(cb) {
    if (!tagCreated) {
      var tag = document.createElement('script');
      tag.src = "https://www.youtube.com/iframe_api";
      var firstScriptTag = document.getElementsByTagName('script')[0];
      firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
      tagCreated = true;

      window.onYouTubeIframeAPIReady = function() {
        loaded = true;

        cbs.forEach(function(cb) {
          cb();
        });
      }
    }

    if (loaded) {
      cb();
    } else {
      cbs.push(cb);
    }
  }

  return exports;
})({});
