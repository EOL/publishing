$(document).ready(function(){
  $("#main_search_autocomplete").autocomplete({
    minLength: 3,
    source: get_objects
  });
});
 
function get_objects(request, response){
  var params = {q: request.term};
  $.get("/autocomplete", params, function(data){
    response(data);
  }, "json");
}
 