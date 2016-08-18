(function () {
  'use strict';
  angular
    .module("searchApp", ['ngMaterial'])
    .controller("SearchCtrl", SearchCtrl);

  function SearchCtrl ($timeout, $q, $log, $window) {
    var self = this;
    self.querySearch = querySearch;
    self.selectedItemChange = selectedItemChange;
    self.searchTextChange = searchTextChange;

    // TODO: change! I'm just testing, now:
    self.pages = [
      {page: 328598, name: "procyon lotor", img: "http://media.eol.org/content/2014/06/14/12/40029_88_88.jpg"},
      {page: 328598, name: "raccoon", img: "http://media.eol.org/content/2014/06/14/12/40029_88_88.jpg"},
      {page: 19831, name: "raccoon dog", img: "http://media.eol.org/content/2012/05/23/20/56168_88_88.jpg"},
      {page: 19831, name: "nyctereutes", img: "http://media.eol.org/content/2012/05/23/20/56168_88_88.jpg"}];

    function querySearch (query) {
      var results = query ? self.pages.filter( createFilterFor(query) ) : self.pages, deferred;
      deferred = $q.defer();
      $timeout(function () { deferred.resolve( results ); }, Math.random() * 1000, false);
      return deferred.promise;
    };
    function searchTextChange(text) {
      $log.info('Text changed to ' + text);
    };
    function selectedItemChange(item) {
      $log.info('Item changed to ' + JSON.stringify(item));
      $window.location.href = "/pages/" + item.page;
    };
    function createFilterFor(query) {
      var re = new RegExp("\\b" + angular.lowercase(query));
      return function filterFn(page) {
        return (re.exec(page.name));
      };
    };
  };
})();
