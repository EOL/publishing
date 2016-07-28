var recaptchaError = false;
var signupApp = angular.module('signupApp', []);

//adding new directive for validation
signupApp.directive('uniqueEmail', ["Users", function (Users) {
  return {
    require: 'ngModel',
    link: function(scope, element, attr, mCtrl) {
      alert("uniqueMail");
      mCtrl.$parsers.push(function (viewValue) {
      	if (viewValue){
      		alert("inside viewvalue:");
      		alert(viewValue);
      		Users.check_email({email: viewValue}, function (is_taken) {
      			alert("is taken is");
      			alert(is_taken);
      			if (is_taken === 1) {
      				mCtrl.$setValidity('uniqueEmail', true);
      			} else {
      				mCtrl.$setValidity('uniqueEmail', false);
      			}
      		});
      		return viewValue;
      	}
      });
    }
  };
}]);

//custom validation for password match
signupApp.directive('passwordMatch', function () {
	alert("kakkkak");
	return {
		require: 'ngModel',
		link: function (scope, element, attrs, ctrl) {
			var firstPassword = '#' + attrs.passwordMatch;
			alert("first password");
			alert(firstPassword);
			element.add(firstPassword).on('keyup', function () {
				scope.$apply(function () {
					var v = elem.val()===$(firstPassword).val();
					alert(v);
					ctrl.$setValidity('pwmismatch', v);
				});
			});
		}
	};
});


signupApp.controller('signupValidate', function($scope, $window) {
    $scope.showErrors = false;
    $scope.recaptchaError = false;
    $scope.validateForm = function(event, signupForm) {
    	alert("kak");
    	alert(signupForm);
        if (signupForm.$invalid) {
        	alert("kak");
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
    });
}
