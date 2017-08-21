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
    $("#page_nav a,#small_page_nav a").on("click", function() {
      console.log("page_nav click");
      $("#tab_content").dimmer("show");
    }).unbind("ajax:complete")
    .bind("ajax:complete", function() {
      console.log("page_nav complete");
      $("#tab_content").dimmer("hide");
      $("#page_nav li").removeClass("uk-active");
      $("#small_page_nav > a").removeClass("active");
      $(this).addClass("active").parent().addClass("uk-active");
      if ($("#page_nav > li:first-of-type").hasClass("uk-active")) {
        $("#name-header").attr("hidden", "hidden");
      } else {
        $("#name-header").removeAttr("hidden");
      }
      history.pushState(null, "", this.href);
      console.log("page_nav complete exit");
    }).unbind("ajax:error")
    .bind("ajax:error", function(evt, data, status) {
      if (status === "parsererror") {
        console.log("** Got that curious parsererror.");
      } else {
        UIkit.modal.alert('Sorry, there was an error loading this subtab.');
      }
      console.log("data response: "+data.responseText);
      console.log("status: "+status);
      console.log("page_nav error:");
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

  EOL.meta_data_toggle = function() {
    console.log("enable meta_data_toggle");
    $(".meta_data_toggle").on("click", function (event) {
      var $parent = $(this).parent();
      var $div = $parent.find(".meta_data");
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
              var offset = $parent.offset();
              if (offset) {
                $('html, body').animate({ scrollTop: offset.top - 100 }, 'fast');
                return false;
              }
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
          console.log($div.html());
          $div.show();
        }
      }
      return event.stopPropagation();
    });
    $(".meta_data").hide();
    EOL.enable_tab_nav();
  };

  EOL.allow_meta_data_to_toggle = function() {
    console.log("allow_meta_data_to_toggle");
    $(".toggle_meta").on("click", function (event) {
      var $div = $(this).find(".meta_data");
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
          console.log($div.html());
          $(".meta_data").hide();
          $div.show();
        }
      }
      return event.stopPropagation();
    });
    $(".meta_data").hide();
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

  EOL.enable_data_toc = function() {
    console.log("enable_data_toc");
    $("#section_links a").on("click", function(e) {
      var link = $(this);
      $("#section_links .item.active").removeClass("active");
      link.parent().addClass("active");
      var secId = link.data("section-id");
      if(secId == "all") {
        $("table#data thead tr").show();
        $("table#data tbody tr").show();
        $("#data_type_glossary").show();
        $("#data_value_glossary").show();
      } else if (secId == "other") {
        $("table#data thead tr").show();
        $("table#data tbody tr").hide();
        $("table#data tbody tr.section_other").show();
        $("#data_type_glossary").hide();
        $("#data_value_glossary").hide();
      } else if (secId == "type_glossary") {
        $("table#data thead tr").hide();
        $("table#data tbody tr").hide();
        $("#data_type_glossary").show();
        $("#data_value_glossary").hide();
      } else if (secId == "value_glossary") {
        $("table#data thead tr").hide();
        $("table#data tbody tr").hide();
        $("#data_type_glossary").hide();
        $("#data_value_glossary").show();
      } else {
        $("table#data thead tr").show();
        $("table#data tbody tr").hide();
        $("table#data tbody tr.section_"+secId).show();
        $("#data_glossary").hide();
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
    console.log("READY.");
    if ($(".eol-flash").length === 1) {
      var flash = $(".eol-flash");
      UIkit.notification({
          message: $(".eol-flash").data("text"),
          status: 'primary',
          pos: 'top-center',
          offset: '100px',
          timeout: 10000
      });
    }

    if ($("#topics").length === 1) {
      console.log("Fetching topics...");
      $.ajax({
        url: "/pages/topics.js",
        cache: false
      });
    }

    if ($(".page_topics").length >= 1) {
      console.log("Fetching page comments...");
      $.ajax({
        url: "/pages/"+$($(".page_topics")[0]).data("id")+"/comments.js",
        cache: false
      });
    }

    $(".disable-on-click").on("click", function() {
      $(this).closest(".button").addClass("disabled loading");
    });

    if ($("#gallery").length === 1) {
      EOL.enable_media_navigation();
    } else if ($("#page_data").length === 1) {
      EOL.enable_data_toc();
      EOL.meta_data_toggle();
    } else if ($("#data_table").length === 1) {
      EOL.allow_meta_data_to_toggle();
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
      // TODO: I'm not sure this is ever used. Check and remove, if not.
      $.getScript(location.href);
    });

    // TODO: move this.
    EOL.searchNames = new Bloodhound({
      datumTokenizer: Bloodhound.tokenizers.obj.whitespace('value'),
      queryTokenizer: Bloodhound.tokenizers.whitespace,
      // TODO: someday we should have a pre-populated list of common search terms
      // and load that here. prefetch: '../data/films/post_1960.json',
      remote: {
        url: '/pages/autocomplete?query=%QUERY',
        wildcard: '%QUERY'
      },
      limit: 10
    });
    EOL.searchNames.initialize();
    // And this...
    EOL.searchUsers = new Bloodhound({
      datumTokenizer: Bloodhound.tokenizers.obj.whitespace('value'),
      queryTokenizer: Bloodhound.tokenizers.whitespace,
      // TODO: someday we should have a pre-populated list of common search terms
      // and load that here. prefetch: '../data/films/post_1960.json',
      remote: {
        url: '/users/autocomplete?query=%QUERY',
        wildcard: '%QUERY'
      },
      limit: 10
    });
    EOL.searchUsers.initialize();

    // Aaaaand this...
    EOL.searchPredicates = new Bloodhound({
      datumTokenizer: Bloodhound.tokenizers.obj.whitespace('name'),
      queryTokenizer: Bloodhound.tokenizers.whitespace,
      remote: {
        url: '/terms/predicate_glossary.json?query=%QUERY',
        wildcard: '%QUERY'
      },
      limit: 10
    });
    EOL.searchPredicates.initialize();

    // And this!
    EOL.searchObjectTerms = new Bloodhound({
      datumTokenizer: Bloodhound.tokenizers.obj.whitespace('name'),
      queryTokenizer: Bloodhound.tokenizers.whitespace,
      remote: {
        url: '/terms/object_term_glossary.json?query=%QUERY',
        wildcard: '%QUERY'
      },
      limit: 10
    });
    EOL.searchObjectTerms.initialize();

    $('#nav-search .ui.search')
      .search({
        apiSettings: {
          url: '/pages/autocomplete?query={query}'
        }
      })
    ;

    if ($('#nav-search .typeahead').length >= 1) {
      console.log("Enable navigation typeahead.");
      $('#nav-search .typeahead').typeahead(null, {
        name: 'search-names',
        display: 'scientific_name',
        source: EOL.searchNames,
        templates: {
          suggestion: function (datum) {
              return "<p><i>" + datum.scientific_name + "</i> (" + datum.preferred_vernacular_strings[0] + ")</p>";
          }
        }
      }).bind('typeahead:selected', function(evt, datum, name) {
        console.log('typeahead:selected:', evt, datum, name);
        window.location.href = '/pages/' + datum.id;
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
        display: 'scientific_name',
        source: EOL.searchNames
      }).bind('typeahead:selected', function(evt, datum, name) {
        console.log('typeahead:selected:', evt, datum, name);
        $(".clade_filter form input#clade").val(datum.id);
        $(".clade_filter form").submit();
      });
    };

    if ($('.find_users .typeahead').length >= 1) {
      console.log("Enable username typeahead.");
      $('.find_users .typeahead').typeahead(null, {
        name: 'find-usernames',
        display: 'username',
        source: EOL.searchUsers
      }).bind('typeahead:selected', function(evt, datum, name) {
        console.log('typeahead:selected:', evt, datum, name);
        $("form.find_users_form input#user_id").val(datum.id)
        $("form.find_users_form").submit();
      });
    };

    if ($('.predicate_filter .typeahead').length >= 1) {
      console.log("Enable predicate typeahead.");
      $('.predicate_filter .typeahead').typeahead(null, {
        name: 'find-predicates',
        display: 'predicates',
        source: EOL.searchPredicates,
        display: "name",
      }).bind('typeahead:selected', function(evt, datum, name) {
        console.log('typeahead:selected:', evt, datum, name);
        $(".predicate_filter form input#and_predicate").val(datum.uri);
        $(".predicate_filter form").submit();
      });
    };

    if ($('.object_filter .typeahead').length >= 1) {
      console.log("Enable object typeahead.");
      $('.object_filter .typeahead').typeahead(null, {
        name: 'find-object-terms',
        display: 'object-terms',
        source: EOL.searchObjectTerms,
        display: "name",
      }).bind('typeahead:selected', function(evt, datum, name) {
        console.log('typeahead:selected:', evt, datum, name);
        $(".object_filter form input#and_object").val(datum.uri);
        $(".object_filter form").submit();
      });
    };

    // Clean up duplicate search icons, argh:
    if ($(".uk-search-icon > svg:nth-of-type(2)").length >= 1) {
      $(".uk-search-icon > svg:nth-of-type(2)");
    };
  };
}

$(document).on("ready page:load page:change", EOL.ready);
