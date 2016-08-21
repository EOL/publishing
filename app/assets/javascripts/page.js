(function () {
  'use strict';
  angular
    .module("pageApp", ["ngMaterial", "ui.bootstrap", "ngSanitize"])
    .controller("PageCtrl", PageCtrl);

  function PageCtrl ($scope) {
    $scope.isCollapsed = false;
  };
})();
