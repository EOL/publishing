var ForgetPassword = angular.module('ForgetPasswordApp', []);
ForgetPassword.controller('ForgetPasswordValidate', function($scope) {
  $scope.showErrors = false;
  $scope.validateForm = function(event, ForgetPasswordForm) {
  if (ForgetPasswordForm.$invalid) {
    $scope.showErrors = true;
    event.preventDefault();
   }
  };
});



