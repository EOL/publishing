var recaptchaError = false;
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


loginApp.directive('login', function($http) {
  return {
    require: 'ngModel',
    link: function(scope, element, attr, mCtrl, http) {
    	
      function myValidation(value) {
   //   	console.log("inside my validatin");
      	console.log( element.val());
      	console.log(scope.regex	);
      	console.log(scope.email);
//        $http({
 //         method : "GET",
 //         url : "/fetch_user?email=" + element.val(),

   //       }).then(function mySucces(response) {
          
      //    	console.log(response + "success" + response.data);
    //        mCtrl.$setValidity('email', response.data);
     //     }, function myError(response) {
      //    	console.log(response + "error");

     //   });
      }
      mCtrl.$parsers.push(myValidation);
    }
  };
});

function recaptchaCallback() {
    var appElement = document.querySelector('[ng-app=loginApp]');
    var $scope = angular.element(appElement).scope().$$childHead;
    $scope.$apply(function() {
        $scope.recaptchaError = false;
    });
}