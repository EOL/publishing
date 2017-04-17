if(!EOL) {
  var EOL = {};
  EOL.allow_meta_traits_to_toggle = function() {
    console.log("Enabling Meta Traits to Toggle.");
    $(".toggle_meta").on("click", function (event) {
      event.stopPropagation();
      var $div = $(this).find(".meta_trait");
      $.ajax({
        type: "GET",
        url: $(this).data("action")
      });
    });
    $(".meta_trait").hide();
  };

  EOL.enable_media_navigation = function() {
    console.log("Enabling Media Navigation.");
    $("#page_nav_content .dropdown").dropdown({ direction: "upward" });
    $(".uk-modal-body a.uk-slidenav-large").on("click", function(e) {
      var link = $(this);
      thisId = link.data("this-id");
      tgtId = link.data("tgt-id");
      UIkit.modal("#"+thisId).hide();
      UIkit.modal("#"+tgtId).show();
    });
  };

  EOL.enable_trait_toc = function() {
    console.log("Enabling Data Tab TOC.");
    $("#section_links a").on("click", function(e) {
      var link = $(this);
      $("#section_links .item.active").removeClass("active");
      link.parent().addClass("active");
      var secId = link.data("section-id");
      if(secId == "all") {
        $("table#traits thead tr").show();
        $("table#traits tbody tr").show();
        $("#trait_glossary").show();
      } else if (secId == "other") {
        $("table#traits thead tr").show();
        $("table#traits tbody tr").hide();
        $("table#traits tbody tr.section_other").show();
        $("#trait_glossary").hide();
      } else if (secId == "glossary") {
        $("table#traits thead tr").hide();
        $("table#traits tbody tr").hide();
        $("#trait_glossary").show();
      } else {
        $("table#traits thead tr").show();
        $("table#traits tbody tr").hide();
        $("table#traits tbody tr.section_"+secId).show();
        $("#trait_glossary").hide();
      }
      e.stopPropagation();
      e.preventDefault();
    });
  };
}

$(document).ready(function() {
  $("#page_nav a").on("click", function() {
    $("#page_nav_content").children().slideUp({ duration: 500 });
    $("#page_nav_content").append("<div class='uk-text-center'><div uk-spinner></div></div>");
  });
  if ($("#gallery").length === 1) {
    EOL.enable_media_navigation();
  } else if ($("#page_traits").length === 1) {
    EOL.enable_trait_toc();
    EOL.allow_meta_traits_to_toggle();
  }
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
