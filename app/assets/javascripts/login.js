var recaptchaError = false;
var loginApp = angular.module('loginApp', []);

loginApp.controller('loginValidate', function($scope, $window) {
   $scope.recaptchaChecked = ($(".g-recaptcha").length == 0) ;
    $scope.showErrors = false;
    $scope.recaptchaError = false;
    $scope.validateForm = function(event, loginForm) {
        if (loginForm.$invalid) {
            $scope.showErrors = true;
            event.preventDefault();
        }
        if (typeof(grecaptcha) !== 'undefined') {
          var recaptchaResponse = grecaptcha.getResponse();
            if ( grecaptcha.getResponse() != undefined &&
                (grecaptcha.getResponse() == null) ||
                (grecaptcha.getResponse() == '')) {
                $scope.showErrors = true;
                $scope.recaptchaError = $window.recaptchaError = true;
                event.preventDefault();
            }
            else
            {
               $scope.recaptchaError = false;
               $scope.recaptchaChecked = true;
            }
        }
    };
});

function recaptchaCallback() {
    var appElement = document.querySelector('[ng-app=loginApp]');
    var $scope = angular.element(appElement).scope().$$childHead;
    $scope.$apply(function() {
        $scope.recaptchaError = false;
        $scope.recaptchaChecked = true;
    });
}