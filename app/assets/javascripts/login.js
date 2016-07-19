var recaptchaError = false;var recaptchaChecked = false;
var loginApp = angular.module('loginApp', []);

loginApp.controller('loginValidate', function($scope, $window) {
    $scope.showErrors = false;
    $scope.recaptchaError = false;
    $scope.validateForm = function(event, loginForm) {
        if (loginForm.$invalid) {
            $scope.showErrors = true;
            event.preventDefault();
        }
        if (!(typeof grecaptcha === 'undefined')) {
            var recaptchaResponse = grecaptcha.getResponse();

            if (grecaptcha.getResponse() != undefined &&
                (grecaptcha.getResponse() == null) ||
                (grecaptcha.getResponse() == '')) {
                $scope.showErrors = true;
                $scope.recaptchaError = $window.recaptchaError = true;
                event.preventDefault();
            }
            else
            {
                recaptchaError = false;
            }
        }
    };
});

loginApp.directive('validatePassword', function () {
  return {
    require: 'ngModel',
    link: function (scope, element, attrs, ctrl) {
    	console.log("hi" +scope.password);
    	if(element.val.length < 8 && element.val.length >32  ){
    		ctrl.$setValidity('password', false);
    	}else{
    		ctrl.$setValidity('password', true);
    	}
    }
  };
});

function recaptchaCallback() {
    var appElement = document.querySelector('[ng-app=signupApp]');
    var $scope = angular.element(appElement).scope().$$childHead;
    $scope.$apply(function() {
        $scope.recaptchaError = false;
        $scope.recaptchaChecked = true;
    });
}