import 'core-js/stable'
import 'regenerator-runtime/runtime'
import '../src/wordcloud'
import '../src/typeahead.bundle'
import '../src/main'
import '../src/youtube'
import '@client-side-validations/client-side-validations'
import '@client-side-validations/simple-form'

import * as Routes from '../src/routes.js.erb'
window.Routes = Routes;
import '../src/js_route_config.js.erb'

import I18n from '../i18n-js/index.js.erb'
window.I18n = I18n

