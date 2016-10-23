// TODO: rename this file and the controller.
var app = angular.module('confirmApp', ['ngMaterial']);
app.controller('AppMaterials', function($scope, $mdDialog, $mdMedia, $http, $window) {
  $scope.showConfirm = function(ev,user_id, msg) {
    var confirm = $mdDialog.confirm()
      .textContent(msg)
      .targetEvent(ev)
      .ok('ok')
      .cancel('cancel');
    $mdDialog.show(confirm).then(function() {
      $http({
        method : 'POST',
        url :'/users/delete_user?id=' + user_id.toString()
        }).then(
         function mySucces(response){
           $window.location.href = "http://"+ $window.location.host;
        });
      });
    };
});
