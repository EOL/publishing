var recaptchaError = false;var recaptchaChecked = false;
var loginApp = angular.module('loginApp', []);
loginApp.controller('loginValidate', function($scope, $window) {
    $scope.showErrors = false;
    $scope.recaptchaError = false;
    $scope.regex = /^[a-z]+[a-z0-9._]+@[a-z]+\.[a-z.]{2,5}$/;
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


loginApp.directive('validateEmail', function($http) {
  return {
    require: 'ngModel',
    link: function(scope, element, attr, mCtrl, http) {
      
      function myValidation(value) {
   //     console.log("inside my validatin");
        console.log( element.val());
        console.log(scope.regex  );
        console.log(scope.email);
        
//        $http({
 //         method : "GET",
 //         url : "/fetch_user?email=" + element.val(),

   //       }).then(function mySucces(response) {
          
      //      console.log(response + "success" + response.data);
    //        mCtrl.$setValidity('email', response.data);
     //     }, function myError(response) {
      //      console.log(response + "error");

     //   });
      }
      mCtrl.$parsers.push(myValidation);
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