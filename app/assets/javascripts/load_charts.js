$(document).ready(function($){
	$('#column_chart_link').click(function(){
		$.ajax({
			url: "/users/draw_column_chart",
			type: "GET",
			success: function (data) {
				$("#chart").html(data);
			}
		});
	});
	
	$('#line_chart_link').click(function(){
		$.ajax({
			url: "/users/draw_line_chart",
			type: "GET",
			success: function (data) {
				$("#chart").html(data);
			}
		});
	});
	
	$('#pie_chart_link').click(function(){
		$.ajax({
			url: "/users/draw_pie_chart",
			type: "GET",
			success: function (data) {
				$("#chart").html(data);
			}
		});
	});
	
});
