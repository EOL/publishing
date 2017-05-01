if(!EOL) {
  var EOL = {};

  EOL.enable_search_pagination = function() {
    $("#search_results .uk-pagination a")
    .unbind("click")
    .on("click", function() {
      console.log("search pagination click");
      $(this).closest(".search_result_container").dimmer("show");
    });
  };

  EOL.enable_tab_nav = function() {
    console.log("enable_tab_nav");
    $("#page_nav a").on("click", function() {
      console.log("page_nav click");
      $("#tab_content").dimmer("show");
    }).unbind("ajax:complete")
    .bind("ajax:complete", function() {
      console.log("page_nav complete");
      $("#tab_content").dimmer("hide");
      $("#page_nav").children().removeClass("uk-active");
      $(this).parent().addClass("uk-active");
      history.pushState(null, "", this.href);
    }).unbind("ajax:error")
    .bind("ajax:error", function(evt, data, status, xhr) {
      console.log("page_nav error:");
      UIkit.modal.alert('Sorry, there was an error loading this subtab.');
      console.log(data.responseText);
    });
    EOL.dim_tab_on_pagination();
  };

  EOL.dim_tab_on_pagination = function() {
    console.log("dim_tab_on_pagination");
    $("#tab_content").dimmer("hide");
    $(".uk-pagination a").on("click", function(e) {
      $("#tab_content").dimmer("show");
    });
  };

  EOL.allow_meta_traits_to_toggle = function() {
    console.log("allow_meta_traits_to_toggle");
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
    EOL.enable_tab_nav();
  };

  EOL.enable_media_navigation = function() {
    console.log("enable_media_navigation");
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
    EOL.enable_tab_nav();
  };

  EOL.enable_trait_toc = function() {
    console.log("enable_trait_toc");
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
  if ($("#gallery").length === 1) {
    EOL.enable_media_navigation();
  } else if ($("#page_traits").length === 1) {
    EOL.enable_trait_toc();
    EOL.allow_meta_traits_to_toggle();
  } else if ($("#traits_table").length === 1) {
    EOL.allow_meta_traits_to_toggle();
  } else if ($("#search_results").length === 1) {
    EOL.enable_search_pagination();
  } else {
    EOL.enable_tab_nav();
  }
  // No "else" because it also has a gallery, so you can need both!
  if ($("#gmap").length >= 1) {
    EoLMap.init();
  }
  $(window).bind("popstate", function () {
    console.log("popstate "+location.href);
    $.getScript(location.href);
  });
});
