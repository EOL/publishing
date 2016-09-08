(function () {
  'use strict';
  // These depend on devise configurations. DON'T FORGET TO CHANGE IT when you
  // change in devise.rb
  var passwordMinLength = 8;
  var passwordMaxLength = 32;

  var app = angular
    .module("eolApp", ["ngMaterial", "ui.bootstrap", "ngSanitize"]);

  app.controller("SearchCtrl", SearchCtrl);
  app.controller("PageCtrl", PageCtrl);
  app.controller("loginValidate", LoginCtrl);
  app.controller('signupValidate', SignupCtrl);

  function SearchCtrl ($scope, $http, $window) {
    $scope.selected = undefined;

    $scope.querySearch = function(query) {
      return $http.get("/search.json", {
        params: { q: query + "*", per_page: "6" }
      }).then(function(response){
        var data = response.data;
        $.each(data, function(i, match) {
          match.preferred_vernaculars =
            jQuery.grep(match.preferred_vernaculars, function(e) {
              var re = new RegExp(query, "i");
              return e.string.match(re);
            });
        });
        return data;
      });
    };

    $scope.onSelect = function($item, $model, $label) {
      if (typeof $item !== 'undefined') {
        $scope.selected = $item.scientific_name;
        $window.location = "/pages/" + $model.id;
      }
    };

    $scope.nameOfModel = function($model) {
      if (typeof $item === 'undefined') {
        return "";
      } else {
        return $model.scientific_name.replace(/<\/?i>/g, "");
      }
    };
  }

  function PageCtrl ($scope) {
    $scope.testVar = "foo";
    $scope.traitsCollapsed = false;
  }

  function LoginCtrl ($scope, $window) {
    $scope.recaptchaChecked = ($(".g-recaptcha").length === 0);
    $scope.recaptchaError = false;
    $scope.showErrors = false;

    $scope.validateForm = function(event, loginForm) {
      if (loginForm.$invalid) {
        $scope.showErrors = true;
        event.preventDefault();
      }
      if (typeof(grecaptcha) !== 'undefined') {
        var recaptchaResponse = grecaptcha.getResponse();
        if (grecaptcha.getResponse() !== undefined &&
          (grecaptcha.getResponse() === null) ||
          (grecaptcha.getResponse() === '')) {
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
  }

  //custom validation for password match
  app.directive('passwordMatch', function () {
  	return {
  		require: 'ngModel',
  		link: function (scope, element, attrs, ctrl) {
  			var firstPassword = '#' + attrs.passwordMatch;
  			$(element).add(firstPassword).on('keyup', function () {
  				scope.$apply(function () {
  					ctrl.$setValidity('pwmismatch', element.val() === $(firstPassword).val());
  				});
  			});
  		}
  	};
  });

  //custom validation for password match
  app.directive('validatePassword', function () {
  	return {
  		require: 'ngModel',
  		link: function (scope, element, attrs, ctrl) {
  			ctrl.$parsers.unshift(function(viewValue) {
  				scope.violatePwdLowerLimit = (viewValue && viewValue.length < passwordMinLength ? true : false);
  				scope.violatePwdUpperLimit = (viewValue && viewValue.length > passwordMaxLength ? true : false);
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

  function SignupCtrl ($scope, $window) {
      $scope.showErrors = false;
      $scope.recaptchaChecked = ($(".g-recaptcha").length === 0);
      $scope.recaptchaError = false;
      $scope.validateForm = function(event, signupForm) {
          if (signupForm.$invalid) {
              $scope.showErrors = true;
              event.preventDefault();
          }
          if (!(typeof grecaptcha === 'undefined')) {
              var recaptchaResponse = grecaptcha.getResponse();
              if (grecaptcha.getResponse() != undefined &&
                  (grecaptcha.getResponse() === null) ||
                  (grecaptcha.getResponse() === '')) {
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
  }

}());

var recaptchaError = false;

function recaptchaCallback() {
  console.log("recaptchaCallback()");
  var appElement = $(".recaptchad")[0];
  var $scope = angular.element(appElement).scope();
  console.log("Recaptcha checked");
  $scope.$apply(function() {
    $scope.recaptchaError = false;
    $scope.recaptchaChecked = true;
  });
}
