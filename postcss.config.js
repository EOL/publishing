const path = require('path');
const rtlPath = path.resolve('app/webpacker/packs/stylesheets/rtl');

module.exports = (ctx) => {
  var rtl = ctx.file.dirname == rtlPath;

  return {
    plugins: [
      require('postcss-import'),
      require('postcss-flexbugs-fixes'),
      require('postcss-preset-env')({
        autoprefixer: {
          flexbox: 'no-2009'
        },
        stage: 3
      }),
      rtl ? require('rtlcss') : false    
    ]
  };
}
