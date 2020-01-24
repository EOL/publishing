(function() {
  function buildPieChart() {
    var width = 450
      , height = width
      , margin = 50
      , radius = Math.min(width, height) / 2 - margin
      ;

    var svg = d3.select('.js-object-pie-chart')
      .append('svg')
        .attr('width', width)
        .attr('height', height)
      .append('g')
        .attr("transform", "translate(" + width / 2 + "," + height / 2 + ")");

    // Create dummy data
    var data = {a: 9, b: 20, c:30, d:8, e:12}

    var color = d3.scaleOrdinal()
      .domain(data)
      .range(d3.schemeAccent)

    console.log(color('a'));
    
    // Compute the position of each group on the pie:
    var pie = d3.pie()
      .value(function(d) {return d.value; })
    var data_ready = pie(d3.entries(data))

    // Build the pie chart: Basically, each part of the pie is a path that we build using the arc function.
    svg
      .selectAll('whatever')
      .data(data_ready)
      .enter()
      .append('path')
      .attr('d', d3.arc()
        .innerRadius(0)
        .outerRadius(radius)
      )
      .attr('fill', function(d){ return(color(d.data.key)) })
      .attr("stroke", "black")
      .style("stroke-width", "2px")
      .style("opacity", 0.7)
  }

  $(function() {
    if ($('.js-object-pie-chart').length) {
      buildPieChart();
    }
  })
})();
