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
      if ($("#page_nav > li:first-of-type").hasClass("uk-active")) {
        $("#name-header").attr("hidden", "hidden");
      } else {
        $("#name-header").removeAttr("hidden");
      }
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
      var target  = $(event.target);
      if( target.is('a') ) { return true; }
      if( $div.is(':visible') ) {
        $div.hide();
      } else {
        if( $div.html() === "" ) {
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
        $("#trait_type_glossary").show();
        $("#trait_value_glossary").show();
      } else if (secId == "other") {
        $("table#traits thead tr").show();
        $("table#traits tbody tr").hide();
        $("table#traits tbody tr.section_other").show();
        $("#trait_type_glossary").hide();
        $("#trait_value_glossary").hide();
      } else if (secId == "type_glossary") {
        $("table#traits thead tr").hide();
        $("table#traits tbody tr").hide();
        $("#trait_type_glossary").show();
        $("#trait_value_glossary").hide();
      } else if (secId == "value_glossary") {
        $("table#traits thead tr").hide();
        $("table#traits tbody tr").hide();
        $("#trait_type_glossary").hide();
        $("#trait_value_glossary").show();
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

  EOL.teardown = function() {
    console.log("TEARDOWN");
    $(".typeahead").typeahead("destroy");
  };

  EOL.ready = function() {
    console.log("READY");
    if ($(".eol-flash").length === 1) {
      var flash = $(".eol-flash");
      UIkit.notification({
          message: $(".eol-flash").data("text"),
          status: 'primary',
          pos: 'top-center',
          offset: '100px',
          timeout: 5000
      });
    }

    $(".disable-on-click").on("click", function() {
      $(this).closest(".button").addClass("disabled loading");
    });

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

    // TODO: move this.
    EOL.searchNames = new Bloodhound({
      datumTokenizer: Bloodhound.tokenizers.obj.whitespace('value'),
      queryTokenizer: Bloodhound.tokenizers.whitespace,
      // TODO: someday we should have a pre-populated list of common search terms
      // and load that here. prefetch: '../data/films/post_1960.json',
      remote: {
        url: '/names/%QUERY.json',
        wildcard: '%QUERY'
      },
      limit: 10
    });
    EOL.searchNames.initialize();

    if ($('#nav-search .typeahead').length >= 1) {
      console.log("Enable navigation typeahead.");
      $('#nav-search .typeahead').typeahead(null, {
        name: 'search-names',
        display: 'value',
        source: EOL.searchNames
      }).bind('typeahead:selected', function(evt, datum, name) {
        console.log('typeahead:selected:', evt, datum, name);
        window.location.href = '/search?q=' + datum.value;
      }).bind('keypress', function(e) {
        console.log('keypress:', e);
        console.log('which:', e.which);
        if (e.which == 13) {
          var q = $('#nav-search input.typeahead.tt-input').val();
          window.location.href = "/search?q=" + q;
          return false;
        }
      });
    };

    if ($('.clade_filter .typeahead').length >= 1) {
      console.log("Enable clade filter typeahead.");
      $('.clade_filter .typeahead').typeahead(null, {
        name: 'clade-filter-names',
        display: 'value',
        source: EOL.searchNames
      }).bind('typeahead:selected', function(evt, datum, name) {
        console.log('typeahead:selected:', evt, datum, name);
        $(".clade_filter form input#clade").val(datum.id);
        $(".clade_filter form").submit();
      });
    };

    // Clean up duplicate search icons, argh:
    if ($(".uk-search-icon > svg:nth-of-type(2)").length >= 1) {
      $(".uk-search-icon > svg:nth-of-type(2)");
    };
  };
}

$(document).on("turbolinks:load", EOL.ready);
$(document).on("turbolinks:before-cache", EOL.teardown);
