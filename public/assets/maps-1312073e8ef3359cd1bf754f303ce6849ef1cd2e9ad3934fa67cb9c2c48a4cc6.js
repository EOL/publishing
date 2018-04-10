EoLMap                  = {};
EoLMap.recs             = null;
EoLMap.map              = null;
EoLMap.markerClusterer  = null;
EoLMap.markers          = [];
EoLMap.infoWindow       = null;

var markerSpiderfier = null;    //for spiderfy
var statuz      = [];           //for back button
var statuz_all  = [];           //for next button
var initial_map = false;        //for original map

function clustersOnOff()
{
    if ($('#goRadioText')[0].innerHTML == "Clusters ON") {$('#goRadioText')[0].innerHTML = "Clusters OFF";}
    else                                             {$('#goRadioText')[0].innerHTML = "Clusters ON";}
    EoLMap.change();
}

function get_center_lat_long(data)
{
    var bound = new google.maps.LatLngBounds();
    EoLMap.recs = data.records;
    var numMarkers = EoLMap.recs.length;
    for (var i = 0; i < numMarkers; i++)
    {
      bound.extend( new google.maps.LatLng(EoLMap.recs[i].h, EoLMap.recs[i].i) ); //h=lat ; i=lon
    }
    return bound.getCenter();
}

EoLMap.init = function(data) {

  //start centering map
  center_latlong = get_center_lat_long(data);
  var latlng = new google.maps.LatLng(center_latlong.lat(), center_latlong.lng());
  //end centering map

  var options = {
    'zoom': 2,
    'center': latlng,
    'mapTypeId': google.maps.MapTypeId.ROADMAP,
    'scaleControl': true};

  EoLMap.map = new google.maps.Map($('#map-canvas')[0], options);

  //start customized controls
  var centerControlDiv = document.createElement('div');
  var centerControl = new CenterControl(centerControlDiv, EoLMap.map, 1);
  centerControlDiv.index = 1;
  centerControlDiv.style['padding-top'] = '10px';
  EoLMap.map.controls[google.maps.ControlPosition.TOP_CENTER].push(centerControlDiv);
  //end customized controls

  EoLMap.recs = data.records;
  $('#total_markers')[0].innerHTML = data.actual + "<br>Plotted: " + data.count;


  EoLMap.map.enableKeyDragZoom();  //for key-drag-zoom

  //start spiderfy
  var spiderConfig = {keepSpiderfied: true, event: 'mouseover'};
  markerSpiderfier = new OverlappingMarkerSpiderfier(EoLMap.map, spiderConfig);
  //end spiderfy

  EoLMap.infoWindow = new google.maps.InfoWindow();
  EoLMap.showMarkers();
  google.maps.event.addListener(EoLMap.map, 'idle', function(){record_history();}); //for back-button    //other option for event 'tilesloaded'

};

EoLMap.showMarkers = function() {
  EoLMap.markers = [];

  if (EoLMap.markerClusterer) {
    EoLMap.markerClusterer.clearMarkers();
  }

  var panel = $('#markerlist')[0];
  panel.innerHTML = '';

  var numMarkers = EoLMap.recs.length;

  for (var i = 0; i < numMarkers; i++) {
    var titleText = EoLMap.recs[i].a; //catalogNumber
    if (titleText === '') {
      titleText = 'No catalog number';
    }

    var item = document.createElement('DIV');
    var title = document.createElement('A');
    title.href = '#';
    title.className = 'title';
    title.innerHTML = titleText;

    item.appendChild(title);
    panel.appendChild(item);

    var latLng = new google.maps.LatLng(EoLMap.recs[i].h, EoLMap.recs[i].i); //h=lat ; i=lon
    var marker = new google.maps.Marker({
      'position': latLng,
      'icon': "https://storage.googleapis.com/support-kms-prod/SNP_2752125_en_v0"
    });

    var fn = EoLMap.markerClickFunction(EoLMap.recs[i], latLng);
    google.maps.event.addListener(marker, 'click', fn);
    google.maps.event.addDomListener(title, 'click', fn);
    EoLMap.markers.push(marker);

    //start spiderfy
    markerSpiderfier.addMarker(marker); // Adds the Marker to OverlappingMarkerSpiderfier
    //end spiderfy

  }//end looping of markers

  //start spiderfy
  markerSpiderfier.addListener('click', function(marker, e) {EoLMap.infoWindow.open(EoLMap.map, marker);});
  markerx = EoLMap.markers;
  markerSpiderfier.addListener('spiderfy', function(markerx) {EoLMap.infoWindow.close();});
  //end spiderfy

  window.setTimeout(EoLMap.time, 0);
};

EoLMap.markerClickFunction = function(pic, latlng) {
  return function(e) {
    e.cancelBubble = true;
    e.returnValue = false;
    if (e.stopPropagation) {
      e.stopPropagation();
      e.preventDefault();
    }

    /*
    $header['a'] = "catalogNumber";
    $header['b'] = "sciname";
    $header['c'] = "publisher";
    $header['d'] = "publisher_id";
    $header['e'] = "dataset";
    $header['f'] = "dataset_id";
    $header['g'] = "gbifID";
    $header['h'] = "lat";
    $header['i'] = "lon";
    $header['j'] = "recordedBy";
    $header['k'] = "identifiedBy";
    $header['l'] = "pic_url";
    $header['m'] = "eventDate";
    */

    var title = pic.b;                                                                                                              //sciname
    var infoHtml = '<div class="info"><h3>' + title + '</h3>';
    if(pic.l)       {infoHtml += '<div class="info-body"><img src="' + pic.l + '" class="info-img"/></div><br/>';}                  //pic_url
    if(pic.a) {infoHtml += 'Catalog number: ' + pic.a + '<br/>';}                                                                   //catalogNumber
    infoHtml += 'Source portal: <a href="https://www.gbif.org/occurrence/' + pic.g + '" target="_blank">GBIF record</a>' + '<br/>' + //gbifID
                'Publisher: <a href="https://www.gbif.org/publisher/' + pic.d + '" target="_blank">' + pic.c + '</a><br/>' +         //publisher_id & publisher
                'Dataset: <a href="https://www.gbif.org/dataset/' + pic.f + '" target="_blank">' + pic.e + '</a><br/>';              //dataset_id & dataset
    if(pic.j)   {infoHtml += 'Recorded by: ' + pic.j + '<br/>';}                                                                    //recordedBy
    if(pic.k) {infoHtml += 'Identified by: ' + pic.k + '<br/>';}                                                                    //identifiedBy
    if(pic.m) {infoHtml += 'Event date: ' + pic.m + '<br/>';}                                                                       //eventDate
    infoHtml += '</div>';


    /*
    var title = pic.sciname;
    var infoHtml = '<div class="info"><h3>' + title + '</h3>';
    if(pic.pic_url)       {infoHtml += '<div class="info-body"><img src="' + pic.pic_url + '" class="info-img"/></div><br/>';}
    if(pic.catalogNumber) {infoHtml += 'Catalog number: ' + pic.catalogNumber + '<br/>';}
    infoHtml += 'Source portal: <a href="https://www.gbif.org/occurrence/' + pic.gbifID + '" target="_blank">GBIF data</a>' + '<br/>' +
                'Publisher: <a href="https://www.gbif.org/publisher/' + pic.publisher_id + '" target="_blank">' + pic.publisher + '</a><br/>' +
                'Dataset: <a href="https://www.gbif.org/dataset/' + pic.dataset_id + '" target="_blank">' + pic.dataset + '</a><br/>';
    if(pic.recordedBy)   {infoHtml += 'Recorded by: ' + pic.recordedBy + '<br/>';}
    if(pic.identifiedBy) {infoHtml += 'Identified by: ' + pic.identifiedBy + '<br/>';}
    if(pic.eventDate) {infoHtml += 'Date recorded: ' + pic.eventDate + '<br/>';}
    infoHtml += '</div>';
    */

    EoLMap.infoWindow.setContent(infoHtml);
    EoLMap.infoWindow.setPosition(latlng);
    EoLMap.infoWindow.open(EoLMap.map);
  };
};

EoLMap.clear = function() {
  for (var i = 0, marker; marker = EoLMap.markers[i]; i++) {marker.setMap(null);}
};

EoLMap.change = function() {
  EoLMap.clear();
  EoLMap.showMarkers();
};

EoLMap.time = function() {
    if (!document.getElementById("goRadioText")) {EoLMap.markerClusterer = new MarkerClusterer(EoLMap.map, EoLMap.markers);}
    else
    {
        if ($('#goRadioText')[0].innerHTML == "Clusters ON") {
            EoLMap.markerClusterer = new MarkerClusterer(EoLMap.map, EoLMap.markers);
        }
        else {
            for (var i = 0, marker; marker = EoLMap.markers[i]; i++) {marker.setMap(EoLMap.map);}
        }
    }
};

$(function() {
  var jsonPath = $('#map-canvas').data('jsonPath');
  $.getJSON(jsonPath, EoLMap.init)
});
var currCenter = "";

function goFullScreen()
{
    currCenter = EoLMap.map.getCenter();

    var elem = document.getElementById("gmap"); // gmap or map-container
    if (!document.fullscreenElement && !document.mozFullScreenElement && !document.webkitFullscreenElement && !document.msFullscreenElement )
    {
        $('#goFullText')[0].innerHTML = "Fullscreen ON";

        if ($('#goPanelText')[0].innerHTML == "Panel ON") {
            $('#panel')[0].style.height      = "100%";
            $('#panel')[0].style.width       = "17%";
            $('#map-canvas')[0].style.height = "100%";
            $('#map-canvas')[0].style.width  = "83%";
        }
        else {
            $('#panel')[0].style.height      = "0px";
            $('#panel')[0].style.width       = "0px";
            $('#map-canvas')[0].style.height = "100%";
            $('#map-canvas')[0].style.width  = "100%";
        }

        if      (elem.requestFullscreen)      {elem.requestFullscreen();}
        else if (elem.msRequestFullscreen)    {elem.msRequestFullscreen();}
        else if (elem.mozRequestFullScreen)   {elem.mozRequestFullScreen();}
        else if (elem.webkitRequestFullscreen) {
            elem.style.width = "100%";
            elem.style.height = "100%";
            elem.webkitRequestFullscreen(); //Element.ALLOW_KEYBOARD_INPUT
        }
    }
    else
    {
          $('#goFullText')[0].innerHTML = "Fullscreen OFF";
          if ($('#goPanelText')[0].innerHTML == "Panel ON")
          {
              $('#panel')[0].style.height      = "500px";
              $('#panel')[0].style.width       = "200px"; //400
              $('#map-canvas')[0].style.height = "500px";
              $('#map-canvas')[0].style.width  = "700px"; //800
          }
          else
          {
              $('#panel')[0].style.height      = "0px";
              $('#panel')[0].style.width       = "0px";
              $('#map-canvas')[0].style.height = "500px";
              $('#map-canvas')[0].style.width  = "900px"; //1200
          }

          if      (document.exitFullscreen) {document.exitFullscreen();}
          else if (document.msExitFullscreen) {document.msExitFullscreen();}
          else if (document.mozCancelFullScreen) {document.mozCancelFullScreen();}
          else if (document.webkitExitFullscreen) {
            elem.style.width = "";
            document.webkitExitFullscreen();
          }
    }

    google.maps.event.trigger(EoLMap.map, 'resize');
    EoLMap.map.setCenter(currCenter);
}

// start: listeners for fullscreenchanges
if (document.addEventListener) {
    document.addEventListener('webkitfullscreenchange', exitHandler, false);
    document.addEventListener('mozfullscreenchange', exitHandler, false);
    document.addEventListener('fullscreenchange', exitHandler, false);
    document.addEventListener('MSFullscreenChange', exitHandler, false);
}
function exitHandler() {

    if(is_full_screen)
    {
        if(!document.webkitIsFullScreen) {
            $('#goFullText')[0].innerHTML = "Fullscreen OFF";
            var elem = document.getElementById("gmap"); //gmap or map-container
            elem.style.width = "";
        }
        if(document.mozFullScreen) $('#goFullText')[0].innerHTML = "Fullscreen ON";
    }

    if(!is_full_screen()) {
        if ($('#goPanelText')[0].innerHTML == "Panel ON") {
            $('#panel')[0].style.height      = "500px";
            $('#panel')[0].style.width       = "200px"; //400
            $('#map-canvas')[0].style.height = "500px";
            $('#map-canvas')[0].style.width  = "700px"; //800
        }
        else {
            $('#map-canvas')[0].style.height = "500px";
            $('#map-canvas')[0].style.width  = "900px"; //1200
        }
    }

    google.maps.event.trigger(EoLMap.map, 'resize');
    EoLMap.map.setCenter(currCenter);
}
// end: listeners for fullscreenchanges

function is_full_screen()
{
    var elem = document.getElementById("gmap"); //gmap or map-container
    if      (elem.requestFullscreen) {}
    else if (elem.msRequestFullscreen) {
        if (document.msFullscreenElement == true) return true;
    }
    else if (elem.mozRequestFullScreen) {
        if (document.mozFullScreen == true) return true;
    }
    else if (elem.webkitRequestFullscreen) {
        if (document.webkitIsFullScreen == true) return true;
    }
    return false;
}

function panelShowHide()
{
    if ($('#goPanelText')[0].innerHTML == "Panel ON") $('#goPanelText')[0].innerHTML = "Panel OFF";
    else                                          $('#goPanelText')[0].innerHTML = "Panel ON";

    if (is_full_screen())
    {
        $('#map-canvas')[0].style.height = "100%";
        if ($('#goPanelText')[0].innerHTML == "Panel ON")
        {
            $('#panel')[0].style.width       = "17%";
            $('#panel')[0].style.height      = "100%";
            $('#map-canvas')[0].style.width  = "83%";
        }
        else
        {
            $('#panel')[0].style.width       = "0px";
            $('#panel')[0].style.height      = "0px";
            $('#map-canvas')[0].style.width  = "100%";
        }
    }
    else //not full screen
    {
        $('#map-canvas')[0].style.height = "500px";
        if ($('#goPanelText')[0].innerHTML == "Panel ON")
        {
            $('#panel')[0].style.width       = "200px"; //400
            $('#panel')[0].style.height      = "500px";
            $('#map-canvas')[0].style.width  = "700px"; //800
        }
        else
        {
            $('#panel')[0].style.width      = "0px";
            $('#panel')[0].style.height     = "0px";
            $('#map-canvas')[0].style.width = "900px"; //1200
        }
    }

    currCenter = EoLMap.map.getCenter();
    google.maps.event.trigger(EoLMap.map, 'resize');
    EoLMap.map.setCenter(currCenter);
}

//start back button
function record_history()
{
    var current = {};
    current.center = EoLMap.map.getCenter();
    current.zoom = EoLMap.map.getZoom();
    current.mapTypeId = EoLMap.map.getMapTypeId();
    statuz.push(current);
    statuz_all.push(current);
    if(!initial_map) initial_map = current;
    currCenter = EoLMap.map.getCenter();
}
EoLMap.back = function()
{
    if(statuz.length > 1) {
        statuz.pop();
        var current = statuz.pop();
        EoLMap.map.setOptions(current);
        if(JSON.stringify(current) == JSON.stringify(initial_map)){
            statuz = [];
            statuz_all = [];
        }
    }
}
EoLMap.next = function()
{
    if(statuz_all.length > 1) {
        statuz_all.pop();
        var current = statuz_all.pop();
        EoLMap.map.setOptions(current);
        if(JSON.stringify(current) == JSON.stringify(initial_map)){
            statuz = [];
            statuz_all = [];
        }
    }
}
//end back button

//start customized controls
function CenterControl(controlDiv, map, ctrl_type) {

    // Set GO BACK button
    var goBackUI = document.createElement('div');
    goBackUI.id = 'goBackUI';                       //.id here is used in HTML <style>
    goBackUI.title = 'Go back one step';
    controlDiv.appendChild(goBackUI);
    // CSS for text
    var goBackText = document.createElement('div');
    goBackText.id = 'goBackText';
    goBackText.innerHTML = 'Go Back';
    goBackUI.appendChild(goBackText);

    // Set MOVE NEXT button
    var goNextUI = document.createElement('div');
    goNextUI.id = "goNextUI";
    goNextUI.title = 'Move forward one step';
    controlDiv.appendChild(goNextUI);
    // CSS for text
    var goNextText = document.createElement('div');
    goNextText.id = 'goNextText';
    goNextText.innerHTML = 'Move Next';
    goNextUI.appendChild(goNextText);

    // Set Original pos button
    var goOrigUI = document.createElement('div');
    goOrigUI.id = "goOrigUI";
    goOrigUI.title = 'Back to original map';
    controlDiv.appendChild(goOrigUI);
    // CSS for text
    var goOrigText = document.createElement('div');
    goOrigText.id = 'goOrigText';
    goOrigText.innerHTML = 'Initial Map';
    goOrigUI.appendChild(goOrigText);

    if(ctrl_type == 1) //for Cluster maps
    {
        // Set Cluster button
        var goRadioUI = document.createElement('div');
        goRadioUI.id = "goRadioUI";
        goRadioUI.title = 'Toggle Clustering';
        controlDiv.appendChild(goRadioUI);
        // CSS for text
        var goRadioText = document.createElement('div');
        goRadioText.id = 'goRadioText';
        goRadioText.innerHTML = 'Clusters ON';
        goRadioUI.appendChild(goRadioText);

        // Set up the click event listener
        goRadioUI.addEventListener('click', function() {clustersOnOff();});
    }

    // Set Panel button
    var goPanelUI = document.createElement('div');
    goPanelUI.id = "goPanelUI";
    goPanelUI.title = 'Toggle Panel';
    controlDiv.appendChild(goPanelUI);
    // CSS for text
    var goPanelText = document.createElement('div');
    goPanelText.id = 'goPanelText';
    goPanelText.innerHTML = 'Panel OFF';
    goPanelUI.appendChild(goPanelText);

    // Set Fullscreen button
    var goFullUI = document.createElement('div');
    goFullUI.id = "goFullUI";
    goFullUI.title = 'Toggle Fullscreen';
    controlDiv.appendChild(goFullUI);
    // CSS for text
    var goFullText = document.createElement('div');
    goFullText.id = 'goFullText';
    goFullText.innerHTML = 'Fullscreen OFF';
    goFullUI.appendChild(goFullText);

    // Set up the click event listener
    goBackUI.addEventListener('click', function() {EoLMap.back();});
    goNextUI.addEventListener('click', function() {EoLMap.next();});
    goOrigUI.addEventListener('click', function() {EoLMap.map.setOptions(initial_map);
        statuz = [];
        statuz_all = [];
    });
    goPanelUI.addEventListener('click', function() {panelShowHide();});
    goFullUI.addEventListener('click', function() {goFullScreen();});
}
//end customized controls
;


