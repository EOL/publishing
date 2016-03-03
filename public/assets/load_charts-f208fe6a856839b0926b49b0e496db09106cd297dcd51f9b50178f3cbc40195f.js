$(document).ready(function($){
	$('#column_chart_link').click(function(){
		alert("RIGHT");
		$('#chart').html('#{escape_javascript(render partial: "line_chart")}');
	});
});
