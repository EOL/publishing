(function () {
  'use strict';
  angular
    .module("pageApp", ["ngMaterial", "ui.bootstrap"])
    .controller("PageCtrl", PageCtrl);

  function PageCtrl ($scope) {
    $scope.testVar = "foo";
    $scope.traitsCollapsed = false;
  };
})();

// Separating out the old-style jQuery stuff for clarity:

$(document).ready(function(){
    $('[data-toggle="tooltip"]').tooltip();
});
