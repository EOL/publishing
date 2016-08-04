var ResetPassword = angular.module('ResetPasswordApp', []);
ResetPassword.controller('ResetPasswordValidate', function($scope) {
  $scope.showErrors = false;
  $scope.validateForm = function(event, ResetPasswordForm) {
  if (ResetPasswordForm.$invalid) {
    $scope.showErrors = true;
    event.preventDefault();
   }
  };
});

ResetPassword.directive('validatePassword', function () {
  return {
          require: 'ngModel',
          link: function (scope, element, attrs, ctrl) {
                  ctrl.$parsers.unshift(function(viewValue) {
                       scope.violatePwdLowerLimit = (viewValue && viewValue.length < 8 ? true : false);
                       scope.violatePwdUpperLimit = (viewValue && viewValue.length > 32 ? true : false);
                       if (!(scope.violatePwdLowerLimit || scope.violatePwdUpperLimit)){
				         scope.ViolatepwdLetterCond = (viewValue && /[A-Za-z]/.test(viewValue)) ? false : true;
						 scope.ViolatepwdNumberCond = (viewValue && /\d/.test(viewValue)) ? false : true;
                       }
					   if (scope.violatePwdLowerLimit && scope.violatePwdUpperLimit && scope.ViolatepwdLetterCond && scope.ViolatepwdNumberCond){
                         ctrl.$setValidity('pwd', false);
                         return viewValue;
                       } else {
                           ctrl.$setValidity('pwd', true);
                           return viewValue;
                         }
                  });
          }
         };
});

ResetPassword.directive('passwordMatch', function() {
  return {
  	      require: 'ngModel',
  	      link: function (scope, element, attrs, ctrl){
  	        var firstPassword = '#' + attrs.passwordMatch;
            $(element).add(firstPassword).on('keyup', function () {
               scope.$apply(function () {
                 ctrl.$setValidity('pwdmismatch', element.val()===$(firstPassword).val());
               });
            });
  	       }
         };
});


