(function () {
  'use strict';
  var app = angular
    .module("eolApp", ["ngMaterial", "ui.bootstrap", "ngSanitize"]);

  app.controller("SearchCtrl", SearchCtrl);
  app.controller("PageCtrl", PageCtrl);

  function SearchCtrl ($scope, $http, $window) {
    $scope.selected = undefined;

    $scope.querySearch = function(query) {
      return $http.get("/search.json", {
        params: { q: query + "*", per_page: "6" }
      }).then(function(response){
        var data = response.data;
        $.each(data, function(i, match) {
          match.preferred_vernaculars =
            jQuery.grep(match.preferred_vernaculars, function(e) {
              var re = new RegExp(query, "i");
              return e.string.match(re);
            });
        });
        return data;
      });
    };

    $scope.onSelect = function($item, $model, $label) {
      if (typeof $item !== 'undefined') {
        $scope.selected = $item.scientific_name;
        $window.location = "/pages/" + $model.id;
      };
    };

    $scope.nameOfModel = function($model) {
      if (typeof $item == 'undefined') {
        return "";
      } else {
        return $model.scientific_name.replace(/<\/?i>/g, "");
      }
    };
  };

  function PageCtrl ($scope) {
    $scope.testVar = "foo";
    $scope.traitsCollapsed = false;
  };

})();
