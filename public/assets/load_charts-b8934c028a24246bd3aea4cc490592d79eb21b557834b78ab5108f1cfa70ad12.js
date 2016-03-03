$(document).ready(function($){
	$('#column_chart_link').click(function(){
		$.ajax({
			url: "/users/draw_column_chart",
			type: "POST",
			success: function (data) {
				alert(data);
				$("#chart").html(data);
			}
		});
	});
});
