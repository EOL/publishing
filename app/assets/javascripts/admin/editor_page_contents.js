//= require "trix"
(function() {
  $(document).on('trix-before-initialize', () => {
    Trix.config.blockAttributes.heading1.tagName = 'h2';
  });

  function listenForAttachments() {
    document.addEventListener('trix-attachment-add', (e) => {
      console.log(e);
    });
  }

  $(function() {
    listenForAttachments();
  });
})();
