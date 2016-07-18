var recaptchaError = false;
var recaptchaChecked = false;

var signupApp = angular.module('signupApp', []);

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

//custom validation for password match
signupApp.directive('validatePassword', function () {
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
    $scope.$apply(function() {
        $scope.recaptchaError = false;
        $scope.recaptchaChecked = true;
    });
}