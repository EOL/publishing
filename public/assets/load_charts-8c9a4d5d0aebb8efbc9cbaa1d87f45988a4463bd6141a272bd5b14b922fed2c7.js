$(document).ready(function($){
	$('#column_chart_link').click(function(){
		alert("right");
		$.ajax({
			url: draw_column_chart_users_path,
			type: "POST",
			success: function (data) {
				$("chart").html(data);
			}
		});
	});
});
