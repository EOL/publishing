(function () {
  'use strict';
  angular
    .module("searchApp", ["ngMaterial", "ngSanitize"])
    .controller("SearchCtrl", SearchCtrl)
    .filter("htmlSafe", function htmlSafe($sce) {
      return function(val) {
        console.log("I was here: " + $sce);
        return $sce.trustAsHtml(val);
      }
    });

  function SearchCtrl ($timeout, $q, $log, $window, $http) {
    var self = this;
    self.querySearch = querySearch;
    self.selectedItemChange = selectedItemChange;
    self.searchTextChange = searchTextChange;

    function querySearch (query) {
      var deferred = $q.defer();
      $http.get("/search.json?q=" + query + "*").then(function(response) {
          // $log.info("Returned response: " + JSON.stringify(response.data));
          deferred.resolve(response.data);
      });
      // return the promise
      return deferred.promise;
    };
    function searchTextChange(text) {
      // $log.info('Text changed to ' + text);
    };
    function selectedItemChange(item) {
      // $log.info('Item changed to ' + JSON.stringify(item));
      $window.location.href = "/pages/" + item.id;
    };
  };
})();
