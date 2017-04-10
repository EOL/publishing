if(!EOL) {
  var EOL = {};
  EOL.allow_meta_traits_to_toggle = function() {
    $(".toggle_meta").on("click", function (event) {
      event.stopPropagation();
      var $table = $(this).next();
      $table.toggle();
      if ($table.is(":visible")) {
        var $node = $(this).closest("tr");
        $($('html,body')).unbind().animate({scrollTop: $node.offset().top - 50}, 400);
      }
    });
    $(".meta_trait").hide();
  };
}

$(document).ready(function() {
  $("#page_nav a").on("click", function() {
    $("#page_nav_content").children().slideUp({ duration: 500 });
    $("#page_nav_content").append("<div class='uk-text-center'><div uk-spinner></div></div>");
  });
  // TODO: this is not great; duplicated with media.js.erb. Generalize.
  $("#page_nav_content .dropdown").dropdown({ direction: "upward" });
});

// (function () {
//   'use strict';
//   // These depend on devise configurations. DON'T FORGET TO CHANGE IT when you
//   // change in devise.rb
//   var passwordMinLength = 8;
//   var passwordMaxLength = 32;
//
//   var app = angular
//     .module("eolApp", ["ngAnimate", "ngMaterial", "ngSanitize"])
//     .config(function($mdThemingProvider) {
//       $mdThemingProvider.theme('default')
//         .primaryPalette('brown', {
//           'default': '800'
//         })
//         .accentPalette('indigo', {
//           'default': '800'
//         });
//     });

  // app.controller("CladeFilterCtrl", CladeFilterCtrl);
  // app.controller("collectionSearchCtrl", collectionSearchCtrl);
  // app.controller('ConfirmDeleteCtrl', ConfirmDeleteCtrl);
  //
  // // function CladeFilterCtrl ($scope, $http, $window) {
	// $scope.cladeFilter = function(clade_name, uri) {
	// 	return $http.get("/clade_filter.js", {
  //      		params: { clade_name: clade_name, uri: uri }
  //   	}).then(function(response, $compile){
  //   		var elem = angular.element("div#traits_table");
  //   		$compile = elem.injector().get('$compile');
  //   		var scope = elem.scope();
  //   		elem.html( $compile(response.data)(scope) );
	// 	});
  // 	};
  // }

  // TODO: move to normal Rails / jQuery...
  // function collectionSearchCtrl ($scope, $http) {
  //   $scope.selected = undefined;
  //   $scope.showClearSearch = false;
  //
  //   $scope.querySearch = function(query, collection_id) {
  //     return $http.get("/collected_pages/search.json", {
  //       params: { q: query + "*", collection_id: collection_id }
  //     }).then(function(response) {
  //       var data = response.data;
  //       if(data.length > 0){
  //         $.each(data, function(i, match) {
  //           var re = new RegExp(query, "i");
  //           match.names = [];
  //           // TODO: this is ALSO broken (see first querySearch above) Ideally,
  //           // this would be an abstracted method that we used in both places.
  //           // Quick note: probably better to abstract the inner then() call,
  //           // since the rest isn't duplicated.
  //           if(match.scientific_name.match(re)) {
  //             match.names += { string: match.scientific_name };
  //           };
  //           match.names =
  //             jQuery.grep(match.preferred_vernaculars, function(e) {
  //               return e.string.match(re);
  //             });
  //         });
  //       } else {
  //         data =  [{names: {string: "No pages found!" }}];
  //       }
  //       return data;
  //     });
  //   };
  //
  //   $scope.onSelect = function($item, $model, $label, collection_id) {
  //     if (typeof $item !== 'undefined') {
  //       if(typeof $scope.selectedPage.names[0] === 'undefined') return;
  //       $scope.name = $scope.selectedPage.names[0].string;
  //       $scope.selected = $item.scientific_name;
  //       $("div.collected_pages").hide();
  //       $http.get("/collected_pages/search_results" , {
  //       params: { q: $scope.name, collection_id: collection_id}
  //     }).then(function(response){
  //       var data = response.data;
  //       document.querySelector('div.search_results').innerHTML= response.data;
  //       $scope.showClearSearch = true;
  //       return data;
  //     });
  //     }
  //   };
  //
  //   $scope.nameOfModel = function($model) {
  //     if (typeof $item === 'undefined') {
  //       return "";
  //     } else {
  //       return $model.scientific_name.replace(/<\/?i>/g, "");
  //     }
  //   };
  //
  //   $scope.clearSearch = function() {
  //     $("div.collected_pages").hide();
  //     $('div.search_results').remove();
  //     $scope.showClearSearch = false;
  //   };
  // }
