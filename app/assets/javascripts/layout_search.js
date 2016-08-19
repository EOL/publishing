(function () {
  'use strict';
  angular
    .module("searchApp", ["ngMaterial", "ui.bootstrap"])
    .controller("SearchCtrl", SearchCtrl);

  function SearchCtrl ($scope, $http) {
    $scope.selected = undefined;

    $scope.querySearch = function(query) {
      return $http.get("/search.json", {
        params: { q: query + "*" }
      }).then(function(response){
        return response.data;
      });
    };

    $scope.onSelect = function($item, $model, $label) {
      $scope.selected = $item.scientific_name;
      console.log("Model: " + JSON.stringify($model));
    }
  };
})();
