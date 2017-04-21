if(!EOL) {
  var EOL = {};

  EOL.dim_tab_on_pagination = function() {
    $("#tab_content").dimmer("hide");
    $(".uk-pagination a").on("click", function(e) {
      $("#tab_content").dimmer("show");
    });
  };

  EOL.allow_meta_traits_to_toggle = function() {
    console.log("Enabling Meta Traits to Toggle.");
    $(".toggle_meta").on("click", function (event) {
      var $div = $(this).find(".meta_trait");
      if($div.is(':visible')) {
        $div.hide();
      } else {
        if($div.html() === "") {
          console.log("Loading row "+$(this).data("action")+"...");
          $.ajax({
            type: "GET",
            url: $(this).data("action"),
            // While they serve no purpose NOW... I am keeping these here for
            // future use.
            beforeSend: function() {
              console.log("Calling before send...");
            },
            complete: function(){
              console.log("Calling complete...");
            },
            success: function(resp){
              console.log("Calling success...");
            },
            error: function(xhr, textStatus, error){
              console.log("There was an error...");
              console.log(xhr.statusText+" : "+textStatus+" : "+error);
            }
          });
        } else {
          console.log("Using cached row...");
          $(".meta_trait").hide();
          $div.show();
        }
      }
      return event.stopPropagation();
    });
    $(".meta_trait").hide();
    EOL.dim_tab_on_pagination();
  };

  EOL.enable_media_navigation = function() {
    console.log("Enabling Media Navigation.");
    $("#page_nav_content .dropdown").dropdown();
    $(".uk-modal-body a.uk-slidenav-large").on("click", function(e) {
      var link = $(this);
      thisId = link.data("this-id");
      tgtId = link.data("tgt-id");
      console.log("Switching images. This: "+thisId+" Target: "+tgtId);
      // Odd: removing this (extra show()) causes a RELOADED page of image
      // modals to stop working:
      UIkit.modal("#"+thisId).show();
      UIkit.modal("#"+thisId).hide();
      UIkit.modal("#"+tgtId).show();
    });
    EOL.dim_tab_on_pagination();
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
      EOL.dim_tab_on_pagination();
    });
  };
}

$(document).ready(function() {
  $("#page_nav a").on("click", function() {
    $("#tab_content").dimmer("show");
  }).bind("ajax:complete", function() {
    $("#tab_content").dimmer("hide");
  }).bind("ajax:error", function(evt, data, status, xhr) {
    UIkit.modal.alert('Sorry, there was an error loading this subtab.');
    console.log(data.responseText)
  });
  if ($("#gallery").length === 1) {
    EOL.enable_media_navigation();
  } else if ($("#page_traits").length === 1) {
    EOL.enable_trait_toc();
    EOL.allow_meta_traits_to_toggle();
  } else if ($("#traits_table").length === 1) {
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
