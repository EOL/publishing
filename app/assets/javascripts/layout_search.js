(function () {
  'use strict';
  angular
    .module("searchApp", ["ngMaterial", "ui.bootstrap", "ngSanitize"])
    .controller("SearchCtrl", SearchCtrl);

  function SearchCtrl ($scope, $http, $window) {
    $scope.selected = undefined;

    $scope.querySearch = function(query) {
      return $http.get("/search.json", {
        params: { q: query + "*", per_page: "6" }
      }).then(function(response){
        return response.data;
      });
    };

    $scope.onSelect = function($item, $model, $label) {
      $scope.selected = $item.scientific_name;
      // /pages/{{ match.model.id }}
      $window.location = "/pages/" + $model.id;
    };

    $scope.nameOfModel = function($model) {
      return $model.scientific_name.replace(/<\/?i>/g, "");
    };
  };
})();
