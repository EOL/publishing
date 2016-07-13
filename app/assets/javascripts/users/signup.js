var recaptchaError = false;
var signupApp = angular.module('signupApp', []);

//custom validation for unique email
signupApp.directive('uniqueEmail', function ($http) {
	return {
		restrict: 'A',
		require: 'ngModel',
		link: function (scope, element, attrs, ngModel) {
			element.bind('blur', function (e) {
				ngModel.$loading = true;
				$http.get('/users/check_email', {
					params: {email:  element.val() }
				}).success(function(data) {
					ngModel.$loading = false;
					ngModel.$setValidity('emailExists', !data);
				});
			});
		}
	};
});

//custom validation for password match
signupApp.directive('passwordMatch', function () {
	return {
		require: 'ngModel',
		link: function (scope, element, attrs, ctrl) {
			var firstPassword = '#' + attrs.passwordMatch;
			element.add(firstPassword).on('keyup', function () {
				scope.$apply(function () {
					ctrl.$setValidity('pwmismatch', element.val()===$(firstPassword).val());
				});
			});
		}
	};
});


signupApp.controller('signupValidate', function($scope, $window) {
    $scope.showErrors = false;
    $scope.recaptchaError = false;
    $scope.validateForm = function(event, signupForm) {
        if (signupForm.$invalid) {
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

function recaptchaCallback() {
    var appElement = document.querySelector('[ng-app=signupApp]');
    var $scope = angular.element(appElement).scope().$$childHead;
    $('#createAccount').removeAttr('disabled');
    $scope.$apply(function() {
        $scope.recaptchaError = false;
    });
}