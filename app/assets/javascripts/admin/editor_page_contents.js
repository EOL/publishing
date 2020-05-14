//= require "trix"
(function() {
  $(document).on('trix-before-initialize', () => {
    Trix.config.blockAttributes.heading1.tagName = 'h2';
  });

  function listenForAttachments() {
    document.addEventListener('trix-attachment-add', (e) => {
      if (e.attachment.file) {
        uploadImage(e.attachment.file);
      }
    });
  }

  function uploadImage(file) {
    var data = new FormData();
    data.append('image', file);

    $.ajax({
      url: 'upload_image',
      type: 'POST',
      data: data,
      processData: false,
      contentType: false,
      success: (response) => {
        console.log(response)
      }
    })
  }

  $(function() {
    listenForAttachments();
  });
})();
