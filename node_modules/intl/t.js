var IntlPolyfill = require('./');

console.log(new Intl.NumberFormat().format());
console.log(new IntlPolyfill.NumberFormat('en', {}).format());

console.log(new IntlPolyfill.DateTimeFormat('en-GB', {
  hour: '2-digit',
  hour12: false,
  minute: 'numeric'
}).resolvedOptions());
console.log(new IntlPolyfill.DateTimeFormat('en-GB', {
  hour: '2-digit',
  hour12: false,
  minute: 'numeric'
}).format(new Date(1983, 9, 13)));

var d = new Date('2015/04/05');
var o = { hour: '2-digit', minute: '2-digit', timeZoneName: 'short' };
var a = new Intl.DateTimeFormat('en-US', o).format(d);
var b = new IntlPolyfill.DateTimeFormat('en-US', o).format(d);
console.log('chrome  : ', a);
console.log('polyfill: ', b);

var d = new Date('2015/04/05');
var o = { year: '2-digit', month: '2-digit', day: '2-digit' };
var a = new Intl.DateTimeFormat('en', o).format(d);
var b = new IntlPolyfill.DateTimeFormat('en', o).format(d);
console.log('chrome  : ', a);
console.log('polyfill: ', b);

// issue #139
var o = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
var a = new Intl.DateTimeFormat('ja-JP', o).format(d);
var b = new IntlPolyfill.DateTimeFormat('ja-JP', o).format(d);
console.log('chrome  : ', a);
console.log('polyfill: ', b);

// issue #128
var a = new Intl.DateTimeFormat('en', {
    month: '2-digit'
}).format(d);
var b = new IntlPolyfill.DateTimeFormat('en', {
    month: '2-digit'
}).format(d);
console.log('chrome  : ', a);
console.log('polyfill: ', b);

// issue 125
var o = {
    weekday: 'long'
};
var a = new Intl.DateTimeFormat('en-US', o).format(d);
var b = new IntlPolyfill.DateTimeFormat('en-US', o).format(d);
console.log('chrome  : ', a);
console.log('polyfill: ', b);

// issue 117
var o = {
    month: 'long'
};
var a = new Intl.DateTimeFormat('en', o).format(d);
var b = new IntlPolyfill.DateTimeFormat('en', o).format(d);
console.log('chrome  : ', a);
console.log('polyfill: ', b);

var o = {
    month: 'long',
    day: 'numeric'
};
var a = new Intl.DateTimeFormat('en', o).format(d);
var b = new IntlPolyfill.DateTimeFormat('en', o).format(d);
console.log('chrome  : ', a);
console.log('polyfill: ', b);
console.log('ddddd');
// issue 69
var d1 = new Date(Date.UTC(2012, 11, 20, 3, 0, 0));
var o = { year: "numeric", month: "short", day: "numeric", weekday: "short" };
// var a = new Intl.DateTimeFormat('zh', o).format(d1);
var uu = new IntlPolyfill.DateTimeFormat('zh', o);
var b = uu.format(d1);
console.log('expected:  2012年12月19日星期三');
//console.log('chrome  : ', a);
console.log('polyfill: ', b); /// tbd

// console.log(new IntlPolyfill.DateTimeFormat("ja", {year: "numeric", month: "long", day: "numeric", weekday: "long"}).format(new Date()));

console.log('\nIssue #126:');
var o = { month: 'long' };
var a = new Intl.DateTimeFormat('ru', o).format(d);
var b = new IntlPolyfill.DateTimeFormat('ru', o).format(d);
console.log('chrome  : ', a);
console.log('polyfill: ', b);
var o = { month: 'long', day: 'numeric' };
var a = new Intl.DateTimeFormat('ru', o).format(d);
var b = new IntlPolyfill.DateTimeFormat('ru', o).format(d);
console.log('chrome  : ', a);
console.log('polyfill: ', b);
