//= require "trix"
$(document).on('trix-before-initialize', () => {
  console.log('boop');
  Trix.config.blockAttributes.heading1.tagName = 'h2';
});
