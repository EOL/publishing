$(document).ready(function($){
	$('#column_chart_link').click(function(){
		alert("right");
		$.ajax({
			url: "/users/draw_column_chart",
			type: "POST",
			success: function (data) {
				$("chart").html(data);
			}
		});
	});
});
